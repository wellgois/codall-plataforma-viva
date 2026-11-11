"""Vigia: observa /opt/erros/entrada, diagnostica cada incidente, executa so correcoes seguras,
prepara proposta de codigo (aplicada apenas com aprovacao) e envia relatorio pelo Telegram."""
import json, os, re, subprocess, sys, time, urllib.request
from pathlib import Path
import comum as c

ESPERA = 15


def chave_llm():
    if os.environ.get("DEEPSEEK_API_KEY"):
        return os.environ["DEEPSEEK_API_KEY"]
    try:
        for l in Path("/ai/codall/.env").read_text().splitlines():
            if l.startswith("DEEPSEEK_API_KEY="):
                return l.split("=", 1)[1].strip().strip('"\'')
    except Exception:
        pass
    for cmd in ("cd /ai/codall && node -e 'process.stdout.write(require(\"./src/services/secretRef\").resolve(\"DEEPSEEK_API_KEY\")||\"\")'",
                "docker exec ap_backend printenv DEEPSEEK_API_KEY"):
        try:
            _, o = sh(cmd, 20)
            if re.fullmatch(r"sk-[A-Za-z0-9_\-]{20,}", o.strip()):
                return o.strip()
        except Exception:
            pass
    return ""


def llm(sistema, usuario):
    """Retorna dict JSON ou None (sem chave ou falha)."""
    stub = os.environ.get("VIGIA_LLM_STUB")
    if stub:
        fila = c.ler_json(stub, [])
        if not fila:
            return None
        r = fila.pop(0); c.gravar_json(stub, fila); return r
    k = chave_llm()
    if not k:
        return None
    corpo = json.dumps({"model": "deepseek-chat", "temperature": 0.1, "max_tokens": 1500,
                        "response_format": {"type": "json_object"},
                        "messages": [{"role": "system", "content": sistema}, {"role": "user", "content": usuario}]}).encode()
    req = urllib.request.Request("https://api.deepseek.com/chat/completions", data=corpo,
                                 headers={"Authorization": "Bearer " + k, "Content-Type": "application/json"})
    try:
        r = json.loads(urllib.request.urlopen(req, timeout=60).read())
        return json.loads(r["choices"][0]["message"]["content"])
    except Exception:
        return None


SIS1 = ("Voce e um SRE. Recebe um trecho de log de erro (ja com dados pessoais mascarados) de um app em producao. "
        "Responda APENAS JSON com as chaves: resumo (1 frase simples para quem nao e tecnico), causa_provavel (1-2 frases), "
        "gravidade (baixa|media|alta), tipo (codigo|infra|externo|config|ruido), "
        "termo_busca (texto literal curto, ate 60 caracteres, que aparece no codigo-fonte e localiza o defeito; vazio se nao for codigo), "
        "acao_segura (reiniciar|nenhuma). Use reiniciar somente se o app provavelmente travou ou ficou sem memoria; "
        "nunca para erro de logica do codigo.")
SIS2 = ("Voce corrige bugs com a menor mudanca possivel. Recebe o erro e trechos do codigo-fonte. Responda APENAS JSON com: "
        "arquivo (caminho exato mostrado), antes (texto EXATO e contiguo que existe no arquivo, copiado sem alterar), "
        "depois (substituto), explicacao (1-2 frases). A correcao deve ser defensiva e nao mudar o comportamento para entradas validas. "
        "Se nao tiver certeza, devolva {\"arquivo\":\"\"}.")


def sh(cmd, t=120):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=t)
    return r.returncode, (r.stdout + r.stderr).strip()


def fonte_cfg(cfg, nome):
    return cfg["containers"].get(nome) or cfg["pm2_apps"].get(nome) or {}


def rodando(nome, cfg):
    if nome in cfg["containers"]:
        _, o = sh(f"docker inspect -f '{{{{.State.Running}}}}' {nome}")
        return o.strip() == "true"
    _, o = sh(f"pm2 jlist")
    try:
        return any(p["name"] == nome and p["pm2_env"]["status"] == "online" for p in json.loads(o))
    except Exception:
        return True


def buscar_codigo(raiz, termo):
    if not termo or len(termo) < 4:
        return ""
    rc, o = sh(f"grep -rnF --include=*.ts --include=*.js --include=*.py --exclude-dir=node_modules --exclude-dir=dist -m2 -- {json.dumps(termo)} {raiz} | head -3")
    partes = []
    for linha in o.splitlines():
        m = re.match(r"(.+?):(\d+):", linha)
        if not m:
            continue
        arq, n = m.group(1), int(m.group(2))
        try:
            txt = Path(arq).read_text().splitlines()
        except Exception:
            continue
        a, b = max(0, n - 13), min(len(txt), n + 8)
        partes.append(f"### {arq} (linhas {a+1}-{b})\n" + "\n".join(txt[a:b]))
    return "\n\n".join(partes)[:6000]


def propor_correcao(inc, termo, raiz):
    contexto = buscar_codigo(raiz, termo)
    if not contexto:
        return None
    r = llm(SIS2, f"ERRO:\n{inc['trecho'][:1500]}\n\nCODIGO:\n{contexto}")
    if not r or not r.get("arquivo") or not r.get("antes"):
        return None
    arq = Path(r["arquivo"])
    try:
        atual = arq.read_text()
    except Exception:
        return None
    if atual.count(r["antes"]) != 1 or r.get("depois") == r["antes"]:
        return None
    r["id"], r["fonte"] = inc["id"], inc["fonte"]
    c.gravar_json(c.PROPOSTAS / (inc["id"] + ".json"), r)
    return r


