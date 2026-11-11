"""Envia o Parquet do gold para um container Azure Blob/ADLS (prefixo gold/).

Uso: python publicar_azure.py <pasta_parquet> <container> [--conta NOME | --conexao STRING]
Em producao usa identidade (DefaultAzureCredential) com a conta informada; no teste usa a string
de conexao do Azurite pelo ambiente (AZURE_STORAGE_CONNECTION_STRING). Nunca credenciais no repositorio.
"""
import argparse
import os
from pathlib import Path

from azure.storage.blob import BlobServiceClient


def cliente(conta, conexao):
    conexao = conexao or os.environ.get("AZURE_STORAGE_CONNECTION_STRING")
    if conexao:
        return BlobServiceClient.from_connection_string(conexao)
    from azure.identity import DefaultAzureCredential
    return BlobServiceClient(f"https://{conta}.blob.core.windows.net", credential=DefaultAzureCredential())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pasta"); ap.add_argument("container")
    ap.add_argument("--conta"); ap.add_argument("--conexao")
    a = ap.parse_args()
    c = cliente(a.conta, a.conexao).get_container_client(a.container)
    n = 0
    for f in sorted(Path(a.pasta).rglob("*.parquet")):
        chave = "gold/" + f.relative_to(a.pasta).as_posix()
        with open(f, "rb") as fh:
            c.upload_blob(chave, fh, overwrite=True)
        n += 1
        print("enviado", chave)
    print(f"{n} arquivos")


if __name__ == "__main__":
    main()
