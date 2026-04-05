-- QuizHub 테이블 설정
-- Supabase SQL Editor에서 실행하세요

-- 기존 테이블 삭제 (재실행 시)
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

-- 보안 정책 (로그인 없이 동작)
alter table members enable row level security;
alter table quizzes enable row level security;

create policy "allow all members" on members for all using (true) with check (true);
create policy "allow all quizzes" on quizzes for all using (true) with check (true);

-- 관리자 계정 생성
insert into members (name, phone, role)
values ('관리자', '01000000000', 'admin');
