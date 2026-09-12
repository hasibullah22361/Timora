-- ============================================================================
-- TIMORA ADMIN ENHANCEMENTS: USER SUSPENSION & REALTIME EXTENSION
-- ============================================================================

-- 1. Add account suspension fields to profiles table if not present
alter table public.profiles 
  add column if not exists is_suspended boolean default false,
  add column if not exists suspended_reason text default null,
  add column if not exists account_status text default 'active';

-- 2. Allow verified admins to update user profiles (for suspension/reactivation)
drop policy if exists "Admins can update user profiles" on public.profiles;
create policy "Admins can update user profiles" on public.profiles
  for update using (public.is_admin());

-- 3. Ensure admins can delete feature flags
drop policy if exists "Admins can delete feature flags" on public.app_feature_flags;
create policy "Admins can delete feature flags" on public.app_feature_flags
  for delete using (public.is_admin());

-- 4. Enable Supabase Realtime for app_system_settings and profiles if not already added
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'app_system_settings'
  ) then
    alter publication supabase_realtime add table public.app_system_settings;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;
exception
  when others then
    null;
end;
$$;
