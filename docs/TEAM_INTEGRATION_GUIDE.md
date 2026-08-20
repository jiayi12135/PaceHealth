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
- [x] 拍照识别食材(冰箱/菜篮子,简化版:只列食材名+大概份量),已实现,格式见第4节
- [x] 食谱推荐(根据可用食材+用户目标生成食谱,可选根据体重进度调整建议方向),已实现,格式见第4节
- [x] Backend:登录、数据库、各表的增删改查
- [x] Backend连AI:Stephanie和Ziyan协商后由Stephanie实现,已把AI代码合并进 `backend/app/services/ai/` 并接好所有7个接口(含图片上传),细节和跟第4节原始设计的出入见第3节开头的更新说明
- [ ] Frontend:所有页面(问卷、计划展示、聊天、周报月报、器材识别、食材识别、食谱推荐几个AI相关页面的Dart模型/mock数据已就绪,等接真实接口)

---

## 3. AI 功能对接说明(给 Backend 队友)

**更新:这一步已经做完了。** 几点说明:

- 代码位置跟原计划一致,但拆成了两个 router:`backend/app/routers/ai.py`(生成计划/聊天/周报/食谱推荐)和 `backend/app/routers/scans.py`(器材/食材拍照识别,因为涉及图片上传,单独拆开更清晰)。
- 真实跑起来的HTTP接口跟本节和第4节原始设计的格式**不完全一样**,以 `docs/API_CONTRACT.md` 为准——真实接口更简单,因为不需要Frontend/Backend之间手动传 `userId`/`profile`/`personalInfo` 这些数据了,详见第5节。
- 新增了两个 backend 自己拥有的接口:`POST /equipment/scan` 和 `POST /ingredients/scan`,直接接收图片文件(multipart),不再是"先传Storage拿URL、再把URL传给AI接口"这种两步走的方式。
- `backend/.env` 需要单独配置 `ANTHROPIC_API_KEY`(跟 `ai-service/.env` 是分开的两份,各自配置),另外需要在 Supabase 手动建一个公开的 `scans` Storage bucket(用来存用户上传的器材/食材照片)。
- 第2节提到的 `current_weight_kg` → `start_weight_kg` 改名 + 新增 `exercise_habit` 字段,已经同步进了backend代码和数据库迁移文件。

以下是原始的对接说明,保留作为理解AI服务本身设计的参考。

这样你的项目就会多出七个接口:

- `GET /ai/health` — 确认 AI 服务正常
- `POST /ai/generate-plan` — 传入用户数据,返回生成的训练计划
- `POST /ai/chat` — 聊天,传入这次消息 + 历史记录,返回AI回复(格式见第4节)
- `POST /ai/report` — 周报/月报,传入这个周期的体重记录,返回算好的数字 + AI总结(格式见第4节)
- `POST /ai/identify-equipment` — 拍照识别器材,传入图片URL(不是base64,见下方"器材识别重要说明"),返回器材名称+用法+安全提示(格式见第4节)
- `POST /ai/identify-ingredients` — 拍照识别食材(冰箱/菜篮子),返回识别出的食材名称+大概份量(格式见第4节)
- `POST /ai/generate-meal-plan` — 根据用户目标+可用食材(+可选的最近体重进度)生成食谱推荐(格式见第4节)

需要在 `.env` 里配置 `ANTHROPIC_API_KEY`(找 Stephanie 要,不要提交到 git)。

**聊天功能重要说明:** `/ai/chat` 这个接口本身不会存聊天记录,也不会去数据库查历史——每次调用都需要 Backend 自己从 `Chat Record` 表里查出这个用户之前的对话,按顺序传进 `history` 字段。同时,AI 在聊天里如果建议用户调整计划,**不会自动更新数据库里的计划**,只是给建议;真正要改计划还是要走 `/ai/generate-plan`。

**周报/月报重要说明:** `weightRecords` 需要 Backend 自己从 `Weight Record` 表按时间范围(本周/本月)查出来、按时间从早到晚排序后传过来。里面的 `initialWeightKg`/`endWeightKg`/`deltaKg`/`progressToGoalPercent`/`projectedWeeksToGoal` 这几个数字是这个AI服务用代码算出来的(没有用AI去算,保证准确),只有 `summary` 那段话是AI写的。`initialWeightKg` 指的是"这个周期开始时"的体重,跟下面 `Profile.startWeightKg`(最初设定目标时的体重)是两个不同概念。

**器材识别重要说明:** 目前是简化版,只返回文字说明(器材名称、用法、安全提示),**没有**示范视频匹配功能。图片需要传公开可访问的URL过来(配合Backend的Supabase Storage设计),不是传base64或文件本身。

