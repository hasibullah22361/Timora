-- ============================================================================
-- TIMORA MASTER DATABASE SCHEMA MIGRATION (PHASE 1)
-- Description: Complete schema for Timora Personal Time Management & Productivity System
-- Includes: RLS policies, automated profile triggers, foreign keys, indexes
-- ============================================================================

-- Enable required extensions
create extension if not exists "uuid-ossp";

-- ============================================================================
-- 1. PROFILES TABLE & TRIGGER
-- ============================================================================
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  email text not null,
  display_name text,
  username text,
  bio text default 'Optimizing time, building routines, and staying focused.',
  avatar_preset text default '⚡',
  avatar_color_value bigint default 4280656875,
  avatar_url text,
  timezone text default 'UTC+05:00 - Islamabad, Karachi',
  work_hours_start_minutes int default 540, -- 9:00 AM
  work_hours_end_minutes int default 1080,  -- 6:00 PM
  daily_goal_hours numeric default 6.0,
  daily_task_goal int default 5,
  routine_preference text default 'Time-blocking',
  theme_mode text default 'system',
  notifications_enabled boolean default true,
  sync_enabled boolean default true,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

-- Enable RLS for profiles
alter table public.profiles enable row level security;

create policy "Users can view own profile" on public.profiles
  for select using (auth.uid() = id);

create policy "Users can update own profile" on public.profiles
  for update using (auth.uid() = id);

create policy "Users can insert own profile" on public.profiles
  for insert with check (auth.uid() = id);

-- Function and trigger to auto-create profile on user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (
    id,
    email,
    display_name,
    username,
    created_at,
    updated_at
  ) values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    split_part(new.email, '@', 1),
    now(),
    now()
  ) on conflict (id) do update set
    email = excluded.email,
    updated_at = now();
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================================
-- 2. PROJECTS TABLE
-- ============================================================================
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  title text not null,
  description text default '',
  category text default 'Work',
  status text default 'active', -- 'active', 'paused', 'completed', 'archived'
  color bigint default 4280656875,
  icon text default '📁',
  target_date timestamptz,
  goal_id uuid,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  completed_at timestamptz
);

alter table public.projects enable row level security;

create policy "Users manage own projects" on public.projects
  for all using (auth.uid() = user_id);

create index if not exists idx_projects_user_id on public.projects(user_id);

-- ============================================================================
-- 3. GOALS & MILESTONES TABLE
-- ============================================================================
create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  title text not null,
  description text default '',
  category text default 'Other',
  status text default 'active', -- 'active', 'paused', 'completed', 'archived'
  priority text default 'medium', -- 'low', 'medium', 'high'
  icon text default '🎯',
  color bigint default 4280656875,
  start_date timestamptz,
  target_date timestamptz,
  progress_mode text default 'auto', -- 'auto', 'manual'
  manual_progress numeric default 0.0,
  notes text default '',
  is_deleted boolean default false,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  completed_at timestamptz
);

alter table public.goals enable row level security;

create policy "Users manage own goals" on public.goals
  for all using (auth.uid() = user_id);

create index if not exists idx_goals_user_id on public.goals(user_id);

create table if not exists public.goal_milestones (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  goal_id uuid references public.goals(id) on delete cascade not null,
  title text not null,
  description text default '',
  status text default 'notStarted', -- 'notStarted', 'inProgress', 'completed', 'skipped'
  priority int default 1,
  sort_order int default 0,
  target_date timestamptz,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  completed_at timestamptz
);

alter table public.goal_milestones enable row level security;

create policy "Users manage own milestones" on public.goal_milestones
  for all using (auth.uid() = user_id);

create index if not exists idx_milestones_goal_id on public.goal_milestones(goal_id);

-- ============================================================================
-- 4. TASKS & SUBTASKS TABLE
-- ============================================================================
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  title text not null,
  description text default '',
  category text default 'Other',
  priority text default 'medium', -- 'none', 'low', 'medium', 'high', 'urgent'
  status text default 'pending',   -- 'pending', 'inProgress', 'completed', 'cancelled'
  due_date date,
  due_time text,
  reminder_enabled boolean default false,
  reminder_minutes_before int default 15,
  schedule_activity_id text,
  project_id uuid references public.projects(id) on delete set null,
  goal_id uuid references public.goals(id) on delete set null,
  milestone_id uuid references public.goal_milestones(id) on delete set null,
  notes text default '',
  is_deleted boolean default false,
  recurrence text default 'none',
  estimated_duration_minutes int default 30,
  actual_duration_minutes int default 0,
  parent_task_id uuid references public.tasks(id) on delete set null,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  completed_at timestamptz
);

alter table public.tasks enable row level security;

