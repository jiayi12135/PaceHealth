"""Bridges the public API to Stephanie's AI service (vendored at app/services/ai/).

Every endpoint here derives the acting user from the bearer token, loads
whatever profile/history/weight data the AI call needs from the database
itself, and persists the AI's structured response — the client never supplies
userId, profile, or raw progress numbers directly (see app/schemas/ai.py for
why). This matches the "backend connects to AI" responsibilities laid out in
docs/TEAM_INTEGRATION_GUIDE.md section 3.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, status
from postgrest.exceptions import APIError as PostgrestAPIError

from app.dependencies.auth import get_current_user
from app.errors import APIError
from app.schemas.ai import (
    ChatRequest,
    ChatResponse,
    DayAssignmentsUpdate,
    MealPlanRequest,
    MealPlanResponse,
    ReportRequest,
    ReportResponse,
    WorkoutPlanResponse,
)
from app.schemas.auth import AuthUser
from app.services.ai.claude_client import (
    generate_chat_reply,
    generate_meal_plan,
    generate_report_summary,
    generate_workout_plan,
)
from app.services.ai.models import ProgressSummary
from app.services.exercise_image_service import fetch_exercise_image_urls
from app.services.ai_bridge import (
    compute_report_stats,
    to_ai_personal_info,
    to_ai_profile,
    to_meal_plan_response,
    to_report_response,
    to_workout_plan_response,
)
from app.services.chat_service import ChatService, get_chat_service
from app.services.workout_service import WorkoutService, get_workout_service
from app.services.plan_service import PlanService, get_plan_service
from app.services.profile_service import ProfileService, get_profile_service
from app.services.report_service import ReportService, get_report_service
from app.services.weight_service import WeightService, get_weight_service


router = APIRouter(prefix="/ai", tags=["ai"])


@router.get("/health")
def ai_health_check() -> dict[str, str]:
    return {"status": "ok"}


# 跟前端workout_session_screen.dart里的skip理由选项一一对应(见_skipReasonLabels),
# 只是这边给的是给AI读的措辞,不是给用户看的按钮文字。收到没在这个映射里的code
# (理论上不该发生,前端是从固定选项里选的)就原样把code显示出来,不报错。
_SKIP_REASON_LABELS = {
    "too_difficult": "too difficult",
    "pain_discomfort": "pain or discomfort",
    "equipment_unavailable": "equipment unavailable",
    "dont_know_how": "didn't know how to perform it",
    "not_enough_space": "not enough space",
    "other": "other reason",
}


def _describe_skip_reason(entry) -> str:
    label = _SKIP_REASON_LABELS.get(entry.skip_reason or "", entry.skip_reason or "no reason given")
    if entry.skip_reason == "other" and entry.skip_reason_note:
        return f"{label}: {entry.skip_reason_note}"
    return label


def _build_adherence_note(workouts: WorkoutService, user_id: str, *, days: int = 14) -> str | None:
    """最近训练完成/跳过记录拼成一段给AI看的摘要——哪些天完成了、哪些跳过了、
    为什么,完成的那天里单个动作又是否被跳过(比如深蹲反复因为pain跳过,即使
    那天整体算完成)。记录本身是系统写的事实,AI只读不编。

    原本只喂给聊天功能用,现在generate-plan生成"新一轮"计划时也要用同一份逻辑,
    所以抽成共用函数,而不是两边各写一份、以后容易改一边漏改另一边。
    Best-effort:查失败就返回None,不阻断调用方。
    """
    try:
        recent = workouts.list_recent(user_id, days=days)
    except PostgrestAPIError:
        return None
    if not recent:
        return None

    parts = []
    for completion in recent[:10]:
        if completion.status == "completed":
            part = f"{completion.day}: completed"
            skipped = [e for e in (completion.exercise_log or []) if e.status == "skipped"][:3]
            if skipped:
                reasons = "; ".join(f"{e.exercise_name} ({_describe_skip_reason(e)})" for e in skipped)
                part += f" but skipped within the session: {reasons}"
            parts.append(part)
        else:
            parts.append(f"{completion.day}: skipped ({completion.reason or 'no reason given'})")
    return "; ".join(parts)


def _require_profile(profiles: ProfileService, user_id: str):
    try:
        profile = profiles.get(user_id)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to load the profile.", "PROFILE_READ_FAILED") from exc

    if profile is None:
        raise APIError(
            404,
            "Complete your profile before using this AI feature.",
            "PROFILE_NOT_FOUND",
        )
    return profile


@router.post("/generate-plan", response_model=WorkoutPlanResponse, status_code=status.HTTP_201_CREATED)
def generate_plan(
    user: Annotated[AuthUser, Depends(get_current_user)],
    profiles: Annotated[ProfileService, Depends(get_profile_service)],
    plans: Annotated[PlanService, Depends(get_plan_service)],
    workouts: Annotated[WorkoutService, Depends(get_workout_service)],
) -> WorkoutPlanResponse:
    profile = _require_profile(profiles, user.user_id)

    # 有值的话说明这不是第一次生成——"新一轮"计划要参考上一轮实际做下来的情况
    # (哪些天完成/跳过、为什么、单个动作反馈)来调整,而不是每周原样重复。
    # 第一次生成(还没有任何记录)这里自然是None,提示词里对应那段就不会出现。
    adherence_note = _build_adherence_note(workouts, user.user_id)

    try:
        plan = generate_workout_plan(
            to_ai_profile(profile.profile),
            to_ai_personal_info(profile.personal_info),
            adherence_note=adherence_note,
        )
    except APIError:
        raise
    except Exception as exc:  # Anthropic SDK errors, malformed tool_use, etc.
        raise APIError(502, "The AI service failed to generate a plan.", "AI_REQUEST_FAILED") from exc

    # Best-effort — a Pexels hiccup should never fail an otherwise-successful
    # plan generation, so guard this even though fetch_exercise_image_urls
    # already catches its own errors internally. Fetched *before* saving (unlike
    # before) so the thumbnail URLs can be persisted alongside the exercise rows —
    # otherwise reloading a saved plan later (GET /ai/plan, e.g. after a restart)
    # would have no image_url to read back.
    try:
        images = fetch_exercise_image_urls(exercise.exerciseName for exercise in plan.exercises)
    except Exception:  # noqa: BLE001
        images = {}

    try:
        plan_id, created_at = plans.save(user.user_id, plan, images)
    except PostgrestAPIError as exc:
        raise APIError(502, "Generated the plan but failed to save it.", "PLAN_WRITE_FAILED") from exc

    return to_workout_plan_response(plan_id, plan, images, created_at=created_at)


@router.get("/plan", response_model=WorkoutPlanResponse)
def latest_plan(
    user: Annotated[AuthUser, Depends(get_current_user)],
    plans: Annotated[PlanService, Depends(get_plan_service)],
) -> WorkoutPlanResponse:
    """Most recently generated plan for this user, so a restored session (see the
    frontend's session-persistence work) doesn't land with an empty Home/Calendar/
    Plan just because the plan itself used to only live in the app's memory."""
    try:
        plan = plans.get_latest(user.user_id)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to load your plan.", "PLAN_READ_FAILED") from exc

    if plan is None:
        raise APIError(404, "No plan generated yet.", "PLAN_NOT_FOUND")
    return plan


@router.put("/plan/day-assignments", status_code=status.HTTP_204_NO_CONTENT)
def save_day_assignments(
    payload: DayAssignmentsUpdate,
    user: Annotated[AuthUser, Depends(get_current_user)],
    plans: Annotated[PlanService, Depends(get_plan_service)],
) -> None:
    """planDay -> weekday map from AssignWorkoutDaysScreen / Plan tab's reschedule,
    persisted so it survives a restart alongside the plan itself."""
    try:
        updated = plans.save_day_assignments(user.user_id, payload.plan_id, payload.assignments)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to save your schedule.", "DAY_ASSIGNMENTS_WRITE_FAILED") from exc

    if not updated:
        raise APIError(404, "Plan not found.", "PLAN_NOT_FOUND")


@router.post("/chat", response_model=ChatResponse)
def chat(
    payload: ChatRequest,
    user: Annotated[AuthUser, Depends(get_current_user)],
    profiles: Annotated[ProfileService, Depends(get_profile_service)],
    chats: Annotated[ChatService, Depends(get_chat_service)],
    weights: Annotated[WeightService, Depends(get_weight_service)],
    workouts: Annotated[WorkoutService, Depends(get_workout_service)],
) -> ChatResponse:
    # Unlike generate-plan/report, chat works without a saved profile — it just
    # can't give personalized advice yet (mirrors ai-service's own behavior).
    try:
        profile = profiles.get(user.user_id)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to load the profile.", "PROFILE_READ_FAILED") from exc

    try:
        history = chats.get_recent_history(user.user_id)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to load chat history.", "CHAT_HISTORY_READ_FAILED") from exc

    # Same constraint data that feeds generate-plan/equipment-scan/report also feeds
    # chat: equipment + injuries via to_ai_personal_info (already used below), and
    # this week's weight progress computed the same way /ai/report and the meal-plan
    # endpoint's recentProgress do — one consistent context, not a separate copy per
    # feature. Best-effort: if weight data can't be loaded, chat still works without it.
    recent_progress = None
    if profile is not None:
        try:
            _, _, _, stats = compute_report_stats(weights, profile.profile, user.user_id, "weekly")
            if stats.has_enough_data:
                recent_progress = ProgressSummary(
                    periodType="weekly",
                    deltaKg=stats.delta_kg,
                    progressToGoalPercent=stats.progress_to_goal_percent,
                )
        except PostgrestAPIError:
            pass

    # 最近14天的训练完成/跳过记录也进同一份context——AI能看到"跳过了几次、为什么",
    # 但记录本身是系统写的事实,AI只读不编。跟generate-plan用的是同一份逻辑
    # (见_build_adherence_note),Best-effort,查失败聊天照常。
    adherence_note = _build_adherence_note(workouts, user.user_id, days=14)

    try:
        reply = generate_chat_reply(
            payload.message,
            history,
            to_ai_profile(profile.profile) if profile else None,
            to_ai_personal_info(profile.personal_info) if profile else None,
            recent_progress,
            adherence_note,
        )
    except APIError:
        raise
    except Exception as exc:
        raise APIError(502, "The AI service failed to reply.", "AI_REQUEST_FAILED") from exc

    try:
        chats.append_exchange(user.user_id, payload.message, reply)
    except PostgrestAPIError as exc:
        raise APIError(502, "Got a reply but failed to save the conversation.", "CHAT_WRITE_FAILED") from exc

    return ChatResponse(reply=reply)


@router.post("/report", response_model=ReportResponse)
def report(
    payload: ReportRequest,
    user: Annotated[AuthUser, Depends(get_current_user)],
    profiles: Annotated[ProfileService, Depends(get_profile_service)],
    weights: Annotated[WeightService, Depends(get_weight_service)],
    reports: Annotated[ReportService, Depends(get_report_service)],
    workouts: Annotated[WorkoutService, Depends(get_workout_service)],
) -> ReportResponse:
    profile = _require_profile(profiles, user.user_id)

    try:
        start, end, weight_points, stats = compute_report_stats(
            weights, profile.profile, user.user_id, payload.period_type
        )
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to load weight records.", "WEIGHT_READ_FAILED") from exc

    # 跟这份报告的周期对齐(周报看7天/月报看30天),这样AI点评的"最近训练情况"
    # 和上面体重趋势看的是同一个时间窗口,不会一个说本周一个说上个月。
    period_days = 7 if payload.period_type == "weekly" else 30
    adherence_note = _build_adherence_note(workouts, user.user_id, days=period_days)

    try:
        summary = generate_report_summary(stats, to_ai_profile(profile.profile), payload.period_type, adherence_note)
    except APIError:
        raise
    except Exception as exc:
        raise APIError(502, "The AI service failed to generate a report.", "AI_REQUEST_FAILED") from exc

    try:
        reports.save(user.user_id, payload.period_type, start, end, stats, summary)
    except PostgrestAPIError as exc:
        raise APIError(502, "Generated the report but failed to save it.", "REPORT_WRITE_FAILED") from exc

    return to_report_response(payload.period_type, stats, summary, weight_points)


@router.post("/generate-meal-plan", response_model=MealPlanResponse)
def generate_meal_plan_endpoint(
    payload: MealPlanRequest,
    user: Annotated[AuthUser, Depends(get_current_user)],
    profiles: Annotated[ProfileService, Depends(get_profile_service)],
    weights: Annotated[WeightService, Depends(get_weight_service)],
) -> MealPlanResponse:
    profile = _require_profile(profiles, user.user_id)

    recent_progress = None
    if payload.include_recent_progress:
        try:
            _, _, _, stats = compute_report_stats(weights, profile.profile, user.user_id, "weekly")
        except PostgrestAPIError as exc:
            raise APIError(502, "Unable to load weight records.", "WEIGHT_READ_FAILED") from exc

        if stats.has_enough_data:
            recent_progress = ProgressSummary(
                periodType="weekly",
                deltaKg=stats.delta_kg,
                progressToGoalPercent=stats.progress_to_goal_percent,
            )
        # If there isn't enough weight data yet, silently skip recentProgress
        # rather than erroring — the meal plan can still be generated without it.

    try:
        plan = generate_meal_plan(
            to_ai_profile(profile.profile),
            payload.available_ingredients,
            payload.dietary_restrictions,
            recent_progress,
        )
    except APIError:
        raise
    except Exception as exc:
        raise APIError(502, "The AI service failed to generate a meal plan.", "AI_REQUEST_FAILED") from exc

    return to_meal_plan_response(plan)
