"""
AI功能的路由,单独拆出来是为了方便backend队友直接把它"插"进他自己的FastAPI主项目。

他那边只需要:
    from ai_service.app.router import router as ai_router
    app.include_router(ai_router, prefix="/ai")

就能在他的主app里多出 /ai/generate-plan 这个接口,不用另外起一个服务、
也不用处理跨服务的网络请求。
"""

from fastapi import APIRouter, HTTPException

from app.models import (
    ChatRequest,
    ChatResponse,
    EquipmentIdentifyRequest,
    EquipmentIdentifyResponse,
    GeneratePlanRequest,
    ReportRequest,
    ReportResponse,
    WorkoutPlan,
)
from app.claude_client import (
    generate_chat_reply,
    generate_report_summary,
    generate_workout_plan,
    identify_equipment,
)
from app.report_calculator import calculate_report_stats

router = APIRouter(tags=["AI"])


@router.get("/health")
def health_check():
    return {"status": "ok"}


@router.post("/generate-plan", response_model=WorkoutPlan)
def generate_plan(request: GeneratePlanRequest):
    try:
        plan = generate_workout_plan(request.profile, request.personalInfo)
        return plan
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"生成计划失败: {str(e)}")


@router.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest):
    """
    聊天接口。backend每次调用时需要把这个用户之前的聊天记录(history)一起传过来,
    因为这个AI服务本身不存数据、不记得之前聊过什么,是backend负责存Chat Record表、
    并且每次都把历史记录带上,AI才能有上下文接着聊。
    """
    try:
        reply = generate_chat_reply(
            message=request.message,
            history=request.history,
            profile=request.profile,
            personal_info=request.personalInfo,
        )
        return ChatResponse(reply=reply)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"聊天回复失败: {str(e)}")


@router.post("/report", response_model=ReportResponse)
def generate_report(request: ReportRequest):
    """
    周报/月报接口。backend需要先从数据库把这个用户在对应周期(本周/本月)内的
    体重记录查出来,按recordedAt从早到晚排序,传进weightRecords。
    数字(体重变化、目标进度、预计周数)由这个服务用代码算,AI只负责写总结文字。
    """
    try:
        stats = calculate_report_stats(request.weightRecords, request.profile)
        summary = generate_report_summary(stats, request.profile, request.periodType)

        return ReportResponse(
            periodType=request.periodType,
            hasEnoughData=stats.has_enough_data,
            initialWeightKg=stats.start_weight_kg,
            endWeightKg=stats.end_weight_kg,
            deltaKg=stats.delta_kg,
            progressToGoalPercent=stats.progress_to_goal_percent,
            projectedWeeksToGoal=stats.projected_weeks_to_goal,
            summary=summary,
            weightRecords=request.weightRecords,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"生成报告失败: {str(e)}")


@router.post("/identify-equipment", response_model=EquipmentIdentifyResponse)
def identify_equipment_endpoint(request: EquipmentIdentifyRequest):
    """
    器材识别接口。imageUrl 需要是一个公开可访问的图片链接(比如Supabase Storage
    生成的URL),backend需要先把用户拍的照片上传到存储、拿到URL,再传给这个接口。
    这里不做视频匹配,只返回文字说明(器材名称、用途、用法、安全提示)。
    """
    try:
        result = identify_equipment(
            image_url=request.imageUrl,
            personal_info=request.personalInfo,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"识别器材失败: {str(e)}")
