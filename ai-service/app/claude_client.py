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

from app.models import ChatMessage, EquipmentIdentifyResponse, Profile, UserPersonalInfo, WorkoutPlan
from app.prompts import (
    PLAN_SYSTEM_PROMPT,
    REPORT_SYSTEM_PROMPT,
    EQUIPMENT_SYSTEM_PROMPT,
    build_user_message,
    build_chat_system_context,
    build_report_user_message,
    build_equipment_user_message,
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

# 强制 Claude 按这个 schema 返回结果(对应 models.py 里的 EquipmentIdentifyResponse)
EQUIPMENT_IDENTIFY_TOOL = {
    "name": "submit_equipment_info",
    "description": "提交识别出的健身器材信息",
    "input_schema": {
        "type": "object",
        "properties": {
            "recognized": {"type": "boolean", "description": "是否成功从照片中识别出健身器材"},
            "confidence": {"type": "number", "description": "0到1之间的小数,表示你对这次识别结果的把握程度,越确定越接近1;如果recognized为false,通常应该是比较低的数字(比如0.1-0.3)"},
            "equipmentName": {"type": ["string", "null"], "description": "器材名称,recognized为false时填null"},
            "description": {"type": ["string", "null"], "description": "这个器材是什么、主要用来练什么,recognized为false时填null"},
            "targetMuscles": {"type": "array", "items": {"type": "string"}, "description": "主要训练的肌群,recognized为false时给空数组"},
            "usageInstructions": {"type": ["string", "null"], "description": "使用步骤说明,recognized为false时填null"},
            "safetyNotes": {"type": ["string", "null"], "description": "安全注意事项和常见错误,recognized为false时填null"},
            "personalizedWarning": {"type": ["string", "null"], "description": "如果这个器材对用户的伤病/体态问题有风险,在这里提醒并给替代建议;没有风险或没有用户信息则为null"},
            "notRecognizedMessage": {"type": ["string", "null"], "description": "recognized为false时,给用户的友好提示(比如建议重新拍摄);recognized为true时填null"},
        },
        "required": ["recognized", "confidence", "targetMuscles"],
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


def identify_equipment(
    image_url: str,
    personal_info: Optional[UserPersonalInfo],
) -> EquipmentIdentifyResponse:
    """调用 Claude 的 vision 能力识别照片里的健身器材,返回结构化结果。

    图片用URL的方式传给Claude(source.type="url"),Claude会自己去访问这个链接读图,
    我们这个服务不需要下载图片、不需要转base64。这要求 image_url 必须是一个
    公开可访问的地址(比如Supabase Storage生成的公开链接),Claude的服务器访问不到
    你自己电脑上的本地文件路径。
    """

    user_message = build_equipment_user_message(personal_info)

    response = client.messages.create(
        model=MODEL_NAME,
        max_tokens=1024,
        system=EQUIPMENT_SYSTEM_PROMPT,
        tools=[EQUIPMENT_IDENTIFY_TOOL],
        tool_choice={"type": "tool", "name": "submit_equipment_info"},
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "url",
                            "url": image_url,
                        },
                    },
                    {"type": "text", "text": user_message},
                ],
            }
        ],
    )

    for block in response.content:
        if block.type == "tool_use" and block.name == "submit_equipment_info":
            return EquipmentIdentifyResponse.model_validate(block.input)

    raise RuntimeError("Claude 没有返回预期的 tool_use 结果,请检查prompt或API返回内容")


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
