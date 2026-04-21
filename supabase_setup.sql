-- ============================================================
-- SVJM App — Supabase Setup SQL
-- Run this entire script in Supabase Dashboard > SQL Editor
-- ============================================================

-- 1. PROFILES TABLE (extends auth.users)
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  name text not null,
  role text not null check (role in ('admin', 'mde')),
  created_at timestamptz default now()
);

-- Enable RLS
alter table public.profiles enable row level security;

-- Policies: users can read their own profile; admins can read all
create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Admins can view all profiles"
  on public.profiles for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
  );

-- 2. TOKENS TABLE (project assignments)
create table if not exists public.tokens (
  id uuid default gen_random_uuid() primary key,
  project_name text not null,
  quote_ref text,                          -- optional: links to a confirmed quote fileName
  assigned_to uuid references public.profiles(id) on delete set null,
  assigned_by uuid references public.profiles(id) on delete set null,
  status text not null default 'assigned' check (status in ('assigned', 'completed')),
  created_at timestamptz default now(),
  completed_at timestamptz
);

alter table public.tokens enable row level security;

-- Admins can do everything on tokens
create policy "Admins full access to tokens"
  on public.tokens for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- MDEs can view tokens assigned to them
create policy "MDEs can view own tokens"
  on public.tokens for select
  using (assigned_to = auth.uid());

-- MDEs can update status of their own tokens
create policy "MDEs can update own token status"
  on public.tokens for update
  using (assigned_to = auth.uid());

-- 3. TOKEN FILES TABLE (files uploaded by MDE per token)
create table if not exists public.token_files (
  id uuid default gen_random_uuid() primary key,
  token_id uuid references public.tokens(id) on delete cascade not null,
  uploaded_by uuid references public.profiles(id) on delete set null,
  file_name text not null,
  file_path text not null,               -- storage path: token_id/filename
  file_size bigint,
  mime_type text,
  uploaded_at timestamptz default now()
);

alter table public.token_files enable row level security;

-- Admins can view all files
create policy "Admins can view all files"
  on public.token_files for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- MDEs can manage files for their own tokens
create policy "MDEs can manage own token files"
  on public.token_files for all
  using (uploaded_by = auth.uid());

-- MDEs can view files of tokens assigned to them
create policy "MDEs can view files of assigned tokens"
  on public.token_files for select
  using (
    exists (
      select 1 from public.tokens t
      where t.id = token_id and t.assigned_to = auth.uid()
    )
  );

-- 4. AUTO-CREATE PROFILE ON SIGNUP (trigger)
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'role', 'mde')
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 5. STORAGE BUCKET for MDE file uploads
insert into storage.buckets (id, name, public)
values ('project-files', 'project-files', false)
on conflict (id) do nothing;

-- Storage policies
create policy "MDEs can upload to their token folders"
  on storage.objects for insert
  with check (
    bucket_id = 'project-files' and
    auth.role() = 'authenticated'
  );

create policy "Authenticated users can view project files"
  on storage.objects for select
  using (
    bucket_id = 'project-files' and
    auth.role() = 'authenticated'
  );

create policy "MDEs can delete own uploads"
  on storage.objects for delete
  using (
    bucket_id = 'project-files' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- ============================================================
-- 6. SEED USERS
-- NOTE: Run these one at a time using Supabase Auth API or
-- use the Supabase Dashboard > Authentication > Users > Add User
-- Then the trigger above will auto-create their profiles.
--
-- After creating users via Dashboard/API, run this to set roles:
-- (Replace the UUIDs with the actual user IDs from auth.users)
--
-- UPDATE public.profiles SET name = 'Madan', role = 'admin'
--   WHERE id = '<madan-user-uuid>';
-- UPDATE public.profiles SET name = 'Karthi', role = 'mde'
--   WHERE id = '<karthi-user-uuid>';
-- ============================================================
