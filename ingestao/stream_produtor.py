"""Produtor: le novas linhas de governance_log (SQLite somente leitura) e publica
no topico codall.eventos do Redpanda. Incremental por rowid (estado em arquivo).

Uso: python stream_produtor.py --db /ai/codall/data/codall.db --estado ARQ
        [--broker 127.0.0.1:19092] [--topico codall.eventos] [--max 500]
     python stream_produtor.py --sintetico ID --broker ...   (publica 1 evento de teste)
event_id = "gov-<rowid>": reenviar o mesmo evento nao cria um segundo no silver.
"""
import argparse
import datetime as dt
import json
import sqlite3
from pathlib import Path

from confluent_kafka import Producer
from confluent_kafka.admin import AdminClient, NewTopic


def garantir_topico(broker, topico):
    adm = AdminClient({"bootstrap.servers": broker})
    if topico not in adm.list_topics(timeout=10).topics:
        for f in adm.create_topics([NewTopic(topico, num_partitions=1, replication_factor=1)]).values():
            try:
                f.result()
            except Exception as e:  # corrida com outro produtor
                if "EXISTS" not in str(e).upper():
                    raise


def evento(event_id, ts, categoria):
    return {"event_id": event_id, "ts": ts, "dt": ts[:10], "origem": "governanca",
            "projeto": "codall", "categoria": categoria, "qtd": 1}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db")
    ap.add_argument("--estado")
    ap.add_argument("--broker", default="127.0.0.1:19092")
    ap.add_argument("--topico", default="codall.eventos")
    ap.add_argument("--max", type=int, default=500)
    ap.add_argument("--sintetico")
    a = ap.parse_args()
    garantir_topico(a.broker, a.topico)
    p = Producer({"bootstrap.servers": a.broker, "enable.idempotence": True})
    if a.sintetico:
        ts = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
        p.produce(a.topico, json.dumps(evento(a.sintetico, ts, "teste_aceite")).encode(), key=a.sintetico)
        p.flush(10)
        print("publicado", a.sintetico)
        return
    est = Path(a.estado)
    ultimo = int(est.read_text()) if est.exists() else 0
    con = sqlite3.connect(f"file:{a.db}?mode=ro", uri=True)
    linhas = con.execute("select rowid, action, created_at from governance_log where rowid>? order by rowid limit ?",
                         (ultimo, a.max)).fetchall()
    for rid, acao, criado in linhas:
        ts = dt.datetime.fromisoformat(str(criado).replace("Z", "")).strftime("%Y-%m-%dT%H:%M:%S")
        p.produce(a.topico, json.dumps(evento(f"gov-{rid}", ts, str(acao))).encode(), key=f"gov-{rid}")
    restantes = p.flush(15)
    if restantes == 0 and linhas:
        est.write_text(str(linhas[-1][0]))   # so avanca o estado depois da entrega confirmada
    print(f"publicados {len(linhas)} eventos (nao entregues: {restantes})")


if __name__ == "__main__":
    main()
