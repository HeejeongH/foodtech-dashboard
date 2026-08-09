-- ============================================================
-- 푸드테크 센터 대시보드 · 등록된 SQL 쿼리 모음
-- Total: 26 queries
--
-- 이 파일은 서울대학교 푸드테크 센터 & 월드푸드테크협의회 워크스페이스의
-- 대시보드 인터랙티브 뷰가 프론트엔드에서 window.agentdb.executeQuery(name, params)
-- 로 호출하는 named query들의 정의입니다.
--
-- 편집 후 재적용하려면 각 쿼리를 upsert_app_query로 다시 등록하거나
-- 워크스페이스 UI에서 "앱 편집 > 쿼리" 에서 수정하세요.
-- ============================================================


-- ------------------------------------------------------------
-- Query: summary_kpis
-- Description: 상단 KPI 카드용 핵심 지표
-- ------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM people) AS total_people,
  (SELECT COUNT(*) FROM program_enrollments WHERE role = '수강생') AS total_enrollments,
  (SELECT COUNT(*) FROM wftc_memberships WHERE membership_status = '가입 완료') AS wftc_members,
  (SELECT COUNT(*) FROM wftc_memberships WHERE membership_status IN ('가입 권유 중','가입 신청')) AS wftc_pipeline,
  (SELECT COUNT(*) FROM events WHERE status IN ('예정','준비중','진행중')) AS active_events,
  (SELECT COUNT(*) FROM event_presentations WHERE status = '완료') AS presentations_done,
  (SELECT COUNT(*) FROM projects WHERE status IN ('진행중','선정')) AS active_projects,
  (SELECT COUNT(*) FROM projects WHERE status = '발굴/기획') AS pipeline_projects;


-- ------------------------------------------------------------
-- Query: enrollments_by_program
-- Description: 교육과정별 수강생 수
-- ------------------------------------------------------------
SELECT ep.name AS program, COUNT(DISTINCT pe.person_id) AS student_count
FROM education_programs ep
LEFT JOIN program_cohorts pc ON pc.program_id = ep.id
LEFT JOIN program_enrollments pe ON pe.cohort_id = pc.id AND pe.role = '수강생'
GROUP BY ep.id, ep.name
ORDER BY ep.id;


-- ------------------------------------------------------------
-- Query: wftc_status_breakdown
-- Description: 협의회 가입 상태 분포
-- ------------------------------------------------------------
SELECT
  COALESCE(wm.membership_status, '미가입') AS status,
  COUNT(p.id) AS person_count
FROM people p
LEFT JOIN wftc_memberships wm ON wm.person_id = p.id
GROUP BY COALESCE(wm.membership_status, '미가입')
ORDER BY person_count DESC;


-- ------------------------------------------------------------
-- Query: upcoming_events
-- Description: 다가오는 행사 목록
-- ------------------------------------------------------------
SELECT id, name, event_type, start_date, location, status,
  (SELECT COUNT(*) FROM event_presentations ep WHERE ep.event_id = e.id) AS presentation_count
FROM events e
WHERE status IN ('예정','준비중','진행중')
ORDER BY start_date NULLS LAST
LIMIT 10;


-- ------------------------------------------------------------
-- Query: projects_by_domain
-- Description: 10대 분야별 과제 수
-- ------------------------------------------------------------
SELECT fd.name AS domain, COUNT(pr.id) AS project_count
FROM foodtech_domains fd
LEFT JOIN projects pr ON pr.domain_id = fd.id
GROUP BY fd.id, fd.name, fd.display_order
ORDER BY fd.display_order;


-- ------------------------------------------------------------
-- Query: recent_activities
-- Description: 최근 활동 로그
-- ------------------------------------------------------------
SELECT al.activity_date, al.activity_type, al.title, p.name AS person_name
FROM activity_logs al
LEFT JOIN people p ON p.id = al.person_id
ORDER BY al.activity_date DESC, al.created_at DESC
LIMIT 8;


-- ------------------------------------------------------------
-- Query: enrollment_to_wftc_funnel
-- Description: 교육과정 수료 → 협의회 가입 전환 파이프라인
-- ------------------------------------------------------------
WITH enrolled_people AS (
  SELECT DISTINCT pe.person_id
  FROM program_enrollments pe
  WHERE pe.role = '수강생'
)
SELECT
  (SELECT COUNT(*) FROM enrolled_people) AS enrolled_total,
  (SELECT COUNT(*) FROM enrolled_people ep
    JOIN wftc_memberships wm ON wm.person_id = ep.person_id
    WHERE wm.membership_status = '가입 권유 중') AS invited,
  (SELECT COUNT(*) FROM enrolled_people ep
    JOIN wftc_memberships wm ON wm.person_id = ep.person_id
    WHERE wm.membership_status = '가입 신청') AS applied,
  (SELECT COUNT(*) FROM enrolled_people ep
    JOIN wftc_memberships wm ON wm.person_id = ep.person_id
    WHERE wm.membership_status = '가입 완료') AS joined;


