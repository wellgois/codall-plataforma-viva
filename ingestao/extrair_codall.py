"""Extrator do host: le o SQLite do Codall em SOMENTE LEITURA e grava parquet em landing/.

Seguranca por construcao:
  - abre o banco com mode=ro; nunca monta nem le o cofre de segredos;
  - de pontes_vagas leva apenas titulo, fonte (tipo), nome e tipo do requisito.
    NAO leva status da candidatura, status/evidencia do requisito (lacunas), salario,
    texto da vaga, empresa, URL nem notas;
  - de governance_log, execution_feedback e inspections leva so contagens por dia.
    Nunca e-mail, IP, detalhes, descricao de tarefa ou saida de comando.

Uso: python extrair_codall.py --db /ai/codall/data/codall.db --landing LANDING
         [--salt-file ARQ] [--dias 30] [--ate AAAA-MM-DD]
Cada dia dt e regravado por inteiro (idempotente). Para pontes_requisitos, a particao de
um dia mostra o estado do radar naquele dia: vagas com created_at ate o fim do dia.
"""
import argparse
import datetime as dt
import hashlib
import json
import os
import secrets
import sqlite3
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq

SCH_REQ = pa.schema([("dt", pa.date32()), ("vaga_hash", pa.string()), ("fonte_tipo", pa.string()),
                     ("titulo_vaga", pa.string()), ("requisito_nome", pa.string()),
                     ("requisito_tipo", pa.string())])
SCH_EV = pa.schema([("dt", pa.date32()), ("origem", pa.string()), ("projeto", pa.string()),
                    ("categoria", pa.string()), ("qtd", pa.int64())])


def salt(path: Path) -> str:
    if not path.exists():
        path.write_text(secrets.token_hex(16))
        os.chmod(path, 0o600)
    return path.read_text().strip()


def gravar(landing: Path, nome: str, dia: dt.date, schema, linhas):
    pasta = landing / nome / f"dt={dia}"
    pasta.mkdir(parents=True, exist_ok=True)
    cols = schema.names
    tabela = pa.table({c: [l[i] for l in linhas] for i, c in enumerate(cols)}, schema=schema)
    tmp = pasta / ".part-0.tmp"
    pq.write_table(tabela, tmp)
    os.replace(tmp, pasta / "part-0.parquet")


def fonte_tipo(f: str) -> str:
    f = (f or "").lower()
    for k in ("gupy", "remotive"):
        if k in f:
            return k
    return "manual"


def requisitos_dia(con, h, dia: dt.date):
    fim_ms = int(dt.datetime.combine(dia + dt.timedelta(days=1), dt.time.min,
                                     tzinfo=dt.timezone.utc).timestamp() * 1000)
    linhas = []
    cur = con.execute("select id, titulo, fonte, requisitos from pontes_vagas "
                      "where created_at < ? and requisitos is not null and requisitos != '[]'", (fim_ms,))
    for vid, titulo, fonte, req in cur:
        try:
            itens = json.loads(req)
        except ValueError:
            continue
        vh = hashlib.sha256(f"{h}:{vid}".encode()).hexdigest()[:12]
        for it in itens:
            nome = (it.get("nome") or "").strip()
            if nome:
                linhas.append((dia, vh, fonte_tipo(fonte), (titulo or "").strip()[:120], nome[:160],
                               (it.get("tipo") or "").strip()[:30] or None))
    return linhas


def eventos_dia(con, dia: dt.date):
    d = str(dia)
    ev = []
    for acao, n in con.execute("select action, count(*) from governance_log where date(created_at)=? group by 1", (d,)):
        ev.append((dia, "governanca", "codall", acao, n))
    for proj, st, n in con.execute("select coalesce(project_key,'codall'), coalesce(result_status,'?'), count(*) "
                                   "from execution_feedback where date(created_at)=? group by 1,2", (d,)):
        ev.append((dia, "tarefa", proj, st, n))
    for dire, st, n in con.execute("select directory, status, count(*) from inspections "
                                   "where date(created_at)=? group by 1,2", (d,)):
        ev.append((dia, "inspecao", os.path.basename(dire.rstrip("/")) or "raiz", st, n))
    return ev


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", required=True)
    ap.add_argument("--landing", required=True)
    ap.add_argument("--salt-file", default=None)
    ap.add_argument("--dias", type=int, default=1)
    ap.add_argument("--ate", default=str(dt.date.today()))
    a = ap.parse_args()
    landing = Path(a.landing)
    h = salt(Path(a.salt_file) if a.salt_file else landing.parent / ".salt")
    con = sqlite3.connect(f"file:{a.db}?mode=ro", uri=True)
    ate = dt.date.fromisoformat(a.ate)
    total = [0, 0]
    for i in range(a.dias):
        dia = ate - dt.timedelta(days=a.dias - 1 - i)
        r = requisitos_dia(con, h, dia)
        e = eventos_dia(con, dia)
        if r:
            gravar(landing, "pontes_requisitos", dia, SCH_REQ, r)
        if e:
            gravar(landing, "codall_eventos", dia, SCH_EV, e)
        total[0] += len(r)
        total[1] += len(e)
    print(f"extraido: {total[0]} requisitos, {total[1]} eventos, {a.dias} dia(s) ate {ate}")


if __name__ == "__main__":
    main()
