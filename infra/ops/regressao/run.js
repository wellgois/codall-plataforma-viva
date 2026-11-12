#!/usr/bin/env node
// Roda o conjunto de regressao usando o proprio servico de IA do Codall (as chaves ficam
// dentro do app; este script nao le nem imprime segredos). Resultado em data/regressao.jsonl.
const fs = require('fs'), path = require('path'), cp = require('child_process');
const CODALL = process.env.CODALL_DIR || '/ai/codall';
try { require(path.join(CODALL, 'node_modules/dotenv')).config({ path: path.join(CODALL, '.env') }); } catch (e) {}
const ai = require(path.join(CODALL, 'src/services/aiProvider.js'));
const tarefas = require('./tarefas.js');
const OUT = path.join(CODALL, 'data/regressao.jsonl');
const USD_POR_MTOK = 0.18;

function codigo(texto) {
  // o servico de IA do Codall usa um prompt de agente; escolher o bloco que define a funcao
  const blocos = [...texto.matchAll(/```[a-zA-Z]*\s*\n([\s\S]*?)```/g)].map(m => m[1]);
  const b = blocos.find(x => /^\s*def\s+\w+\(/m.test(x) && !/^\s*python3\s+-c/m.test(x)) || blocos[0] || texto;
  return b.trim() + '\n';
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
  for (const t of tarefas.filter(x => !filtro || x.id === filtro)) {
    n++;
    const dir = path.join(base, t.id); fs.mkdirSync(dir);
    const prompt = `Escreva APENAS um bloco de codigo Python (sem explicacao), usando so a biblioteca padrao, que define: ${t.prompt}`;
    const t0 = Date.now(); let resp = '', erro = null, passou = false, saida = '';
    try {
      resp = await perguntar(prompt);
      fs.writeFileSync(path.join(dir, 'sol.py'), codigo(resp));
      fs.writeFileSync(path.join(dir, 'teste.py'), t.teste + '\n');
      const r = cp.spawnSync('python3', ['teste.py'], { cwd: dir, timeout: 20000, encoding: 'utf8' });
      saida = ((r.stdout || '') + (r.stderr || '')).trim().slice(-300);
      passou = r.status === 0 && /ok\s*$/.test(r.stdout || '');
    } catch (e) { erro = String(e.message || e).slice(0, 200); }
    const tokens = Math.round((prompt.length + resp.length) / 3.5);
    const linha = { lote, id: t.id, nome: t.nome, assunto: t.assunto, passou, ms: Date.now() - t0,
      tokens_estimados: tokens, custo_usd_estimado: +(tokens * USD_POR_MTOK / 1e6).toFixed(6), erro, saida: passou ? '' : saida };
    fs.appendFileSync(OUT, JSON.stringify(linha) + '\n');
    if (passou) ok++;
    console.log((passou ? 'OK  ' : 'FALHA ') + t.id + ' ' + t.nome + ' (' + linha.ms + 'ms)');
  }
  console.log(`resultado: ${ok}/${n} em ${lote}`);
  process.exit(0);
})().catch(e => { console.error('erro geral:', e.message); process.exit(1); });
