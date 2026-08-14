"""
封装对 Claude API 的调用。

关键设计: 用 tool use(function calling)强制 Claude 按照固定的 JSON schema
返回结果,而不是让它自由发挥输出文字再自己解析。这样可以避免:
- AI输出多余的解释文字导致JSON解析失败
- 字段名拼错、格式不一致
- 有时候输出markdown代码块包裹JSON导致解析报错
"""

import os
import json
from anthropic import Anthropic
from dotenv import load_dotenv

from typing import List, Optional

from app.models import ChatMessage, Profile, UserPersonalInfo, WorkoutPlan
from app.prompts import (
    PLAN_SYSTEM_PROMPT,
    REPORT_SYSTEM_PROMPT,
    build_user_message,
    build_chat_system_context,
    build_report_user_message,
)
from app.report_calculator import ReportStats

load_dotenv()

client = Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))

MODEL_NAME = "claude-sonnet-4-5-20250929"

# 强制 Claude 按这个 schema 返回结果(对应 models.py 里的 WorkoutPlan)
WORKOUT_PLAN_TOOL = {
    "name": "submit_workout_plan",
    "description": "提交生成好的个性化训练计划",
    "input_schema": {
        "type": "object",
        "properties": {
            "planName": {"type": "string", "description": "计划名称,描述目标和方式即可,不要包含具体周数,例如 '增肌塑形每周训练模板'"},
            "goal": {"type": "string"},
            "weeklyFrequency": {"type": "integer"},
            "exercises": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "day": {"type": "string", "description": "例如 'Monday' 或 'Day 1'"},
                        "exerciseName": {"type": "string"},
                        "sets": {"type": "integer"},
                        "reps": {"type": ["integer", "null"], "description": "力量动作用,没有则为null"},
                        "duration": {"type": ["integer", "null"], "description": "有氧/拉伸动作用,单位秒,没有则为null"},
                        "restSeconds": {"type": "integer"},
                        "reason": {"type": "string", "description": "为什么推荐这个动作给这个用户"},
                        "videoUrl": {"type": ["string", "null"], "description": "示范视频链接,暂时可以为null"},
                    },
                    "required": ["day", "exerciseName", "sets", "restSeconds", "reason"],
                },
            },
        },
        "required": ["planName", "goal", "weeklyFrequency", "exercises"],
    },
}


def generate_workout_plan(profile: Profile, personal_info: UserPersonalInfo) -> WorkoutPlan:
    """调用 Claude API,返回结构化的 WorkoutPlan"""

    user_message = build_user_message(profile, personal_info)

    response = client.messages.create(
        model=MODEL_NAME,
        max_tokens=4096,
        system=PLAN_SYSTEM_PROMPT,
        tools=[WORKOUT_PLAN_TOOL],
        tool_choice={"type": "tool", "name": "submit_workout_plan"},
        messages=[{"role": "user", "content": user_message}],
    )

    # 从返回结果里取出 tool use 的输入(就是我们要的结构化JSON)
    for block in response.content:
        if block.type == "tool_use" and block.name == "submit_workout_plan":
            return WorkoutPlan.model_validate(block.input)

    raise RuntimeError("Claude 没有返回预期的 tool_use 结果,请检查prompt或API返回内容")


def generate_chat_reply(
    message: str,
    history: List[ChatMessage],
    profile: Optional[Profile],
    personal_info: Optional[UserPersonalInfo],
) -> str:
    """调用 Claude API 生成一句聊天回复(纯文字,不强制JSON格式)"""

    system_prompt = build_chat_system_context(profile, personal_info)

    # 把之前的聊天记录转成 Claude API 要求的格式
    # ChatMessage.role 目前只有 "user" / "assistant" 两种,跟 Claude API 的角色名正好一致
    messages = [{"role": m.role, "content": m.message} for m in history]
    messages.append({"role": "user", "content": message})

    response = client.messages.create(
        model=MODEL_NAME,
        max_tokens=1024,
        system=system_prompt,
        messages=messages,
    )

    # 聊天场景下直接取文字回复(没有用tool use,因为不需要固定JSON格式)
    text_blocks = [block.text for block in response.content if block.type == "text"]
    return "".join(text_blocks).strip()


def generate_report_summary(stats: ReportStats, profile: Profile, period_type: str) -> str:
    """调用 Claude API,根据已经算好的体重数据(stats)生成一段总结文字。
    注意: 所有数字都是 report_calculator.py 算好的,这里只是让AI把数字"翻译"成人话,
    AI不会、也不应该自己重新计算任何数字。
    """

    user_message = build_report_user_message(stats, profile, period_type)

    response = client.messages.create(
        model=MODEL_NAME,
        max_tokens=512,
        system=REPORT_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_message}],
    )

    text_blocks = [block.text for block in response.content if block.type == "text"]
    return "".join(text_blocks).strip()
