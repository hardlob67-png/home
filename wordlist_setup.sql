-- 단어장 시스템 (분반별 단어장 + 단어)
-- Supabase SQL Editor에서 실행

-- 단어장 테이블
-- class_id: legacy 단일 분반 컬럼 (호환성 유지, nullable). 신규 코드는 wordlist_classes를 사용.
create table if not exists wordlists (
  id uuid primary key default gen_random_uuid(),
  class_id uuid references classes(id) on delete set null,
  title text not null,
  created_at timestamptz default now()
);

-- 단어 테이블 (단어장에 속함, 단원으로 분할)
create table if not exists words (
  id uuid primary key default gen_random_uuid(),
  wordlist_id uuid references wordlists(id) on delete cascade,
  unit int not null default 1,
  idx int not null,
  en text not null,
  ko text not null
);

-- 단어장 ↔ 분반 다대다 매핑 테이블 (한 단어장이 여러 분반에 매핑 가능)
create table if not exists wordlist_classes (
  wordlist_id uuid not null references wordlists(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  primary key (wordlist_id, class_id)
);

-- 인덱스
create index if not exists idx_wordlists_class on wordlists(class_id);
create index if not exists idx_words_wordlist on words(wordlist_id);
create index if not exists idx_words_unit on words(wordlist_id, unit);
create index if not exists idx_wlc_class on wordlist_classes(class_id);
create index if not exists idx_wlc_wordlist on wordlist_classes(wordlist_id);

-- 기존 wordlists.class_id 데이터를 junction으로 이전 (1회성, 안전: on conflict do nothing)
insert into wordlist_classes (wordlist_id, class_id)
  select id, class_id from wordlists where class_id is not null
  on conflict do nothing;

-- RLS (기존 패턴과 동일 — 클라이언트단 권한 체크)
alter table wordlists enable row level security;
alter table words enable row level security;
alter table wordlist_classes enable row level security;

drop policy if exists "allow all wordlists" on wordlists;
drop policy if exists "allow all words" on words;
drop policy if exists "allow all wordlist_classes" on wordlist_classes;

create policy "allow all wordlists" on wordlists for all using (true) with check (true);
create policy "allow all words" on words for all using (true) with check (true);
create policy "allow all wordlist_classes" on wordlist_classes for all using (true) with check (true);
