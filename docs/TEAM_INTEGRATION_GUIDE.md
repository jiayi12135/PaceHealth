# PaceHealth — 团队协作与项目结构说明

给 backend / frontend 队友看的对接文档。目的:三个人各自开发的时候,数据格式和项目结构能对得上,不用等到最后才发现拼不到一起。

负责人分工: Stephanie(队长 / Prompt AI)、Backend 队友(Python + FastAPI)、Frontend 队友(Flutter)。

Hackathon 主题: physical health app。本说明只覆盖 Part 1 的范围。

---

## 1. 整体项目结构(建议)

三个人的代码最终放进同一个 repo,结构建议如下:

```
PaceHealth/
├── backend/                      ← Backend 队友负责,FastAPI 主项目
│   ├── app/
│   │   ├── main.py               ← FastAPI 入口,把所有 router include 进来
│   │   ├── routers/
│   │   │   ├── auth.py           ← 登录 / 注册
│   │   │   ├── users.py          ← Profile / UserPersonalInfo 增删改查
│   │   │   ├── weight.py         ← 体重打卡记录
│   │   │   └── ai.py             ← AI 功能的 router(Stephanie 提供,见下方第3节)
│   │   ├── models/                ← 数据库表结构 + 请求/返回的数据格式定义
│   │   ├── services/
│   │   │   └── ai/                ← AI 相关代码(Stephanie 提供)
│   │   │       ├── claude_client.py
│   │   │       └── prompts.py
│   │   └── database.py
│   ├── requirements.txt          ← 三人共用一份依赖清单
│   └── .env                      ← API key / 数据库连接串,不上传 git
│
├── frontend/                      ← Frontend 队友负责,Flutter 项目
│   └── lib/
│       ├── screens/               ← 各个页面(登录、问卷、计划展示、聊天、报告等)
│       ├── models/                ← Dart 数据类,字段要跟 backend 返回的 JSON 完全对齐
│       └── services/
│           └── api_service.dart   ← 统一负责发请求给 backend
│
├── ai-service/                    ← Stephanie 当前的开发/测试环境(临时,最终代码会合并进 backend/app/)
│
└── docs/
    └── TEAM_INTEGRATION_GUIDE.md  ← 就是这份文件
```

**为什么 AI 代码最终要合并进 backend,而不是单独跑一个服务:** Stephanie 和 Backend 队友都用 Python + FastAPI,合并成一个服务可以少跑一个进程,demo 当天更简单稳定,也不用处理服务之间的网络请求问题。

---

## 2. 目前完成进度

- [x] AI 根据用户资料生成个性化训练计划(prompt 设计 + Claude API 调用),已用真实 API 测试通过
- [x] 聊天框(健身知识问答 + 调整计划建议),已实现,格式见第4节
- [x] 周报 / 月报(体重趋势 + AI总结文字),已实现,格式见第4节
- [x] 拍照识别健身器材(简化版:只有文字说明,不含示范视频匹配),已实现,格式见第4节
<<<<<<< Updated upstream
- [ ] Backend:登录、数据库、各表的增删改查
- [ ] Frontend:所有页面
=======
- [x] 拍照识别食材(冰箱/菜篮子,简化版:只列食材名+大概份量),已实现,格式见第4节
- [x] 食谱推荐(根据可用食材+用户目标生成食谱,可选根据体重进度调整建议方向),已实现,格式见第4节
- [x] Backend:登录、数据库、各表的增删改查
- [x] Backend连AI:Stephanie和Ziyan协商后由Stephanie实现,已把AI代码合并进 `backend/app/services/ai/` 并接好所有7个接口(含图片上传),细节和跟第4节原始设计的出入见第3节开头的更新说明
- [ ] Frontend:所有页面(问卷、计划展示、聊天、周报月报、器材识别、食材识别、食谱推荐几个AI相关页面的Dart模型/mock数据已就绪,等接真实接口)
>>>>>>> Stashed changes

---

## 3. AI 功能对接说明(给 Backend 队友)

<<<<<<< Updated upstream
=======
**更新:这一步已经做完了。** 跟Ziyan协商后,"backend连AI"这部分由Stephanie直接实现(而不是Ziyan照着下面的说明自己接),原因是这样能保证AI这边的字段契约、安全边界、错误处理不会在传递过程中走样。实际做法跟下面原始计划有几点重要出入,Backend/Frontend队友对接时要按这几点来,而不是按下面"怎么接入你的项目"里的原始设想:

