-- Fills the gap exposed by frontend session persistence: once login survives a
-- restart, the in-memory-only workout plan (and day-of-week assignments) needs a
-- backend home too, or a restored session lands with an empty Home/Calendar/Plan.
-- Applied live via the Supabase MCP as migration `persist_plan_details`.

alter table public.ai_plans add column if not exists day_assignments jsonb;
alter table public.exercises add column if not exists instructions text;
alter table public.exercises add column if not exists image_url text;
