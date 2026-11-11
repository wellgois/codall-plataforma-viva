#!/usr/bin/env bash
# Cria /opt/plataforma-viva/.alerta (0600, fora do git) com o token e o chat id que o Codall ja usa,
# e envia uma mensagem de teste. Nao imprime token nem chat id.
cd /ai/codall
node -e '
const https = require("https"), fs = require("fs");
let tok = process.env.TELEGRAM_BOT_TOKEN || "";
try { const v = require("./src/services/secretRef").resolve("TELEGRAM_BOT_TOKEN"); if (v) tok = v; } catch (e) {}
const db = require("better-sqlite3")("data/codall.db", { readonly: true });
const row = db.prepare("select value from settings where key = ?").get("telegram_chat_id");
const chat = ((row && row.value) || process.env.TELEGRAM_CHAT_ID || "").trim();
tok = tok.trim();
if (!tok || !/^-?[0-9]+$/.test(chat)) { console.log("faltam token ou chat id numerico"); process.exit(1); }
fs.writeFileSync("/opt/plataforma-viva/.alerta", "TELEGRAM_TOKEN=" + tok + "\nTELEGRAM_CHAT_ID=" + chat + "\n", { mode: 0o600 });
fs.chmodSync("/opt/plataforma-viva/.alerta", 0o600);
const body = new URLSearchParams({ chat_id: chat, text: "Plataforma Viva: alerta configurado. Voce recebera mensagens quando o monitor detectar falha." }).toString();
const req = https.request("https://api.telegram.org/bot" + tok + "/sendMessage", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" } }, r => {
  let d = ""; r.on("data", c => d += c); r.on("end", () => console.log(".alerta criado | envio de teste: HTTP", r.statusCode, r.statusCode === 200 ? "ok, olhe seu Telegram" : d.slice(0, 120)));
});
req.on("error", e => console.log("erro de rede:", e.message)); req.end(body);
'
