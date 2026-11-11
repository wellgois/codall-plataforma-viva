"""Ciclo criar -> publicar -> conferir -> destruir no Azurite (emulador de armazenamento Azure), duas vezes.
Cobre o caminho dos dados (container e blobs). Os recursos de gerenciamento (grupo, conta, papel, orcamento)
so tem emulador pago; ficam cobertos por terraform validate e pelo primeiro plan na conta real.
Uso: python teste-azurite.py <pasta_parquet>  (AZURE_STORAGE_CONNECTION_STRING no ambiente)
"""
import os
import subprocess
import sys
from pathlib import Path

from azure.storage.blob import BlobServiceClient

pasta = sys.argv[1]
esperado = {"gold/" + f.relative_to(pasta).as_posix(): f.stat().st_size for f in Path(pasta).rglob("*.parquet")}
svc = BlobServiceClient.from_connection_string(os.environ["AZURE_STORAGE_CONNECTION_STRING"])
falhas = 0
for ciclo in (1, 2):
    svc.create_container("lake")
    subprocess.run([sys.executable, str(Path(__file__).parents[2] / "nuvem/publicar_azure.py"), pasta, "lake"], check=True, capture_output=True)
    c = svc.get_container_client("lake")
    lido = {b.name: b.size for b in c.list_blobs()}
    ok = lido == esperado and len(esperado) > 0
    print(f"ciclo {ciclo}: {len(lido)} blobs, conferem com a origem: {ok}")
    falhas += 0 if ok else 1
    svc.delete_container("lake")
    sobrou = [x.name for x in svc.list_containers()]
    print(f"ciclo {ciclo}: destruido, containers restantes: {sobrou}")
    falhas += 1 if sobrou else 0
print("falhas:", falhas)
sys.exit(falhas)