需要做的页面(对应 Part 1 需求):登录、问卷收集(身高体重目标 + 个性化问题)、拍照识别器材、计划展示页、聊天框、周报月报、Profile、Setting,再加上新的拍照识别食材 + 食谱推荐页。AI这六块功能(生成计划/聊天/周报/器材识别/食材识别/食谱推荐)现在全部做完了,而且已经接进了Backend、可以真实调用了(不只是AI服务本身跑起来,Backend那层也跑起来了)。

### 关于"训练完成率"

已经确认 Backend 在 Supabase 里建好了 `workout_completions` 表(`id`/`user_id`/`plan_id`/`day`/`completed_at`),跟这里最早建议的设计基本一致,这个功能算是已经在做了。Frontend 需要在训练页加一个"完成"按钮,点击后插入一条记录即可,不需要用户填任何详细数据。这个功能**不需要AI接口**,属于Backend + Frontend配合就能做的纯统计功能(周报里"完成X/Y次"直接查这张表算)。

---

## 4. 数据格式(AI 服务本身的原始设计,给 Backend 队友对接用)

**字段命名说明:** 数据库里最初叫 `current_weight_kg` 的字段已改名为 `start_weight_kg`(表示"设定目标时的体重",避免跟"当前最新体重"混淆),并新增了 `exercise_habit`(用户平时的运动习惯,字符串数组)。下面所有格式已经按新字段名更新。

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

### 返回

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

### 请求 `POST /ai/chat`

```json
{
  "userId": "string",
  "message": "string",
  "history": [
    { "role": "user", "content": "string" },
    { "role": "assistant", "content": "string" }
  ],
  "profile": { "...": "跟上面 generate-plan 的 profile 格式一样,可选" },
  "personalInfo": { "...": "跟上面 generate-plan 的 personalInfo 格式一样,可选" }
}
```

`history` 需要Backend自己从 `Chat Record` 表里查出这个用户之前的对话,按时间顺序传进来。

### 返回

```json
{ "reply": "string" }
```

### 请求 `POST /ai/report`

`weightRecords` 从 `Weight Record` 表查这个周期(本周/本月)内的记录,按 `recordedAt` 从早到晚排序传过来。`profile` 必填,因为要用 `startWeightKg`(设定目标时的体重)和 `targetWeightKg` 来算进度百分比。

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

### 请求 `POST /ai/identify-ingredients`

跟器材识别用一样的方式传图片:`imageUrl` 必须是公开可访问的地址(Backend先把用户拍的冰箱/食材照片上传到Supabase Storage拿到URL,再传过来)。

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

只要认出至少一样食材,`recognized` 就是 `true`,不要求认全;认不出来时 `ingredients` 是空数组,`notRecognizedMessage` 会提示用户重新拍摄。返回的 `ingredients` 里的 `name` 列表可以直接拿去填下面 `/ai/generate-meal-plan` 请求里的 `availableIngredients`。

### 请求 `POST /ai/generate-meal-plan`

`availableIngredients` 可以是 `/ai/identify-ingredients` 识别出的食材名字,也可以是用户手动输入的,留空数组也可以调用(AI会自由推荐常见食材)。`recentProgress` 可选——想让食谱建议"跟着体重进度走"的话,把 `/ai/report` 算出来的 `periodType`/`deltaKg`/`progressToGoalPercent` 摘出来传进来就行。

```json
{
  "userId": "string",
  "profile": { "...": "跟上面 generate-plan 的 profile 格式一样" },
  "availableIngredients": ["鸡蛋", "西红柿", "菠菜"],
  "dietaryRestrictions": ["不吃海鲜"],
  "recentProgress": {
    "periodType": "weekly",
    "deltaKg": 0.1,
    "progressToGoalPercent": 12.0
  }
}
```

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

`estimatedCalories`/`estimatedProteinG`/`dailyCalorieTarget` 是AI给的粗略估算,不是精确的营养计算,不要当成医疗级精确数据展示。`adjustmentNote` 只有在请求里传了 `recentProgress` 时才可能有内容;没传时固定是 `null`。这个AI服务不会推荐极端节食/单一食物断食这类不健康的方式,这是写死在prompt里的安全边界。

---

## 5. 给 Frontend 队友的说明

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

---

## 6. Git 协作提醒

- 建议每人在自己的分支上开发(现在 Stephanie 用的是 `Stephanie` 分支),完成一个可用的小功能就提 PR 合并到 `main`,不要都堆在最后一天合并
- `.env` 文件(存 API key、数据库密码)不要提交到 git,已经在 `.gitignore` 里排除了
- 如果字段名或接口格式需要改动,三个人先在群里同步一下,不要各自改各自的,容易对不上

---

有疑问的地方直接问 Stephanie,或者把这份文档丢给你自己的 AI 助手,让它按这个格式来生成代码。
