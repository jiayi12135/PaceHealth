"""
AI功能的路由,单独拆出来是为了方便backend队友直接把它"插"进他自己的FastAPI主项目。

他那边只需要:
    from ai_service.app.router import router as ai_router
    app.include_router(ai_router, prefix="/ai")

就能在他的主app里多出 /ai/generate-plan 这个接口,不用另外起一个服务、
也不用处理跨服务的网络请求。
"""

from fastapi import APIRouter, HTTPException

from app.models import GeneratePlanRequest, WorkoutPlan
from app.claude_client import generate_workout_plan

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
