-- Adds per-exercise breakdown + contextual feedback to workout_completions, for the
-- new swipe-through workout session screen (one full-screen page per exercise, with
-- skip/auto-timed-progression). Both columns are nullable so existing rows and any
-- client that only sends the day-level status/reason keep working unchanged.
-- Applied live via the Supabase MCP as migration `add_workout_exercise_log`.

alter table public.workout_completions add column if not exists exercise_log jsonb;
alter table public.workout_completions add column if not exists feedback jsonb;
