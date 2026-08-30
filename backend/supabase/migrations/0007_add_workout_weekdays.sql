-- Stores the ordered weekdays selected during onboarding.
alter table public.user_personal_info
  add column if not exists workout_weekdays text[] not null default '{}';