-- ------------------------------------------------------------
-- Query: program_detail
-- Params: program_name (text)
-- Description: 특정 교육과정의 기수별 참여자 목록
-- ------------------------------------------------------------
SELECT
  pc.cohort_name,
  pe.role,
  p.id AS person_id,
  p.name AS person_name,
  o.name AS organization,
  p.position,
  p.email,
  p.phone,
  COALESCE(wm.membership_status, '미가입') AS wftc_status,
  wm.membership_tier
FROM program_enrollments pe
JOIN program_cohorts pc ON pc.id = pe.cohort_id
JOIN education_programs ep ON ep.id = pc.program_id
JOIN people p ON p.id = pe.person_id
LEFT JOIN organizations o ON o.id = p.organization_id
LEFT JOIN wftc_memberships wm ON wm.person_id = p.id
WHERE ep.name = $1
ORDER BY pc.cohort_name, pe.role, p.name;


-- ------------------------------------------------------------
-- Query: wftc_members_list
-- Params: status_filter (text, nullable)
-- Description: 협의회 가입 상태별 사람 목록
-- ------------------------------------------------------------
SELECT
  p.id AS person_id,
  p.name,
  o.name AS organization,
  p.position,
  p.email,
  p.phone,
  COALESCE(wm.membership_status, '미가입') AS wftc_status,
  wm.membership_tier,
  wm.member_type,
  wm.join_date,
  (SELECT string_agg(DISTINCT ep.short_name, ', ')
    FROM program_enrollments pe
    JOIN program_cohorts pc ON pc.id = pe.cohort_id
    JOIN education_programs ep ON ep.id = pc.program_id
    WHERE pe.person_id = p.id AND pe.role='수강생') AS programs
FROM people p
LEFT JOIN organizations o ON o.id = p.organization_id
LEFT JOIN wftc_memberships wm ON wm.person_id = p.id
WHERE ($1::text IS NULL OR COALESCE(wm.membership_status, '미가입') = $1)
ORDER BY p.name
LIMIT 2000;


-- ------------------------------------------------------------
-- Query: people_list
-- Params: search (text, nullable)
-- Description: 전체 사람 목록 (필터 가능)
-- ------------------------------------------------------------
SELECT
  p.id AS person_id,
  p.name,
  p.person_types,
  o.name AS organization,
  p.position,
  p.email,
  p.phone,
  COALESCE(wm.membership_status, '미가입') AS wftc_status,
  (SELECT string_agg(DISTINCT ep.short_name, ', ')
    FROM program_enrollments pe
    JOIN program_cohorts pc ON pc.id = pe.cohort_id
    JOIN education_programs ep ON ep.id = pc.program_id
    WHERE pe.person_id = p.id) AS programs
FROM people p
LEFT JOIN organizations o ON o.id = p.organization_id
LEFT JOIN wftc_memberships wm ON wm.person_id = p.id
WHERE ($1::text IS NULL OR $1 = ''
       OR p.name ILIKE '%'||$1||'%'
       OR o.name ILIKE '%'||$1||'%'
       OR p.email ILIKE '%'||$1||'%')
ORDER BY p.name
LIMIT 2000;


-- ------------------------------------------------------------
-- Query: person_detail
-- Params: person_id (integer)
-- Description: 한 사람의 상세 프로필
-- ------------------------------------------------------------
SELECT
  p.id, p.name, p.person_types,
  o.name AS organization, p.position, p.department,
  p.email, p.phone, p.expertise, p.bio, p.notes,
  COALESCE(wm.membership_status, '미가입') AS wftc_status,
  wm.membership_tier, wm.member_type, wm.join_date, wm.notes AS wftc_notes
FROM people p
LEFT JOIN organizations o ON o.id = p.organization_id
LEFT JOIN wftc_memberships wm ON wm.person_id = p.id
WHERE p.id = $1;


-- ------------------------------------------------------------
-- Query: person_enrollments
-- Params: person_id (integer)
-- Description: 한 사람의 교육과정 참여 이력
-- ------------------------------------------------------------
SELECT
  ep.name AS program,
  pc.cohort_name,
  pe.role,
  pe.completion_status,
  pe.notes
FROM program_enrollments pe
JOIN program_cohorts pc ON pc.id = pe.cohort_id
JOIN education_programs ep ON ep.id = pc.program_id
WHERE pe.person_id = $1
ORDER BY ep.name, pc.cohort_name;


