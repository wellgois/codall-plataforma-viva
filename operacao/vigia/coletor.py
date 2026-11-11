"""Coletor: junta erros novos dos logs (pm2 e docker) e grava um arquivo por incidente em /opt/erros/entrada."""
import hashlib, json, re, subprocess, sys, time
from pathlib import Path
import comum as c

ERRO = re.compile(r'"level"\s*:\s*"error"|\b(?:Error|TypeError|ReferenceError|RangeError|Exception|Traceback|FATAL|CRITICAL|ECONN[A-Z]+|ETIMEDOUT|EADDRINUSE|heap out of memory|UnhandledPromiseRejection)\b')
CONT = re.compile(r'^(\s+|at\s|File\s|Traceback|Caused by)')
MAX_LEITURA = 262144


def normalizar(s):
    s = re.sub(r'\b(?:cm[a-z0-9]{15,}|[0-9a-f]{8,}(?:-[0-9a-f]{4,})*)\b', '#', s)
    s = re.sub(r'\d+', '#', s)
    return re.sub(r'\s+', ' ', s).strip()


def assinatura(primeira):
    m = re.search(r'"message"\s*:\s*"((?:[^"\\]|\\.)*)"', primeira)
    base = m.group(1) if m else primeira
    return normalizar(base)[-70:]


def eventos(linhas):
    out, i = [], 0
    while i < len(linhas):
        if ERRO.search(linhas[i]):
            bloco = [linhas[i]]
            j = i + 1
            while j < len(linhas) and len(bloco) < 15 and CONT.match(linhas[j]):
                bloco.append(linhas[j]); j += 1
            out.append(bloco); i = j
        else:
            i += 1
    return out


def novas_linhas_pm2(estado, cfg):
    off = estado.setdefault("pm2_off", {})
    for p in sorted(Path(cfg["pm2_logs"]).glob("*-error.log")):
        app = p.name[:-len("-error.log")]
        if app in cfg.get("ignorar_pm2", []):
            continue
        tam = p.stat().st_size
        if str(p) not in off:
            off[str(p)] = tam      # primeira vez: comeca do fim, ignora o passado
            continue
        ini = off[str(p)] if tam >= off[str(p)] else 0
        if tam == ini:
            continue
        with open(p, "rb") as f:
            f.seek(ini)
            dados = f.read(MAX_LEITURA)
        corte = dados.rfind(b"\n")
        if corte < 0:
            continue
        off[str(p)] = ini + corte + 1
        yield app, dados[:corte].decode("utf-8", "replace").splitlines()


def novas_linhas_docker(estado, cfg):
    if c.os.environ.get("VIGIA_SEM_DOCKER"):
        return
    marcas = estado.setdefault("docker_desde", {})
    for nome in cfg["containers"]:
        desde = marcas.get(nome)
        marcas[nome] = c.agora()
        if not desde:
            continue
        try:
            r = subprocess.run(["docker", "logs", "--since", desde, nome], capture_output=True, text=True, timeout=25)
        except Exception:
            continue
        linhas = (r.stdout + r.stderr).splitlines()[-3000:]
        if linhas:
            yield nome, linhas


def main():
    c.garantir_pastas()
    cfg = c.fontes()
    lim = cfg["limites"]
    estado = c.ler_json(c.ESTADO, {})
    vistos = estado.setdefault("assinaturas", {})
    horas = estado.setdefault("criados", [])
    agora = time.time()
    horas[:] = [t for t in horas if agora - t < 3600]
    novos = suprimidos = 0
    fontes_iter = list(novas_linhas_pm2(estado, cfg)) + list(novas_linhas_docker(estado, cfg))
    for fonte, linhas in fontes_iter:
        for bloco in eventos(linhas):
            sig = hashlib.sha1((fonte + "|" + assinatura(bloco[0])).encode()).hexdigest()[:10]
            v = vistos.get(sig)
            if v and agora - v["ultima"] < lim["repetir_apos_horas"] * 3600:
                v["ultima"] = agora; v["n"] += 1
                continue
            if novos >= lim["novos_por_rodada"] or len(horas) >= lim["novos_por_hora"]:
                suprimidos += 1
                estado["suprimidos"] = estado.get("suprimidos", 0) + 1
                continue
            vistos[sig] = {"primeira": agora, "ultima": agora, "n": 1}
            horas.append(agora)
            novos += 1
            trecho = c.mascarar("\n".join(bloco))[:3500]
            inc = {"id": time.strftime("%Y%m%d-%H%M%S", time.gmtime()) + "-" + sig[:6], "fonte": fonte,
                   "criado": c.agora(), "assinatura": sig, "trecho": trecho,
                   "suprimidos_recentes": estado.get("suprimidos", 0)}
            c.gravar_json(c.ENTRADA / (inc["id"] + ".json"), inc)
    vistos_limpos = {k: v for k, v in vistos.items() if agora - v["ultima"] < 7 * 86400}
    estado["assinaturas"] = vistos_limpos
    c.gravar_json(c.ESTADO, estado)
    print(f"coletor: {novos} incidente(s) novo(s), {suprimidos} suprimido(s)")


if __name__ == "__main__":
    main()
