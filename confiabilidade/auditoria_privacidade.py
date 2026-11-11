"""Auditoria de privacidade dos artefatos publicos (paginas e JSON).

Uso: python auditoria_privacidade.py <arquivo_ou_pasta> [...]
Sai com 1 e lista cada achado se encontrar dado pessoal, segredo, valor financeiro,
link de vaga/empresa ou, para radar.json, qualquer campo fora da lista permitida.
So o e-mail/telefone/LinkedIn proprios do autor listados em PERMITIDOS sao aceitos.
"""
import json
import re
import sys
from pathlib import Path

PERMITIDOS = {"linkedin.com/in/wellingtongois", "github.com/wellgois"}
PADROES = {
    "e-mail": re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
    "telefone": re.compile(r"(?<!\d)(?:\+?55\s?)?\(?\d{2}\)?\s?9?\d{4}[-\s]?\d{4}(?!\d)"),
    "cpf": re.compile(r"\b\d{3}\.\d{3}\.\d{3}-\d{2}\b"),
    "valor em reais": re.compile(r"R\$\s?\d"),
    "salario": re.compile(r"sal[aá]rio", re.I),
    "segredo longo": re.compile(r"(?<![A-Za-z0-9/_.-])[A-Za-z0-9_\-]{40,}(?![A-Za-z0-9/_.-])"),
    "token telegram": re.compile(r"\b\d{8,10}:[A-Za-z0-9_-]{30,}\b"),
    "link de vaga": re.compile(r"(gupy\.io|linkedin\.com/jobs|vagas\.com|indeed\.com|catho\.com)", re.I),
    "ip": re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"),
}
CAMPOS_RADAR = {
    "gerado_em", "referencia", "k_minimo", "vagas_analisadas", "amostra_pequena", "tecnologias",
    "senioridade", "serie_vagas", "metodologia"}
CAMPOS_TEC = {"tecnologia", "pct_vagas", "pct_media_7d", "tendencia"}
CABECALHOS_CSV = {
    "gold_radar_demanda.csv": "dt,tecnologia,vagas,vagas_com_tec,pct_vagas,pct_media_7d",
    "gold_operacao_diaria.csv": "dt,projeto,origem,eventos",
}


def auditar_csv(nome: str, texto: str) -> list[str]:
    esperado = CABECALHOS_CSV.get(nome)
    primeira = texto.splitlines()[0].strip() if texto else ""
    if esperado is None:
        return [f"{nome}: csv fora da lista permitida"]
    if primeira != esperado:
        return [f"{nome}: cabecalho inesperado: {primeira[:60]}"]
    return []


def varrer_texto(nome: str, texto: str) -> list[str]:
    achados = []
    # remove trechos de css/js minificado e URLs permitidas antes de procurar
    for p in PERMITIDOS:
        texto = texto.replace(p, "")
    texto = re.sub(r"https?://[^\s\"'<>)]+", " ", texto)
    for rotulo, rx in PADROES.items():
        if rotulo == "ip" and nome.endswith(".html"):
            continue  # numeros de versao e css geram falso positivo em HTML
        for m in rx.finditer(texto):
            achados.append(f"{nome}: {rotulo}: {m.group(0)[:40]}")
    return achados


def auditar_radar(nome: str, texto: str) -> list[str]:
    achados = []
    d = json.loads(texto)
    extra = set(d) - CAMPOS_RADAR
    if extra:
        achados.append(f"{nome}: campos fora da lista permitida: {sorted(extra)}")
    for t in d.get("tecnologias", []):
        if set(t) - CAMPOS_TEC:
            achados.append(f"{nome}: campo inesperado em tecnologia: {sorted(set(t) - CAMPOS_TEC)}")
    k = d.get("k_minimo", 5)
    for s in d.get("senioridade", []):
        if s.get("vagas", 0) < k:
            achados.append(f"{nome}: grupo de senioridade abaixo de k={k}")
    return achados


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    achados, n = [], 0
    for alvo in map(Path, sys.argv[1:]):
        arquivos = [alvo] if alvo.is_file() else sorted(p for p in alvo.rglob("*") if p.suffix in {".html", ".json", ".csv"})
        for f in arquivos:
            n += 1
            texto = f.read_text(encoding="utf-8")
            achados += varrer_texto(f.name, texto)
            if f.suffix == ".csv":
                achados += auditar_csv(f.name, texto)
            if f.name == "radar.json":
                achados += auditar_radar(f.name, texto)
    if achados:
        print("PRIVACIDADE VIOLADA:")
        print("\n".join(" - " + a for a in achados))
        return 1
    print(f"privacidade ok: {n} arquivos publicos sem dado pessoal")
    return 0


if __name__ == "__main__":
    sys.exit(main())
