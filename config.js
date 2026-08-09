// ============================================================
// Supabase 접속 정보
//
// Cloudflare Pages 배포 전에 반드시 아래 두 값을 채워 넣으세요.
// Supabase 대시보드 > Project Settings > API에서 확인할 수 있어요.
//
// - URL: Project URL
// - Anon Key: anon/public key (⚠️ service_role key 아님!)
//
// ⚠️ 보안 주의:
// anon key는 브라우저에 공개되어도 안전하도록 설계된 키입니다.
// 다만 Row Level Security (RLS) 정책이 켜져 있어야 실제로 안전해요.
// supabase_schema.sql 파일의 마지막 부분에서 RLS를 설정합니다.
// ============================================================

window.__SUPABASE_URL__ = 'https://YOUR_PROJECT_REF.supabase.co';
window.__SUPABASE_ANON_KEY__ = 'YOUR_ANON_KEY_HERE';
