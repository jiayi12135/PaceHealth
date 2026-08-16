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
- [ ] 拍照识别健身器材
- [ ] Backend:登录、数据库、各表的增删改查
- [ ] Frontend:所有页面

---

## 3. AI 功能对接说明(给 Backend 队友)

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

这样你的项目就会多出四个接口:

- `GET /ai/health` — 确认 AI 服务正常
- `POST /ai/generate-plan` — 传入用户数据,返回生成的训练计划
- `POST /ai/chat` — 聊天,传入这次消息 + 历史记录,返回AI回复(格式见第4节)
- `POST /ai/report` — 周报/月报,传入这个周期的体重记录,返回算好的数字 + AI总结(格式见第4节)

需要在 `.env` 里配置 `ANTHROPIC_API_KEY`(找 Stephanie 要,不要提交到 git)。

**聊天功能重要说明:** `/ai/chat` 这个接口本身不会存聊天记录,也不会去数据库查历史——每次调用都需要 Backend 自己从 `Chat Record` 表里查出这个用户之前的对话,按顺序传进 `history` 字段。同时,AI 在聊天里如果建议用户调整计划,**不会自动更新数据库里的计划**,只是给建议;真正要改计划还是要走 `/ai/generate-plan`。

**周报/月报重要说明:** `weightRecords` 需要 Backend 自己从 `Weight Record` 表按时间范围(本周/本月)查出来、按时间从早到晚排序后传过来。里面的 `startWeightKg`/`endWeightKg`/`deltaKg`/`progressToGoalPercent`/`projectedWeeksToGoal` 这几个数字是这个AI服务用代码算出来的(没有用AI去算,保证准确),只有 `summary` 那段话是AI写的。

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

这份数据从 Frontend 的"问卷收集"页面来 → 传给 Backend → Backend 转发给 AI 接口。

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

`weightRecords` 从 `Weight Record` 表查这个周期(本周/本月)内的记录,按 `recordedAt` 从早到晚排序传过来。`profile` 必填,因为要用 `currentWeightKg`(设定目标时的体重)和 `targetWeightKg` 来算进度百分比。

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

如果这个周期体重记录少于2条,`hasEnoughData` 是 `false`,数字字段全是 `null`,`summary` 会变成鼓励用户多记录体重的话——Frontend 这种情况下建议直接显示 `summary` 就好,不用尝试显示图表(没有足够数据画)。

`weightRecords` 是把请求里传的体重记录原样带回来,Frontend 可以直接用这个数组画折线图(比如用它做体重变化趋势图),不用再单独请求一次原始数据。

### 关于"训练完成率"

如果之后想在报告里加"这周计划练3次实际练了几次",目前的数据表里没有任何地方记录"用户是否真的完成了某次训练",需要新增一张表,建议字段如下(Stephanie 已经设计好,讨论后再决定要不要加):

```
WorkoutCompletion
completionId    — 数据库自动生成的主键
userId          — 哪个用户完成的
planId          — 对应哪个训练计划
day             — 对应SportsType里的day字段,标记"这一天"完成了
completedAt     — 用户点"完成"按钮的时间戳
```

Frontend 需要在训练页加一个"完成"按钮,点击后插入一条记录即可,不需要用户填任何详细数据。这个功能目前**还没有对应的AI接口**,属于Backend + Frontend配合就能做的纯统计功能(周报里"完成X/Y次"直接查这张表算,不需要调用AI)。

---

## 5. 给 Frontend 队友的说明

需要做的页面(对应 Part 1 需求):登录、问卷收集(身高体重目标 + 个性化问题)、拍照识别器材(暂时可以先做 UI,功能等 Stephanie 完成)、计划展示页、聊天框、周报月报、Profile、Setting。

跟 AI 功能直接相关的几个页面:

1. **问卷收集页**:收集完数据后,按第4节的请求格式打包成 JSON,通过 `api_service.dart` 发给 Backend 的 `POST /ai/generate-plan`(具体网址等 Backend 队友把项目跑起来后给你)
2. **计划展示页**:拿到第4节的返回 JSON 后,按 `day` 分组显示每天的动作列表,每个动作显示名称、组数、次数/时长、休息时间、以及 `reason`(推荐理由,建议展示出来,这是个性化的重点)
3. **聊天页**:见第4节聊天接口部分
4. **周报/月报页**:调用 `POST /ai/report` 拿到数据后,数字部分(`startWeightKg`/`endWeightKg`/`deltaKg`/`progressToGoalPercent`)可以做成体重趋势图/进度条这类可视化,`summary` 那段文字直接展示在下方当作"AI点评"。如果 `hasEnoughData` 是 `false`,不要尝试画图,只显示 `summary` 里鼓励记录体重的话就好
3. **聊天页**:一个普通的对话气泡界面就够了。每次用户发消息,把这条消息 + 当前已经显示在界面上的历史记录,发给 Backend 的 `POST /ai/chat`,拿到 `reply` 后加一条新的AI气泡显示出来。如果AI在回复里建议调整计划,目前不会自动更新计划页面,用户需要自己再走一次生成计划的流程(可以在AI建议调整时,加一个"重新生成计划"的按钮方便用户操作)

在 Backend 还没搭好之前,可以直接用第4节的 JSON 示例当作假数据(mock),先把 UI 做出来,不用等。

---

## 6. Git 协作提醒

- 建议每人在自己的分支上开发(现在 Stephanie 用的是 `Stephanie` 分支),完成一个可用的小功能就提 PR 合并到 `main`,不要都堆在最后一天合并
- `.env` 文件(存 API key、数据库密码)不要提交到 git,已经在 `.gitignore` 里排除了
- 如果字段名或接口格式需要改动,三个人先在群里同步一下,不要各自改各自的,容易对不上

---

有疑问的地方直接问 Stephanie,或者把这份文档丢给你自己的 AI 助手,让它按这个格式来生成代码。