- 代码位置和原计划一致:AI代码在 `backend/app/services/ai/`(`models.py`/`prompts.py`/`claude_client.py`/`report_calculator.py`,直接照搬自 `ai-service/app/`,没有改动内容,以后Stephanie这边有新功能可以继续照这个模式合并),router在 `backend/app/routers/ai.py` 和 `backend/app/routers/scans.py`(拆成两个文件,因为器材/食材识别是图片上传,走 `multipart/form-data`,跟其他JSON接口不是一类)。
- **实际的HTTP契约跟第4节写的原始设计不一样**:第4节里的格式是"AI服务本身"期望收到的格式(`userId`、`profile`、`personalInfo`、`recentProgress` 都在请求体里),这是给独立跑AI服务时用的。但backend对外暴露的接口不是直接把这些字段透传给AI——Backend会自己从token拿`userId`、自己查数据库拿`profile`/`personalInfo`/聊天记录/体重进度,再转发给AI这层。所以实际请求体更简单(比如 `/ai/generate-plan` 现在不需要body,`/ai/chat` 只需要传 `{"message": "string"}`),完整的、真实的请求/返回格式以 **`docs/API_CONTRACT.md`** 为准,第4节的格式仅供理解AI服务内部逻辑参考。
- 新增了 `POST /equipment/scan` 和 `POST /ingredients/scan` 两个真正的Backend接口(不是AI服务原本的 `/ai/identify-equipment`/`/ai/identify-ingredients`,那两个AI原始接口还在,但只在Backend内部被这两个新接口调用,不直接对外暴露)。Frontend直接传图片文件给这两个接口(multipart表单,字段名`image`),Backend负责传到Supabase Storage拿URL、再转发给AI、再存库,Frontend不用关心Storage细节。
- 部署前需要在 `backend/.env` 里配置 `ANTHROPIC_API_KEY`(不是只在 `ai-service/.env` 里配了就够,两边是分开的环境变量文件),还需要在Supabase Dashboard里手动建一个名叫 `scans` 的**公开** Storage bucket(代码里默认用这个名字,可以通过 `SCAN_STORAGE_BUCKET` 环境变量改)。
- `current_weight_kg`→`start_weight_kg` 改名和新增 `exercise_habit` 字段(第4节末尾提到的那次会议决定)在这次改动里一并同步进了backend代码和数据库(`backend/supabase/migrations/0001_rename_start_weight_add_exercise_habit.sql`,需要在Supabase SQL编辑器里手动跑一次)。

以下是原始的对接说明,保留作为理解AI服务本身设计的参考:

>>>>>>> Stashed changes
Stephanie 已经写好的代码在 `ai-service/app/` 里,包含:

| 文件 | 作用 |
|---|---|
| `models.py` | 定义请求/返回的数据格式(见第4节) |
| `prompts.py` | 给 Claude 的角色设定和提示词模板 |
| `claude_client.py` | 调用 Claude API 的封装,强制返回固定 JSON 格式 |
| `router.py` | 对外暴露的 HTTP 接口 |

### 怎么接入你的项目

把 `ai-service/app/` 里的文件搬进你的 `backend/app/services/ai/`(`claude_client.py`、`prompts.py`)和 `backend/app/routers/ai.py`(`router.py` 改名),然后在你的 `main.py` 里:

```python
from app.routers.ai import router as ai_router
app.include_router(ai_router, prefix="/ai")
```

<<<<<<< Updated upstream
这样你的项目就会多出五个接口:
=======
这样你的项目就会多出七个接口:
>>>>>>> Stashed changes