create policy "Users manage own tasks" on public.tasks
  for all using (auth.uid() = user_id);

create index if not exists idx_tasks_user_id on public.tasks(user_id);
create index if not exists idx_tasks_due_date on public.tasks(user_id, due_date);
create index if not exists idx_tasks_status on public.tasks(user_id, status);

create table if not exists public.task_subtasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  task_id uuid references public.tasks(id) on delete cascade not null,
  title text not null,
  is_completed boolean default false,
  sort_order int default 0,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

alter table public.task_subtasks enable row level security;

create policy "Users manage own subtasks" on public.task_subtasks
  for all using (auth.uid() = user_id);

create index if not exists idx_subtasks_task_id on public.task_subtasks(task_id);

-- Task Dependencies table
create table if not exists public.task_dependencies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  task_id uuid references public.tasks(id) on delete cascade not null,
  depends_on_task_id uuid references public.tasks(id) on delete cascade not null,
  created_at timestamptz default now() not null,
  unique(task_id, depends_on_task_id)
);

alter table public.task_dependencies enable row level security;

create policy "Users manage own task dependencies" on public.task_dependencies
  for all using (auth.uid() = user_id);

-- ============================================================================
-- 5. ROUTINES & ROUTINE BLOCKS
-- ============================================================================
create table if not exists public.routines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  name text not null,
  description text default '',
  icon text default '📌',
  color bigint default 4280656875,
  enabled boolean default true,
  days_of_week int[] default '{1,2,3,4,5,6,7}',
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

alter table public.routines enable row level security;

create policy "Users manage own routines" on public.routines
  for all using (auth.uid() = user_id);

create index if not exists idx_routines_user_id on public.routines(user_id);

create table if not exists public.routine_blocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  routine_id uuid references public.routines(id) on delete cascade not null,
  title text not null,
  description text default '',
  start_hour int not null,
  start_minute int not null,
  end_hour int not null,
  end_minute int not null,
  category text default 'Routine',
  icon text default '📌',
  color bigint default 4280656875,
  sort_order int default 0,
  enabled boolean default true,
  notes text default '',
  created_at timestamptz default now() not null
);

alter table public.routine_blocks enable row level security;

create policy "Users manage own routine blocks" on public.routine_blocks
  for all using (auth.uid() = user_id);

create index if not exists idx_routine_blocks_routine_id on public.routine_blocks(routine_id);

-- ============================================================================
-- 6. SCHEDULE ACTIVITIES
-- ============================================================================
create table if not exists public.schedule_activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  title text not null,
  description text default '',
  activity_date date not null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  category text default 'Routine',
  icon text default '📌',
  color bigint default 4280656875,
  status text default 'upcoming', -- 'upcoming', 'current', 'completed', 'skipped'
  notes text default '',
  reminder_enabled boolean default true,
  routine_block_id uuid references public.routine_blocks(id) on delete set null,
  is_overridden boolean default false,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  completed_at timestamptz
);

alter table public.schedule_activities enable row level security;

create policy "Users manage own schedule activities" on public.schedule_activities
  for all using (auth.uid() = user_id);

create index if not exists idx_schedule_user_date on public.schedule_activities(user_id, activity_date);

-- ============================================================================
-- 7. HABITS & HABIT LOGS
-- ============================================================================
create table if not exists public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  title text not null,
  description text default '',
  icon text default '🔥',
  color bigint default 4280656875,
  frequency text default 'daily', -- 'daily', 'weekly', 'monthly'
  target_days_per_week int default 7,
  reminder_time text,
  current_streak int default 0,
  best_streak int default 0,
  goal_id uuid references public.goals(id) on delete set null,
  is_archived boolean default false,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

alter table public.habits enable row level security;

create policy "Users manage own habits" on public.habits
  for all using (auth.uid() = user_id);

create index if not exists idx_habits_user_id on public.habits(user_id);

create table if not exists public.habit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  habit_id uuid references public.habits(id) on delete cascade not null,
  log_date date not null,
  completed boolean default true,
  notes text default '',
  created_at timestamptz default now() not null,
  unique(habit_id, log_date)
);

alter table public.habit_logs enable row level security;

create policy "Users manage own habit logs" on public.habit_logs
  for all using (auth.uid() = user_id);

create index if not exists idx_habit_logs_user_date on public.habit_logs(user_id, log_date);

-- ============================================================================
-- 8. DIARY ENTRIES
-- ============================================================================
create table if not exists public.diary_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  entry_date date not null,
  title text default '',
  content text not null,
  mood text default 'neutral', -- 'ecstatic', 'happy', 'neutral', 'stressed', 'tired', 'down'
  energy int default 3, -- 1 to 5
  tags text[] default '{}',
  is_private boolean default true,
  allow_ai_analysis boolean default false,
  tomorrow_priorities text default '',
  lessons_learned text default '',
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

