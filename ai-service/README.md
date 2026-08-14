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
python3 test_local.py         # 测试生成计划功能
python3 test_chat_local.py    # 测试聊天功能
python3 test_report_local.py  # 测试周报/月报功能
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

这样他的项目就会多出四个接口:

- `GET /ai/health` — 检查AI服务是否正常
- `POST /ai/generate-plan` — 传入用户数据,返回生成的训练计划
- `POST /ai/chat` — 聊天,传入这次的消息 + 之前的聊天记录,返回AI的回复
- `POST /ai/report` — 周报/月报,传入这个周期的体重记录,返回算好的数字 + AI总结

### 生成计划 —— 请求格式

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

### 生成计划 —— 返回格式

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

### 聊天 —— 请求格式

`profile` / `personalInfo` 是可选的,不传的话AI还是能聊,只是给不出针对这个用户的个性化建议。`history` 是这个用户之前的聊天记录,backend需要从 `Chat Record` 表里查出来按时间顺序传过来(role只能是 `"user"` 或 `"assistant"`),这样AI才知道之前聊了什么。

```json
{
  "userId": "string",
  "message": "我想把深蹲换成别的动作,有什么推荐吗?",
  "history": [
    { "role": "user", "message": "我今天练完深蹲膝盖有点酸,正常吗?" },
    { "role": "assistant", "message": "轻微酸胀通常是正常的..." }
  ],
  "profile": { "...": "同上面生成计划的格式,可选" },
  "personalInfo": { "...": "同上面生成计划的格式,可选" }
}
```

### 聊天 —— 返回格式

```json
{
  "reply": "string"
}
```

注意:聊天功能目前**不会**直接修改数据库里的计划。如果用户想调整,AI只会在对话里给建议,backend/frontend 需要引导用户重新走一次 `/ai/generate-plan`(或者之后再加一个"应用这个建议"的功能)。

### 周报/月报 —— 请求格式

`weightRecords` 需要backend自己从 `Weight Record` 表按时间范围(本周/本月)查出来,**按 `recordedAt` 从早到晚排序**再传过来,这个AI服务不会自己查数据库、不会自己判断日期范围。

```json
{
  "userId": "string",
  "periodType": "weekly",
  "profile": { "...": "同上面生成计划的格式,必填(需要targetWeightKg和currentWeightKg来算进度)" },
  "weightRecords": [
    { "weightKg": 68.0, "recordedAt": "2026-08-08" },
    { "weightKg": 67.8, "recordedAt": "2026-08-10" },
    { "weightKg": 67.2, "recordedAt": "2026-08-14" }
  ]
}
```

`periodType` 只能是 `"weekly"` 或 `"monthly"`,只是影响AI总结文字里怎么措辞(说"这周"还是"这个月"),不影响计算逻辑。

### 周报/月报 —— 返回格式

```json
{
  "periodType": "weekly",
  "hasEnoughData": true,
  "startWeightKg": 68.0,
  "endWeightKg": 67.2,
  "deltaKg": -0.8,
  "progressToGoalPercent": 10.0,
  "projectedWeeksToGoal": 7.7,
  "summary": "string",
  "weightRecords": [
    { "weightKg": 68.0, "recordedAt": "2026-08-08" },
    { "weightKg": 67.2, "recordedAt": "2026-08-14" }
  ]
}
```

注意:

- `startWeightKg` / `endWeightKg` / `deltaKg` / `progressToGoalPercent` / `projectedWeeksToGoal` 这几个数字**全部是Python代码算出来的,不是AI生成的**,保证准确,AI只写 `summary` 这段总结文字
- 如果这个周期内的体重记录少于2条,`hasEnoughData` 会是 `false`,上面几个数字字段全部是 `null`,`summary` 会是一段鼓励用户多记录体重的话
- `projectedWeeksToGoal` 在当前趋势没有朝目标前进时(比如目标减重但体重反而增加、或者完全没变化)会是 `null`,这种情况 `summary` 里AI会委婉提醒用户
- `weightRecords` 是把请求里传进来的体重记录原样返回,方便Frontend直接拿这个数组画折线图,不用再单独调用Backend的其他接口去查一次

需要提前配置环境变量 `ANTHROPIC_API_KEY`(不要提交到git,放在 `.env` 里)。

## 还没做的部分(后续)

- 拍照识别器材
- 训练完成率追踪(需要backend新增一张表,见 `docs/TEAM_INTEGRATION_GUIDE.md`)
- 聊天里"一键应用AI建议的修改"(目前只能给建议,不能直接改计划)
