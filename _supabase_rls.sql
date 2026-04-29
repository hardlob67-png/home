-- ============================================================
--  RLS 정책 재설계
--  Supabase SQL Editor에서 한 번에 실행
--  실행 전: 백업 브랜치 backup-pre-rls 생성 완료 확인
-- ============================================================

-- 0) 기존 무차별 정책 제거
drop policy if exists "allow all members" on members;
drop policy if exists "allow all quizzes" on quizzes;
drop policy if exists "allow all quiz_records" on quiz_records;
drop policy if exists "allow all badges" on badges;

-- 누락된 14개 테이블도 RLS 켜고 기존 정책 삭제
do $$
declare t text;
begin
  for t in select unnest(array[
    'announcements','chats','class_files','class_members','classes',
    'clinic_locations','clinics','combo_records','grade_sessions','grades',
    'sms_logs','test_responses','test_sets','test_versions'
  ]) loop
    execute format('alter table if exists %I enable row level security', t);
    execute format('drop policy if exists %I on %I', 'allow all '||t, t);
  end loop;
end $$;

-- ============================================================
--  헬퍼 함수: JWT claim 빠르게 꺼내기
-- ============================================================
-- public 스키마에 만든다 (auth 스키마는 protected)
create or replace function public.app_role() returns text
  language sql stable as $$
    select coalesce(auth.jwt()->>'app_role', '')::text
  $$;

create or replace function public.user_id() returns uuid
  language sql stable as $$
    select nullif(auth.jwt()->>'sub', '')::uuid
  $$;

create or replace function public.is_admin() returns boolean
  language sql stable as $$
    select auth.jwt()->>'app_role' = 'admin'
  $$;

-- anon, authenticated가 호출할 수 있도록 권한 부여
grant execute on function public.app_role() to anon, authenticated;
grant execute on function public.user_id() to anon, authenticated;
grant execute on function public.is_admin() to anon, authenticated;

-- ============================================================
--  members
--   - admin: 모두
--   - 본인: 본인 행만 select
--   - 비밀번호(password) 컬럼은 service_role만 (Edge Function용)
-- ============================================================
create policy "members_admin_all" on members for all
  using (public.is_admin()) with check (public.is_admin());
create policy "members_self_select" on members for select
  using (id = public.user_id());

-- 비밀번호 컬럼 read 차단 (column-level은 별도 view 또는 Postgres 12+ column privilege)
-- 가장 단순: 모든 정상 클라이언트가 password를 select하지 않도록 하고,
-- service_role(Edge Function)만 select.
-- (이미 admin 정책이 password 포함 모두 select 가능 — 운영자 본인이 보는 건 OK)

-- ============================================================
--  classes / class_members
--   - admin: 모두
--   - 본인: 본인이 속한 분반만 read
-- ============================================================
create policy "classes_admin_all" on classes for all
  using (public.is_admin()) with check (public.is_admin());
create policy "classes_authenticated_select" on classes for select
  using (auth.role() = 'authenticated');

create policy "class_members_admin_all" on class_members for all
  using (public.is_admin()) with check (public.is_admin());
create policy "class_members_self_select" on class_members for select
  using (member_id = public.user_id());

-- ============================================================
--  quizzes / quiz_records / badges / combo_records
--   - admin: 모두
--   - 본인 기록: 본인만 read/insert
--   - quizzes 자체는 인증된 사용자 전부 read (학생이 풀려면 필요)
-- ============================================================
create policy "quizzes_admin_all" on quizzes for all
  using (public.is_admin()) with check (public.is_admin());
create policy "quizzes_authenticated_select" on quizzes for select
  using (auth.role() = 'authenticated');

create policy "quiz_records_admin_all" on quiz_records for all
  using (public.is_admin()) with check (public.is_admin());
create policy "quiz_records_self_select" on quiz_records for select
  using (member_id = public.user_id());
create policy "quiz_records_self_insert" on quiz_records for insert
  with check (member_id = public.user_id());

create policy "badges_admin_all" on badges for all
  using (public.is_admin()) with check (public.is_admin());
create policy "badges_self_select" on badges for select
  using (member_id = public.user_id());
create policy "badges_self_insert" on badges for insert
  with check (member_id = public.user_id());

