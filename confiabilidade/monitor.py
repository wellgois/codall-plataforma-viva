"""Monitor de confiabilidade da Plataforma Viva. Roda no host a cada 5 minutos.

Checagens: contratos de dados, frescor do landing, ultima execucao da DAG e queda
anomala de volume. Escreve um status.json PUBLICO (sem segredos, sem dados de pessoas)
e um log de incidentes. Em mudanca de estado para falha/recuperacao, envia alerta se
existir um arquivo de alerta (Telegram) fora do repositorio.

Uso: python monitor.py --landing L --contratos C --saida DIR [--estado ARQ]
         [--alerta ARQ] [--compose-dir infra] [--sem-dag]
"""
import argparse
import datetime as dt
import json
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "ingestao"))
import pyarrow.dataset as ds  # noqa: E402
import yaml  # noqa: E402
from validar_contrato import validar  # noqa: E402

LIMITE_DAG_HORAS = 36


def agora():
    return dt.datetime.now(dt.timezone.utc)


def check_contratos(landing: Path, contratos: Path):
    erros = []
    for f in sorted(contratos.glob("*.yml")):
        try:
            erros += validar(landing, yaml.safe_load(f.read_text()), dt.date.today())
        except Exception as e:  # arquivo corrompido tambem e violacao
            erros.append(f"{f.stem}: parquet ilegivel ({type(e).__name__})")
    if erros:
        return {"nome": "contratos_de_dados", "estado": "falha", "detalhe": "; ".join(erros)[:300]}
    return {"nome": "contratos_de_dados", "estado": "ok", "detalhe": "2 contratos validados"}


def check_frescor(landing: Path):
    ult = []
    for p in landing.glob("*/dt=*"):
        ult.append(dt.date.fromisoformat(p.name.split("=", 1)[1]))
    if not ult:
        return {"nome": "frescor_do_landing", "estado": "falha", "detalhe": "landing vazio"}
    dias = (dt.date.today() - max(ult)).days
    estado = "ok" if dias <= 1 else "falha"
    return {"nome": "frescor_do_landing", "estado": estado,
            "detalhe": f"particao mais recente: {max(ult)} ({dias} dia(s) atras)"}


def check_dag(compose_dir: str):
    sql = ("select state, coalesce(extract(epoch from (now() - end_date))/3600, 0) "
           "from dag_run where dag_id='plataforma_viva_diaria' order by id desc limit 1")
    try:
        out = subprocess.run(["docker", "compose", "exec", "-T", "postgres", "psql", "-U", "airflow", "-At", "-F", "|", "-c", sql],
                             cwd=compose_dir, capture_output=True, text=True, timeout=40)
        estado, horas = out.stdout.strip().split("|")
        horas = float(horas)
    except Exception:
        return {"nome": "ultima_execucao_da_dag", "estado": "falha", "detalhe": "nao foi possivel consultar o Airflow"}
    if estado == "failed":
        return {"nome": "ultima_execucao_da_dag", "estado": "falha", "detalhe": "ultima execucao falhou"}
    if estado in ("running", "queued"):
        return {"nome": "ultima_execucao_da_dag", "estado": "ok", "detalhe": f"em andamento ({estado})"}
    if horas > LIMITE_DAG_HORAS:
        return {"nome": "ultima_execucao_da_dag", "estado": "falha", "detalhe": f"ultima execucao ha {horas:.0f}h (limite {LIMITE_DAG_HORAS}h)"}
    return {"nome": "ultima_execucao_da_dag", "estado": "ok", "detalhe": f"sucesso ha {horas:.1f}h"}


def check_volume(landing: Path):
    cont = []
    for p in sorted((landing / "pontes_requisitos").glob("dt=*")):
        try:
            cont.append((p.name, ds.dataset(p, format="parquet").count_rows()))
        except Exception:
            return {"nome": "volume_de_requisitos", "estado": "falha", "detalhe": f"particao ilegivel: {p.name}"}
    if len(cont) < 3:
        return {"nome": "volume_de_requisitos", "estado": "ok", "detalhe": "historico curto demais para comparar"}
    ultimo = cont[-1][1]
    ref = sorted(c for _, c in cont[:-1])[len(cont[:-1]) // 2]
    if ref and ultimo < 0.5 * ref:
        return {"nome": "volume_de_requisitos", "estado": "falha", "detalhe": f"{ultimo} linhas hoje contra mediana {ref}"}
    return {"nome": "volume_de_requisitos", "estado": "ok", "detalhe": f"{ultimo} linhas na particao mais recente"}


def enviar_alerta(arq: Path, texto: str):
    if not arq or not arq.exists():
        return False
    cfg = dict(l.strip().split("=", 1) for l in arq.read_text().splitlines() if "=" in l)
    try:
        url = f"https://api.telegram.org/bot{cfg['TELEGRAM_TOKEN']}/sendMessage"
        dados = urllib.parse.urlencode({"chat_id": cfg["TELEGRAM_CHAT_ID"], "text": texto}).encode()
        urllib.request.urlopen(urllib.request.Request(url, dados), timeout=15)
        return True
    except Exception:
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--landing", required=True)
    ap.add_argument("--contratos", required=True)
    ap.add_argument("--saida", required=True)
    ap.add_argument("--estado", default=None)
    ap.add_argument("--alerta", default=None)
    ap.add_argument("--compose-dir", default="infra")
    ap.add_argument("--sem-dag", action="store_true")
    a = ap.parse_args()
    landing, saida = Path(a.landing), Path(a.saida)
    saida.mkdir(parents=True, exist_ok=True)
    estado_arq = Path(a.estado) if a.estado else saida / ".estado.json"
    antes = json.loads(estado_arq.read_text()) if estado_arq.exists() else {"status": "ok", "incidentes": []}

    checks = [check_contratos(landing, Path(a.contratos)), check_frescor(landing), check_volume(landing)]
    if not a.sem_dag:
        checks.append(check_dag(a.compose_dir))
    status = "ok" if all(c["estado"] == "ok" for c in checks) else "falha"
    t = agora().strftime("%Y-%m-%dT%H:%M:%SZ")
    incs = antes.get("incidentes", [])
    alertou = False
    if status == "falha" and antes["status"] == "ok":
        causas = [f"{c['nome']}: {c['detalhe']}" for c in checks if c["estado"] != "ok"]
        incs.append({"inicio": t, "fim": None, "causas": causas})
        alertou = enviar_alerta(Path(a.alerta) if a.alerta else None, "Plataforma Viva: FALHA detectada\n" + "\n".join(causas))
        incs[-1]["alerta_enviado"] = alertou
    elif status == "ok" and antes["status"] == "falha" and incs and incs[-1]["fim"] is None:
        incs[-1]["fim"] = t
        enviar_alerta(Path(a.alerta) if a.alerta else None, "Plataforma Viva: recuperada")
    incs = incs[-20:]
    pub = {"gerado_em": t, "status": status, "checks": checks, "incidentes": incs}
    (saida / "status.json").write_text(json.dumps(pub, ensure_ascii=False, indent=1))
    estado_arq.write_text(json.dumps({"status": status, "incidentes": incs}))
    print(t, status, "alerta" if alertou else "")
    return 0


if __name__ == "__main__":
    sys.exit(main())
