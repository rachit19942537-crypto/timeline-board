-- Timeline Board schema
-- รันใน Supabase SQL Editor ครั้งเดียว

create extension if not exists "pgcrypto";

create table if not exists tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text default '',
  start_date date not null,
  end_date date not null,
  status text not null default 'todo' check (status in ('todo','doing','done')),
  priority text not null default 'medium' check (priority in ('low','medium','high','urgent')),
  color text default '#06b6d4',
  lane text default 'general',
  progress int default 0 check (progress between 0 and 100),
  subtasks jsonb default '[]'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists tasks_dates_idx on tasks (start_date, end_date);
create index if not exists tasks_status_idx on tasks (status);

-- auto-update updated_at
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists tasks_updated_at on tasks;
create trigger tasks_updated_at
before update on tasks
for each row execute function set_updated_at();

-- RLS: เปิด public access (ใช้ anon key อย่างเดียว ไม่มี auth)
-- ถ้าต้องการ auth ภายหลัง ให้แก้ policy
alter table tasks enable row level security;

drop policy if exists "public read" on tasks;
drop policy if exists "public write" on tasks;
drop policy if exists "public update" on tasks;
drop policy if exists "public delete" on tasks;

create policy "public read"   on tasks for select using (true);
create policy "public write"  on tasks for insert with check (true);
create policy "public update" on tasks for update using (true) with check (true);
create policy "public delete" on tasks for delete using (true);

-- GRANT privileges (RLS จะไม่ทำงานถ้า role ไม่มีสิทธิ์พื้นฐาน)
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on table tasks to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;

-- เปิด realtime
alter publication supabase_realtime add table tasks;

-- =========================================
-- categories (หมวด - ผู้ใช้สร้าง/แก้/ลบเองได้)
-- =========================================
create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  color text default '#60a5fa',
  sort_order int default 0,
  created_at timestamptz default now()
);

alter table categories enable row level security;

drop policy if exists "public read"   on categories;
drop policy if exists "public write"  on categories;
drop policy if exists "public update" on categories;
drop policy if exists "public delete" on categories;

create policy "public read"   on categories for select using (true);
create policy "public write"  on categories for insert with check (true);
create policy "public update" on categories for update using (true) with check (true);
create policy "public delete" on categories for delete using (true);

grant select, insert, update, delete on table categories to anon, authenticated;

-- link tasks → categories
alter table tasks add column if not exists category_id uuid references categories(id) on delete set null;
create index if not exists tasks_category_idx on tasks (category_id);

-- seed 3 default categories (เฉพาะถ้าเปล่า)
insert into categories (name, color, sort_order)
select * from (values
  ('แผนงาน',    '#60a5fa', 0),
  ('กำลังทำ',   '#f59e0b', 1),
  ('เสร็จแล้ว',  '#10b981', 2)
) as v(name, color, sort_order)
where not exists (select 1 from categories);

alter publication supabase_realtime add table categories;
