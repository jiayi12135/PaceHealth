-- Adds outcome tracking to workout_completions so the app can record both
-- finished sessions (with a duration) and skipped ones (with a reason the
-- AI coach reads to adjust its advice). Applied live via the Supabase MCP
-- as migration `extend_workout_completions`.

alter table public.workout_completions
    add column if not exists status text not null default 'completed' check (status in ('completed', 'skipped')),
    add column if not exists reason text,
    add column if not exists duration_seconds integer;
