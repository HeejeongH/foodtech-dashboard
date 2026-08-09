# 푸드테크 센터 대시보드 (Cloudflare Pages + Supabase 배포)

서울대학교 푸드테크 센터 & 월드푸드테크협의회 대시보드를 **Cloudflare Pages** 로 독립 배포하기 위한 프로젝트입니다.

## 🏗️ 아키텍처

```
사용자 브라우저
     │
     ▼
Cloudflare Pages (index.html + config.js)
     │  HTTPS
     ▼
Supabase (PostgreSQL + REST API + RPC)
```

- **Cloudflare Pages**: 정적 파일 호스팅 (무료 티어로 충분, 대역폭 무제한)
- **Supabase**: PostgreSQL DB + 자동 REST API + RPC (무료 티어 500MB DB, 매월 5만 MAU)
- **AgentDB 워크스페이스 → 완전 이전**: 이제 Cloudflare 대시보드에서 데이터를 조회하고 편집할 수 있어요

## 📁 파일 구성

| 파일 | 설명 |
|---|---|
| `index.html` | 대시보드 프론트엔드 (Supabase RPC 호출로 변환된 버전) |
| `config.js` | Supabase URL/API Key 설정 파일 (⚠️ 배포 전 수정 필수) |
| `supabase_schema.sql` | Supabase에 실행할 스키마 + 26개 RPC 함수 정의 |
| `data/*.csv` | 워크스페이스에서 export한 데이터 (총 4,700+ 행) |
| `README.md` | 이 문서 |

## 🚀 배포 절차 (30분 소요)

### Step 1. Supabase 프로젝트 생성

1. https://supabase.com 접속 → 회원가입 (GitHub 계정으로 간편 가입 가능)
2. **New Project** 클릭
   - Name: `foodtech-dashboard` (원하는 이름)
   - Database Password: 강력한 비밀번호 (저장해두세요, 나중에 필요)
   - Region: **Northeast Asia (Seoul) `ap-northeast-2`** 추천
   - Pricing Plan: **Free** (무료)
3. 프로젝트 생성 완료까지 약 2분 대기

### Step 2. 스키마 실행

1. 좌측 사이드바에서 **SQL Editor** 클릭
2. **New query** 클릭
3. `supabase_schema.sql` 파일 내용을 전체 복사해서 붙여넣기
4. 우측 하단 **Run** 클릭 (약 5초 소요)
5. 아래 메시지 확인: `Success. No rows returned`

### Step 3. 데이터 import (13개 테이블)

**중요**: 부모 테이블부터 순서대로 import해야 외래키 오류가 안 나요.

각 테이블에 대해 반복:
1. 좌측 사이드바에서 **Table Editor** → 해당 테이블 선택
2. 우측 상단 **Insert** → **Import data from CSV**
3. 해당 CSV 파일 업로드
4. 컬럼 매핑 자동 감지 → **Import data** 클릭

**Import 순서 (외래키 의존성 순)**:
```
1. organizations.csv        (905행)
2. education_programs.csv   (3행 - 이미 스키마에서 INSERT됨, skip 가능)
3. foodtech_domains.csv     (10행 - 이미 스키마에서 INSERT됨, skip 가능)
4. people.csv               (1,463행)
5. program_cohorts.csv      (24행)
6. program_enrollments.csv  (886행)
7. wftc_memberships.csv     (497행)
8. events.csv               (25행)
9. event_presentations.csv  (896행)
10. projects.csv            (0행 - 비어있음)
11. project_participants.csv (0행)
12. project_organizations.csv (0행)
13. activity_logs.csv       (0행)
```

**⚠️ Import 후 sequence 재설정 (중요!)**

CSV에 이미 `id` 값이 있으므로 auto-increment sequence를 최신값 뒤로 옮겨야 다음 INSERT가 충돌하지 않아요. **SQL Editor** 에서 실행:

```sql
SELECT setval('organizations_id_seq', (SELECT MAX(id) FROM organizations));
SELECT setval('people_id_seq', (SELECT MAX(id) FROM people));
SELECT setval('education_programs_id_seq', (SELECT MAX(id) FROM education_programs));
SELECT setval('program_cohorts_id_seq', (SELECT MAX(id) FROM program_cohorts));
SELECT setval('program_enrollments_id_seq', (SELECT MAX(id) FROM program_enrollments));
SELECT setval('wftc_memberships_id_seq', (SELECT MAX(id) FROM wftc_memberships));
SELECT setval('events_id_seq', (SELECT MAX(id) FROM events));
SELECT setval('event_presentations_id_seq', (SELECT MAX(id) FROM event_presentations));
SELECT setval('foodtech_domains_id_seq', (SELECT MAX(id) FROM foodtech_domains));
```

### Step 4. Supabase API 정보 확인