- `GET /ai/health` — 确认 AI 服务正常
- `POST /ai/generate-plan` — 传入用户数据,返回生成的训练计划
- `POST /ai/chat` — 聊天,传入这次消息 + 历史记录,返回AI回复(格式见第4节)
- `POST /ai/report` — 周报/月报,传入这个周期的体重记录,返回算好的数字 + AI总结(格式见第4节)
<<<<<<< Updated upstream
- `POST /ai/identify-equipment` — 拍照识别器材,传入图片base64,返回器材名称+用法+安全提示(格式见第4节)
=======
- `POST /ai/identify-equipment` — 拍照识别器材,传入图片URL(不是base64,见下方"器材识别重要说明"),返回器材名称+用法+安全提示(格式见第4节)
- `POST /ai/identify-ingredients` — 拍照识别食材(冰箱/菜篮子),返回识别出的食材名称+大概份量(格式见第4节)
- `POST /ai/generate-meal-plan` — 根据用户目标+可用食材(+可选的最近体重进度)生成食谱推荐(格式见第4节)
>>>>>>> Stashed changes

需要在 `.env` 里配置 `ANTHROPIC_API_KEY`(找 Stephanie 要,不要提交到 git)。

**聊天功能重要说明:** `/ai/chat` 这个接口本身不会存聊天记录,也不会去数据库查历史——每次调用都需要 Backend 自己从 `Chat Record` 表里查出这个用户之前的对话,按顺序传进 `history` 字段。同时,AI 在聊天里如果建议用户调整计划,**不会自动更新数据库里的计划**,只是给建议;真正要改计划还是要走 `/ai/generate-plan`。

**周报/月报重要说明:** `weightRecords` 需要 Backend 自己从 `Weight Record` 表按时间范围(本周/本月)查出来、按时间从早到晚排序后传过来。里面的 `initialWeightKg`/`endWeightKg`/`deltaKg`/`progressToGoalPercent`/`projectedWeeksToGoal` 这几个数字是这个AI服务用代码算出来的(没有用AI去算,保证准确),只有 `summary` 那段话是AI写的。`initialWeightKg` 指的是"这个周期开始时"的体重,跟下面 `Profile.startWeightKg`(最初设定目标时的体重)是两个不同概念。

**器材识别重要说明:** 目前是简化版,只返回文字说明(器材名称、用法、安全提示),**没有**示范视频匹配功能。图片需要传公开可访问的URL过来(配合Backend的Supabase Storage设计),不是传base64或文件本身。

<<<<<<< Updated upstream
=======
**食材识别重要说明:** 跟器材识别是完全一样的图片传法(公开URL,不是base64),用途不同——这个是拍冰箱/菜篮子识别食材,不是识别器材。只要认出至少一样食材就算成功,不要求认全,返回的是一个食材列表(名称+大概份量),不是单个结果。这个接口目前跟 `equipment_scans` 表没有关联,如果Backend想存历史识别记录,需要团队讨论要不要新建一张类似结构的表(比如 `ingredient_scans`),目前AI服务这边不强制要求持久化——Frontend也可以选择"识别完直接用,不存历史"的简化做法先做出来。

**食谱推荐重要说明:** 这个接口每次调用都是重新生成,不会自己记忆之前推荐过什么(跟 `/ai/chat` 类似,是无状态的)。`availableIngredients` 通常是 `/ai/identify-ingredients` 识别出的食材名称列表(把返回结果里每个 `ingredients[].name` 摘出来就行),也可以是用户手动输入/编辑过的食材,两种来源都可以直接传。`recentProgress` 是可选的"进度感知"功能——如果Backend想让食谱建议根据用户最近的减重/增重进度调整方向(比如进度停滞了就在建议里提醒调整热量),可以把调用 `/ai/report` 时算出来的 `periodType`/`deltaKg`/`progressToGoalPercent` 三个字段摘出来传进 `recentProgress`,这个AI服务不会重新计算这些数字、也不会自己去查体重记录。这个功能是否要持久化存储(存到数据库里,还是纯粹"生成即展示,不保存"),同样需要团队讨论决定,目前AI服务不强制要求。

>>>>>>> Stashed changes
### 需要你补的字段

AI 只负责"生成内容"这部分(`planName`、`goal`、`weeklyFrequency`、`exercises`)。以下字段需要你在存入数据库时自己补上,AI 不会生成:

- `planId` — 数据库自动生成的主键
- `userId` — 从当前登录用户的 session/token 里取,不需要问 AI
- `createdAt` — 存入数据库的时间戳

---

## 4. 数据格式(前后端都要照着这个写)

这是三方沟通最容易出错的地方,字段名必须完全一致(大小写也要对)。

### 请求 `POST /ai/generate-plan`

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

这份数据从 Frontend 的"问卷收集"页面来 → 传给 Backend → Backend 转发给 AI 接口。

