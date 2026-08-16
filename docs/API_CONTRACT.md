# PaceHealth API Contract (MVP)

This contract keeps Flutter, FastAPI, and the AI integration aligned. JSON field names are case-sensitive and use `camelCase`. Except for `/health`, `/auth/register`, and `/auth/login`, planned endpoints require `Authorization: Bearer <access-token>`.

`GET /health`, authentication, `/users/me`, and weight-record endpoints are implemented. The other endpoints below define the agreed implementation target.

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

These payloads must remain aligned with Stephanie's AI service.

- `GET /ai/health`
- `POST /ai/generate-plan` - accepts the full profile/questionnaire object above and returns `planName`, `goal`, `weeklyFrequency`, and `exercises`.
- `POST /ai/chat` - accepts `message`, ordered `history`, and optional `profile`/`personalInfo`; returns `{ "reply": "string" }`.
- `POST /ai/report` - accepts `periodType`, profile, and ascending `weightRecords`; returns report metrics, `summary`, and the original weight records.

Exercise response item:

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

- Flutter sends and receives the JSON in this document.
- FastAPI authenticates requests, reads/writes Supabase, stores chat history, and prepares ordered weight records.
- The AI service generates content but does not authenticate users or write directly to the database.
