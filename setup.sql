-- QuizHub 테이블 설정
-- Supabase SQL Editor에서 실행하세요

-- 기존 테이블 삭제 (재실행 시)
drop table if exists badges;
drop table if exists quiz_records;
drop table if exists quizzes;
drop table if exists members;

-- 회원 테이블
create table members (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  phone text not null,
  role text default 'user',
  joined timestamptz default now(),
  unique(name, phone)
);

-- 퀴즈 테이블
create table quizzes (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  description text default '',
  html_content text not null,
  added timestamptz default now()
);

-- 풀이 기록 테이블
create table quiz_records (
  id uuid default gen_random_uuid() primary key,
  member_id uuid references members(id) on delete cascade,
  member_name text,
  quiz_id uuid references quizzes(id) on delete set null,
  quiz_title text,
  score int not null,
  total int not null,
  wrong_words jsonb default '[]',
  max_combo int default 0,
  total_time int default 0,
  played_at timestamptz default now()
);

-- 뱃지 테이블
create table badges (
  id uuid default gen_random_uuid() primary key,
  member_id uuid references members(id) on delete cascade,
  member_name text,
  badge_type text not null,
  quiz_id uuid references quizzes(id) on delete set null,
  quiz_title text,
  earned_at timestamptz default now(),
  unique(member_id, badge_type, quiz_id)
);

-- 보안 정책 (로그인 없이 동작)
alter table members enable row level security;
alter table quizzes enable row level security;
alter table quiz_records enable row level security;
alter table badges enable row level security;

create policy "allow all members" on members for all using (true) with check (true);
create policy "allow all quizzes" on quizzes for all using (true) with check (true);
create policy "allow all quiz_records" on quiz_records for all using (true) with check (true);
create policy "allow all badges" on badges for all using (true) with check (true);

-- 관리자 계정 생성
insert into members (name, phone, role)
values ('관리자', '01000000000', 'admin');
