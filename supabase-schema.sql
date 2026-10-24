-- Wahi Al-Samaa: run once in Supabase > SQL Editor

create table if not exists items (
  id bigint generated always as identity primary key,
  name text not null,
  category text,
  qty int not null default 0 check (qty >= 0),
  min_qty int not null default 0,
  location text,
  created_at timestamptz default now()
);

create table if not exists loans (
  id bigint generated always as identity primary key,
  item_id bigint not null references items(id) on delete cascade,
  borrower text not null,
  qty int not null check (qty > 0),
  destination text not null,
  loan_date date not null default current_date,
  returned_at timestamptz
);

create table if not exists kitchen_items (
  id bigint generated always as identity primary key,
  name text not null,
  category text,
  qty int not null default 0 check (qty >= 0),
  min_qty int not null default 0,
  expiry_date date,
  location text
);

create table if not exists books (
  id bigint generated always as identity primary key,
  title text not null,
  author text,
  category text,
  shelf text,
  status text not null default 'متوفر',
  borrower text
);

create table if not exists students (
  id bigint generated always as identity primary key,
  name text not null,
  plan text,
  progress int not null default 0 check (progress between 0 and 100),
  notes text
);

-- Stock moves automatically when a loan is created or returned
create or replace function loan_stock() returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    update items set qty = qty - new.qty where id = new.item_id;
  elsif tg_op = 'UPDATE' and old.returned_at is null and new.returned_at is not null then
    update items set qty = qty + new.qty where id = new.item_id;
  end if;
  return new;
end $$;

drop trigger if exists trg_loan_stock on loans;
create trigger trg_loan_stock after insert or update on loans
  for each row execute function loan_stock();

-- Access: OPEN to anyone holding the site link (no login yet).
-- Replace with auth-based policies before storing sensitive data.
do $$
declare t text;
begin
  foreach t in array array['items','loans','kitchen_items','books','students'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists open_access on %I', t);
    execute format('create policy open_access on %I for all to anon using (true) with check (true)', t);
  end loop;
end $$;
