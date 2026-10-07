/**
 * SafeStart · Google Apps Script (งานอัตโนมัติ)
 * - ทุก 5 นาที: ส่งต่อเรื่องที่ไม่รับทราบ ส่งซ้ำเรื่องด่วน แล้วส่งแจ้งเตือน (บนเครื่อง / LINE / อีเมล)
 * - 07:00 เตือนยื่นแผนพรุ่งนี้ + เอกสาร/Self-declaration ใกล้หมดอายุ · 08:30–11:00 ทีมที่ยังไม่ check-in · 12:00 สรุปเที่ยง · 18:30 ยังไม่ปิดงาน
 * - รับข้อความ LINE (webhook) เพื่อผูกบัญชี
 * Script properties (Project Settings › Script properties):
 *   SUPABASE_URL, SUPABASE_SERVICE_KEY (service_role · เก็บที่นี่ที่เดียว ห้ามใส่ในหน้าเว็บ), APP_URL,
 *   LINE_TOKEN (ไม่ใส่ = ไม่ส่ง LINE), PUSH_URL + PUSH_SECRET (ไม่ใส่ = ไม่ส่งแจ้งเตือนบนเครื่อง)
 */
const P = PropertiesService.getScriptProperties();
const prop = k => P.getProperty(k) || '';

function sb_(path, method, body, extraHeaders) {
  const res = UrlFetchApp.fetch(prop('SUPABASE_URL') + '/rest/v1/' + path, {
    method: method || 'get', contentType: 'application/json', muteHttpExceptions: true,
    headers: Object.assign({ apikey: prop('SUPABASE_SERVICE_KEY'), Authorization: 'Bearer ' + prop('SUPABASE_SERVICE_KEY'), Prefer: 'return=representation' }, extraHeaders || {}),
    payload: body ? JSON.stringify(body) : undefined
  });
  const code = res.getResponseCode(), txt = res.getContentText();
  if (code >= 300) throw new Error('Supabase ' + code + ': ' + txt);
  return txt ? JSON.parse(txt) : null;
}
const rpc_ = (fn, args) => sb_('rpc/' + fn, 'post', args || {});

function linePush_(to, text) {
  if (!prop('LINE_TOKEN') || !to) return false;
  const r = UrlFetchApp.fetch('https://api.line.me/v2/bot/message/push', { method: 'post', contentType: 'application/json', muteHttpExceptions: true,
    headers: { Authorization: 'Bearer ' + prop('LINE_TOKEN') }, payload: JSON.stringify({ to: to, messages: [{ type: 'text', text: text.slice(0, 4900) }] }) });
  return r.getResponseCode() < 300;
}
function lineReply_(token, text) {
  if (!prop('LINE_TOKEN')) return;
  UrlFetchApp.fetch('https://api.line.me/v2/bot/message/reply', { method: 'post', contentType: 'application/json', muteHttpExceptions: true,
    headers: { Authorization: 'Bearer ' + prop('LINE_TOKEN') }, payload: JSON.stringify({ replyToken: token, messages: [{ type: 'text', text: text }] }) });
}
function quiet_() { const h = Number(Utilities.formatDate(new Date(), 'Asia/Bangkok', 'H')); return h >= 21 || h < 6; }

/* ---------- ทุก 5 นาที ---------- */
function every5min() {
  try { Logger.log(JSON.stringify(rpc_('run_escalations'))); } catch (e) { Logger.log(e); }
  dispatch_();
}

function dispatch_() {
  const since = new Date(Date.now() - 24 * 3600e3).toISOString();
  const rows = sb_('notifications?select=*&created_at=gte.' + since + '&or=(sent_push_at.is.null,sent_line_at.is.null,sent_email_at.is.null)&order=created_at&limit=200');
  if (!rows.length) return;
  const ids = [...new Set(rows.map(r => r.to_id))];
  const profs = sb_('profiles?select=id,email,full_name,line_user_id,active&id=in.(' + ids.join(',') + ')');
  const byId = {}; profs.forEach(p => byId[p.id] = p);
  const now = new Date().toISOString(), app = prop('APP_URL');
  const push = [];
  rows.forEach(n => {
    const p = byId[n.to_id]; if (!p || !p.active) return;
    const patch = {};
    const text = (n.urgent ? '🚨 ด่วน · ' : '') + n.title + (n.body ? '\n' + n.body : '') + (n.need_ack ? '\n→ เปิดแอปเพื่อกดรับทราบ' : '') + (app ? '\n' + app : '');
    // 1) แจ้งเตือนบนเครื่อง (ทุกเรื่อง · ฟรี)
    if (!n.sent_push_at) { push.push({ user_id: n.to_id, title: (n.urgent ? 'ด่วน · ' : '') + n.title, body: n.body || '', urgent: n.urgent, tag: n.ref_id || n.id, url: app }); patch.sent_push_at = now; }
    // 2) LINE: เรื่องที่ต้องรับทราบ/ด่วน · งดช่วง 21:00–06:00 ยกเว้นด่วน
    if (!n.sent_line_at) {
      if ((n.need_ack || n.urgent) && p.line_user_id && (n.urgent || !quiet_())) { if (linePush_(p.line_user_id, text)) patch.sent_line_at = now; }
      else if (!(n.need_ack || n.urgent) || !p.line_user_id) patch.sent_line_at = now;  // ไม่ต้องส่ง LINE
    }
    // 3) อีเมล: เรื่องที่ต้องรับทราบ (ส่งครั้งเดียว)
    if (!n.sent_email_at) {
      if (n.need_ack && p.email && (n.urgent || !quiet_())) {
        try { MailApp.sendEmail({ to: p.email, subject: '[SafeStart] ' + (n.urgent ? 'ด่วน · ' : '') + n.title, body: text, name: 'SafeStart' }); patch.sent_email_at = now; } catch (e) { Logger.log(e); }
      } else if (!n.need_ack) patch.sent_email_at = now;
    }
    if (Object.keys(patch).length) sb_('notifications?id=eq.' + n.id, 'patch', patch, { Prefer: 'return=minimal' });
  });
  if (push.length && prop('PUSH_URL')) {
    try { UrlFetchApp.fetch(prop('PUSH_URL'), { method: 'post', contentType: 'application/json', muteHttpExceptions: true,
      headers: { Authorization: 'Bearer ' + prop('SUPABASE_SERVICE_KEY'), 'x-push-secret': prop('PUSH_SECRET') }, payload: JSON.stringify({ items: push }) }); } catch (e) { Logger.log(e); }
  }
}

