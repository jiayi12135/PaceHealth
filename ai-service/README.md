# AI Service (Prompt / Personalized Plan Generation)

负责人: Stephanie

## 这是什么

根据用户的 Profile + UserPersonalInfo 数据,调用 Claude API 生成个性化的每周训练计划。
输出格式对齐团队约定的 `AI Plan` / `SportsType` 数据表结构。

后续在原计划基础上加了聊天、周报/月报、拍照识别器材、拍照识别食材、食谱推荐五个功能,细节见下方。

**这个 `ai-service/` 目录是 Stephanie 本地开发/测试用的,最终代码已经合并进了 `backend/app/services/ai/`,由 `backend/app/routers/ai.py` 和 `backend/app/routers/scans.py` 接好了真实的HTTP接口(见 `docs/API_CONTRACT.md`)。这份 README 保留作为理解AI服务本身设计的参考。**

## 本地测试(不依赖backend项目)

```bash
cd ai-service
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # 然后把 .env 里的 key 换成你自己的
python3 test_local.py            # 测试生成计划功能
python3 test_chat_local.py       # 测试聊天功能
python3 test_report_local.py     # 测试周报/月报功能
python3 test_equipment_local.py 你的照片.jpg  # 测试器材识别(需要一张真实的器材照片)
python3 test_ingredients_local.py 你的照片.jpg  # 测试食材识别(需要一张真实的食材/冰箱照片)
python3 test_meal_plan_local.py  # 测试食谱推荐功能
```

## 怎么接入你的项目(给 Backend 队友,原始设计参考)

```python
from app.router import router as ai_router
app.include_router(ai_router, prefix="/ai")
```

这样你的项目就会多出七个接口:

- `GET /ai/health` — 检查AI服务是否正常
- `POST /ai/generate-plan` — 传入用户数据,返回生成的训练计划
- `POST /ai/chat` — 聊天,传入这次的消息 + 之前的聊天记录,返回AI的回复
- `POST /ai/report` — 周报/月报,传入这个周期的体重记录,返回算好的数字 + AI总结
- `POST /ai/identify-equipment` — 拍照识别器材,传入图片URL,返回器材名称 + 使用说明 + 安全提示
- `POST /ai/identify-ingredients` — 拍照识别食材(冰箱/菜篮子),传入图片URL,返回识别出的食材名称+大概份量
- `POST /ai/generate-meal-plan` — 根据用户目标+可用食材(+可选的最近体重进度)生成食谱推荐

需要提前配置环境变量 `ANTHROPIC_API_KEY`(不要提交到git,放在 `.env` 里)。

### 生成计划 —— 请求格式

