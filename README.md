# PaceHealth

An AI-powered health and fitness app that creates adaptive plans based on users’ goals, lifestyle, equipment, injuries, and progress.

## Backend foundation

The backend uses Python, FastAPI, and Supabase. Supabase Auth owns login credentials; FastAPI owns the API contract, authorization checks, database operations, and AI integration.

### Local setup

From the repository root:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
```

Fill in `backend/.env` with the Supabase project URL and backend-only secret key. Never commit this file or expose the secret key to Flutter.

Start the API:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload
```

Then open `http://127.0.0.1:8000/docs` or call `GET http://127.0.0.1:8000/health`.

Implemented endpoints:

- `GET /health`
- `POST /auth/register`
- `POST /auth/login`
- `GET /users/me`
- `PUT /users/me`
- `POST /weights`
- `GET /weights`
- `DELETE /weights/{weightLogId}`

Run tests:

```powershell
.\.venv\Scripts\python.exe -m pytest -q -p no:cacheprovider
```

### Supabase schema

For the initial project setup, run `backend/supabase/schema.sql` once in the Supabase SQL Editor. The schema is secure by default with Row Level Security enabled and no direct public table policies; application data access goes through FastAPI.

The planned frontend/backend payloads and responsibility boundaries are documented in `docs/API_CONTRACT.md`.

The database tables, relationships, naming choices, and open team decisions are explained in `docs/DATABASE_SCHEMA_GUIDE.md`.
