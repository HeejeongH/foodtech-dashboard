-- ============================================================
-- Supabase용 스키마 (Cloudflare Pages 이전용)
--
-- 실행 방법:
--   1. Supabase 프로젝트 생성 (https://supabase.com/dashboard)
--   2. SQL Editor 열기
--   3. 이 파일 전체를 복사해서 실행
-- ============================================================

-- 1. Organizations
CREATE TABLE organizations (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    org_type TEXT CHECK (org_type IN ('기업', '대학', '정부기관', '연구소', '협회', '기타')),
    industry TEXT,
    website TEXT,
    address TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. People
CREATE TABLE people (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    name_en TEXT,
    person_types TEXT[] NOT NULL DEFAULT '{}',
    organization_id INTEGER REFERENCES organizations(id) ON DELETE SET NULL,
    position TEXT,
    department TEXT,
    email TEXT,
    phone TEXT,
    expertise TEXT,
    bio TEXT,
    profile_photo_url TEXT,
    linkedin_url TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_people_org ON people(organization_id);
CREATE INDEX idx_people_types ON people USING GIN(person_types);

-- 3. Education Programs
CREATE TABLE education_programs (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    short_name TEXT,
    description TEXT,
    program_lead TEXT,
    duration TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Program Cohorts
CREATE TABLE program_cohorts (
    id SERIAL PRIMARY KEY,
    program_id INTEGER NOT NULL REFERENCES education_programs(id) ON DELETE CASCADE,
    cohort_name TEXT NOT NULL,
    start_date DATE,
    end_date DATE,
    status TEXT DEFAULT '진행중' CHECK (status IN ('예정', '진행중', '수료', '중단')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(program_id, cohort_name)
);
CREATE INDEX idx_cohorts_program ON program_cohorts(program_id);

-- 5. Program Enrollments
CREATE TABLE program_enrollments (
    id SERIAL PRIMARY KEY,
    person_id INTEGER NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    cohort_id INTEGER NOT NULL REFERENCES program_cohorts(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('수강생', '교수', '강사', '조교', '운영진')),
    enrolled_date DATE,
    completion_status TEXT DEFAULT '수강중' CHECK (completion_status IN ('수강중', '수료', '중도포기', '불합격', 'N/A')),
    grade TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(person_id, cohort_id, role)
);
CREATE INDEX idx_enrollment_person ON program_enrollments(person_id);
CREATE INDEX idx_enrollment_cohort ON program_enrollments(cohort_id);

-- 6. WFTC Memberships
CREATE TABLE wftc_memberships (
    id SERIAL PRIMARY KEY,
    person_id INTEGER NOT NULL UNIQUE REFERENCES people(id) ON DELETE CASCADE,
    membership_status TEXT NOT NULL DEFAULT '미가입' CHECK (membership_status IN ('미가입', '가입 권유 중', '가입 신청', '가입 완료', '탈퇴')),
    member_type TEXT CHECK (member_type IN ('기존 멤버', '신규 가입(서울대 과정 출신)', '초청 멤버', '기타')),
    join_date DATE,
    membership_tier TEXT,
    invited_by TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_wftc_status ON wftc_memberships(membership_status);

-- 7. Events
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('ConFex', 'Summit', 'Forum', '세미나', '워크숍', '실증사업 발표회', '기타')),
    edition TEXT,
    start_date DATE,
    end_date DATE,
    location TEXT,
    theme TEXT,
    description TEXT,
    status TEXT DEFAULT '예정' CHECK (status IN ('예정', '준비중', '진행중', '종료', '취소')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_events_date ON events(start_date);

-- 8. Event Presentations
CREATE TABLE event_presentations (
    id SERIAL PRIMARY KEY,
    event_id INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    person_id INTEGER REFERENCES people(id) ON DELETE SET NULL,
    presenter_name_snapshot TEXT,
    title TEXT NOT NULL,
    topic TEXT,
    session_type TEXT CHECK (session_type IN ('기조연설', '세션 발표', '패널토론', '워크숍', '포스터', '기타')),
    session_date DATE,
    session_time TEXT,
    abstract TEXT,
    materials_url TEXT,
    status TEXT DEFAULT '예정' CHECK (status IN ('예정', '확정', '완료', '취소')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_presentations_event ON event_presentations(event_id);
CREATE INDEX idx_presentations_person ON event_presentations(person_id);

-- 9. Foodtech Domains
CREATE TABLE foodtech_domains (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    display_order INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Projects
CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    project_type TEXT CHECK (project_type IN ('협력 과제', '실증 사업', '시범 인증사업', 'R&D 과제', '기타')),
    domain_id INTEGER REFERENCES foodtech_domains(id) ON DELETE SET NULL,
    lead_person_id INTEGER REFERENCES people(id) ON DELETE SET NULL,
    lead_organization_id INTEGER REFERENCES organizations(id) ON DELETE SET NULL,
    funding_source TEXT,
    budget NUMERIC,
    start_date DATE,
    end_date DATE,
    status TEXT DEFAULT '기획중' CHECK (status IN ('발굴/기획', '기획중', '신청', '선정', '진행중', '완료', '중단', '탈락')),
    description TEXT,
    outcomes TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_projects_domain ON projects(domain_id);
CREATE INDEX idx_projects_status ON projects(status);

-- 11. Project Participants
CREATE TABLE project_participants (
    id SERIAL PRIMARY KEY,
    project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    person_id INTEGER NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    role TEXT,
    contribution TEXT,
    joined_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(project_id, person_id)
);
CREATE INDEX idx_pp_project ON project_participants(project_id);
CREATE INDEX idx_pp_person ON project_participants(person_id);

-- 12. Project Organizations
CREATE TABLE project_organizations (
    id SERIAL PRIMARY KEY,
    project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    organization_id INTEGER NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    role TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(project_id, organization_id)
);

-- 13. Activity Logs
CREATE TABLE activity_logs (
    id SERIAL PRIMARY KEY,
    activity_date DATE NOT NULL DEFAULT CURRENT_DATE,
    activity_type TEXT CHECK (activity_type IN ('미팅', '이메일', '전화', '방문', '문의', '기타')),
    person_id INTEGER REFERENCES people(id) ON DELETE SET NULL,
    related_project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL,
    related_event_id INTEGER REFERENCES events(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    content TEXT,
    followup_needed BOOLEAN DEFAULT FALSE,
    followup_date DATE,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_logs_person ON activity_logs(person_id);
CREATE INDEX idx_logs_date ON activity_logs(activity_date);

-- ============================================================
-- 26개 named query를 Postgres 함수(RPC)로 등록
-- Supabase는 supabase.rpc('function_name', {params})로 호출 가능
-- ============================================================

CREATE OR REPLACE FUNCTION summary_kpis()
RETURNS TABLE(total_people BIGINT, total_enrollments BIGINT, wftc_members BIGINT,
              wftc_pipeline BIGINT, active_events BIGINT, presentations_done BIGINT,
              active_projects BIGINT, pipeline_projects BIGINT) AS $$
  SELECT
    (SELECT COUNT(*) FROM people),
    (SELECT COUNT(*) FROM program_enrollments WHERE role = '수강생'),
    (SELECT COUNT(*) FROM wftc_memberships WHERE membership_status = '가입 완료'),
    (SELECT COUNT(*) FROM wftc_memberships WHERE membership_status IN ('가입 권유 중','가입 신청')),
    (SELECT COUNT(*) FROM events WHERE status IN ('예정','준비중','진행중')),
    (SELECT COUNT(*) FROM event_presentations WHERE status = '완료'),
    (SELECT COUNT(*) FROM projects WHERE status IN ('진행중','선정')),
    (SELECT COUNT(*) FROM projects WHERE status = '발굴/기획');
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION wftc_status_breakdown()
RETURNS TABLE(status TEXT, person_count BIGINT) AS $$
  SELECT COALESCE(wm.membership_status, '미가입'), COUNT(p.id)
  FROM people p
  LEFT JOIN wftc_memberships wm ON wm.person_id = p.id
  GROUP BY COALESCE(wm.membership_status, '미가입')
  ORDER BY 2 DESC;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION enrollment_to_wftc_funnel()
RETURNS TABLE(enrolled_total BIGINT, invited BIGINT, applied BIGINT, joined BIGINT) AS $$
  WITH ep AS (SELECT DISTINCT person_id FROM program_enrollments WHERE role='수강생')
  SELECT
    (SELECT COUNT(*) FROM ep),
    (SELECT COUNT(*) FROM ep JOIN wftc_memberships wm ON wm.person_id=ep.person_id WHERE wm.membership_status='가입 권유 중'),
    (SELECT COUNT(*) FROM ep JOIN wftc_memberships wm ON wm.person_id=ep.person_id WHERE wm.membership_status='가입 신청'),
    (SELECT COUNT(*) FROM ep JOIN wftc_memberships wm ON wm.person_id=ep.person_id WHERE wm.membership_status='가입 완료');
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION programs_summary()
RETURNS TABLE(id INTEGER, name TEXT, short_name TEXT, description TEXT,
              students BIGINT, lecturers BIGINT, cohort_count BIGINT) AS $$
  SELECT ep.id, ep.name, ep.short_name, ep.description,
    (SELECT COUNT(DISTINCT pe.person_id) FROM program_enrollments pe JOIN program_cohorts pc ON pc.id=pe.cohort_id WHERE pc.program_id=ep.id AND pe.role='수강생'),
    (SELECT COUNT(DISTINCT pe.person_id) FROM program_enrollments pe JOIN program_cohorts pc ON pc.id=pe.cohort_id WHERE pc.program_id=ep.id AND pe.role='강사'),
    (SELECT COUNT(*) FROM program_cohorts pc WHERE pc.program_id=ep.id)
  FROM education_programs ep ORDER BY ep.id;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION program_detail(program_name TEXT)
RETURNS TABLE(cohort_name TEXT, role TEXT, person_id INTEGER, person_name TEXT,
              organization TEXT, "position" TEXT, email TEXT, phone TEXT,
              wftc_status TEXT, membership_tier TEXT) AS $$
  SELECT pc.cohort_name, pe.role, p.id, p.name, o.name, p.position, p.email, p.phone,
    COALESCE(wm.membership_status, '미가입'), wm.membership_tier
  FROM program_enrollments pe
  JOIN program_cohorts pc ON pc.id=pe.cohort_id
  JOIN education_programs ep ON ep.id=pc.program_id
  JOIN people p ON p.id=pe.person_id
  LEFT JOIN organizations o ON o.id=p.organization_id
  LEFT JOIN wftc_memberships wm ON wm.person_id=p.id
  WHERE ep.name = program_name
  ORDER BY pc.cohort_name, pe.role, p.name;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION wftc_members_list(status_filter TEXT DEFAULT NULL)
RETURNS TABLE(person_id INTEGER, name TEXT, organization TEXT, "position" TEXT,
              email TEXT, phone TEXT, wftc_status TEXT, membership_tier TEXT,
              member_type TEXT, join_date DATE, programs TEXT) AS $$
  SELECT p.id, p.name, o.name, p.position, p.email, p.phone,
    COALESCE(wm.membership_status, '미가입'), wm.membership_tier, wm.member_type, wm.join_date,
    (SELECT string_agg(DISTINCT ep.short_name, ', ')
      FROM program_enrollments pe
      JOIN program_cohorts pc ON pc.id=pe.cohort_id
      JOIN education_programs ep ON ep.id=pc.program_id
      WHERE pe.person_id=p.id AND pe.role='수강생')
  FROM people p
  LEFT JOIN organizations o ON o.id=p.organization_id
  LEFT JOIN wftc_memberships wm ON wm.person_id=p.id
  WHERE (status_filter IS NULL OR COALESCE(wm.membership_status, '미가입')=status_filter)
  ORDER BY p.name LIMIT 2000;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION people_list(search TEXT DEFAULT NULL)
RETURNS TABLE(person_id INTEGER, name TEXT, person_types TEXT[], organization TEXT,
              "position" TEXT, email TEXT, phone TEXT, wftc_status TEXT, programs TEXT) AS $$
  SELECT p.id, p.name, p.person_types, o.name, p.position, p.email, p.phone,
    COALESCE(wm.membership_status, '미가입'),
    (SELECT string_agg(DISTINCT ep.short_name, ', ')
      FROM program_enrollments pe
      JOIN program_cohorts pc ON pc.id=pe.cohort_id
      JOIN education_programs ep ON ep.id=pc.program_id
      WHERE pe.person_id=p.id)
  FROM people p
  LEFT JOIN organizations o ON o.id=p.organization_id
  LEFT JOIN wftc_memberships wm ON wm.person_id=p.id
  WHERE (search IS NULL OR search = '' OR p.name ILIKE '%'||search||'%' OR o.name ILIKE '%'||search||'%' OR p.email ILIKE '%'||search||'%')
  ORDER BY p.name LIMIT 2000;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION person_detail(person_id INTEGER)
RETURNS TABLE(id INTEGER, name TEXT, person_types TEXT[], organization TEXT,
              "position" TEXT, department TEXT, email TEXT, phone TEXT,
              expertise TEXT, bio TEXT, notes TEXT, wftc_status TEXT,
              membership_tier TEXT, member_type TEXT, join_date DATE, wftc_notes TEXT) AS $$
  SELECT p.id, p.name, p.person_types, o.name, p.position, p.department,
    p.email, p.phone, p.expertise, p.bio, p.notes,
    COALESCE(wm.membership_status, '미가입'), wm.membership_tier, wm.member_type,
    wm.join_date, wm.notes
  FROM people p
  LEFT JOIN organizations o ON o.id=p.organization_id
  LEFT JOIN wftc_memberships wm ON wm.person_id=p.id
  WHERE p.id = person_detail.person_id;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION person_enrollments(person_id INTEGER)
RETURNS TABLE(program TEXT, cohort_name TEXT, role TEXT, completion_status TEXT, notes TEXT) AS $$
  SELECT ep.name, pc.cohort_name, pe.role, pe.completion_status, pe.notes
  FROM program_enrollments pe
  JOIN program_cohorts pc ON pc.id=pe.cohort_id
  JOIN education_programs ep ON ep.id=pc.program_id
  WHERE pe.person_id = person_enrollments.person_id
  ORDER BY ep.name, pc.cohort_name;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION non_members_from_programs()
RETURNS TABLE(person_id INTEGER, name TEXT, organization TEXT, "position" TEXT,
              email TEXT, phone TEXT, programs TEXT) AS $$
  SELECT DISTINCT p.id, p.name, o.name, p.position, p.email, p.phone,
    (SELECT string_agg(DISTINCT ep.short_name, ', ')
      FROM program_enrollments pe
      JOIN program_cohorts pc ON pc.id=pe.cohort_id
      JOIN education_programs ep ON ep.id=pc.program_id
      WHERE pe.person_id=p.id AND pe.role='수강생')
  FROM people p
  LEFT JOIN organizations o ON o.id=p.organization_id
  LEFT JOIN wftc_memberships wm ON wm.person_id=p.id
  WHERE COALESCE(wm.membership_status, '미가입') = '미가입'
    AND EXISTS (SELECT 1 FROM program_enrollments pe WHERE pe.person_id=p.id AND pe.role='수강생')
  ORDER BY 3 NULLS LAST, 2;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION events_list(status_filter TEXT DEFAULT NULL, type_filter TEXT DEFAULT NULL)
RETURNS TABLE(id INTEGER, name TEXT, event_type TEXT, edition TEXT,
              start_date DATE, end_date DATE, location TEXT, theme TEXT, status TEXT,
              presentation_count BIGINT, presenter_count BIGINT) AS $$
  SELECT e.id, e.name, e.event_type, e.edition, e.start_date, e.end_date,
    e.location, e.theme, e.status,
    (SELECT COUNT(*) FROM event_presentations ep WHERE ep.event_id=e.id),
    (SELECT COUNT(DISTINCT ep.person_id) FROM event_presentations ep WHERE ep.event_id=e.id AND ep.person_id IS NOT NULL)
  FROM events e
  WHERE (status_filter IS NULL OR status_filter='' OR e.status=status_filter)
    AND (type_filter IS NULL OR type_filter='' OR e.event_type=type_filter)
  ORDER BY e.start_date DESC NULLS LAST, e.id DESC;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION event_detail(event_id INTEGER)
RETURNS TABLE(id INTEGER, name TEXT, event_type TEXT, edition TEXT,
              start_date DATE, end_date DATE, location TEXT, theme TEXT,
              description TEXT, status TEXT, notes TEXT) AS $$
  SELECT e.id, e.name, e.event_type, e.edition, e.start_date, e.end_date,
    e.location, e.theme, e.description, e.status, e.notes
  FROM events e WHERE e.id = event_detail.event_id;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION event_presenters(event_id INTEGER)
RETURNS TABLE(presentation_id INTEGER, person_id INTEGER, presenter_name TEXT,
              organization TEXT, "position" TEXT, title TEXT, topic TEXT,
              session_type TEXT, session_date DATE, session_time TEXT,
              abstract TEXT, materials_url TEXT, status TEXT) AS $$
  SELECT ep.id, ep.person_id, COALESCE(p.name, ep.presenter_name_snapshot),
    o.name, p.position, ep.title, ep.topic, ep.session_type,
    ep.session_date, ep.session_time, ep.abstract, ep.materials_url, ep.status
  FROM event_presentations ep
  LEFT JOIN people p ON p.id=ep.person_id
  LEFT JOIN organizations o ON o.id=p.organization_id
  WHERE ep.event_id = event_presenters.event_id
  ORDER BY ep.session_date NULLS LAST, ep.session_time NULLS LAST, ep.id;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION person_presentations(person_id INTEGER)
RETURNS TABLE(presentation_id INTEGER, event_id INTEGER, event_name TEXT,
              event_type TEXT, event_date DATE, title TEXT, topic TEXT,
              session_type TEXT, session_date DATE, session_time TEXT, status TEXT) AS $$
  SELECT ep.id, e.id, e.name, e.event_type, e.start_date,
    ep.title, ep.topic, ep.session_type, ep.session_date, ep.session_time, ep.status
  FROM event_presentations ep
  JOIN events e ON e.id=ep.event_id
  WHERE ep.person_id = person_presentations.person_id
  ORDER BY e.start_date DESC NULLS LAST, ep.id DESC;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION events_kpis()
RETURNS TABLE(total_events BIGINT, upcoming_events BIGINT, past_events BIGINT,
              total_presentations BIGINT, presentations_done BIGINT, unique_presenters BIGINT) AS $$
  SELECT
    (SELECT COUNT(*) FROM events),
    (SELECT COUNT(*) FROM events WHERE status IN ('예정','준비중','진행중')),
    (SELECT COUNT(*) FROM events WHERE status = '종료'),
    (SELECT COUNT(*) FROM event_presentations),
    (SELECT COUNT(*) FROM event_presentations WHERE status='완료'),
    (SELECT COUNT(DISTINCT person_id) FROM event_presentations WHERE person_id IS NOT NULL);
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION events_by_type()
RETURNS TABLE(event_type TEXT, event_count BIGINT) AS $$
  SELECT event_type, COUNT(*) FROM events GROUP BY event_type ORDER BY 2 DESC;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION top_presenters()
RETURNS TABLE(person_id INTEGER, name TEXT, organization TEXT, presentation_count BIGINT) AS $$
  SELECT p.id, p.name, o.name, COUNT(*)
  FROM event_presentations ep
  JOIN people p ON p.id=ep.person_id
  LEFT JOIN organizations o ON o.id=p.organization_id
  GROUP BY p.id, p.name, o.name
  ORDER BY 4 DESC, p.name LIMIT 10;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION search_people_for_picker(q TEXT)
RETURNS TABLE(id INTEGER, name TEXT, organization TEXT, "position" TEXT) AS $$
  SELECT p.id, p.name, o.name, p.position
  FROM people p
  LEFT JOIN organizations o ON o.id=p.organization_id
  WHERE p.name ILIKE '%'||q||'%' OR o.name ILIKE '%'||q||'%'
  ORDER BY p.name LIMIT 20;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION events_calendar_window()
RETURNS TABLE(id INTEGER, name TEXT, event_type TEXT, edition TEXT,
              start_date DATE, end_date DATE, location TEXT, theme TEXT, status TEXT,
              presentation_count BIGINT, presenter_count BIGINT) AS $$
  SELECT e.id, e.name, e.event_type, e.edition, e.start_date, e.end_date,
    e.location, e.theme, e.status,
    (SELECT COUNT(*) FROM event_presentations ep WHERE ep.event_id=e.id),
    (SELECT COUNT(DISTINCT ep.person_id) FROM event_presentations ep WHERE ep.event_id=e.id AND ep.person_id IS NOT NULL)
  FROM events e
  WHERE e.start_date IS NOT NULL
    AND e.start_date >= CURRENT_DATE - INTERVAL '3 months'
    AND e.start_date <= CURRENT_DATE + INTERVAL '3 months'
  ORDER BY e.start_date ASC;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION event_summary_popup(event_id INTEGER)
RETURNS TABLE(id INTEGER, name TEXT, event_type TEXT, edition TEXT,
              start_date DATE, end_date DATE, location TEXT, theme TEXT,
              status TEXT, description TEXT, presentation_count BIGINT, top_presenters TEXT) AS $$
  SELECT e.id, e.name, e.event_type, e.edition, e.start_date, e.end_date,
    e.location, e.theme, e.status, e.description,
    (SELECT COUNT(*) FROM event_presentations ep WHERE ep.event_id=e.id),
    (SELECT string_agg(x.name, ' · ' ORDER BY x.rn) FROM (
        SELECT COALESCE(p.name, ep.presenter_name_snapshot) AS name,
               ROW_NUMBER() OVER (ORDER BY ep.id) AS rn
        FROM event_presentations ep
        LEFT JOIN people p ON p.id=ep.person_id
        WHERE ep.event_id=e.id
        LIMIT 5) x)
  FROM events e WHERE e.id = event_summary_popup.event_id;
$$ LANGUAGE SQL STABLE;

-- ============================================================
-- RLS (Row Level Security): 지금은 익명 read/write 허용
-- 나중에 인증 추가할 때 이 부분만 수정하면 됨
-- ============================================================

ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE people ENABLE ROW LEVEL SECURITY;
ALTER TABLE education_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE program_cohorts ENABLE ROW LEVEL SECURITY;
ALTER TABLE program_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE wftc_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_presentations ENABLE ROW LEVEL SECURITY;
ALTER TABLE foodtech_domains ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

-- 익명 사용자에게 read/write 모두 허용 (초기 설정)
-- ⚠️ 프로덕션에서는 인증 후 정책 강화 필수
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['organizations','people','education_programs','program_cohorts',
    'program_enrollments','wftc_memberships','events','event_presentations',
    'foodtech_domains','projects','project_participants','project_organizations','activity_logs']
  LOOP
    EXECUTE format('CREATE POLICY "public_read" ON %I FOR SELECT USING (true)', t);
    EXECUTE format('CREATE POLICY "public_write" ON %I FOR ALL USING (true) WITH CHECK (true)', t);
  END LOOP;
END $$;
