// SafeStart · Edge Function "push": ส่งแจ้งเตือนบนเครื่อง (Web Push) · Apps Script เรียกทุก 5 นาที
// Secrets (Supabase › Edge Functions › Secrets): VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT (เช่น mailto:safety@scg.com), PUSH_SECRET
// SUPABASE_URL และ SUPABASE_SERVICE_ROLE_KEY มีให้อัตโนมัติ
import webpush from 'npm:web-push@3.6.7';
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

webpush.setVapidDetails(Deno.env.get('VAPID_SUBJECT') ?? 'mailto:safety@example.com', Deno.env.get('VAPID_PUBLIC_KEY')!, Deno.env.get('VAPID_PRIVATE_KEY')!);
const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

Deno.serve(async (req) => {
  if (req.headers.get('x-push-secret') !== Deno.env.get('PUSH_SECRET')) return new Response('forbidden', { status: 403 });
  const { items } = await req.json() as { items: { user_id: string; title: string; body: string; urgent?: boolean; tag?: string; url?: string }[] };
  const users = [...new Set(items.map((i) => i.user_id))];
  const { data: subs } = await db.from('push_subs').select('*').in('user_id', users);
  let sent = 0, gone = 0;
  for (const it of items) {
    for (const s of (subs ?? []).filter((x) => x.user_id === it.user_id)) {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: s.keys }, JSON.stringify(it), { TTL: it.urgent ? 3600 : 86400, urgency: it.urgent ? 'high' : 'normal' });
        sent++;
      } catch (e) {
        const code = (e as { statusCode?: number }).statusCode;
        if (code === 404 || code === 410) { await db.from('push_subs').delete().eq('id', s.id); gone++; }
      }
    }
  }
  return Response.json({ sent, removed: gone });
});
