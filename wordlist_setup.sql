-- 단어장 시스템 (분반별 단어장 + 단어)
-- Supabase SQL Editor에서 실행

-- 단어장 테이블 (분반 1개에 매핑)
create table wordlists (
  id uuid primary key default gen_random_uuid(),
  class_id uuid references classes(id) on delete cascade,
  title text not null,
  created_at timestamptz default now()
);

-- 단어 테이블 (단어장에 속함, 단원으로 분할)
create table words (
  id uuid primary key default gen_random_uuid(),
  wordlist_id uuid references wordlists(id) on delete cascade,
  unit int not null default 1,
  idx int not null,
  en text not null,
  ko text not null
);

-- 인덱스
create index idx_wordlists_class on wordlists(class_id);
create index idx_words_wordlist on words(wordlist_id);
create index idx_words_unit on words(wordlist_id, unit);

-- RLS (기존 패턴과 동일 — 클라이언트단 권한 체크)
alter table wordlists enable row level security;
alter table words enable row level security;

create policy "allow all wordlists" on wordlists for all using (true) with check (true);
create policy "allow all words" on words for all using (true) with check (true);
