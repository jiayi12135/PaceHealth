-- Migration for the Supabase project the team is already using (profiles table
-- was created before this rename was agreed on). Safe to run once; guarded so
-- re-running it is a no-op.
--
-- Run this in the Supabase SQL editor (or via the Supabase MCP apply_migration
-- tool) against the live project. schema.sql has already been updated to match
-- this end state, so a brand-new project created from schema.sql does NOT need
-- this file — it's only for bringing an existing database up to date.

do $$
begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'profiles' and column_name = 'current_weight_kg'
    ) then
        alter table public.profiles rename column current_weight_kg to start_weight_kg;
    end if;
end $$;

alter table public.profiles
    add column if not exists exercise_habit text[] not null default '{}';