-- ------------------------------------------------------------
-- Query: non_members_from_programs
-- Description: 교육과정 수강생 중 협의회 미가입자 (가입 권유 대상)
-- ------------------------------------------------------------
SELECT DISTINCT
  p.id AS person_id,
  p.name,
  o.name AS organization,
  p.position,
  p.email,
  p.phone,
  (SELECT string_agg(DISTINCT ep.short_name, ', ')
    FROM program_enrollments pe
    JOIN program_cohorts pc ON pc.id = pe.cohort_id
    JOIN education_programs ep ON ep.id = pc.program_id
    WHERE pe.person_id = p.id AND pe.role='수강생') AS programs
FROM people p
LEFT JOIN organizations o ON o.id = p.organization_id
LEFT JOIN wftc_memberships wm ON wm.person_id = p.id
WHERE COALESCE(wm.membership_status, '미가입') = '미가입'
  AND EXISTS (
    SELECT 1 FROM program_enrollments pe
    WHERE pe.person_id = p.id AND pe.role = '수강생'
  )
ORDER BY o.name NULLS LAST, p.name;


-- ------------------------------------------------------------
-- Query: programs_summary
-- Description: 교육과정 리스트 + 각 과정 별 통계
-- ------------------------------------------------------------
SELECT
  ep.id, ep.name, ep.short_name, ep.description,
  (SELECT COUNT(DISTINCT pe.person_id)
    FROM program_enrollments pe
    JOIN program_cohorts pc ON pc.id = pe.cohort_id
    WHERE pc.program_id = ep.id AND pe.role='수강생') AS students,
  (SELECT COUNT(DISTINCT pe.person_id)
    FROM program_enrollments pe
    JOIN program_cohorts pc ON pc.id = pe.cohort_id
    WHERE pc.program_id = ep.id AND pe.role='강사') AS lecturers,
  (SELECT COUNT(*) FROM program_cohorts pc WHERE pc.program_id = ep.id) AS cohort_count
FROM education_programs ep
ORDER BY ep.id;


-- ------------------------------------------------------------
-- Query: events_list
-- Params: status_filter (text, nullable), type_filter (text, nullable)
-- Description: 전체 행사 목록 (필터/검색)
-- ------------------------------------------------------------
SELECT
  e.id, e.name, e.event_type, e.edition, e.start_date, e.end_date,
  e.location, e.theme, e.status,
  (SELECT COUNT(*) FROM event_presentations ep WHERE ep.event_id = e.id) AS presentation_count,
  (SELECT COUNT(DISTINCT ep.person_id) FROM event_presentations ep WHERE ep.event_id = e.id AND ep.person_id IS NOT NULL) AS presenter_count
FROM events e
WHERE ($1::text IS NULL OR $1 = '' OR e.status = $1)
  AND ($2::text IS NULL OR $2 = '' OR e.event_type = $2)
ORDER BY e.start_date DESC NULLS LAST, e.id DESC;


-- ------------------------------------------------------------
-- Query: event_detail
-- Params: event_id (integer)
-- Description: 특정 행사의 상세
-- ------------------------------------------------------------
SELECT
  e.id, e.name, e.event_type, e.edition,
  e.start_date, e.end_date, e.location, e.theme, e.description, e.status, e.notes
FROM events e
WHERE e.id = $1;


-- ------------------------------------------------------------
-- Query: event_presenters
-- Params: event_id (integer)
-- Description: 특정 행사의 발표자·세션 목록
-- ------------------------------------------------------------
SELECT
  ep.id AS presentation_id,
  ep.person_id,
  COALESCE(p.name, ep.presenter_name_snapshot) AS presenter_name,
  o.name AS organization,
  p.position,
  ep.title, ep.topic, ep.session_type,
  ep.session_date, ep.session_time,
  ep.abstract, ep.materials_url, ep.status
FROM event_presentations ep
LEFT JOIN people p ON p.id = ep.person_id
LEFT JOIN organizations o ON o.id = p.organization_id
WHERE ep.event_id = $1
ORDER BY ep.session_date NULLS LAST, ep.session_time NULLS LAST, ep.id;


-- ------------------------------------------------------------
-- Query: person_presentations
-- Params: person_id (integer)
-- Description: 한 사람의 발표 이력
-- ------------------------------------------------------------
SELECT
  ep.id AS presentation_id,
  e.id AS event_id,
  e.name AS event_name,
  e.event_type,
  e.start_date AS event_date,
  ep.title, ep.topic, ep.session_type,
  ep.session_date, ep.session_time, ep.status
FROM event_presentations ep
JOIN events e ON e.id = ep.event_id
WHERE ep.person_id = $1
ORDER BY e.start_date DESC NULLS LAST, ep.id DESC;


