# AI Service (Prompt / Personalized Plan Generation)

负责人: Stephanie

## 这是什么

根据用户的 Profile + UserPersonalInfo 数据,调用 Claude API 生成个性化的每周训练计划。
输出格式对齐团队约定的 `AI Plan` / `SportsType` 数据表结构。

## 本地测试(不依赖backend项目)

```bash
cd ai-service
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # 然后把 .env 里的 key 换成你自己的
python3 test_local.py  # 用假数据跑一次,检查prompt效果
```

也可以起服务在浏览器里测试:

```bash
uvicorn app.main:app --reload --port 8000
```

打开 http://localhost:8000/docs 有自动生成的接口文档,可以直接在网页上试。

## 给backend队友接入用

不需要另外起一个服务。把这个仓库里的 `app/` 目录(或者直接整个 `ai-service` 文件夹)
放进他的项目里,然后在他的主 FastAPI app 里:

```python
from ai_service.app.router import router as ai_router
app.include_router(ai_router, prefix="/ai")
```

这样他的项目就会多出两个接口:

- `GET /ai/health` — 检查AI服务是否正常
- `POST /ai/generate-plan` — 传入用户数据,返回生成的训练计划

### 请求格式

```json
{
  "userId": "string",
  "profile": {
    "name": "string",
    "age": 28,
    "sex": "female",
    "heightCm": 165,
    "currentWeightKg": 68,
    "targetWeightKg": 60,
    "goal": "lose_weight",
    "lifestyle": "sedentary desk job",
    "exerciseFrequencyPerWeek": 3,
    "exerciseDurationMinutes": 45,
    "exerciseLocation": "home"
  },
  "personalInfo": {
    "availableEquipment": ["dumbbells", "yoga mat"],
    "postureIssues": ["forward head posture"],
    "injuries": ["mild lower back pain"],
    "surgeryHistory": [],
    "exercisesToAvoid": ["heavy deadlifts"]
  }
}
```

### 返回格式

```json
{
  "planName": "string",
  "goal": "string",
  "weeklyFrequency": 3,
  "exercises": [
    {
      "day": "Monday",
      "exerciseName": "string",
      "sets": 3,
      "reps": 12,
      "duration": null,
      "restSeconds": 60,
      "reason": "string",
      "videoUrl": null
    }
  ]
}
```

需要提前配置环境变量 `ANTHROPIC_API_KEY`(不要提交到git,放在 `.env` 里)。

## 还没做的部分(后续)

- Chatbox(健身知识问答 + 调整计划)
- 拍照识别器材
- 根据每周体重变化调整计划的逻辑
