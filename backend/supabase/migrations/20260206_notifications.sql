-- Create notifications table for in-app alerts
create table if not exists public.notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  product_id uuid references public.products(id) on delete set null,
  title text not null,
  body text not null,
  is_read boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS Policies
alter table public.notifications enable row level security;

create policy "Users can view their own notifications"
  on public.notifications for select
  using (auth.uid() = user_id);

create policy "Users can update their own notifications (mark read)"
  on public.notifications for update
  using (auth.uid() = user_id);

-- Backend (Service Role) can insert
-- Note: Service role bypasses RLS, so no specific insert policy needed for it
-- provided "Enable Row Level Security" is on.