def reiniciar_permitido(estado, fonte, cfg):
    h = estado.setdefault("reinicios", {})
    h[fonte] = [t for t in h.get(fonte, []) if time.time() - t < 3600]
    return len(h[fonte]) < cfg["limites"]["reinicios_por_hora"]


def tratar(inc, cfg, estado):
    fonte = inc["fonte"]
    fc = fonte_cfg(cfg, fonte)
    nome = fc.get("nome", fonte)
    r = llm(SIS1, f"APP: {nome}\nLOG:\n{inc['trecho'][:2500]}")
    ia = r is not None
    r = r or {"resumo": "Erro registrado nos logs (sem diagnostico de IA disponivel).",
              "causa_provavel": "Nao determinada automaticamente.", "gravidade": "media",
              "tipo": "desconhecido", "termo_busca": "", "acao_segura": "nenhuma"}
    acao, proposta = "Nenhuma acao automatica.", None
    parado = not rodando(fonte, cfg)
    if fc.get("reiniciar") and (parado or r.get("acao_segura") == "reiniciar") and r.get("tipo") != "codigo":
        if reiniciar_permitido(estado, fonte, cfg):
            sh(fc["reiniciar"], 90)
            estado["reinicios"][fonte].append(time.time())
            time.sleep(15)
            ok = rodando(fonte, cfg)
            acao = "Reiniciado automaticamente; " + ("voltou a funcionar." if ok else "NAO voltou, precisa de atencao humana.")
        else:
            acao = "Reinicio ja feito 2x na ultima hora; nao repeti. Precisa de atencao humana."
    elif r.get("tipo") == "codigo" and fc.get("codigo"):
        proposta = propor_correcao(inc, r.get("termo_busca", ""), fc["codigo"])
        if proposta:
            acao = ("Correcao de codigo PREPARADA (nao aplicada: app em producao). "
                    "Para aplicar com backup e reversao automatica:\n  python3 /opt/plataforma-viva/operacao/vigia/aplicar.py " + inc["id"])
        else:
            acao = "Defeito de codigo, mas nao consegui montar correcao segura. Precisa de revisao."
    return nome, r, acao, proposta, ia


def relatorio(inc, nome, r, acao, proposta, ia):
    sup = inc.get("suprimidos_recentes", 0)
    md = [f"# Incidente {inc['id']}", f"- App: {nome} ({inc['fonte']})", f"- Detectado: {inc['criado']}",
          f"- Gravidade: {r.get('gravidade')} | Tipo: {r.get('tipo')} | Diagnostico por IA: {'sim' if ia else 'nao'}",
          "", "## O que aconteceu", r.get("resumo", ""), "", "## Causa provavel", r.get("causa_provavel", ""),
          "", "## Acao", acao]
    if proposta:
        md += ["", "## Correcao proposta", proposta.get("explicacao", ""), f"Arquivo: {proposta['arquivo']}",
               "```", "- " + proposta["antes"].strip()[:700], "+ " + proposta["depois"].strip()[:700], "```"]
    md += ["", "## Trecho do log (dados pessoais mascarados)", "```", inc["trecho"][:1800], "```"]
    texto = "\n".join(md)
    (c.RELATORIOS / (inc["id"] + ".md")).write_text(texto)
    icone = {"alta": "🔴", "media": "🟠", "baixa": "🟡"}.get(r.get("gravidade"), "⚪")
    tg = [f"{icone} Incidente em {nome}", "", r.get("resumo", ""), "", "Causa: " + r.get("causa_provavel", ""), "", "Acao: " + acao]
    if proposta:
        tg += ["", "Correcao: " + proposta.get("explicacao", "")]
    if sup:
        tg += ["", f"({sup} erro(s) a mais foram agrupados por excesso de volume.)"]
    tg += ["", "Relatorio: /opt/erros/relatorios/" + inc["id"] + ".md"]
    c.telegram("\n".join(tg))


def uma_rodada():
    cfg = c.fontes()
    estado = c.ler_json(c.ESTADO, {})
    feitos = 0
    for arq in sorted(c.ENTRADA.glob("*.json")):
        inc = c.ler_json(arq, None)
        if not inc:
            arq.rename(c.PROCESSADOS / (arq.name + ".invalido")); continue
        try:
            relatorio(inc, *tratar(inc, cfg, estado))
        except Exception as e:
            c.telegram(f"⚠️ O vigia falhou ao tratar {inc.get('id')}: {type(e).__name__}. O erro original esta em /opt/erros/entrada.")
            continue
        arq.rename(c.PROCESSADOS / arq.name)
        feitos += 1
    estado_atual = c.ler_json(c.ESTADO, {})
    estado_atual["reinicios"] = estado.get("reinicios", {})
    estado_atual["suprimidos"] = 0 if feitos else estado_atual.get("suprimidos", 0)
    c.gravar_json(c.ESTADO, estado_atual)
    return feitos


if __name__ == "__main__":
    c.garantir_pastas()
    if "--uma-vez" in sys.argv:
        print("tratados:", uma_rodada()); sys.exit(0)
    while True:
        try:
            uma_rodada()
        except Exception as e:
            print("erro no ciclo:", e, flush=True)
        time.sleep(ESPERA)