-- ------------------------------------------------------------
-- Query: events_kpis
-- Description: 대시보드용 행사 관련 통계
-- ------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM events) AS total_events,
  (SELECT COUNT(*) FROM events WHERE status IN ('예정','준비중','진행중')) AS upcoming_events,
  (SELECT COUNT(*) FROM events WHERE status = '종료') AS past_events,
  (SELECT COUNT(*) FROM event_presentations) AS total_presentations,
  (SELECT COUNT(*) FROM event_presentations WHERE status='완료') AS presentations_done,
  (SELECT COUNT(DISTINCT person_id) FROM event_presentations WHERE person_id IS NOT NULL) AS unique_presenters;


-- ------------------------------------------------------------
-- Query: events_by_type
-- Description: 행사 유형별 개수 (도넛/바 차트용)
-- ------------------------------------------------------------
SELECT event_type, COUNT(*) AS event_count
FROM events
GROUP BY event_type
ORDER BY event_count DESC;


-- ------------------------------------------------------------
-- Query: top_presenters
-- Description: 발표 많이 한 상위 인물 (TOP 10)
-- ------------------------------------------------------------
SELECT
  p.id AS person_id,
  p.name,
  o.name AS organization,
  COUNT(*) AS presentation_count
FROM event_presentations ep
JOIN people p ON p.id = ep.person_id
LEFT JOIN organizations o ON o.id = p.organization_id
GROUP BY p.id, p.name, o.name
ORDER BY presentation_count DESC, p.name
LIMIT 10;


-- ------------------------------------------------------------
-- Query: create_event
-- Params: name, event_type, edition, start_date, end_date, location, theme, status, description
-- Description: 행사 등록 (INSERT)
-- ------------------------------------------------------------
INSERT INTO events (name, event_type, edition, start_date, end_date, location, theme, status, description)
VALUES ($1, $2, $3, NULLIF($4,'')::date, NULLIF($5,'')::date, $6, $7, $8, $9)
RETURNING id, name;


-- ------------------------------------------------------------
-- Query: create_presentation
-- Params: event_id, person_id, presenter_name_snapshot, title, topic, session_type, session_date, session_time, abstract, status
-- Description: 발표 등록 (INSERT)
-- ------------------------------------------------------------
INSERT INTO event_presentations (event_id, person_id, presenter_name_snapshot, title, topic, session_type, session_date, session_time, abstract, status)
VALUES ($1, $2, $3, $4, $5, $6, NULLIF($7,'')::date, $8, $9, $10)
RETURNING id, title;


-- ------------------------------------------------------------
-- Query: search_people_for_picker
-- Params: q (text)
-- Description: 발표자 선택용 사람 검색 (자동완성)
-- ------------------------------------------------------------
SELECT p.id, p.name, o.name AS organization, p.position
FROM people p
LEFT JOIN organizations o ON o.id = p.organization_id
WHERE p.name ILIKE '%'||$1||'%' OR o.name ILIKE '%'||$1||'%'
ORDER BY p.name
LIMIT 20;


-- ------------------------------------------------------------
-- Query: events_calendar_window
-- Description: 오늘 기준 앞뒤 3개월 범위의 행사 (캘린더 섹션용)
-- ------------------------------------------------------------
SELECT
  e.id, e.name, e.event_type, e.edition,
  e.start_date, e.end_date, e.location, e.theme, e.status,
  (SELECT COUNT(*) FROM event_presentations ep WHERE ep.event_id = e.id) AS presentation_count,
  (SELECT COUNT(DISTINCT ep.person_id) FROM event_presentations ep
    WHERE ep.event_id = e.id AND ep.person_id IS NOT NULL) AS presenter_count
FROM events e
WHERE e.start_date IS NOT NULL
  AND e.start_date >= CURRENT_DATE - INTERVAL '3 months'
  AND e.start_date <= CURRENT_DATE + INTERVAL '3 months'
ORDER BY e.start_date ASC;


-- ------------------------------------------------------------
-- Query: event_summary_popup
-- Params: event_id (integer)
-- Description: 캘린더 팝업용 행사 요약 (상위 발표자 몇 명 포함)
-- ------------------------------------------------------------
SELECT
  e.id, e.name, e.event_type, e.edition,
  e.start_date, e.end_date, e.location, e.theme, e.status, e.description,
  (SELECT COUNT(*) FROM event_presentations ep WHERE ep.event_id = e.id) AS presentation_count,
  (SELECT string_agg(x.name, ' · ' ORDER BY x.rn) FROM (
      SELECT COALESCE(p.name, ep.presenter_name_snapshot) AS name,
             ROW_NUMBER() OVER (ORDER BY ep.id) AS rn
      FROM event_presentations ep
      LEFT JOIN people p ON p.id = ep.person_id
      WHERE ep.event_id = e.id
      LIMIT 5
    ) x
  ) AS top_presenters
FROM events e
WHERE e.id = $1;