1. 좌측 사이드바에서 **Project Settings** (톱니바퀴) → **API**
2. 다음 두 값을 복사:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon public** key: `eyJhbGc...` (긴 문자열)

### Step 5. config.js 수정

로컬에서 `config.js` 파일 열고 두 값을 채워 넣기:

```javascript
window.__SUPABASE_URL__ = 'https://xxxxx.supabase.co';  // Step 4의 Project URL
window.__SUPABASE_ANON_KEY__ = 'eyJhbGc...';             // Step 4의 anon key
```

### Step 6. GitHub에 push

```bash
cd /경로/foodtech-dashboard
git add .
git commit -m "Cloudflare Pages 배포용 설정"
git push
```

### Step 7. Cloudflare Pages 연결

1. https://dash.cloudflare.com 접속 (없으면 회원가입)
2. 좌측 **Workers & Pages** → **Create application** → **Pages** 탭 → **Connect to Git**
3. GitHub 계정 연결 → `foodtech-dashboard` 저장소 선택
4. 배포 설정:
   - Project name: `foodtech-dashboard` (자유)
   - Production branch: `main`
   - Framework preset: **None** (그냥 정적 파일이니까)
   - Build command: (비워둠)
   - Build output directory: `/` (루트)
5. **Save and Deploy** 클릭
6. 1분 안에 배포 완료 → `https://foodtech-dashboard.pages.dev` 같은 URL 발급

### Step 8. 브라우저에서 확인

배포된 URL 접속 → 대시보드가 실제 데이터로 채워져 있으면 성공!

## 🔒 인증/보안 추가 (나중에)

지금은 URL만 알면 누구나 볼 수 있는 상태입니다. 개인정보 보호를 위해 추후 아래 중 하나를 적용하세요:

### 옵션 A. Cloudflare Access (가장 간단, 무료)
1. Cloudflare 대시보드 → **Zero Trust** → **Access** → **Applications**
2. Add an application → Self-hosted
3. Application domain: `foodtech-dashboard.pages.dev`
4. Policy: 특정 이메일만 허용 (예: `@snu.ac.kr` 도메인)
5. 이제 접속 시 로그인 요구됨

### 옵션 B. Supabase Auth (더 정교)
1. `supabase_schema.sql` 의 RLS 정책을 `auth.uid() IS NOT NULL` 로 변경
2. 프론트엔드에 로그인 화면 추가 (Supabase Auth UI 사용)
3. 이메일/구글/카카오 등 로그인 가능

두 옵션 다 적용해도 됩니다 (Cloudflare Access = 접근 자체 차단 / Supabase Auth = 사용자별 권한 관리).

## 🔄 유지보수

### 데이터 편집
- **Supabase Table Editor**: 브라우저에서 스프레드시트처럼 편집
- **대시보드 앱 내 폼**: 행사·발표 등록은 대시보드에서 직접 가능
- **SQL Editor**: 대량 수정은 SQL로

### 코드 수정
- 로컬에서 `index.html` 편집 → git push
- Cloudflare Pages가 자동으로 재배포 (약 30초)
- 미리보기 브랜치 push하면 preview URL도 자동 생성

### 새 쿼리 추가
1. `supabase_schema.sql` 의 RPC 함수 스타일로 새 함수 작성
2. Supabase SQL Editor에서 실행
3. `index.html` 에서 `window.agentdb.executeQuery('새함수명', {...})` 호출

## 📊 무료 티어 한도

| 서비스 | 무료 제공 | 이 프로젝트 예상 사용량 |
|---|---|---|
| Cloudflare Pages | 무제한 대역폭, 500 빌드/월 | ✅ 충분 |
| Supabase | DB 500MB, 5만 MAU, 2GB 대역폭/월 | ✅ 충분 (1,500명·10만 행 수준) |

두 서비스 모두 **신용카드 등록 불필요**한 무료 티어로 시작 가능합니다.

## ❓ 문제 해결

**"CORS error" 나올 때**
→ config.js의 URL과 anon key가 정확한지 확인. Supabase는 기본적으로 모든 origin 허용해요.

**"permission denied for table" 오류**
→ Step 2의 RLS 정책이 제대로 적용됐는지 확인. supabase_schema.sql 맨 아래 `CREATE POLICY` 부분 실행됐는지 체크.

**데이터가 안 보일 때**
→ Supabase Table Editor에서 각 테이블에 데이터가 있는지 확인. 브라우저 개발자 도구 (F12) → Console에서 에러 메시지 확인.

**행사가 캘린더 섹션에 안 나올 때**
→ 정상입니다. 오늘 기준 앞뒤 3개월 안에 예정된 행사가 없으면 빈 상태로 나옵니다. 대시보드에서 새 행사를 등록하면 채워져요.
