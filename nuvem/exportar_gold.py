"""Exporta as tabelas gold (agregadas) em Parquet e CSV para uso em nuvem e Power BI.

Uso (dentro do container do Airflow):
    python exportar_gold.py <duckdb> <pasta_saida> [--k 5]
Saida: <pasta>/parquet/<tabela>/<tabela>.parquet e <pasta>/csv/<tabela>.csv

Privacidade: so tabelas gold agregadas; linhas do radar com menos de K vagas sao
removidas (mesmo k-anonimato do radar publico).
"""
import argparse
from pathlib import Path

import duckdb

CONSULTAS = {
    "gold_radar_demanda": (
        "select cast(dt as date) dt, tecnologia, cast(vagas as bigint) vagas, "
        "cast(vagas_com_tec as bigint) vagas_com_tec, cast(pct_vagas as double) pct_vagas, "
        "cast(pct_media_7d as double) pct_media_7d from gold_radar_demanda "
        "where vagas_com_tec >= {k} order by dt, tecnologia"),
    "gold_operacao_diaria": (
        "select cast(dt as date) dt, projeto, origem, cast(eventos as bigint) eventos "
        "from gold_operacao_diaria order by dt, projeto, origem"),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("duckdb")
    ap.add_argument("saida")
    ap.add_argument("--k", type=int, default=5)
    a = ap.parse_args()
    con = duckdb.connect(a.duckdb, read_only=True)
    base = Path(a.saida)
    for nome, sql in CONSULTAS.items():
        (base / "parquet" / nome).mkdir(parents=True, exist_ok=True)
        (base / "csv").mkdir(parents=True, exist_ok=True)
        q = sql.format(k=a.k)
        con.execute(f"copy ({q}) to '{base}/parquet/{nome}/{nome}.parquet' (format parquet)")
        con.execute(f"copy ({q}) to '{base}/csv/{nome}.csv' (header, delimiter ',')")
        n = con.execute(f"select count(*) from ({q})").fetchone()[0]
        print(f"{nome}: {n} linhas")


if __name__ == "__main__":
    main()