/* ---------- งานรายวัน ---------- */
function morning() { Logger.log(JSON.stringify(rpc_('run_daily', { p_kind: 'morning' }))); every5min(); }
function missingCheckin() {
  const h = Number(Utilities.formatDate(new Date(), 'Asia/Bangkok', 'H'));
  if (h < 8 || h > 11) return;
  Logger.log(JSON.stringify(rpc_('run_daily', { p_kind: 'missing_checkin' }))); every5min();
}
function evening() { Logger.log(JSON.stringify(rpc_('run_daily', { p_kind: 'evening' }))); every5min(); }

/* สรุปเที่ยง: ส่งให้ IC และ IC & QC Manager ของแต่ละบริษัท (LINE ถ้าผูกแล้ว + อีเมล) */
function noonSummary() {
  const cos = sb_('scg_companies?select=id,name&active=eq.true');
  cos.forEach(c => {
    const s = rpc_('today_summary', { p_co: c.id });
    const text = '📋 SafeStart สรุปเที่ยง · ' + c.name + '\n' + s.date + '\nงานวันนี้ ' + s.jobs + ' (เสี่ยงสูง ' + s.high + ')\nCheck-in แล้ว ' + s.checked_in +
      '\nยังไม่ check-in: ' + (s.missing.length ? s.missing.join(', ') : '-') + '\nบัตรส้มค้าง ' + s.setup_open + ' · หยุดงาน ' + s.stopped +
      '\nFinding ค้าง ' + s.findings_open + ' · แจ้งเหตุวันนี้ ' + s.incidents_today + (prop('APP_URL') ? '\n' + prop('APP_URL') : '');
    const users = sb_('profiles?select=email,line_user_id&active=eq.true&role=in.(installation_consultant,ic_qc_manager)&scg_company_ids=cs.{' + c.id + '}');
    users.forEach(u => { if (u.line_user_id) linePush_(u.line_user_id, text); });
    const emails = users.map(u => u.email).filter(Boolean);
    if (emails.length) MailApp.sendEmail({ to: emails.join(','), subject: '[SafeStart] สรุปเที่ยง ' + c.name + ' ' + s.date, body: text, name: 'SafeStart' });
  });
}

/* ---------- LINE webhook: พิมพ์รหัส 6 ตัวจากหน้า "ฉัน" เพื่อผูกบัญชี ---------- */
function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents);
    (body.events || []).forEach(ev => {
      if (ev.type !== 'message' || ev.message.type !== 'text') return;
      const code = String(ev.message.text || '').trim().toUpperCase();
      if (!/^[0-9A-F]{6}$/.test(code)) return lineReply_(ev.replyToken, 'พิมพ์รหัส 6 ตัวจากหน้า "ฉัน" ในแอป SafeStart เพื่อรับแจ้งเตือน');
      const name = rpc_('link_line', { p_code: code, p_line_user: ev.source.userId });
      lineReply_(ev.replyToken, name ? 'ผูกบัญชีแล้ว: ' + name + ' ✅\nจะได้รับแจ้งเตือนเรื่องที่ต้องรับทราบและเรื่องด่วนทางนี้' : 'รหัสไม่ถูกต้องหรือหมดอายุ ขอรหัสใหม่ในหน้า "ฉัน"');
    });
  } catch (err) { Logger.log(err); }
  return ContentService.createTextOutput('ok');
}

/* ---------- ติดตั้งครั้งเดียว ---------- */
function setupTriggers() {
  ScriptApp.getProjectTriggers().forEach(t => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('every5min').timeBased().everyMinutes(5).create();
  ScriptApp.newTrigger('missingCheckin').timeBased().everyMinutes(30).create();
  ScriptApp.newTrigger('morning').timeBased().atHour(7).nearMinute(0).everyDays(1).inTimezone('Asia/Bangkok').create();
  ScriptApp.newTrigger('noonSummary').timeBased().atHour(12).nearMinute(0).everyDays(1).inTimezone('Asia/Bangkok').create();
  ScriptApp.newTrigger('evening').timeBased().atHour(18).nearMinute(30).everyDays(1).inTimezone('Asia/Bangkok').create();
  Logger.log('ตั้งเวลาเรียบร้อย ' + ScriptApp.getProjectTriggers().length + ' รายการ');
}
function testConnection() {
  const cos = sb_('scg_companies?select=name');
  Logger.log('เชื่อม Supabase ได้ · บริษัท: ' + cos.map(c => c.name).join(', '));
  Logger.log(JSON.stringify(rpc_('run_escalations')));
}
