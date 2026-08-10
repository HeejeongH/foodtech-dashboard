// Cloudflare Pages Function — POST /api/agent
//
// Holds the Anthropic API key server-side (set ANTHROPIC_API_KEY in
// Cloudflare Pages > Settings > Environment variables). The client never
// sees this key.
//
// Body: { message?: string, fileBase64?: string, mediaType?: string }
// Returns: { proposal: {...} } | { message: string } | { error: string }
//
// Design: the agent only PROPOSES a change (via the propose_person_update
// tool call) — it never writes to the DB itself. The frontend shows the
// proposal to the user and applies it via the existing update_person /
// update_wftc_membership Supabase calls only after explicit confirmation.

const SB_URL = 'https://rfeffxzeqxcpareyczbt.supabase.co';
const SB_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJmZWZmeHplcXhjcGFyZXljemJ0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNzYzODUsImV4cCI6MjEwMTg1MjM4NX0.KeahHKM5Y6kt6jDj1SSlEIW3Pb28cxcrLCnb_nMkbH8';

const TOOLS = [
  {
    name: 'search_person',
    description: '이름/소속으로 등록된 회원을 검색합니다. 특정 사람을 지목하기 전에 항상 먼저 호출하세요.',
    input_schema: {
      type: 'object',
      properties: { query: { type: 'string', description: '검색어 (이름 또는 소속)' } },
      required: ['query'],
    },
  },
  {
    name: 'propose_person_update',
    description: '검색으로 정확히 특정된 사람에 대해 변경할 내용을 제안합니다. 실제 DB에는 반영되지 않고, 사용자가 확인 후 직접 적용합니다. 확신이 없으면 호출하지 말고 대신 텍스트로 사용자에게 되물으세요.',
    input_schema: {
      type: 'object',
      properties: {
        person_id: { type: 'integer' },
        person_name: { type: 'string' },
        updates: {
          type: 'object',
          properties: {
            position: { type: 'string' },
            department: { type: 'string' },
            email: { type: 'string' },
            phone: { type: 'string' },
            expertise: { type: 'string' },
            wftc_status: { type: 'string', enum: ['미가입', '가입 권유 중', '가입 신청', '가입 완료', '탈퇴'] },
            membership_tier: { type: 'string' },
            member_type: { type: 'string' },
            join_date: { type: 'string', description: 'YYYY-MM-DD' },
          },
        },
        summary: { type: 'string', description: '무엇을 왜 바꾸는지 사람이 읽을 한국어 한두 문장 요약' },
      },
      required: ['person_id', 'person_name', 'updates', 'summary'],
    },
  },
];

const SYSTEM_PROMPT = '당신은 서울대 푸드테크 센터 회원관리 시스템의 보조 관리자입니다. ' +
  '사용자의 자연어 요청이나 첨부 파일(합격서·지원서 등)을 보고, 등록된 회원 중 대상을 검색하여 어떤 정보를 어떻게 바꿀지 제안하세요. ' +
  '대상이 여러 명이거나 특정할 수 없으면 절대 추측하지 말고 텍스트로 사용자에게 되물으세요. ' +
  '검색으로 일치하는 등록 인원을 찾지 못하면(신규 인물) propose_person_update를 호출하지 말고, 알아낸 정보를 텍스트로 요약해 전달하세요 — 신규 등록은 아직 지원하지 않습니다.';

export async function onRequestPost({ request, env }) {
  const apiKey = env.ANTHROPIC_API_KEY;
  if (!apiKey) return json({ error: 'ANTHROPIC_API_KEY가 설정되지 않았습니다 (Cloudflare Pages 환경변수 확인 필요)' }, 500);

  let body;
  try { body = await request.json(); } catch { return json({ error: '잘못된 요청 본문' }, 400); }

  const userContent = [];
  if (body.fileBase64) {
    const mediaType = body.mediaType || 'application/pdf';
    userContent.push(
      mediaType === 'application/pdf'
        ? { type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: body.fileBase64 } }
        : { type: 'image', source: { type: 'base64', media_type: mediaType, data: body.fileBase64 } }
    );
  }
  userContent.push({
    type: 'text',
    text: body.message || '이 파일에서 인물 정보를 추출해서, 이미 등록된 사람 중 일치하는 사람을 찾아 어떤 값을 업데이트할지 제안해줘.',
  });

  // 클라이언트가 들고 다니는 이전 대화 맥락 — 이게 없으면 매 요청이 새 대화로 취급되어
  // "그 사람 가입완료로 해줘" 같은 후속 요청이 누구를 말하는지 모르게 된다.
  const history = Array.isArray(body.history)
    ? body.history
        .filter(m => m && (m.role === 'user' || m.role === 'assistant') && typeof m.content === 'string')
        .slice(-20)
        .map(m => ({ role: m.role, content: m.content }))
    : [];

  const messages = [...history, { role: 'user', content: userContent }];

  try {
    for (let i = 0; i < 4; i++) {
      const resp = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: 'claude-opus-5',
          max_tokens: 2048,
          output_config: { effort: 'medium' },
          system: SYSTEM_PROMPT,
          tools: TOOLS,
          messages,
        }),
      });
      const data = await resp.json();
      if (data.type === 'error') return json({ error: data.error.message }, 502);

      if (data.stop_reason !== 'tool_use') {
        const textBlock = (data.content || []).find(b => b.type === 'text');
        return json({ message: textBlock ? textBlock.text : '' });
      }

      const toolResults = [];
      let proposal = null;
      for (const block of data.content) {
        if (block.type !== 'tool_use') continue;
        if (block.name === 'propose_person_update') {
          proposal = block.input;
          toolResults.push({ type: 'tool_result', tool_use_id: block.id, content: '제안이 사용자에게 전달되었습니다.' });
        } else if (block.name === 'search_person') {
          const rows = await searchPerson(block.input.query);
          toolResults.push({ type: 'tool_result', tool_use_id: block.id, content: JSON.stringify(rows) });
        }
      }
      if (proposal) return json({ proposal });

      messages.push({ role: 'assistant', content: data.content });
      messages.push({ role: 'user', content: toolResults });
    }
    return json({ message: '요청을 처리하지 못했습니다. 다시 시도해주세요.' });
  } catch (e) {
    return json({ error: String(e && e.message || e) }, 500);
  }
}

async function searchPerson(query) {
  const res = await fetch(`${SB_URL}/rest/v1/rpc/search_people_for_picker`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}` },
    body: JSON.stringify({ q: query }),
  });
  return res.json();
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json' } });
}
