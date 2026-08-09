-- ============================================================
-- 서울대 푸드테크 센터 & 월드푸드테크협의회 워크스페이스 스키마
-- PostgreSQL 기반
--
-- 총 13개 테이블 + 3개 뷰
-- ============================================================

-- ============================================
-- 1. 조직/기관 (기업, 대학, 정부기관 등)
-- ============================================
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

-- ============================================
-- 2. 사람 (모든 사람 통합)
-- ============================================
CREATE TABLE people (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    name_en TEXT,
    person_types TEXT[] NOT NULL DEFAULT '{}',
    -- 복수 유형 가능: '기업 임원', '개인 참여자', '학생', '교수',
    -- '외부 강사', '협의회 기존 멤버', '과천 센터 담당자', '연구실 졸업생', '발표자'
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

-- ============================================
-- 3. 서울대 푸드테크 센터 교육과정
-- ============================================
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

INSERT INTO education_programs (name, short_name, description) VALUES
('푸드테크 최고책임자과정', '최고책임자과정', '기업 임원 대상 최고경영자 교육과정'),
('푸드테크 기술사업화교육', '기술사업화교육', '기술 기반 사업화 전문 교육과정'),
('푸드테크 계약학과', '계약학과', '기업 연계 학위 과정');

-- ============================================
-- 4. 교육과정 기수 (Cohort)
-- ============================================
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

-- ============================================
-- 5. 교육과정 참여 (사람 ↔ 교육과정 기수)
-- ============================================
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

-- ============================================
-- 6. 월드푸드테크협의회 가입
-- ============================================
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

-- ============================================
-- 7. 협의회 행사
-- ============================================
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

-- ============================================
-- 8. 발표/세션
-- ============================================
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

-- ============================================
-- 9. 10대 분야 (시범 인증사업)
-- ============================================
CREATE TABLE foodtech_domains (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    display_order INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO foodtech_domains (name, display_order) VALUES
('세포배양식품', 1),
('식물성 대체식품', 2),
('식품프린팅', 3),
('개인맞춤형 식품', 4),
('간편식/HMR', 5),
('스마트팜/스마트농업', 6),
('푸드로봇/자동화', 7),
('친환경 식품포장', 8),
('푸드 업사이클링', 9),
('디지털 식품안전관리', 10);

-- ============================================
-- 10. 협력 과제 / 실증 사업
-- ============================================
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

-- ============================================
-- 11. 과제 참여자
-- ============================================
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

-- ============================================
-- 12. 과제 참여 조직
-- ============================================
CREATE TABLE project_organizations (
    id SERIAL PRIMARY KEY,
    project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    organization_id INTEGER NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    role TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(project_id, organization_id)
);

-- ============================================
-- 13. 활동 로그
-- ============================================
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

-- ============================================
-- 편의 뷰 1: 사람별 전체 프로필 (한눈에 보기)
-- ============================================
CREATE VIEW v_person_360 AS
SELECT
    p.id AS person_id,
    p.name,
    p.person_types,
    o.name AS organization,
    p.position,
    p.email,
    p.phone,
    (SELECT string_agg(DISTINCT ep.short_name || '(' || pe.role || ')', ', ')
     FROM program_enrollments pe
     JOIN program_cohorts pc ON pc.id = pe.cohort_id
     JOIN education_programs ep ON ep.id = pc.program_id
     WHERE pe.person_id = p.id) AS programs,
    wm.membership_status AS wftc_status,
    wm.join_date AS wftc_join_date,
    (SELECT COUNT(*) FROM event_presentations ep WHERE ep.person_id = p.id) AS presentation_count,
    (SELECT COUNT(*) FROM project_participants pp WHERE pp.person_id = p.id) AS project_count
FROM people p
LEFT JOIN organizations o ON o.id = p.organization_id
LEFT JOIN wftc_memberships wm ON wm.person_id = p.id;

-- ============================================
-- 편의 뷰 2: 교육과정 수료생 → 협의회 가입 파이프라인
-- ============================================
CREATE VIEW v_enrollment_to_wftc AS
SELECT
    p.id AS person_id,
    p.name,
    o.name AS organization,
    ep.name AS program,
    pc.cohort_name,
    pe.role AS program_role,
    pe.completion_status,
    COALESCE(wm.membership_status, '미가입') AS wftc_status,
    wm.join_date AS wftc_join_date
FROM people p
JOIN program_enrollments pe ON pe.person_id = p.id
JOIN program_cohorts pc ON pc.id = pe.cohort_id
JOIN education_programs ep ON ep.id = pc.program_id
LEFT JOIN organizations o ON o.id = p.organization_id
LEFT JOIN wftc_memberships wm ON wm.person_id = p.id;

-- ============================================
-- 편의 뷰 3: 행사별 발표자 리스트
-- ============================================
CREATE VIEW v_event_presentations AS
SELECT
    e.id AS event_id,
    e.name AS event_name,
    e.event_type,
    e.start_date,
    ep.id AS presentation_id,
    COALESCE(p.name, ep.presenter_name_snapshot) AS presenter,
    o.name AS presenter_org,
    ep.title AS presentation_title,
    ep.topic,
    ep.session_type,
    ep.status
FROM events e
LEFT JOIN event_presentations ep ON ep.event_id = e.id
LEFT JOIN people p ON p.id = ep.person_id
LEFT JOIN organizations o ON o.id = p.organization_id;
