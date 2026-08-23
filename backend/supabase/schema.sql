-- PaceHealth MVP schema for Supabase Postgres.
-- Authentication credentials live in Supabase Auth (auth.users), not this schema.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    name text not null,
    age smallint check (age between 13 and 120),
    sex text,
    height_cm numeric(5, 2) check (height_cm > 0),
    -- Renamed from current_weight_kg: the weight recorded when the goal was set. It does
    -- not change with daily weight_records check-ins (see docs/DATABASE_SCHEMA_GUIDE.md
    -- Decision 1, resolved by team agreement).
    start_weight_kg numeric(6, 2) check (start_weight_kg > 0),
    target_weight_kg numeric(6, 2) check (target_weight_kg > 0),
    goal text,
    lifestyle text,
    exercise_frequency_per_week smallint check (exercise_frequency_per_week between 0 and 14),
    exercise_duration_minutes smallint check (exercise_duration_minutes > 0),
    -- Added per team agreement: usual exercise habits (e.g. dancing, swimming), used by
    -- the AI service to personalize generated plans.
    exercise_habit text[] not null default '{}',
    exercise_location text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.user_personal_info (
    user_id uuid primary key references auth.users(id) on delete cascade,
    available_equipment text[] not null default '{}',
    posture_issues text[] not null default '{}',
    injuries text[] not null default '{}',
    surgery_history text[] not null default '{}',
    exercises_to_avoid text[] not null default '{}',
    -- Optional. Powers the Home calendar's next-period prediction (fixed 28-day
    -- cycle assumption, computed in code) and feeds the same fact into AI plan
    -- generation + chat context, same pattern as injuries/equipment.
    last_period_date date,
    updated_at timestamptz not null default now()
);

create table if not exists public.ai_plans (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    plan_name text not null,
    goal text not null,
    weekly_frequency smallint not null check (weekly_frequency between 1 and 14),
    created_at timestamptz not null default now()
);

create table if not exists public.exercises (
    id bigint generated always as identity primary key,
    plan_id uuid not null references public.ai_plans(id) on delete cascade,
    day text not null,
    exercise_name text not null,
    sets smallint check (sets > 0),
    reps smallint check (reps > 0),
    duration_seconds integer check (duration_seconds > 0),
    rest_seconds integer check (rest_seconds >= 0),
    reason text not null,
    video_url text,
    check ((reps is null) <> (duration_seconds is null))
);

create table if not exists public.weight_records (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    weight_kg numeric(6, 2) not null check (weight_kg > 0),
    recorded_at date not null,
    created_at timestamptz not null default now(),
    unique (user_id, recorded_at)
);

create table if not exists public.chat_records (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    role text not null check (role in ('user', 'assistant')),
    message text not null,
    created_at timestamptz not null default now()
);

create table if not exists public.reports (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    period_type text not null check (period_type in ('weekly', 'monthly')),
    period_start date not null,
    period_end date not null,
    start_weight_kg numeric(6, 2),
    end_weight_kg numeric(6, 2),
    delta_kg numeric(6, 2),
    progress_to_goal_percent numeric(6, 2),
    projected_weeks_to_goal numeric(8, 2),
    summary text not null,
    created_at timestamptz not null default now(),
    check (period_end >= period_start)
);

create table if not exists public.equipment_scans (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    image_url text not null,
    equipment_name text,
    confidence numeric(5, 4) check (confidence between 0 and 1),
    ai_result jsonb,
    created_at timestamptz not null default now()
);

create table if not exists public.food_scans (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    image_url text not null,
    food_name text,
    confidence numeric(5, 4) check (confidence between 0 and 1),
    estimated_calories integer,
    estimated_protein_g numeric(6, 2),
    estimated_carbs_g numeric(6, 2),
    estimated_fat_g numeric(6, 2),
    ai_result jsonb,
    created_at timestamptz not null default now()
);

create table if not exists public.workout_completions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    plan_id uuid not null references public.ai_plans(id) on delete cascade,
    day text not null,
    -- 'completed' or 'skipped'. Skips carry a reason so the AI coach can read
    -- recent adherence and adjust its advice (see routers/ai.py chat context).
    status text not null default 'completed' check (status in ('completed', 'skipped')),
    reason text,
    duration_seconds integer,
    -- Per-exercise breakdown from the swipe-through workout session screen: each
    -- entry is {exerciseName, status, estimatedDurationSeconds, actualDurationSeconds,
    -- skipReason, skipReasonNote}. Null for older/simpler completions that only
    -- recorded the day-level status above.
    exercise_log jsonb,
    -- Answers from the contextual end-of-workout feedback form (only asked when the
    -- session looked unusual — see WorkoutFeedback in app/schemas/workout.py). Null
    -- when no feedback was collected (the normal case).
    feedback jsonb,
    completed_at timestamptz not null default now()
);

create index if not exists ai_plans_user_id_idx on public.ai_plans(user_id);
create index if not exists exercises_plan_id_idx on public.exercises(plan_id);
create index if not exists weight_records_user_date_idx on public.weight_records(user_id, recorded_at);
create index if not exists chat_records_user_created_idx on public.chat_records(user_id, created_at);
create index if not exists reports_user_period_idx on public.reports(user_id, period_type, period_start);
create index if not exists equipment_scans_user_created_idx on public.equipment_scans(user_id, created_at);
create index if not exists food_scans_user_created_idx on public.food_scans(user_id, created_at);
create index if not exists workout_completions_user_created_idx on public.workout_completions(user_id, completed_at);

-- Secure by default: only the FastAPI backend's secret key may access these tables.
-- Add user-scoped RLS policies later only if Flutter needs direct table access.
alter table public.profiles enable row level security;
alter table public.user_personal_info enable row level security;
alter table public.ai_plans enable row level security;
alter table public.exercises enable row level security;
alter table public.weight_records enable row level security;
alter table public.chat_records enable row level security;
alter table public.reports enable row level security;
alter table public.equipment_scans enable row level security;
alter table public.food_scans enable row level security;
alter table public.workout_completions enable row level security;
