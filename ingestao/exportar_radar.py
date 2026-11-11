"""Exporta o Radar do Mercado de Dados BR (JSON publico) a partir da camada gold.

Uso: python exportar_radar.py <duckdb> [--k 5]   (JSON em stdout)

Privacidade por construcao:
  - so campos permitidos (lista fixa): tecnologia, percentuais, contagens agregadas;
  - nunca titulo de vaga, empresa, URL, hash de vaga ou texto livre;
  - k-anonimato: qualquer grupo com menos de K vagas e suprimido (tecnologia) ou
    agrupado em "outras" (senioridade).
"""
import argparse
import datetime as dt
import json

import duckdb


def exportar(caminho: str, k: int = 5) -> dict:
    con = duckdb.connect(caminho, read_only=True)
    ultimo = con.execute("select max(dt) from gold_radar_demanda").fetchone()[0]
    if ultimo is None:
        raise SystemExit("gold_radar_demanda vazia")
    vagas = con.execute("select max(vagas) from gold_radar_demanda where dt=?", [ultimo]).fetchone()[0]
    tecs = []
    for nome, n, pct, m7 in con.execute(
            "select tecnologia, vagas_com_tec, pct_vagas, pct_media_7d from gold_radar_demanda "
            "where dt=? and vagas_com_tec>=? order by pct_vagas desc, tecnologia", [ultimo, k]).fetchall():
        d = round(pct - m7, 1)
        tecs.append({"tecnologia": nome, "pct_vagas": float(pct), "pct_media_7d": float(m7),
                     "tendencia": "alta" if d >= 3 else "queda" if d <= -3 else "estavel"})
    sen, outras = [], 0
    for nome, n in con.execute(
            "select senioridade, count(distinct vaga_hash) from silver_requisitos where dt=? group by 1 order by 2 desc",
            [ultimo]).fetchall():
        if n >= k:
            sen.append({"senioridade": nome, "vagas": int(n)})
        else:
            outras += int(n)
    if outras >= k:
        sen.append({"senioridade": "outras", "vagas": outras})
    serie = [{"dt": str(d), "vagas": int(v)} for d, v in con.execute(
        "select dt, max(vagas) from gold_radar_demanda group by 1 order by 1 desc limit 30").fetchall()][::-1]
    return {
        "gerado_em": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "referencia": str(ultimo),
        "k_minimo": k,
        "vagas_analisadas": int(vagas),
        "amostra_pequena": int(vagas) < 30,
        "tecnologias": tecs,
        "senioridade": sen,
        "serie_vagas": serie,
        "metodologia": "Contagem por palavra-chave nos requisitos de vagas de Engenharia de Dados. "
                       "Aproximada. Grupos com menos de K vagas sao suprimidos.",
    }


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("duckdb")
    ap.add_argument("--k", type=int, default=5)
    a = ap.parse_args()
    print(json.dumps(exportar(a.duckdb, a.k), ensure_ascii=False, indent=1))
