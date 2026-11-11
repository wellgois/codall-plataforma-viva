#!/usr/bin/env bash
# Implementa Salvar/Testar da aba Telegram em /ai/codall (rotas + JS) e reinicia o Codall.
set -e
cd /ai/codall
TS=$(date +%Y%m%d%H%M%S)
cp src/routes/settings.js src/routes/settings.js.bak-$TS
cp public/settings.html public/settings.html.bak-$TS
node - <<'JS'
const fs = require('fs');
let r = fs.readFileSync('src/routes/settings.js', 'utf8');
if (!r.includes('/* telegram-botoes */')) {
  const rotas = `
/* telegram-botoes */
function _tgSet(db, k, v) {
  db.prepare('DELETE FROM settings WHERE key=?').run(k);
  db.prepare('INSERT INTO settings (key, value) VALUES (?, ?)').run(k, v);
}
router.get('/telegram', (req, res) => {
  const db = getDb();
  const g = (k) => (db.prepare('SELECT value FROM settings WHERE key=?').get(k) || {}).value || '';
  res.json({ ok: true, tokenSalvo: !!g('telegram_bot_token'), chatId: g('telegram_chat_id') });
});
router.post('/telegram', (req, res) => {
  try {
    const db = getDb();
    const token = String((req.body && req.body.token) || '').trim();
    const chatId = String((req.body && req.body.chatId) || '').trim();
    if (!token && !chatId) return res.status(400).json({ ok: false, error: 'nada para salvar' });
    if (token) _tgSet(db, 'telegram_bot_token', token);
    if (chatId) _tgSet(db, 'telegram_chat_id', chatId);
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ ok: false, error: e.message }); }
});
router.post('/telegram/test', async (req, res) => {
  try {
    const n = require('../services/telegramNotifier');
    const fn = n.notifyRaw || n.sendMessage;
    const r2 = await fn('✅ Teste do Codall: Telegram conectado.');
    res.json({ ok: true, resposta: r2 === undefined ? null : r2 });
  } catch (e) { res.status(500).json({ ok: false, error: e.message }); }
});
`;
  const i = r.lastIndexOf('module.exports');
  r = r.slice(0, i) + rotas + '\n' + r.slice(i);
  fs.writeFileSync('src/routes/settings.js', r);
}
let h = fs.readFileSync('public/settings.html', 'utf8');
if (!h.includes('/* telegram-botoes */')) {
  const js = `
        /* telegram-botoes */
        async function _tgPost(url, body) {
            const r = await fetch(url, {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(body||{})});
            return r.json().catch(() => ({ok:false, error:'resposta invalida'}));
        }
        async function saveTelegram() {
            const token = document.getElementById('telegram-token').value.trim();
            const chatId = document.getElementById('telegram-chat-id').value.trim();
            const j = await _tgPost('/api/settings/telegram', {token: token, chatId: chatId});
            alert(j.ok ? 'Telegram salvo.' : 'Erro ao salvar: ' + (j.error || 'falha'));
            if (j.ok) { document.getElementById('telegram-token').value = ''; loadTelegram(); }
        }
        async function testTelegram() {
            const j = await _tgPost('/api/settings/telegram/test', {});
            alert(j.ok ? 'Mensagem de teste enviada. Confira o Telegram.' : 'Falha no teste: ' + (j.error || 'sem resposta'));
        }
        async function loadTelegram() {
            try {
                const r = await fetch('/api/settings/telegram'); const j = await r.json();
                if (j.chatId) document.getElementById('telegram-chat-id').value = j.chatId;
                document.getElementById('telegram-token').placeholder = j.tokenSalvo ? 'token salvo (preencha so para trocar)' : '123456:ABC-DEF...';
            } catch (e) {}
        }
        document.addEventListener('DOMContentLoaded', function () {
            loadTelegram();
            const f = document.getElementById('telegram-form');
            if (f) f.addEventListener('submit', function (ev) { ev.preventDefault(); saveTelegram(); });
        });
`;
  const i = h.lastIndexOf('</script>');
  h = h.slice(0, i) + js + '    ' + h.slice(i);
  fs.writeFileSync('public/settings.html', h);
}
JS
node --check src/routes/settings.js && pm2 restart codall >/dev/null && echo "OK: rotas e botoes do Telegram instalados"
