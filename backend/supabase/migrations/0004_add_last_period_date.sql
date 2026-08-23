-- Adds optional menstrual cycle tracking so the Home calendar can predict the
-- next period and (via the AI context, same pattern as injuries/equipment)
-- suggest lighter training around that time. Applied live via the Supabase
-- MCP as migration `add_last_period_date`.

alter table public.user_personal_info add column if not exists last_period_date date;
