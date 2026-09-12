-- ============================================================================
-- TIMORA ADMIN RLS & REALTIME SYNC MIGRATION
-- Adds SELECT permissions for verified admins on core tables
-- Configures storage bucket for career_documents
-- Adds shared admin tables to supabase_realtime publication
-- ============================================================================

-- 1. ADMIN SELECT POLICIES ON CORE TABLES FOR METRICS & MANAGEMENT
drop policy if exists "Admins can view all profiles" on public.profiles;
create policy "Admins can view all profiles" on public.profiles
  for select using (public.is_admin());

drop policy if exists "Admins can view all tasks" on public.tasks;
create policy "Admins can view all tasks" on public.tasks
  for select using (public.is_admin());

drop policy if exists "Admins can view all task_subtasks" on public.task_subtasks;
create policy "Admins can view all task_subtasks" on public.task_subtasks
  for select using (public.is_admin());

drop policy if exists "Admins can view all routines" on public.routines;
create policy "Admins can view all routines" on public.routines
  for select using (public.is_admin());

drop policy if exists "Admins can view all routine_blocks" on public.routine_blocks;
create policy "Admins can view all routine_blocks" on public.routine_blocks
  for select using (public.is_admin());

drop policy if exists "Admins can view all schedule_activities" on public.schedule_activities;
create policy "Admins can view all schedule_activities" on public.schedule_activities
  for select using (public.is_admin());

drop policy if exists "Admins can view all goals" on public.goals;
create policy "Admins can view all goals" on public.goals
  for select using (public.is_admin());

drop policy if exists "Admins can view all goal_milestones" on public.goal_milestones;
create policy "Admins can view all goal_milestones" on public.goal_milestones
  for select using (public.is_admin());

drop policy if exists "Admins can view all projects" on public.projects;
create policy "Admins can view all projects" on public.projects
  for select using (public.is_admin());

drop policy if exists "Admins can view all focus_sessions" on public.focus_sessions;
create policy "Admins can view all focus_sessions" on public.focus_sessions
  for select using (public.is_admin());

drop policy if exists "Admins can view all habits" on public.habits;
create policy "Admins can view all habits" on public.habits
  for select using (public.is_admin());

drop policy if exists "Admins can view all habit_logs" on public.habit_logs;
create policy "Admins can view all habit_logs" on public.habit_logs
  for select using (public.is_admin());

-- 2. STORAGE BUCKET & POLICIES FOR CAREER DOCUMENT VAULT
insert into storage.buckets (id, name, public)
values ('career_documents', 'career_documents', true)
on conflict (id) do update set public = true;

insert into storage.buckets (id, name, public)
values ('career_vault', 'career_vault', true)
on conflict (id) do update set public = true;

drop policy if exists "Authenticated users can upload career documents" on storage.objects;
create policy "Authenticated users can upload career documents" on storage.objects
  for insert with check (
    bucket_id in ('career_documents', 'career_vault') and
    auth.role() = 'authenticated'
  );

drop policy if exists "Users and admins can view career documents" on storage.objects;
create policy "Users and admins can view career documents" on storage.objects
  for select using (
    bucket_id in ('career_documents', 'career_vault') and (
      public.is_admin() or
      (storage.foldername(name))[2] = auth.uid()::text or
      auth.role() = 'authenticated'
    )
  );

drop policy if exists "Users can delete own career documents" on storage.objects;
create policy "Users can delete own career documents" on storage.objects
  for delete using (
    bucket_id in ('career_documents', 'career_vault') and (
      public.is_admin() or
      (storage.foldername(name))[2] = auth.uid()::text
    )
  );

-- 3. ENABLE SUPABASE REALTIME ON SHARED ADMIN TABLES
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'app_activities'
  ) then
    alter publication supabase_realtime add table public.app_activities;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'app_activity_categories'
  ) then
    alter publication supabase_realtime add table public.app_activity_categories;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'app_templates'
  ) then
    alter publication supabase_realtime add table public.app_templates;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'app_feature_flags'
  ) then
    alter publication supabase_realtime add table public.app_feature_flags;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'app_content'
  ) then
    alter publication supabase_realtime add table public.app_content;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'app_notifications'
  ) then
    alter publication supabase_realtime add table public.app_notifications;
  end if;
exception
  when others then
    -- Publication alters may require superuser or may already exist
    null;
end;
$$;
