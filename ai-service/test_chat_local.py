"""
本地快速测试聊天功能,不需要起服务器,直接跑:
    python3 test_chat_local.py

用假的聊天记录 + 假用户资料,测试AI能不能:
1. 接上之前的聊天上下文
2. 结合用户的伤病信息给出安全的建议
3. 在用户想调整计划时,给建议但提醒需要点"重新生成计划"
"""

from app.mock_data import MOCK_PROFILE, MOCK_PERSONAL_INFO, MOCK_CHAT_HISTORY, MOCK_CHAT_MESSAGE
from app.claude_client import generate_chat_reply

if __name__ == "__main__":
    reply = generate_chat_reply(
        message=MOCK_CHAT_MESSAGE,
        history=MOCK_CHAT_HISTORY,
        profile=MOCK_PROFILE,
        personal_info=MOCK_PERSONAL_INFO,
    )
    print("用户: " + MOCK_CHAT_MESSAGE)
    print("AI: " + reply)
