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
python3 test_local.py            # 测试生成计划功能
python3 test_chat_local.py       # 测试聊天功能
python3 test_report_local.py     # 测试周报/月报功能
python3 test_equipment_local.py 你的照片.jpg  # 测试器材识别(需要一张真实的器材照片)
<<<<<<< Updated upstream
=======
python3 test_ingredients_local.py 你的照片.jpg  # 测试食材识别(需要一张真实的食材/冰箱照片)
python3 test_meal_plan_local.py  # 测试食谱推荐功能(含"根据进度调整"的场景)
>>>>>>> Stashed changes
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

<<<<<<< Updated upstream
这样他的项目就会多出五个接口:
=======
这样他的项目就会多出七个接口:
>>>>>>> Stashed changes

- `GET /ai/health` — 检查AI服务是否正常
- `POST /ai/generate-plan` — 传入用户数据,返回生成的训练计划
- `POST /ai/chat` — 聊天,传入这次的消息 + 之前的聊天记录,返回AI的回复
- `POST /ai/report` — 周报/月报,传入这个周期的体重记录,返回算好的数字 + AI总结
- `POST /ai/identify-equipment` — 拍照识别器材,传入图片,返回器材名称 + 使用说明 + 安全提示
<<<<<<< Updated upstream
=======
- `POST /ai/identify-ingredients` — 拍照识别食材(冰箱/菜篮子),传入图片,返回识别出的食材列表
- `POST /ai/generate-meal-plan` — 根据用户目标 + 可用食材(+可选的最近体重进度)生成食谱推荐
>>>>>>> Stashed changes

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
  "profile": { "...": "同上面生成计划的格式,必填(需要targetWeightKg和startWeightKg来算进度)" },
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

注意:

- `initialWeightKg`(这个周期开始时的体重,注意跟 `Profile.startWeightKg` 是两个不同概念,不要搞混)/ `endWeightKg` / `deltaKg` / `progressToGoalPercent` / `projectedWeeksToGoal` 这几个数字**全部是Python代码算出来的,不是AI生成的**,保证准确,AI只写 `summary` 这段总结文字
- 如果这个周期内的体重记录少于2条,`hasEnoughData` 会是 `false`,上面几个数字字段全部是 `null`,`summary` 会是一段鼓励用户多记录体重的话
- `projectedWeeksToGoal` 在当前趋势没有朝目标前进时(比如目标减重但体重反而增加、或者完全没变化)会是 `null`,这种情况 `summary` 里AI会委婉提醒用户
- `weightRecords` 是把请求里传进来的体重记录原样返回,方便Frontend直接拿这个数组画折线图,不用再单独调用Backend的其他接口去查一次

### 器材识别 —— 请求格式

`imageUrl` 需要是一个**公开可访问**的图片链接(比如Supabase Storage生成的公开URL),Claude的服务器要能直接打开这个链接读图。Backend需要先把用户拍的照片上传到Supabase Storage拿到URL,再传给这个接口——**不是**传base64编码的图片内容,也不是传本地文件路径。

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

注意:

- 目前**不做示范视频匹配**,只有文字说明,`Exercise.videoUrl` 那种视频链接功能不在这里
- `confidence` 是0到1之间的小数,表示AI对这次识别的把握程度,这个是配合 `equipment_scans` 表里的 `confidence` 字段设计的,Backend存的时候直接存这个数字
- 如果AI没能从照片里认出器材(照片模糊、拍的不是健身器材等),`recognized` 会是 `false`,`confidence` 通常会是个偏低的数字,`equipmentName`/`description`/`usageInstructions`/`safetyNotes` 全部是 `null`,`targetMuscles` 是空数组,只有 `notRecognizedMessage` 有内容(提示用户重新拍摄),Frontend这种情况下应该显示这条提示,引导用户重拍,而不是显示一堆空白字段
- `personalizedWarning` 只有在传了 `personalInfo` 且这个器材对用户的伤病/体态问题有风险时才会有内容,平时是 `null`

<<<<<<< Updated upstream
=======
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

>>>>>>> Stashed changes
需要提前配置环境变量 `ANTHROPIC_API_KEY`(不要提交到git,放在 `.env` 里)。

## 还没做的部分(后续)

<<<<<<< Updated upstream
- 器材识别配示范视频(目前只有文字说明)
- 训练完成率追踪(需要backend新增一张表,见 `docs/TEAM_INTEGRATION_GUIDE.md`)
- 聊天里"一键应用AI建议的修改"(目前只能给建议,不能直接改计划)
=======
- 器材识别 / 食材识别配示范视频或图片(目前只有文字说明)
- 训练完成率追踪(需要backend新增一张表,见 `docs/TEAM_INTEGRATION_GUIDE.md`)
- 聊天里"一键应用AI建议的修改"(目前只能给建议,不能直接改计划)
- 食谱推荐目前是"每次调用都重新生成",没有持久化存储(数据库要不要新增表存历史食谱,需要跟backend队友讨论,见 `docs/TEAM_INTEGRATION_GUIDE.md`)
>>>>>>> Stashed changes
