"""
本地快速测试器材识别功能。

现在接口改成了传图片URL(配合backend用Supabase Storage存图片的设计),不再是传本地
文件转base64。测试的时候需要一个"公开可访问"的图片链接,Claude的服务器要能直接
访问到这个URL才行,不能是你电脑本地的文件路径。

用法:
    python3 test_equipment_local.py "https://xxx.supabase.co/storage/v1/object/public/xxx.jpg"

如果backend还没把图片上传功能做出来,可以先随便找一张网上健身器材的公开图片链接
（比如维基百科的图片)来测试识别效果,不影响验证AI这边的逻辑对不对。
"""

import sys

from app.mock_data import MOCK_PERSONAL_INFO
from app.claude_client import identify_equipment

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("请提供一个图片URL,用法:")
        print('  python3 test_equipment_local.py "https://xxx.com/dumbbell.jpg"')
        sys.exit(1)

    image_url = sys.argv[1]

    print(f"正在识别 {image_url} ...")
    # 用假的伤病信息测试个性化提醒功能会不会触发
    result = identify_equipment(image_url, MOCK_PERSONAL_INFO)

    print(f"\n识别成功: {result.recognized}")
    print(f"置信度: {result.confidence}")
    if result.recognized:
        print(f"器材名称: {result.equipmentName}")
        print(f"说明: {result.description}")
        print(f"主要练: {', '.join(result.targetMuscles)}")
        print(f"使用方法: {result.usageInstructions}")
        print(f"安全提示: {result.safetyNotes}")
        print(f"个性化提醒: {result.personalizedWarning}")
    else:
        print(f"提示信息: {result.notRecognizedMessage}")
