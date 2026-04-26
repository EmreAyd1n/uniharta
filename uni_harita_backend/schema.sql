-- Supabase Auth ile uyumlu profiles tablosu
create table public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  email text,
  full_name text,
  interests text
);

-- RLS (Row Level Security) ayarları
alter table public.profiles enable row level security;

create policy "Public profiles are viewable by everyone."
  on profiles for select
  using ( true );

create policy "Users can insert their own profile."
  on profiles for insert
  with check ( auth.uid() = id );

create policy "Users can update own profile."
  on profiles for update
  using ( auth.uid() = id );

-- Buildings Tablosu
create table public.buildings (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  latitude double precision,
  longitude double precision,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Events Tablosu
create table public.events (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  description text,
  start_time timestamp with time zone not null,
  end_time timestamp with time zone not null,
  building_id uuid references public.buildings(id) on delete cascade,
  organizer_id uuid references public.profiles(id) on delete cascade,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS (Row Level Security) Ayarları - Buildings
alter table public.buildings enable row level security;

create policy "Buildings are viewable by everyone."
  on public.buildings for select
  using ( true );

-- RLS (Row Level Security) Ayarları - Events
alter table public.events enable row level security;

create policy "Events are viewable by everyone."
  on public.events for select
  using ( true );

create policy "Authenticated users can create events."
  on public.events for insert
  with check ( auth.role() = 'authenticated' );

create policy "Organizers can update their own events."
  on public.events for update
  using ( auth.uid() = organizer_id );

create policy "Organizers can delete their own events."
  on public.events for delete
  using ( auth.uid() = organizer_id );
