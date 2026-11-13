#!/usr/bin/env node
// Gera perguntas novas (nivel intermediario a avancado) com o servico de IA do Codall e so
// guarda as que passam por uma checagem cega: outra chamada responde sem ver o gabarito e
// precisa concordar com ele. Acrescenta em perguntas-gerado.json (nao reescreve o que existe).
// Uso: node gerar.js [por_area=30]
const fs = require('fs'), path = require('path');
const CODALL = process.env.CODALL_DIR || '/ai/codall';
try { require(path.join(CODALL, 'node_modules/dotenv')).config({ path: path.join(CODALL, '.env') }); } catch (e) {}
const ai = require(path.join(CODALL, 'src/services/aiProvider.js'));
const base = require('./perguntas.js');
const ARQ = path.join(__dirname, 'perguntas-gerado.json');
const AREAS = ['SQL avancado (janelas, CTE, otimizacao)', 'Python para dados', 'pandas', 'Apache Airflow', 'dbt', 'Docker', 'Linux e shell', 'Git', 'Redes e HTTP', 'Seguranca de aplicacoes web', 'Modelagem dimensional e data warehouse', 'Apache Spark', 'Terraform', 'AWS (S3, IAM, EC2, Lambda)', 'Kafka e streaming', 'Node.js e JavaScript', 'PostgreSQL', 'Qualidade e contratos de dados', 'Estatistica aplicada', 'CI/CD e observabilidade'];
const POR_AREA = parseInt(process.argv[2] || '30', 10);
const norm = s => s.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
function hash(str) { let h = 2166136261; for (const c of str) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619); } return h >>> 0; }
async function perguntar(prompt) {
  let out = '';
  for await (const c of ai.streamChat([{ role: 'user', content: prompt }])) out += typeof c === 'string' ? c : (c && (c.text || c.content || c.delta || '')) || '';
  return out;
}
function json(txt) { const a = txt.indexOf('['), b = txt.lastIndexOf(']'); if (a < 0 || b < a) return []; try { return JSON.parse(txt.slice(a, b + 1)); } catch (e) { return []; } }
(async () => {
  const gerado = fs.existsSync(ARQ) ? JSON.parse(fs.readFileSync(ARQ, 'utf8')) : [];
  const vistos = new Set([...base, ...gerado].map(p => norm(p[1])));
  let novos = 0, descartados = 0;
  for (const area of AREAS) {
    const nome = area.split(' (')[0];
    let tem = gerado.filter(p => p[0] === nome).length;
    for (let rodada = 0; rodada < 6 && tem < POR_AREA; rodada++) {
      const prompt = `Nao execute comandos. Responda APENAS com um array JSON puro. Crie 10 perguntas de multipla escolha NOVAS e DIFERENTES entre si, nivel intermediario a avancado, estilo prova de certificacao, sobre: ${area}. Cada item: {"q":"pergunta","certa":"alternativa correta","erradas":["plausivel 1","plausivel 2","plausivel 3"]}. Apenas UMA alternativa pode estar correta, sem ambiguidade; alternativas de tamanho parecido; sem "todas as anteriores". Variacao ${rodada + 1}.`;
      let itens = []; try { itens = json(await perguntar(prompt)); } catch (e) { continue; }
      for (const it of itens) {
        if (!it || !it.q || !it.certa || !Array.isArray(it.erradas) || it.erradas.length !== 3) continue;
        const k = norm(it.q); if (vistos.has(k)) continue;
        const alts = [it.certa, ...it.erradas].map(String);
        if (new Set(alts.map(norm)).size !== 4) continue;
        const ord = alts.map(a => [hash(it.q + a), a]).sort((x, y) => x[0] - y[0]).map(x => x[1]);
        const gab = 'ABCD'[ord.indexOf(alts[0])];
        let dada = null;
        try {
          const r = await perguntar(`Pergunta de multipla escolha. Nao execute comandos. Termine com uma unica linha "RESPOSTA: X", onde X e A, B, C ou D.\n\n${it.q}\n` + ord.map((a, i) => `${'ABCD'[i]}) ${a}`).join('\n'));
          const ms = [...r.matchAll(/RESPOSTA:\s*\**\s*([A-D])\b/gi)]; dada = ms.length ? ms[ms.length - 1][1].toUpperCase() : null;
        } catch (e) {}
        if (dada !== gab) { descartados++; continue; }
        vistos.add(k); gerado.push([nome, String(it.q), alts[0], alts[1], alts[2], alts[3]]); tem++; novos++;
        fs.writeFileSync(ARQ, JSON.stringify(gerado, null, 1));
      }
    }
    console.log(nome, tem, 'no banco');
  }
  console.log(`novas: ${novos}, descartadas na checagem: ${descartados}, total gerado: ${gerado.length}`);
  process.exit(0);
})().catch(e => { console.error('erro geral:', e.message); process.exit(1); });
