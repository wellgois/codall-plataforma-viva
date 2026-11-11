"""Aplica uma correcao proposta pelo vigia: backup, troca, deploy, verificacao e reversao automatica."""
import shutil, subprocess, sys, time
from pathlib import Path
import comum as c


def sh(cmd, t=900):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=t)
    return r.returncode, (r.stdout + r.stderr)[-600:]


def main(pid):
    p = c.ler_json(c.PROPOSTAS / (pid + ".json"), None)
    if not p:
        sys.exit("proposta nao encontrada: " + pid)
    cfg = c.fontes()
    fc = cfg["containers"].get(p["fonte"]) or cfg["pm2_apps"].get(p["fonte"]) or {}
    deploy = fc.get("deploy")
    if not deploy:
        sys.exit("fonte sem comando de deploy em fontes.json: " + p["fonte"])
    arq = Path(p["arquivo"])
    original = arq.read_text()
    if original.count(p["antes"]) != 1:
        sys.exit("o arquivo mudou desde a proposta; gere outra")
    bak = arq.with_name(arq.name + ".bak-vigia-" + pid)
    shutil.copy2(arq, bak)
    arq.write_text(original.replace(p["antes"], p["depois"]))
    rc, out = sh(deploy)
    time.sleep(20)
    _, run = sh("docker inspect -f '{{.State.Running}}' " + p["fonte"] if p["fonte"] in cfg["containers"] else "echo true", 20)
    if rc != 0 or run.strip() != "true":
        arq.write_text(original)
        sh(deploy)
        c.telegram(f"↩️ Correcao {pid} revertida: o deploy falhou ({out[-200:]}). Backup em {bak}.")
        sys.exit("revertido")
    c.telegram(f"✅ Correcao {pid} aplicada em {p['fonte']}: {p.get('explicacao','')}\nBackup: {bak}")
    print("aplicado; backup em", bak)


if __name__ == "__main__":
    main(sys.argv[1])
