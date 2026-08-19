# PaceHealth API Contract (MVP)

This contract keeps Flutter, FastAPI, and the AI integration aligned. JSON field names are case-sensitive and use `camelCase`. Except for `/health`, `/auth/register`, and `/auth/login`, planned endpoints require `Authorization: Bearer <access-token>`.

<<<<<<< Updated upstream
`GET /health`, authentication, `/users/me`, and weight-record endpoints are implemented. The other endpoints below define the agreed implementation target.
=======
`GET /health`, authentication, `/users/me`, weight-record, and all AI endpoints (including the equipment/ingredient scan uploads) are implemented.
>>>>>>> Stashed changes

## Current endpoint

### `GET /health`

Response `200`:

```json
{ "status": "ok" }
```

## Authentication

Supabase Auth owns passwords. PaceHealth tables reference the authenticated Supabase user UUID and never store password hashes.

- `POST /auth/register` - body: `{ "email": "string", "password": "string" }`
- `POST /auth/login` - body: `{ "email": "string", "password": "string" }`
- `POST /auth/logout` - planned

Successful login response:

```json
{
  "accessToken": "string",
  "refreshToken": "string",
  "emailConfirmationRequired": false,
  "user": { "userId": "uuid", "email": "string" }
}
```

Registration uses the same response. When Supabase email confirmation is enabled, both tokens are `null` and `emailConfirmationRequired` is `true`.

## Profile and questionnaire

- `GET /users/me`
- `PUT /users/me`

Request/response data:

