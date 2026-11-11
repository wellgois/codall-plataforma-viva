"""Gera dados SINTETICOS na camada landing, com o mesmo formato dos contratos.

Serve apenas para CI e desenvolvimento. Os dados reais nunca passam por aqui.
Uso: python sintetico.py <landing_root> [--dias 30] [--ate AAAA-MM-DD] [--semente 7]
"""
import sys
import random
import hashlib
import datetime as dt
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq

# Pesos aproximados da demanda observada em vagas de dados no Brasil (nov/2026).
REQUISITOS = [
    ("SQL avancado", "tecnico", 26), ("Python para pipelines", "tecnico", 24),
    ("CI/CD, Git e Docker", "tecnico", 22), ("Apache Spark / PySpark", "tecnico", 21),
    ("Governanca, catalogo e LGPD", "pratica", 21), ("Qualidade e observabilidade de dados", "pratica", 19),
    ("Lakehouse com Delta Lake", "tecnico", 15), ("Databricks", "tecnico", 14),
    ("Apache Airflow", "tecnico", 13), ("AWS (S3, Glue, Redshift)", "tecnico", 13),
    ("Kafka e streaming", "tecnico", 10), ("dbt", "tecnico", 9),
    ("Ingles intermediario", "idioma", 7), ("Power BI e DAX", "tecnico", 9),
]
TITULOS = ["Engenheiro de Dados Pleno", "Engenheiro de Dados Senior", "Engenheiro de Dados Junior",
           "Data Engineer", "Analytics Engineer", "Engenheiro de Dados SR"]
FONTES = ["gupy", "remotive", "manual"]
PROJETOS = ["codall", "euprofessor", "wellgois", "jogandologica", "meuingles"]
ORIGENS = [("tarefa", ["com_achado", "sem_achado"]), ("restart", ["aprovado", "recusado"]),
           ("inspecao", ["ok", "com_problema"]), ("chat", ["deepseek", "anthropic"]),
           ("governanca", ["consulta", "alteracao"]), ("pontes", ["vaga_nova", "vaga_analisada"])]


def hash_vaga(dia: dt.date, n: int, sal: str = "sintetico") -> str:
    return hashlib.sha256(f"{sal}:{dia}:{n}".encode()).hexdigest()[:12]


def gerar_dia(rng: random.Random, dia: dt.date):
    reqs, evs = [], []
    for n in range(rng.randint(4, 10)):
        vaga = hash_vaga(dia, n)
        titulo = rng.choice(TITULOS)
        fonte = rng.choice(FONTES)
        escolhidos = {r for r in REQUISITOS if rng.random() < r[2] / 26 * 0.8}
        for nome, tipo, _ in escolhidos or {REQUISITOS[0]}:
            reqs.append((dia, vaga, fonte, titulo, nome, tipo))
    for origem, categorias in ORIGENS:
        for projeto in PROJETOS:
            for cat in categorias:
                if rng.random() < 0.55:
                    evs.append((dia, origem, projeto, cat, rng.randint(1, 12)))
    return reqs, evs


def gravar(landing: Path, nome: str, dia: dt.date, colunas: dict, linhas: list):
    pasta = landing / nome / f"dt={dia}"
    pasta.mkdir(parents=True, exist_ok=True)
    cols = list(colunas)
    dados = {c: [l[i] for l in linhas] for i, c in enumerate(cols)}
    tabela = pa.table(dados, schema=pa.schema([(c, colunas[c]) for c in cols]))
    pq.write_table(tabela, pasta / "part-0.parquet")


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    landing = Path(sys.argv[1])
    arg = lambda k, d: sys.argv[sys.argv.index(k) + 1] if k in sys.argv else d
    dias = int(arg("--dias", 30))
    ate = dt.date.fromisoformat(arg("--ate", str(dt.date.today())))
    rng = random.Random(int(arg("--semente", 7)))
    for i in range(dias):
        dia = ate - dt.timedelta(days=dias - 1 - i)
        reqs, evs = gerar_dia(rng, dia)
        gravar(landing, "pontes_requisitos", dia,
               {"dt": pa.date32(), "vaga_hash": pa.string(), "fonte_tipo": pa.string(),
                "titulo_vaga": pa.string(), "requisito_nome": pa.string(), "requisito_tipo": pa.string()}, reqs)
        gravar(landing, "codall_eventos", dia,
               {"dt": pa.date32(), "origem": pa.string(), "projeto": pa.string(),
                "categoria": pa.string(), "qtd": pa.int64()}, evs)
    print(f"sintetico: {dias} dias ate {ate} em {landing}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