```json
{
  "userId": "string",
  "profile": {
    "name": "string",
    "age": 28,
    "sex": "female",
    "heightCm": 165,
    "startWeightKg": 68,
    "targetWeightKg": 60,
    "goal": "lose_weight",
    "lifestyle": "sedentary desk job",
    "exerciseFrequencyPerWeek": 3,
    "exerciseDurationMinutes": 45,
    "exerciseHabit": ["dancing", "swimming"],
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
  "goal": "lose_weight",
  "weeklyFrequency": 3,
  "exercises": [
    {
      "day": "Day 1",
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

`reps` 和 `duration` 只有一个会有值(计时类动作用 `duration`,单位秒)。`reason` 是给这个用户推荐这个动作的理由,建议在Frontend展示出来,这是个性化的重点。

### 聊天 —— 请求格式

```json
{
  "message": "string",
  "history": [
    { "role": "user", "content": "string" },
    { "role": "assistant", "content": "string" }
  ],
  "profile": { "...": "同上面生成计划的格式,可选" },
  "personalInfo": { "...": "同上面生成计划的格式,可选" }
}
```

`history` 需要Backend自己从 `Chat Record` 表里查出这个用户之前的对话,按时间顺序传进来——这个AI服务本身不存数据,每次调用都是"无状态"的。

### 聊天 —— 返回格式

```json
{ "reply": "string" }
```

如果AI在回复里建议用户调整计划,不会自动更新数据库里的计划,只是给建议;真正要改计划还是要走 `/ai/generate-plan`。

### 周报/月报 —— 请求格式

`weightRecords` 需要Backend自己从 `Weight Record` 表按时间范围(本周/本月)查出来、按时间从早到晚排序后传过来。`profile` 必填,因为要用 `startWeightKg`(设定目标时的体重)和 `targetWeightKg` 来算进度百分比。

```json
{
  "userId": "string",
  "periodType": "weekly",
  "profile": { "...": "同上面生成计划的格式" },
  "weightRecords": [
    { "weightKg": 68.0, "recordedAt": "2026-08-08" },
    { "weightKg": 67.2, "recordedAt": "2026-08-14" }
  ]
}
```

`periodType` 只能是 `"weekly"` 或 `"monthly"`。

### 周报/月报 —— 返回格式

```json
{
  "periodType": "weekly",
  "hasEnoughData": true,
  "initialWeightKg": 68.0,
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

数字字段(`initialWeightKg`/`endWeightKg`/`deltaKg`/`progressToGoalPercent`/`projectedWeeksToGoal`)是代码算出来的,不是AI算的,保证准确;只有 `summary` 那段话是AI写的。如果这个周期体重记录少于2条,`hasEnoughData` 是 `false`,数字字段全是 `null`,`summary` 会变成鼓励用户多记录体重的话。

### 器材识别 —— 请求格式

`imageUrl` 需要是一个**公开可访问的图片链接**(不是base64、不是本地文件路径)。Backend需要先把用户拍的照片上传到Supabase Storage拿到URL,再传给这个接口。`personalInfo` 可选,传了的话AI会检查这个器材对用户的伤病/体态问题有没有风险。

```json
{
  "userId": "string",
  "imageUrl": "https://xxx.supabase.co/storage/v1/object/public/xxx.jpg",
  "personalInfo": { "...": "同上面生成计划的格式,可选" }
}
```

### 器材识别 —— 返回格式

```json
{
  "recognized": true,
  "confidence": 0.92,
  "equipmentName": "string",
  "description": "string",
  "targetMuscles": ["string"],
  "usageInstructions": "string",
  "safetyNotes": "string",
  "personalizedWarning": null,
  "notRecognizedMessage": null
}
```

如果AI认不出照片里的器材,`recognized` 会是 `false`,其他字段大多是 `null`,只有 `notRecognizedMessage` 有内容(提示用户重新拍摄)。目前是简化版,只有文字说明,**没有**示范视频匹配功能。

### 食材识别 —— 请求格式

跟器材识别用一样的方式传图片:`imageUrl` 必须是**公开可访问**的地址(Backend先把用户拍的冰箱/食材照片上传到Supabase Storage拿到URL,再传过来),不传base64、不传本地文件路径。

```json
{
  "userId": "string",
  "imageUrl": "https://xxx.supabase.co/storage/v1/object/public/xxx.jpg"
}
```

### 食材识别 —— 返回格式

```json
{
  "recognized": true,
  "confidence": 0.85,
  "ingredients": [
    { "name": "鸡蛋", "quantity": "6个" },
    { "name": "西红柿", "quantity": "3个" }
  ],
  "notRecognizedMessage": null
}
```

注意:只要认出至少一样食材,`recognized` 就是 `true`,不要求认全;认不出来时 `ingredients` 是空数组,`notRecognizedMessage` 会提示用户重新拍摄。返回的 `ingredients` 里的 `name` 列表可以直接拿去填 `/ai/generate-meal-plan` 请求里的 `availableIngredients`(把数组里的 `name` 摘出来就行,也可以让用户在Frontend上先编辑增删再提交)。

### 食谱推荐 —— 请求格式

`availableIngredients` 可以是 `/ai/identify-ingredients` 识别出的食材名字,也可以是用户手动输入的,留空数组也可以调用(AI会自由推荐常见食材)。`recentProgress` 可选——想让食谱建议"跟着体重进度走"的话,把 `/ai/report` 算出来的 `periodType`/`deltaKg`/`progressToGoalPercent` 摘出来传进来就行,这个AI服务不会重新计算这些数字。

```json
{
  "userId": "string",
  "profile": { "...": "同上面生成计划的格式" },
  "availableIngredients": ["鸡蛋", "西红柿", "菠菜"],
  "dietaryRestrictions": ["不吃海鲜"],
  "recentProgress": {
    "periodType": "weekly",
    "deltaKg": 0.1,
    "progressToGoalPercent": 12.0
  }
}
```

### 食谱推荐 —— 返回格式

```json
{
  "planName": "string",
  "goal": "lose_weight",
  "dailyCalorieTarget": 1600,
  "recipes": [
    {
      "mealType": "lunch",
      "recipeName": "string",
      "ingredientsUsed": ["鸡蛋", "西红柿"],
      "instructions": "string",
      "estimatedCalories": 400,
      "estimatedProteinG": 28.5,
      "reason": "string"
    }
  ],
  "adjustmentNote": null
}
```

注意:

- `estimatedCalories`/`estimatedProteinG`/`dailyCalorieTarget` 是AI给的粗略估算,不是精确的营养计算(不像周报的体重数字那样是代码算出来的),不要当成医疗级精确数据展示
- `adjustmentNote` 只有在请求里传了 `recentProgress` 时才可能有内容,说明这次建议有没有根据进度做调整(比如进度停滞就建议增加蛋白质/调整热量);没传 `recentProgress` 时固定是 `null`
- 这个AI服务不会推荐极端节食/单一食物断食这类不健康的方式,即使用户目标是快速减重也不会,这是写死在prompt里的安全边界
- 目前不做营养成分的精确计算,也没有食谱配图/示范视频

需要提前配置环境变量 `ANTHROPIC_API_KEY`(不要提交到git,放在 `.env` 里)。

## 实际接入方式(真实实现,以此为准)

上面几节是这个AI服务本身的原始设计。实际接入 `backend/` 之后,真实的HTTP接口跟上面不完全一样——不需要传 `userId`/`profile`/`personalInfo`(Backend从bearer token和数据库自动读取),器材/食材识别改成直接传图片文件(multipart)而不是先传URL。完整的真实接口格式见 `docs/API_CONTRACT.md`,团队协作细节见 `docs/TEAM_INTEGRATION_GUIDE.md`。

## 还没做的部分(后续)

- 器材识别 / 食材识别配示范视频或图片(目前只有文字说明)
- 训练完成率追踪(需要backend新增一张表,见 `docs/TEAM_INTEGRATION_GUIDE.md`)
- 聊天里"一键应用AI建议的修改"(目前只能给建议,不能直接改计划)
- 食谱推荐目前是"每次调用都重新生成",没有持久化存储(数据库要不要新增表存历史食谱,需要跟backend队友讨论,见 `docs/TEAM_INTEGRATION_GUIDE.md`)
