"""Utilitarios do vigia de erros: pastas, mascara de dados pessoais, Telegram."""
import json, os, re, time, urllib.parse, urllib.request
from pathlib import Path

BASE = Path(os.environ.get("ERROS_DIR", "/opt/erros"))
ENTRADA, PROCESSADOS = BASE / "entrada", BASE / "processados"
RELATORIOS, PROPOSTAS = BASE / "relatorios", BASE / "propostas"
ESTADO = BASE / "estado.json"
ALERTA = Path(os.environ.get("VIGIA_ALERTA", "/opt/plataforma-viva/.alerta"))
FONTES = Path(os.environ.get("VIGIA_FONTES", str(Path(__file__).with_name("fontes.json"))))

_MASCARAS = [
    (re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"), "[email]"),
    (re.compile(r"\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b"), "[cpf]"),
    (re.compile(r"(?<!\d)(?:\+?55\s?)?\(?\d{2}\)?\s?9?\d{4}-?\d{4}(?!\d)"), "[tel]"),
    (re.compile(r"(?i)(bearer\s+)[a-z0-9._\-]{16,}"), r"\1[segredo]"),
    (re.compile(r"\b(?:sk|ghp|gho|xox[bp])[-_][A-Za-z0-9_\-]{16,}"), "[segredo]"),
    (re.compile(r"\b\d{6,12}:[A-Za-z0-9_-]{30,}\b"), "[segredo]"),
    (re.compile(r"(?i)((?:token|senha|password|secret|api[_-]?key|authorization)[\"']?\s*[:=]\s*[\"']?)[^\s\"',}]{6,}"), r"\1[segredo]"),
]


def mascarar(texto):
    for rx, sub in _MASCARAS:
        texto = rx.sub(sub, texto)
    return texto


def garantir_pastas():
    for p in (ENTRADA, PROCESSADOS, RELATORIOS, PROPOSTAS):
        p.mkdir(parents=True, exist_ok=True)


def ler_json(p, padrao):
    try:
        return json.loads(Path(p).read_text())
    except Exception:
        return padrao


def gravar_json(p, obj):
    p = Path(p)
    tmp = p.with_suffix(p.suffix + ".tmp")
    tmp.write_text(json.dumps(obj, ensure_ascii=False, indent=1))
    tmp.replace(p)


def fontes():
    return json.loads(FONTES.read_text())


def _credenciais():
    d = {}
    try:
        for linha in ALERTA.read_text().splitlines():
            if "=" in linha:
                k, v = linha.split("=", 1)
                d[k.strip()] = v.strip()
    except Exception:
        pass
    return d.get("TELEGRAM_TOKEN", ""), d.get("TELEGRAM_CHAT_ID", "")


def telegram(texto):
    """Envia em partes de ate 3800 caracteres. Retorna True se enviou."""
    if os.environ.get("VIGIA_TELEGRAM_DRY"):
        print("[telegram-dry]\n" + texto)
        return True
    tok, chat = _credenciais()
    if not tok or not chat:
        return False
    ok = True
    for i in range(0, len(texto), 3800):
        dados = urllib.parse.urlencode({"chat_id": chat, "text": texto[i:i + 3800]}).encode()
        try:
            urllib.request.urlopen(urllib.request.Request(
                "https://api.telegram.org/bot" + tok + "/sendMessage", data=dados), timeout=15).read()
        except Exception:
            ok = False
    return ok


def agora():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
