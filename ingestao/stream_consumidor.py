"""Consumidor: le codall.eventos em micro-lotes e grava parquet no landing/stream_eventos.

Idempotente: o nome do arquivo e <particao>-<offset inicial>-<offset final>, entao
reprocessar os mesmos offsets regrava o mesmo arquivo (sem duplicar). O offset so e
confirmado (commit) depois do arquivo estar no lugar (tmp + rename atomico).

Uso: python stream_consumidor.py --landing DIR [--broker redpanda:9092] [--grupo g]
        [--lote 200] [--segundos 15] [--uma-vez] [--do-inicio]
"""
import argparse
import datetime as dt
import json
import os
import time
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq
from confluent_kafka import Consumer, KafkaError

ESQUEMA = pa.schema([("event_id", pa.string()), ("ts", pa.timestamp("us")), ("dt", pa.date32()),
                     ("origem", pa.string()), ("projeto", pa.string()), ("categoria", pa.string()),
                     ("qtd", pa.int64())])


def gravar(landing: Path, particao: int, msgs: list) -> None:
    linhas = [json.loads(m.value()) for m in msgs]
    por_dia = {}
    for l in linhas:
        por_dia.setdefault(l["dt"], []).append(l)
    ini, fim = msgs[0].offset(), msgs[-1].offset()
    for dia, ls in por_dia.items():
        pasta = landing / "stream_eventos" / f"dt={dia}"
        pasta.mkdir(parents=True, exist_ok=True)
        tab = pa.table({
            "event_id": [x["event_id"] for x in ls],
            "ts": [dt.datetime.fromisoformat(x["ts"]) for x in ls],
            "dt": [dt.date.fromisoformat(x["dt"]) for x in ls],
            "origem": [x["origem"] for x in ls], "projeto": [x["projeto"] for x in ls],
            "categoria": [x["categoria"] for x in ls], "qtd": [int(x["qtd"]) for x in ls]},
            schema=ESQUEMA)
        destino = pasta / f"lote-p{particao}-{ini}-{fim}.parquet"
        tmp = pasta / f".{destino.name}.tmp"
        pq.write_table(tab, tmp)
        os.replace(tmp, destino)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--landing", required=True)
    ap.add_argument("--broker", default="redpanda:9092")
    ap.add_argument("--topico", default="codall.eventos")
    ap.add_argument("--grupo", default="plataforma-viva-landing")
    ap.add_argument("--lote", type=int, default=200)
    ap.add_argument("--segundos", type=float, default=15)
    ap.add_argument("--uma-vez", action="store_true")
    ap.add_argument("--do-inicio", action="store_true")
    a = ap.parse_args()
    c = Consumer({"bootstrap.servers": a.broker, "group.id": a.grupo, "enable.auto.commit": False,
                  "auto.offset.reset": "earliest"})
    c.subscribe([a.topico])
    landing = Path(a.landing)
    buf, inicio = [], time.time()
    vazios = 0
    while True:
        m = c.poll(1.0)
        if m is not None and not m.error():
            buf.append(m)
            vazios = 0
        elif m is not None and m.error().code() != KafkaError._PARTITION_EOF:
            print("erro kafka:", m.error())
        else:
            vazios += 1
        vencido = time.time() - inicio >= a.segundos
        if buf and (len(buf) >= a.lote or vencido or (a.uma_vez and vazios >= 3)):
            gravar(landing, buf[0].partition(), buf)
            c.commit(message=buf[-1], asynchronous=False)
            print(f"lote gravado: offsets {buf[0].offset()}-{buf[-1].offset()} ({len(buf)} eventos)", flush=True)
            buf, inicio = [], time.time()
        if vencido:
            inicio = time.time()
        if a.uma_vez and vazios >= 5 and not buf:
            break


if __name__ == "__main__":
    main()