alter table public.diary_entries enable row level security;

create policy "Users manage own diary entries" on public.diary_entries
  for all using (auth.uid() = user_id);

create index if not exists idx_diary_user_date on public.diary_entries(user_id, entry_date);

-- ============================================================================
-- 9. FOCUS SESSIONS
-- ============================================================================
create table if not exists public.focus_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  task_id uuid references public.tasks(id) on delete set null,
  project_id uuid references public.projects(id) on delete set null,
  goal_id uuid references public.goals(id) on delete set null,
  milestone_id uuid references public.goal_milestones(id) on delete set null,
  started_at timestamptz not null,
  ended_at timestamptz,
  planned_duration_seconds int default 1500,
  actual_duration_seconds int default 0,
  total_paused_duration_seconds int default 0,
  status text default 'completed', -- 'running', 'paused', 'completed', 'cancelled', 'breakTime'
  mode text default 'focus',       -- 'focus', 'pomodoro', 'custom'
  notes text default '',
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

alter table public.focus_sessions enable row level security;

create policy "Users manage own focus sessions" on public.focus_sessions
  for all using (auth.uid() = user_id);

create index if not exists idx_focus_user_id on public.focus_sessions(user_id);

-- ============================================================================
-- 10. PLANNING TABLES (DAILY, WEEKLY, MONTHLY)
-- ============================================================================
create table if not exists public.daily_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  plan_date date not null,
  status text default 'draft', -- 'draft', 'planned', 'inProgress', 'completed', 'archived'
  planned_duration_seconds int default 0,
  completed_duration_seconds int default 0,
  notes text default '',
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  unique(user_id, plan_date)
);

alter table public.daily_plans enable row level security;

create policy "Users manage own daily plans" on public.daily_plans
  for all using (auth.uid() = user_id);

create table if not exists public.planned_task_blocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  daily_plan_id uuid references public.daily_plans(id) on delete cascade not null,
  task_id uuid references public.tasks(id) on delete cascade not null,
  start_hour int not null,
  start_minute int not null,
  end_hour int not null,
  end_minute int not null,
  estimated_duration_seconds int default 1800,
  status text default 'pending', -- 'pending', 'completed', 'missed'
  focus_session_id uuid references public.focus_sessions(id) on delete set null,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

alter table public.planned_task_blocks enable row level security;

create policy "Users manage own planned task blocks" on public.planned_task_blocks
  for all using (auth.uid() = user_id);

create table if not exists public.weekly_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  week_start_date date not null,
  week_end_date date not null,
  status text default 'draft',
  notes text default '',
  planned_duration_seconds int default 0,
  target_focus_duration_seconds int default 0,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

alter table public.weekly_plans enable row level security;

create policy "Users manage own weekly plans" on public.weekly_plans
  for all using (auth.uid() = user_id);

create table if not exists public.monthly_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  plan_year int not null,
  plan_month int not null,
  status text default 'draft',
  notes text default '',
  planned_duration_seconds int default 0,
  target_focus_duration_seconds int default 0,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  unique(user_id, plan_year, plan_month)
);

alter table public.monthly_plans enable row level security;

create policy "Users manage own monthly plans" on public.monthly_plans
  for all using (auth.uid() = user_id);

-- ============================================================================
-- 11. AI CONVERSATIONS, MESSAGES & ACTION AUDIT LOGS
-- ============================================================================
create table if not exists public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  title text default 'New Conversation',
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

alter table public.ai_conversations enable row level security;

create policy "Users manage own AI conversations" on public.ai_conversations
  for all using (auth.uid() = user_id);

create table if not exists public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  conversation_id uuid references public.ai_conversations(id) on delete cascade not null,
  role text not null, -- 'user', 'assistant', 'system', 'tool'
  content text not null,
  action_payload jsonb,
  created_at timestamptz default now() not null
);

alter table public.ai_messages enable row level security;

create policy "Users manage own AI messages" on public.ai_messages
  for all using (auth.uid() = user_id);

create table if not exists public.ai_action_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  conversation_id uuid references public.ai_conversations(id) on delete set null,
  action_type text not null,
  input_prompt text,
  structured_action jsonb not null,
  status text default 'proposed', -- 'proposed', 'confirmed', 'executed', 'rejected', 'failed'
  created_at timestamptz default now() not null,
  executed_at timestamptz
);

alter table public.ai_action_logs enable row level security;

create policy "Users manage own AI action logs" on public.ai_action_logs
  for all using (auth.uid() = user_id);