```json
{
  "userId": "uuid",
  "profile": {
    "name": "string",
    "age": 28,
    "sex": "female",
    "heightCm": 165,
<<<<<<< Updated upstream
    "currentWeightKg": 68,
=======
    "startWeightKg": 68,
>>>>>>> Stashed changes
    "targetWeightKg": 60,
    "goal": "lose_weight",
    "lifestyle": "sedentary desk job",
    "exerciseFrequencyPerWeek": 3,
    "exerciseDurationMinutes": 45,
<<<<<<< Updated upstream
=======
    "exerciseHabit": ["dancing", "swimming"],
>>>>>>> Stashed changes
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

The `userId` is returned by `GET`/`PUT` responses but is not accepted in the `PUT` body. FastAPI derives it from the bearer token.

## Weight records

- `POST /weights` - body: `{ "weightKg": 67.2, "recordedAt": "2026-08-14" }`
- `GET /weights?from=2026-08-01&to=2026-08-31`
- `DELETE /weights/{weightLogId}`

Create response:

```json
{
  "weightLogId": "uuid",
  "weightKg": 67.2,
  "recordedAt": "2026-08-14"
}
```

`GET /weights` returns these objects ordered by `recordedAt` from earliest to latest. `DELETE` returns `204` when successful.

The authenticated user comes from the bearer token; clients must not select another user's ID.

## AI endpoints

<<<<<<< Updated upstream
These payloads must remain aligned with Stephanie's AI service.

- `GET /ai/health`
- `POST /ai/generate-plan` - accepts the full profile/questionnaire object above and returns `planName`, `goal`, `weeklyFrequency`, and `exercises`.
- `POST /ai/chat` - accepts `message`, ordered `history`, and optional `profile`/`personalInfo`; returns `{ "reply": "string" }`.
- `POST /ai/report` - accepts `periodType`, profile, and ascending `weightRecords`; returns report metrics, `summary`, and the original weight records.

Exercise response item:
=======
Stephanie's AI service (`ai-service/`, contract in `docs/TEAM_INTEGRATION_GUIDE.md` section 4) is vendored into the backend at `backend/app/services/ai/` and wrapped by `backend/app/routers/ai.py` + `backend/app/routers/scans.py`. Flutter's contract with these endpoints is **not** a 1:1 passthrough of the AI service's own request shape — the backend derives the user from the bearer token and loads profile/history/progress data from the database itself, rather than trusting a client-supplied `userId`, `profile`, or `recentProgress`. All of these require `Authorization: Bearer <access-token>`.

- `GET /ai/health`
- `POST /ai/generate-plan` - no body. Loads the caller's saved profile (`404 PROFILE_NOT_FOUND` if none), generates a plan, saves it to `ai_plans`/`exercises`, and returns it with a `planId`.
- `POST /ai/chat` - body: `{ "message": "string" }`. Loads the caller's profile (if any) and recent chat history from `chat_records` automatically, calls the AI, saves both sides of the exchange, and returns `{ "reply": "string" }`.
- `POST /ai/report` - body: `{ "periodType": "weekly" | "monthly" }`. Loads the caller's profile (`404 PROFILE_NOT_FOUND` if none) and this period's `weight_records` (rolling 7-day/30-day window ending today), generates the report, saves it to `reports`, and returns it.
- `POST /ai/generate-meal-plan` - body: `{ "availableIngredients": ["string"], "dietaryRestrictions": ["string"], "includeRecentProgress": false }`. Loads the caller's profile (`404 PROFILE_NOT_FOUND` if none). When `includeRecentProgress` is `true`, the backend computes the same weekly stats `/ai/report` would (from `weight_records`, not from client input) and passes them to the AI. Not persisted — see Decision 8 in `docs/DATABASE_SCHEMA_GUIDE.md`.
- `POST /equipment/scan` - `multipart/form-data` with an `image` file field (JPEG/PNG/WEBP/HEIC, max 8 MB). Uploads the image to Supabase Storage, calls the AI, saves the result to `equipment_scans`, and returns it.
- `POST /ingredients/scan` - `multipart/form-data` with an `image` file field, same constraints as above. Uploads the image, calls the AI, and returns the result. Not persisted yet — see Decision 8 in `docs/DATABASE_SCHEMA_GUIDE.md`.

Exercise response item (part of `/ai/generate-plan`'s `exercises` array, alongside `planId`/`planName`/`goal`/`weeklyFrequency`):
>>>>>>> Stashed changes

```json
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
```

Exactly one of `reps` and `duration` has a value. `duration` is measured in seconds.

<<<<<<< Updated upstream
=======
`/ai/report` response:

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

If fewer than two `weight_records` fall in the window, `hasEnoughData` is `false` and every numeric field is `null` except `summary`, which becomes encouragement to log weight more often.

Equipment identification response:

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

Ingredient identification response:

```json
{
  "recognized": true,
  "confidence": 0.85,
  "ingredients": [{ "name": "egg", "quantity": "6" }],
  "notRecognizedMessage": null
}
```

Meal plan response:

```json
{
  "planName": "string",
  "goal": "string",
  "dailyCalorieTarget": 1600,
  "recipes": [
    {
      "mealType": "lunch",
      "recipeName": "string",
      "ingredientsUsed": ["egg", "tomato"],
      "instructions": "string",
      "estimatedCalories": 400,
      "estimatedProteinG": 28.5,
      "reason": "string"
    }
  ],
  "adjustmentNote": null
}
```

`estimatedCalories`, `estimatedProteinG`, and `dailyCalorieTarget` are AI estimates, not exact calculations (unlike the report endpoint's weight metrics, which are computed in code). `adjustmentNote` is only populated when the request includes `recentProgress`; otherwise it is `null`. See `docs/TEAM_INTEGRATION_GUIDE.md` for full request formats and field-by-field notes.

>>>>>>> Stashed changes
## Errors

All planned endpoints use a consistent error body:

```json
{
  "success": false,
  "message": "Human-readable explanation",
  "data": { "errorCode": "MACHINE_READABLE_CODE" }
}
```

## Ownership rules

<<<<<<< Updated upstream
- Flutter sends and receives the JSON in this document.
- FastAPI authenticates requests, reads/writes Supabase, stores chat history, and prepares ordered weight records.
- The AI service generates content but does not authenticate users or write directly to the database.
=======
- Flutter sends and receives the JSON in this document, and never calls the AI service directly or holds Supabase Storage credentials.
- FastAPI authenticates requests, reads/writes Supabase, stores chat history, uploads scan images to Storage, and prepares the profile/weight data every AI call needs.
- The AI service (vendored at `backend/app/services/ai/`) generates content only. It doesn't authenticate users, doesn't query Supabase, and doesn't decide what counts as "recent progress" — the backend computes that from `weight_records` so a client can't hand the AI made-up numbers.
>>>>>>> Stashed changes
