"""Carrega o Parquet do gold no BigQuery (uma tabela por pasta) e confere contagem e consulta.

Uso: python publicar_gcp.py <pasta_parquet> --projeto ID [--dataset plataforma_viva]
Credencial por GOOGLE_APPLICATION_CREDENTIALS (conta de servico). Nunca credenciais no repositorio.
Funciona no modo sandbox: usa so jobs de carga (gratuitos), sem streaming e sem cobranca.
"""
import argparse
from pathlib import Path

import pyarrow.parquet as pq
from google.cloud import bigquery


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pasta")
    ap.add_argument("--projeto", required=True)
    ap.add_argument("--dataset", default="plataforma_viva")
    a = ap.parse_args()
    cli = bigquery.Client(project=a.projeto)
    cfg = bigquery.LoadJobConfig(source_format=bigquery.SourceFormat.PARQUET,
                                 write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE)
    falhas = 0
    for f in sorted(Path(a.pasta).rglob("*.parquet")):
        tabela = f.parent.name
        destino = f"{a.projeto}.{a.dataset}.{tabela}"
        with open(f, "rb") as fh:
            cli.load_table_from_file(fh, destino, job_config=cfg).result()
        esperado = pq.ParquetFile(f).metadata.num_rows
        lido = next(iter(cli.query(f"select count(*) n from `{destino}`").result())).n
        ok = esperado == lido and esperado > 0
        falhas += 0 if ok else 1
        print(f"{tabela}: origem {esperado} linhas, BigQuery {lido}, confere: {ok}")
    print("falhas:", falhas)
    raise SystemExit(falhas)


if __name__ == "__main__":
    main()