**字段更新(团队会议决定):** 原来的 `currentWeightKg` 改名成 `startWeightKg`,意思是"用户最初设定目标时的体重",这个值定了之后不会跟着日常体重打卡更新(区别于 `Weight Record` 表里那些持续新增的打卡记录)。另外新增了 `exerciseHabit` 字段(平时喜欢的运动方式,比如跳舞、游泳,数组格式)。三边都要同步改,`docs/API_CONTRACT.md`、`docs/DATABASE_SCHEMA_GUIDE.md`、Frontend的Dart模型、Backend的测试代码目前还是旧的 `currentWeightKg`,需要一起更新。

### 返回

```json
{
  "planName": "string",
  "goal": "string",
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

注意:

- `reps` 和 `duration` 只会有一个有值,另一个是 `null`(力量动作用 reps,有氧/拉伸动作用 duration,单位秒)
- `day` 目前是 `"Day 1"` / `"Day 2"` 这种格式,代表"这周第几次训练日",**不是**具体星期几,也不代表日历日期。这份计划是"每周重复用的模板",不是一次性的多周计划
- `videoUrl` 目前固定是 `null`(示范视频功能还没做)
- `exercises` 里同一个 `day` 会出现多条记录(一天里的多个动作),Backend 存入 `SportsType` 表时,每条 `exercise` 存一行,用生成后拿到的 `planId` 做外键关联

### 请求 `POST /ai/chat`

`profile` / `personalInfo` 可选,不传AI也能聊,只是没法给个性化建议。`history` 是这个用户之前的对话,Backend 需要从 `Chat Record` 表按时间顺序查出来传进来。

```json
{
  "userId": "string",
  "message": "我想把深蹲换成别的动作,有什么推荐吗?",
  "history": [
    { "role": "user", "message": "我今天练完深蹲膝盖有点酸,正常吗?" },
    { "role": "assistant", "message": "轻微酸胀通常是正常的..." }
  ],
  "profile": { "...": "跟上面 generate-plan 的 profile 格式一样,可选" },
  "personalInfo": { "...": "跟上面 generate-plan 的 personalInfo 格式一样,可选" }
}
```

### 返回

```json
{ "reply": "string" }
```

Backend 拿到 `reply` 后,连同用户刚才发的 `message`,各自存一行进 `Chat Record` 表(`role` 分别是 `"user"` 和 `"assistant"`),下次聊天时把最新的历史记录再传回来。

### 请求 `POST /ai/report`

<<<<<<< Updated upstream
`weightRecords` 从 `Weight Record` 表查这个周期(本周/本月)内的记录,按 `recordedAt` 从早到晚排序传过来。`profile` 必填,因为要用 `currentWeightKg`(设定目标时的体重)和 `targetWeightKg` 来算进度百分比。
=======
`weightRecords` 从 `Weight Record` 表查这个周期(本周/本月)内的记录,按 `recordedAt` 从早到晚排序传过来。`profile` 必填,因为要用 `startWeightKg`(设定目标时的体重)和 `targetWeightKg` 来算进度百分比。
>>>>>>> Stashed changes

```json
{
  "userId": "string",
  "periodType": "weekly",
  "profile": { "...": "跟上面 generate-plan 的 profile 格式一样" },
  "weightRecords": [
    { "weightKg": 68.0, "recordedAt": "2026-08-08" },
    { "weightKg": 67.2, "recordedAt": "2026-08-14" }
  ]
}
```

`periodType` 只能是 `"weekly"` 或 `"monthly"`。

### 返回

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

如果这个周期体重记录少于2条,`hasEnoughData` 是 `false`,数字字段全是 `null`,`summary` 会变成鼓励用户多记录体重的话——Frontend 这种情况下建议直接显示 `summary` 就好,不用尝试显示图表(没有足够数据画)。

`weightRecords` 是把请求里传的体重记录原样带回来,Frontend 可以直接用这个数组画折线图(比如用它做体重变化趋势图),不用再单独请求一次原始数据。

### 关于"训练完成率"

已经确认 Backend 在 Supabase 里建好了 `workout_completions` 表(`id`/`user_id`/`plan_id`/`day`/`completed_at`),跟这里最早建议的设计基本一致,这个功能算是已经在做了。Frontend 需要在训练页加一个"完成"按钮,点击后插入一条记录即可,不需要用户填任何详细数据。这个功能**不需要AI接口**,属于Backend + Frontend配合就能做的纯统计功能(周报里"完成X/Y次"直接查这张表算)。

### 请求 `POST /ai/identify-equipment`

`imageUrl` 需要是一个**公开可访问的图片链接**(不是base64、不是本地文件路径)。这是配合 Backend 在 Supabase 里建的 `equipment_scans` 表设计的——用户拍完照后,Backend 先把图片传到 Supabase Storage 拿到URL,再把URL传给这个接口。`personalInfo` 可选,传了的话AI会检查这个器材对用户的伤病/体态问题有没有风险。

```json
{
  "userId": "string",
  "imageUrl": "https://xxx.supabase.co/storage/v1/object/public/xxx.jpg",
  "personalInfo": { "...": "跟上面 generate-plan 的 personalInfo 格式一样,可选" }
}
```

### 返回

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

`confidence`(0到1之间的小数)是配合 `equipment_scans` 表里的 `confidence` 字段加的,Backend把AI返回的这个数字直接存进那一列就行。`ai_result` 那个jsonb字段建议把整个返回结果原样存进去,方便以后回溯。

如果AI认不出照片里的器材,`recognized` 会是 `false`,其他字段大多是 `null`,只有 `notRecognizedMessage` 有内容(提示用户重新拍摄)——Frontend 这种情况下应该显示这条提示引导用户重拍,而不是展示空白的器材信息卡片。**目前没有示范视频功能**,只有文字说明。

<<<<<<< Updated upstream
=======
### 请求 `POST /ai/identify-ingredients`

跟器材识别一样,`imageUrl` 必须是公开可访问的URL。

```json
{
  "userId": "string",
  "imageUrl": "https://xxx.supabase.co/storage/v1/object/public/xxx.jpg"
}
```

### 返回

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

只要认出至少一样食材,`recognized` 就是 `true`,不要求全部认出来。认不出来时(照片模糊、没拍到食材)`recognized` 为 `false`,`ingredients` 是空数组,`notRecognizedMessage` 有提示文字,Frontend这种情况应引导用户重拍。`quantity` 是AI大概估的份量,看不出来会是 `null`,不要当成精确称重数据。

### 请求 `POST /ai/generate-meal-plan`

```json
{
  "userId": "string",
  "profile": { "...": "同generate-plan的profile格式" },
  "availableIngredients": ["鸡蛋", "西红柿", "菠菜"],
  "dietaryRestrictions": ["不吃海鲜"],
  "recentProgress": {
    "periodType": "weekly",
    "deltaKg": 0.1,
    "progressToGoalPercent": 12.0
  }
}
```

`availableIngredients` 可以来自 `/ai/identify-ingredients` 的识别结果,也可以是用户手动输入,留空数组也能调用(AI会自由推荐常见食材)。`dietaryRestrictions` 是过敏/忌口/饮食偏好,AI会严格遵守。`recentProgress` 整体可选,不传就正常生成,`periodType`/`deltaKg`/`progressToGoalPercent` 这几个字段跟 `/ai/report` 返回的同名字段含义一致,直接摘过来传即可,不用重新计算。

### 返回

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

- `mealType` 只会是 `"breakfast"` / `"lunch"` / `"dinner"` / `"snack"` 这几种
- `estimatedCalories` / `estimatedProteinG` / `dailyCalorieTarget` 是AI给的粗略估算,不是像周报数字那样代码精确算出来的,Frontend展示时建议加个"预估"字样,不要当成精确营养数据
- `adjustmentNote` 只有传了 `recentProgress` 时才可能有内容,没传则固定是 `null`;Frontend如果拿到非null的 `adjustmentNote`,建议用醒目一点的样式单独展示,这是AI根据用户最近进度给的针对性提醒
- 这个接口内置了安全边界,不会给出极端节食/断食类建议,即使用户目标是快速减重

>>>>>>> Stashed changes
---

## 5. 给 Frontend 队友的说明

<<<<<<< Updated upstream
需要做的页面(对应 Part 1 需求):登录、问卷收集(身高体重目标 + 个性化问题)、拍照识别器材、计划展示页、聊天框、周报月报、Profile、Setting。AI这四块功能(生成计划/聊天/周报/器材识别)现在全部做完了,Frontend不用等,可以直接照第4节的格式对接。

跟 AI 功能直接相关的几个页面:

1. **问卷收集页**:收集完数据后,按第4节的请求格式打包成 JSON,通过 `api_service.dart` 发给 Backend 的 `POST /ai/generate-plan`(具体网址等 Backend 队友把项目跑起来后给你)
2. **计划展示页**:拿到第4节的返回 JSON 后,按 `day` 分组显示每天的动作列表,每个动作显示名称、组数、次数/时长、休息时间、以及 `reason`(推荐理由,建议展示出来,这是个性化的重点)
3. **聊天页**:一个普通的对话气泡界面就够了。每次用户发消息,把这条消息 + 当前已经显示在界面上的历史记录,发给 Backend 的 `POST /ai/chat`,拿到 `reply` 后加一条新的AI气泡显示出来。如果AI在回复里建议调整计划,目前不会自动更新计划页面,用户需要自己再走一次生成计划的流程(可以在AI建议调整时,加一个"重新生成计划"的按钮方便用户操作)
4. **周报/月报页**:调用 `POST /ai/report` 拿到数据后,数字部分(`initialWeightKg`/`endWeightKg`/`deltaKg`/`progressToGoalPercent`)可以做成体重趋势图/进度条这类可视化,`weightRecords` 数组可以直接拿去画折线图,`summary` 那段文字直接展示在下方当作"AI点评"。如果 `hasEnoughData` 是 `false`,不要尝试画图,只显示 `summary` 里鼓励记录体重的话就好
5. **拍照识别器材页**:用户拍照/选图后,Frontend 先把图片上传到 Backend(Backend 再存到 Supabase Storage 拿到URL,这一步不是Frontend直接传base64了,是配合Backend在Supabase里建的 `equipment_scans` 表设计的),Backend 上传完拿到图片URL后,再调用 `POST /ai/identify-equipment` 传这个URL过去。拿到结果后,如果 `recognized` 是 `true`,展示器材名称、说明、使用方法、安全提示;如果有 `personalizedWarning`,建议用醒目的颜色/图标单独标出来提醒用户。如果 `recognized` 是 `false`,显示 `notRecognizedMessage` 引导用户重新拍摄,不要展示空白卡片。目前**没有**示范视频,不用做视频播放器

在 Backend 还没搭好之前,可以直接用第4节的 JSON 示例当作假数据(mock),先把 UI 做出来,不用等。
=======
需要做的页面(对应 Part 1 需求):登录、问卷收集(身高体重目标 + 个性化问题)、拍照识别器材、计划展示页、聊天框、周报月报、Profile、Setting,再加上新的拍照识别食材 + 食谱推荐页。AI这六块功能(生成计划/聊天/周报/器材识别/食材识别/食谱推荐)现在全部做完了,而且已经接进了Backend、可以真实调用了(不只是AI服务本身跑起来,Backend那层也跑起来了)。

**重要:下面几点请按真实实现来,跟第4节(AI服务本身的原始设计)不完全一样,以 `docs/API_CONTRACT.md` 为准:**

- 所有AI接口都需要带 `Authorization: Bearer <token>`,Backend会自动从token识别是哪个用户,**不需要**Frontend在请求体里传 `userId`。
- `profile`/`personalInfo` 也**不需要**Frontend在调用AI接口时重新传一遍——Backend会自动读取这个用户之前通过 `PUT /users/me` 存好的资料。如果用户还没填过问卷,`/ai/generate-plan` 和 `/ai/report` 会返回 `404 PROFILE_NOT_FOUND`,Frontend这种情况应该引导用户先去完成问卷,而不是显示一个奇怪的错误。
- 器材/食材识别不再是"传图片URL给AI",而是Frontend直接把图片文件当成 `multipart/form-data` 传给Backend(字段名 `image`),Backend自己处理上传Storage、转发AI、存库这一整套。

跟 AI 功能直接相关的几个页面:

1. **问卷收集页**:收集完数据后,先按第2节的 `profile`/`personalInfo` 格式调用 `PUT /users/me` 存起来。生成计划这一步不用再单独打包发送——问卷收集完之后,直接调用不带任何body的 `POST /ai/generate-plan` 就行,Backend会自动用刚存的资料生成计划。
2. **计划展示页**:拿到 `POST /ai/generate-plan` 的返回JSON后(比第4节多一个 `planId` 字段),按 `day` 分组显示每天的动作列表,每个动作显示名称、组数、次数/时长、休息时间、以及 `reason`(推荐理由,建议展示出来,这是个性化的重点)
3. **聊天页**:一个普通的对话气泡界面就够了。每次用户发消息,只需要发 `{ "message": "用户输入的文字" }` 给 `POST /ai/chat`(**不用**自己拼历史记录,Backend会自动从数据库查),拿到 `reply` 后加一条新的AI气泡显示出来。如果AI在回复里建议调整计划,目前不会自动更新计划页面,用户需要自己再走一次生成计划的流程(可以在AI建议调整时,加一个"重新生成计划"的按钮方便用户操作)
4. **周报/月报页**:调用 `POST /ai/report`,body只需要 `{ "periodType": "weekly" }` 或 `{ "periodType": "monthly" }`。拿到数据后,数字部分(`initialWeightKg`/`endWeightKg`/`deltaKg`/`progressToGoalPercent`)可以做成体重趋势图/进度条这类可视化,`weightRecords` 数组可以直接拿去画折线图,`summary` 那段文字直接展示在下方当作"AI点评"。如果 `hasEnoughData` 是 `false`,不要尝试画图,只显示 `summary` 里鼓励记录体重的话就好
5. **拍照识别器材页**:用户拍照/选图后,直接把图片文件传给 `POST /equipment/scan`(multipart表单,字段名 `image`),Backend会处理剩下的一切(上传Storage、调AI、存equipment_scans表)。拿到结果后,如果 `recognized` 是 `true`,展示器材名称、说明、使用方法、安全提示;如果有 `personalizedWarning`,建议用醒目的颜色/图标单独标出来提醒用户。如果 `recognized` 是 `false`,显示 `notRecognizedMessage` 引导用户重新拍摄,不要展示空白卡片。目前**没有**示范视频,不用做视频播放器
6. **拍照识别食材页**:跟识别器材页流程一样,直接把图片文件传给 `POST /ingredients/scan`。拿到结果后展示识别出的食材列表(名称+份量),建议做成可以增删/编辑的列表(比如用户可以手动把AI漏识别的食材加进去,或者删掉识别错的),这个列表最终会作为 `availableIngredients` 传给食谱推荐页。`recognized` 为 `false` 时显示 `notRecognizedMessage` 引导重拍。
7. **食谱推荐页**:用户可以从"拍照识别食材页"编辑好的食材列表进来,也可以不识别直接手动输入食材,调用 `POST /ai/generate-meal-plan`(`availableIngredients` 留空数组也能调用)。拿到结果后按 `mealType` 分组展示食谱(早/午/晚/加餐),每个食谱展示菜名、用到的食材、做法、`estimatedCalories`/`estimatedProteinG`(建议加"预估"字样,不要当成精确数值展示)、以及 `reason`。如果想让建议"根据本周体重进度调整",**不用**自己去查体重算数字,请求体里加一个 `"includeRecentProgress": true` 就行,Backend会自动算好传给AI;拿到的 `adjustmentNote` 如果不是 `null`,建议用醒目样式单独展示给用户看。

在 Backend 本地还没跑起来之前,可以先按上面的真实格式写mock数据把UI做出来,不用等(`frontend/lib/services/api_service.dart` 里已经有 `ApiConfig.useMockData` 这个开关,Backend地址跑起来后改成 `false` 并把 `ApiConfig.baseUrl` 指过去就行)。
>>>>>>> Stashed changes

---

## 6. Git 协作提醒

- 建议每人在自己的分支上开发(现在 Stephanie 用的是 `Stephanie` 分支),完成一个可用的小功能就提 PR 合并到 `main`,不要都堆在最后一天合并
- `.env` 文件(存 API key、数据库密码)不要提交到 git,已经在 `.gitignore` 里排除了
- 如果字段名或接口格式需要改动,三个人先在群里同步一下,不要各自改各自的,容易对不上

---

有疑问的地方直接问 Stephanie,或者把这份文档丢给你自己的 AI 助手,让它按这个格式来生成代码。
