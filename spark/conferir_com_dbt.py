"""Confere o resultado do Spark contra a tabela gold do dbt (DuckDB). Falha se houver qualquer diferenca.
Uso: python conferir_com_dbt.py <plataforma.duckdb> <saida_spark_parquet>
"""
import sys
import duckdb

COLS = "cast(dt as varchar) dt, tecnologia, cast(vagas as bigint) vagas, cast(vagas_com_tec as bigint) vagas_com_tec, cast(pct_vagas as decimal(6,1)) pct_vagas, cast(pct_media_7d as decimal(6,1)) pct_media_7d"


def main(db, spark_dir):
    con = duckdb.connect(db, read_only=True)
    con.execute(f"create temp view dbt as select {COLS} from gold_radar_demanda")
    con.execute(f"create temp view spk as select {COLS} from read_parquet('{spark_dir}/*.parquet')")
    n_dbt, n_spk = (con.execute(f"select count(*) from {t}").fetchone()[0] for t in ("dbt", "spk"))
    d1 = con.execute("select count(*) from (select * from dbt except select * from spk)").fetchone()[0]
    d2 = con.execute("select count(*) from (select * from spk except select * from dbt)").fetchone()[0]
    print(f"dbt: {n_dbt} linhas | spark: {n_spk} linhas | so no dbt: {d1} | so no spark: {d2}")
    if n_dbt == 0 or d1 or d2 or n_dbt != n_spk:
        print("REPROVADO: resultados diferentes"); sys.exit(1)
    print("APROVADO: diferenca = 0 linhas")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
