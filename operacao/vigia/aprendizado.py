"""Medidor de aprendizado do Codall: indicadores semanais a partir do livro /opt/erros/aprendizado.jsonl.

Uso: python3 aprendizado.py [--telegram] [--json]
Indicadores (cada um em %, por semana e acumulado):
  autonomia   incidentes tratados sem ajuda humana (reinicio que funcionou, ou correcao preparada) / total
  diagnostico incidentes com diagnostico da IA / total
  recorrencia incidentes cuja assinatura ja tinha aparecido antes / total (quanto menor, melhor)
  eficacia    correcoes aplicadas e que nao voltaram a ocorrer / aplicadas
  reuso       incidentes resolvidos reaproveitando uma licao anterior / reincidentes
Previsao: so com 4+ semanas com dados; regressao linear com intervalo de 95%.
"""
import json, math, sys, time
import comum as c

SEM = 7 * 86400
T95 = {2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262, 10: 2.228}
MIN_INC = 3  # semana com menos incidentes que isso nao entra na tendencia


def pct(a, b):
    return None if not b else round(100.0 * a / b, 1)


def indicadores(ev):
    inc = [e for e in ev if e.get("tipo") == "incidente"]
    n = len(inc)
    aut = sum(1 for e in inc if e.get("reiniciou_ok") or e.get("acao") == "proposta")
    dia = sum(1 for e in inc if e.get("ia"))
    rec = sum(1 for e in inc if e.get("reincidente"))
    reuso = sum(1 for e in inc if e.get("licao_reutilizada"))
    apl = [e for e in ev if e.get("tipo") == "aplicada"]
    voltou = sum(1 for a in apl if any(e.get("correcao_anterior_falhou") and e.get("assinatura") == a.get("assinatura") for e in inc))
    return {"incidentes": n, "autonomia": pct(aut, n), "diagnostico": pct(dia, n), "recorrencia": pct(rec, n),
            "aplicadas": len(apl), "revertidas": sum(1 for e in ev if e.get("tipo") == "revertida"),
            "eficacia": pct(len(apl) - voltou, len(apl)), "reuso": pct(reuso, rec)}


def semanas(ev):
    if not ev:
        return []
    t0 = min(e["ts"] for e in ev)
    ag = {}
    for e in ev:
        ag.setdefault(int((e["ts"] - t0) // SEM), []).append(e)
    return [(k, indicadores(v)) for k, v in sorted(ag.items())]


def tendencia(pontos):
    """OLS y = a + b x com IC 95% da inclinacao. Retorna None se insuficiente."""
    n = len(pontos)
    if n < 4 or n - 2 not in T95:
        return None
    xs, ys = [p[0] for p in pontos], [p[1] for p in pontos]
    mx, my = sum(xs) / n, sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    if sxx == 0:
        return None
    b = sum((x - mx) * (y - my) for x, y in pontos) / sxx
    a = my - b * mx
    res = sum((y - (a + b * x)) ** 2 for x, y in pontos)
    ep = math.sqrt(res / (n - 2) / sxx)
    return {"a": a, "b": b, "ic": T95[n - 2] * ep, "n": n}


def previsao(sem, chave, meta, mais_e_melhor=True):
    pts = [(k, v[chave]) for k, v in sem if v[chave] is not None and v["incidentes"] >= MIN_INC]
    t = tendencia(pts)
    if not t:
        return f"{chave}: dados insuficientes para prever (precisa de 4+ semanas com {MIN_INC}+ incidentes; ha {len(pts)})."
    b, ic, a = t["b"], t["ic"], t["a"]
    if abs(b) <= ic:
        return f"{chave}: sem tendencia estatistica clara (inclinacao {b:+.1f} pontos/semana, IC95% +-{ic:.1f})."
    if (b > 0) != mais_e_melhor:
        return f"{chave}: piorando ({b:+.1f} pontos/semana, IC95% +-{ic:.1f})."
    ult = pts[-1][0]
    atual = a + b * ult
    if (atual >= meta) == mais_e_melhor:
        return f"{chave}: meta {meta:.0f}% ja atingida na tendencia (estimado {atual:.0f}% agora; {b:+.1f} pontos/semana, IC95% +-{ic:.1f})."
    dias = lambda bb: (meta - atual) / bb * 7 if bb and (bb > 0) == mais_e_melhor else None
    est, c1, c2 = dias(b), dias(b + ic), dias(b - ic)
    lim = sorted(x for x in (c1, c2) if x is not None)
    faixa = f"{lim[0]:.0f} a {lim[1]:.0f} dias" if len(lim) == 2 else (f"a partir de {lim[0]:.0f} dias" if lim else "indefinida")
    return f"{chave}: meta {meta:.0f}% em ~{est:.0f} dias (faixa {faixa}; {b:+.1f} pontos/semana, IC95% +-{ic:.1f}, {t['n']} semanas)."


def texto(ev):
    tot = indicadores(ev)
    sem = semanas(ev)
    f = lambda v: "n/d" if v is None else f"{v}%"
    L = ["Aprendizado do Codall (vigia de erros)",
         f"Acumulado: {tot['incidentes']} incidentes | autonomia {f(tot['autonomia'])} | diagnostico IA {f(tot['diagnostico'])} | "
         f"recorrencia {f(tot['recorrencia'])} | correcoes aplicadas {tot['aplicadas']} (revertidas {tot['revertidas']}) | "
         f"eficacia das correcoes {f(tot['eficacia'])} | reuso de licoes {f(tot['reuso'])}", ""]
    for k, v in sem[-6:]:
        L.append(f"Semana {k + 1}: {v['incidentes']} inc | autonomia {f(v['autonomia'])} | recorrencia {f(v['recorrencia'])} | diagnostico {f(v['diagnostico'])}")
    L += ["", "Previsao:", previsao(sem, "autonomia", 90), previsao(sem, "recorrencia", 10, mais_e_melhor=False)]
    if tot["incidentes"] < 10:
        L += ["", f"Aviso: so {tot['incidentes']} incidentes registrados; os numeros ainda oscilam muito."]
    return "\n".join(L)


if __name__ == "__main__":
    ev = c.ler_livro()
    if "--json" in sys.argv:
        print(json.dumps({"total": indicadores(ev), "semanas": [dict(v, semana=k + 1) for k, v in semanas(ev)]}, ensure_ascii=False, indent=1))
    else:
        t = texto(ev)
        print(t)
        if "--telegram" in sys.argv:
            c.telegram(t)
