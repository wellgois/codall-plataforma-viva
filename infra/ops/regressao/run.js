#!/usr/bin/env node
// Roda o conjunto de regressao usando o proprio servico de IA do Codall (as chaves ficam
// dentro do app; este script nao le nem imprime segredos). Resultado em data/regressao.jsonl.
const fs = require('fs'), path = require('path'), cp = require('child_process');
const CODALL = process.env.CODALL_DIR || '/ai/codall';
try { require(path.join(CODALL, 'node_modules/dotenv')).config({ path: path.join(CODALL, '.env') }); } catch (e) {}
const ai = require(path.join(CODALL, 'src/services/aiProvider.js'));
const tarefas = require('./tarefas.js');
let perguntas = require('./perguntas.js');
try { perguntas = perguntas.concat(JSON.parse(fs.readFileSync(path.join(__dirname, 'perguntas-gerado.json'), 'utf8'))); } catch (e) {}
const OUT = process.env.OUT || path.join(CODALL, 'data/regressao.jsonl'); // OUT=/tmp/x.jsonl roda como teste, sem tocar nos resultados
const TOTAL = parseInt(process.env.TOTAL || '500', 10);

function hash(str) { let h = 2166136261; for (const c of str) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619); } return h >>> 0; }
function rng(seed) { let a = seed >>> 0; return () => { a = (a + 0x6D2B79F5) >>> 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
function embaralha(arr, rand) { const a = arr.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rand() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }
// monta as perguntas do dia: ordem e alternativas sorteadas pela data
function perguntasDoDia(dia, quantas) {
  const todas = perguntas.map((p, i) => ({ id: 'q' + String(i + 1).padStart(3, '0'), area: p[0], q: p[1], certa: p[2], erradas: p.slice(3) }));
  const sel = embaralha(todas, rng(hash(dia))).slice(0, quantas);
  return sel.map(p => {
    const alts = embaralha([p.certa, ...p.erradas], rng(hash(dia + p.id)));
    return { ...p, alts, gabarito: 'ABCD'[alts.indexOf(p.certa)] };
  });
}

const USD_POR_MTOK = 0.18;

function codigo(texto) {
  // o servico de IA do Codall usa um prompt de agente; escolher o bloco que define a funcao
  const blocos = [...texto.matchAll(/```[a-zA-Z]*\s*\n([\s\S]*?)```/g)].map(m => m[1]);
  const b = blocos.find(x => /^\s*def\s+\w+\(/m.test(x) && !/^\s*python3\s+-c/m.test(x)) || blocos[0] || texto;
  const h = b.match(/<<-?\s*['"]?(\w+)['"]?[^\n]*\n([\s\S]*?)\n\1\s*(\n|$)/);
  return (h ? h[2] : b).trim() + '\n';
}
async function perguntar(prompt) {
  const msgs = [{ role: 'user', content: prompt }];
  let out = '';
  for await (const c of ai.streamChat(msgs)) {
    out += typeof c === 'string' ? c : (c && (c.text || c.content || c.delta || '')) || '';
  }
  return out;
}
(async () => {
  const filtro = process.argv[2];
  const lote = new Date().toISOString();
  const base = fs.mkdtempSync('/tmp/regressao-');
  let ok = 0, n = 0;
  const dia = new Date().toISOString().slice(0, 10);
  const codigoTarefas = tarefas.filter(x => !filtro || x.id === filtro);
  const nPerg = filtro ? 0 : Math.max(0, TOTAL - codigoTarefas.length);
  const lista = [...codigoTarefas.map(t => ({ tipo: 'codigo', t })), ...perguntasDoDia(dia, nPerg).map(p => ({ tipo: 'mcq', p }))];
  for (const it of lista) {
    n++;
    const t0 = Date.now(); let reenvio = false, resp = '', erro = null, passou = false, saida = '', prompt = '', meta;
    try {
      if (it.tipo === 'codigo') {
        const t = it.t; meta = { id: t.id, nome: t.nome, assunto: t.assunto };
        const dir = path.join(base, t.id); fs.mkdirSync(dir);
        prompt = `Escreva APENAS um bloco de codigo Python (sem explicacao), usando so a biblioteca padrao, que define: ${t.prompt}`;
        resp = await perguntar(prompt);
        fs.writeFileSync(path.join(dir, 'sol.py'), codigo(resp));
        fs.writeFileSync(path.join(dir, 'teste.py'), t.teste + '\n');
        const r = cp.spawnSync('python3', ['teste.py'], { cwd: dir, timeout: 20000, encoding: 'utf8' });
        saida = ((r.stdout || '') + (r.stderr || '')).trim().slice(-300);
        passou = r.status === 0 && /ok\s*$/.test(r.stdout || '');
      } else {
        const p = it.p; meta = { id: p.id, nome: p.q.slice(0, 80), assunto: p.area };
        prompt = `Pergunta de multipla escolha (estilo certificacao). Responda sem executar comandos. Termine com uma unica linha "RESPOSTA: X", onde X e A, B, C ou D.\n\n${p.q}\n` + p.alts.map((a, i) => `${'ABCD'[i]}) ${a}`).join('\n');
        resp = await perguntar(prompt);
        const ms = [...resp.matchAll(/RESPOSTA:\s*\**\s*([A-D])\b/gi)];
        let dada = ms.length ? ms[ms.length - 1][1].toUpperCase() : null;
        if (!dada) { // falha de formato: pede de novo so a letra, uma vez
          try {
            const r2 = await perguntar(prompt + '\n\nA resposta anterior nao terminou com a linha pedida. Responda SOMENTE com a linha "RESPOSTA: X" (X = A, B, C ou D), sem mais nada.');
            const m2 = [...r2.matchAll(/RESPOSTA:\s*\**\s*([A-D])\b/gi)];
            if (m2.length) dada = m2[m2.length - 1][1].toUpperCase();
            resp += r2; reenvio = true;
          } catch (e) {}
        }
        passou = dada === p.gabarito; saida = passou ? '' : `deu ${dada || 'nenhuma'}, gabarito ${p.gabarito}`;
      }
    } catch (e) { erro = String(e.message || e).slice(0, 200); }
    const tokens = Math.round((prompt.length + resp.length) / 3.5);
    const linha = { lote, dia, tipo: it.tipo, ...meta, passou, ms: Date.now() - t0,
      tokens_estimados: tokens, custo_usd_estimado: +(tokens * USD_POR_MTOK / 1e6).toFixed(6), erro, saida: passou ? '' : saida, ...(reenvio ? { reenvio } : {}) };
    fs.appendFileSync(OUT, JSON.stringify(linha) + '\n');
    if (passou) ok++;
    console.log((passou ? 'OK  ' : 'FALHA ') + meta.id + ' ' + meta.nome.slice(0, 40));
  }
  console.log(`resultado: ${ok}/${n} em ${lote}`);
  process.exit(0);
})().catch(e => { console.error('erro geral:', e.message); process.exit(1); });
