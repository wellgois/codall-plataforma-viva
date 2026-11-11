"""Envia o Parquet do gold para o bucket S3 (prefixo gold/). Usa so a politica 'somente-gold'.

Uso: python publicar_nuvem.py <pasta_parquet> <bucket> [--endpoint URL]
Credenciais pelo ambiente (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY); nunca no repositorio.
"""
import argparse
from pathlib import Path

import boto3


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pasta")
    ap.add_argument("bucket")
    ap.add_argument("--endpoint")
    a = ap.parse_args()
    s3 = boto3.client("s3", endpoint_url=a.endpoint)
    n = 0
    for f in sorted(Path(a.pasta).rglob("*.parquet")):
        chave = "gold/" + f.relative_to(a.pasta).as_posix()
        s3.upload_file(str(f), a.bucket, chave)
        n += 1
        print("enviado", chave)
    print(f"{n} arquivos")


if __name__ == "__main__":
    main()