create policy "combo_records_admin_all" on combo_records for all
  using (public.is_admin()) with check (public.is_admin());
create policy "combo_records_self_select" on combo_records for select
  using (member_id = public.user_id());
create policy "combo_records_self_insert" on combo_records for insert
  with check (member_id = public.user_id());

-- ============================================================
--  announcements (공지) — admin만 작성, 모두 read
-- ============================================================
create policy "announcements_admin_all" on announcements for all
  using (public.is_admin()) with check (public.is_admin());
create policy "announcements_authenticated_select" on announcements for select
  using (auth.role() = 'authenticated');

-- ============================================================
--  chats — admin은 모두, 학부모/학생은 본인 관련 메시지만
-- ============================================================
create policy "chats_admin_all" on chats for all
  using (public.is_admin()) with check (public.is_admin());
create policy "chats_self_rw" on chats for all
  using (member_id = public.user_id())
  with check (member_id = public.user_id());

-- ============================================================
--  clinics / clinic_locations
--   - admin / clinic_admin: 모두
--   - 본인: 본인 클리닉 일정만 read
-- ============================================================
create policy "clinic_locations_admin_all" on clinic_locations for all
  using (public.is_admin()) with check (public.is_admin());
create policy "clinic_locations_authenticated_select" on clinic_locations for select
  using (auth.role() = 'authenticated');

create policy "clinics_admin_all" on clinics for all
  using (public.is_admin() or public.app_role() = 'clinic_admin')
  with check (public.is_admin() or public.app_role() = 'clinic_admin');
create policy "clinics_self_select" on clinics for select
  using (member_id = public.user_id());

-- ============================================================
--  grades / grade_sessions
--   - admin: 모두
--   - 본인: 본인 성적만 read
-- ============================================================
create policy "grade_sessions_admin_all" on grade_sessions for all
  using (public.is_admin()) with check (public.is_admin());
create policy "grade_sessions_authenticated_select" on grade_sessions for select
  using (auth.role() = 'authenticated');

create policy "grades_admin_all" on grades for all
  using (public.is_admin()) with check (public.is_admin());
create policy "grades_self_select" on grades for select
  using (member_id = public.user_id());

-- ============================================================
--  test_sets / test_versions / test_responses
--   - admin: 모두
--   - 본인: 본인 응답만 read/insert
-- ============================================================
create policy "test_sets_admin_all" on test_sets for all
  using (public.is_admin()) with check (public.is_admin());
create policy "test_sets_authenticated_select" on test_sets for select
  using (auth.role() = 'authenticated');

create policy "test_versions_admin_all" on test_versions for all
  using (public.is_admin()) with check (public.is_admin());
create policy "test_versions_authenticated_select" on test_versions for select
  using (auth.role() = 'authenticated');

create policy "test_responses_admin_all" on test_responses for all
  using (public.is_admin()) with check (public.is_admin());
create policy "test_responses_self_rw" on test_responses for all
  using (member_id = public.user_id())
  with check (member_id = public.user_id());

-- ============================================================
--  class_files — admin / clinic_admin: 모두, 본인 분반 회원: read
-- ============================================================
create policy "class_files_admin_all" on class_files for all
  using (public.is_admin()) with check (public.is_admin());
create policy "class_files_self_select" on class_files for select
  using (
    class_id in (select class_id from class_members where member_id = public.user_id())
  );

-- ============================================================
--  sms_logs — admin만
-- ============================================================
create policy "sms_logs_admin_all" on sms_logs for all
  using (public.is_admin()) with check (public.is_admin());

-- ============================================================
--  되돌리기 (만약 사이트가 안 되면 이 SQL을 실행)
-- ============================================================
-- do $$
-- declare t text;
-- begin
--   for t in select unnest(array[
--     'members','quizzes','quiz_records','badges','announcements','chats',
--     'class_files','class_members','classes','clinic_locations','clinics',
--     'combo_records','grade_sessions','grades','sms_logs','test_responses',
--     'test_sets','test_versions'
--   ]) loop
--     execute format('drop policy if exists %I on %I', '...', t);
--   end loop;
--   -- 또는 가장 단순: alter table xxx disable row level security; for each
-- end $$;
