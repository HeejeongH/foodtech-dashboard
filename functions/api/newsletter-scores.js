// Cloudflare Pages Function — GET /api/newsletter-scores
//
// Fetches the newsletter admin's participation-score CSV server-side and
// returns it as JSON. The Basic Auth credential (NEWSLETTER_ADMIN_TOKEN)
// stays server-side — set it in Cloudflare Pages > Settings > Environment
// variables. The client never sees it.
//
// Source: FoodTech-Agent (https://github.com/MingyumSong/FoodTech-Agent)
// admin_token-gated CSV export at /admin/scores.csv.

const SOURCE_URL = 'https://admin.foodtech-center.org/admin/scores.csv';

export async function onRequestGet({ env }) {
  const token = env.NEWSLETTER_ADMIN_TOKEN;
  if (!token) return json({ error: 'NEWSLETTER_ADMIN_TOKEN이 설정되지 않았습니다' }, 500);

  try {
    const res = await fetch(SOURCE_URL, {
      headers: { Authorization: 'Basic ' + btoa(`admin:${token}`) },
    });
    if (!res.ok) return json({ error: `뉴스레터 서버 응답 오류 (${res.status})` }, 502);

    let text = await res.text();
    if (text.charCodeAt(0) === 0xfeff) text = text.slice(1); // strip BOM

    return json({ rows: parseCsv(text) });
  } catch (e) {
    return json({ error: String(e && e.message || e) }, 500);
  }
}

function parseCsv(text) {
  const lines = text.replace(/\r\n/g, '\n').split('\n').filter(l => l.length > 0);
  if (lines.length === 0) return [];
  const headers = splitCsvLine(lines[0]);
  return lines.slice(1).map(line => {
    const cells = splitCsvLine(line);
    const obj = {};
    headers.forEach((h, i) => { obj[h] = cells[i] ?? ''; });
    return obj;
  });
}

// Minimal RFC4180 line splitter — handles quoted fields containing commas.
function splitCsvLine(line) {
  const out = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (inQuotes) {
      if (c === '"') {
        if (line[i + 1] === '"') { cur += '"'; i++; } else inQuotes = false;
      } else cur += c;
    } else if (c === '"') inQuotes = true;
    else if (c === ',') { out.push(cur); cur = ''; }
    else cur += c;
  }
  out.push(cur);
  return out;
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json' } });
}
