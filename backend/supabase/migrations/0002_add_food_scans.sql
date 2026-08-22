-- Adds the food_scans table for the Nutrition tab's "photo -> estimated calories" feature.
-- Applied live against the PaceHealth Supabase project via the Supabase MCP tool;
-- this file documents the change and lets a fresh install pick it up too (schema.sql
-- already includes this table for brand-new projects, so this migration only matters
-- for databases created before this feature existed).

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

create index if not exists food_scans_user_created_idx on public.food_scans(user_id, created_at);

alter table public.food_scans enable row level security;
