"""Valida os arquivos da camada landing contra os contratos de dados.

Uso: python validar_contrato.py <landing_root> <contratos_dir> [--maximo-horas N]

Sai com codigo 1 e uma mensagem clara se uma coluna faltar, tiver tipo errado,
tiver nulo onde e obrigatoria, ou se a particao mais recente estiver velha.
"""
import sys
import datetime as dt
from pathlib import Path

import pyarrow as pa
import pyarrow.dataset as ds
import yaml

TIPOS = {
    "string": lambda t: pa.types.is_string(t) or pa.types.is_large_string(t),
    "int64": pa.types.is_int64,
    "date": pa.types.is_date32,
    "timestamp": pa.types.is_timestamp,
    "double": pa.types.is_floating,
}


def validar(landing: Path, contrato: dict, hoje: dt.date) -> list[str]:
    erros = []
    pasta = landing / contrato["nome"]
    if not pasta.exists() or not any(pasta.rglob("*.parquet")):
        return [f"{contrato['nome']}: nenhum arquivo parquet em {pasta}"]
    # dt tambem esta dentro do arquivo; a pasta dt=... e usada so para o frescor.
    dataset = ds.dataset(pasta, format="parquet")
    esquema = {f.name: f.type for f in dataset.schema}
    tabela = dataset.to_table()
    for col in contrato["colunas"]:
        nome = col["nome"]
        if nome not in esquema:
            erros.append(f"{contrato['nome']}.{nome}: coluna ausente")
            continue
        tipo = esquema[nome]
        # Particao hive de data pode vir como string; aceita se converter.
        if nome == contrato.get("particao") and pa.types.is_string(tipo):
            continue
        if not TIPOS[col["tipo"]](tipo):
            erros.append(f"{contrato['nome']}.{nome}: tipo {tipo}, esperado {col['tipo']}")
        if col.get("obrigatorio") and tabela[nome].null_count > 0:
            erros.append(f"{contrato['nome']}.{nome}: {tabela[nome].null_count} nulos em coluna obrigatoria")
    particoes = sorted(p.name.split("=", 1)[1] for p in pasta.glob("dt=*"))
    if particoes:
        ultima = dt.date.fromisoformat(particoes[-1])
        horas = (hoje - ultima).days * 24
        limite = contrato.get("frescor_maximo_horas")
        if limite and horas > limite:
            erros.append(f"{contrato['nome']}: particao mais recente e {ultima}, {horas}h atras (limite {limite}h)")
    return erros


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    landing, contratos = Path(sys.argv[1]), Path(sys.argv[2])
    hoje = dt.date.today()
    if "--hoje" in sys.argv:
        hoje = dt.date.fromisoformat(sys.argv[sys.argv.index("--hoje") + 1])
    erros = []
    arquivos = sorted(contratos.glob("*.yml"))
    for f in arquivos:
        erros += validar(landing, yaml.safe_load(f.read_text()), hoje)
    if erros:
        print("CONTRATO VIOLADO:")
        for e in erros:
            print(" -", e)
        return 1
    print(f"contratos ok: {len(arquivos)} validados")
    return 0


if __name__ == "__main__":
    sys.exit(main())
