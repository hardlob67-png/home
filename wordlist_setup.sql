-- 단어장 시스템: wordlists + words + wordlist_classes
-- Supabase SQL Editor 에서 실행
-- 기존 데이터 안전: if not exists, on conflict do nothing

create table if not exists wordlists (
  id uuid primary key default gen_random_uuid(),
  class_id uuid references classes(id) on delete set null,
  title text not null,
  created_at timestamptz default now()
);

create table if not exists words (
  id uuid primary key default gen_random_uuid(),
  wordlist_id uuid references wordlists(id) on delete cascade,
  unit int not null default 1,
  idx int not null,
  en text not null,
  ko text not null
);

create table if not exists wordlist_classes (
  wordlist_id uuid not null references wordlists(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  primary key (wordlist_id, class_id)
);

create index if not exists idx_wordlists_class on wordlists(class_id);
create index if not exists idx_words_wordlist on words(wordlist_id);
create index if not exists idx_words_unit on words(wordlist_id, unit);
create index if not exists idx_wlc_class on wordlist_classes(class_id);
create index if not exists idx_wlc_wordlist on wordlist_classes(wordlist_id);

-- legacy class_id 를 junction 으로 이전
insert into wordlist_classes (wordlist_id, class_id)
  select id, class_id from wordlists where class_id is not null
  on conflict do nothing;

alter table wordlists enable row level security;
alter table words enable row level security;
alter table wordlist_classes enable row level security;

drop policy if exists "allow all wordlists" on wordlists;
drop policy if exists "allow all words" on words;
drop policy if exists "allow all wordlist_classes" on wordlist_classes;

create policy "allow all wordlists" on wordlists for all using (true) with check (true);
create policy "allow all words" on words for all using (true) with check (true);
create policy "allow all wordlist_classes" on wordlist_classes for all using (true) with check (true);
