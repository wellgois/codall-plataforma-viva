#!/usr/bin/env bash
# Diagnostico do Telegram do Codall. NAO imprime token nem chat id: so formato, tamanho e o status devolvido pelo Telegram.
cd /ai/codall
node -e '
const https = require("https");
let tok = null, via = "";
try { const r = require("./src/services/secretRef"); const v = r.resolve("TELEGRAM_BOT_TOKEN"); if (v) { tok = v; via = "cofre"; } } catch (e) {}
if (!tok && process.env.TELEGRAM_BOT_TOKEN) { tok = process.env.TELEGRAM_BOT_TOKEN; via = "env"; }
const db = require("better-sqlite3")("data/codall.db", { readonly: true });
const rows = db.prepare("select key, length(value) n, value from settings where key like ?").all("telegram%");
console.log("chaves em settings:", rows.map(r => r.key + "(" + r.n + ")").join(", ") || "nenhuma");
const chat = (rows.find(r => r.key === "telegram_chat_id") || {}).value || process.env.TELEGRAM_CHAT_ID || "";
console.log("chat id:", chat ? (/^-?[0-9]+$/.test(chat.trim()) ? "numerico, ok" : "NAO e numerico (precisa ser um numero)") : "nao encontrado");
if (!tok) { console.log("token: nao resolvido"); process.exit(0); }
console.log("token vindo de:", via, "| tamanho:", tok.length, "| formato:", /^[0-9]{8,12}:[A-Za-z0-9_-]{35}$/.test(tok.trim()) ? "valido" : "FORMATO INVALIDO", tok !== tok.trim() ? "| tem espaco ou quebra de linha nas pontas" : "");
https.get("https://api.telegram.org/bot" + tok.trim() + "/getMe", r => {
  let d = ""; r.on("data", c => d += c); r.on("end", () => {
    let j = {}; try { j = JSON.parse(d); } catch (e) {}
    console.log("Telegram getMe: HTTP", r.statusCode, j.ok ? "ok, bot @" + j.result.username : (j.description || ""));
  });
}).on("error", e => console.log("erro de rede:", e.message));
' 2>&1 | head -20
