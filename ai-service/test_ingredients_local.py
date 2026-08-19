"""
本地快速测试食材识别功能。

用法(需要一个公开可访问的图片URL,同器材识别一样,不能是本地文件路径):
    python3 test_ingredients_local.py "https://xxx.com/fridge.jpg"

如果backend还没把图片上传功能做出来,可以先随便找一张网上冰箱/食材的公开图片链接来测试,
不影响验证AI这边的逻辑对不对。
"""

import json
import sys

from app.claude_client import identify_ingredients

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("请提供一个图片URL,用法:")
        print('  python3 test_ingredients_local.py "https://xxx.com/fridge.jpg"')
        sys.exit(1)

    image_url = sys.argv[1]

    print(f"正在识别 {image_url} ...")
    result = identify_ingredients(image_url)

    print(json.dumps(result.model_dump(), indent=2, ensure_ascii=False))
