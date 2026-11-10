"""Gerador de carga que emite os SLIs da demo para o Datadog (DogStatsD) e mostra um painel local.

Métricas (todas com as tags cell, version, env, demo_run):
  sre.requests.total   toda requisição
  sre.requests.good    resposta 200            -> SLO de disponibilidade = good / total
  sre.requests.fast    resposta 200 < LATENCY_MS -> SLO de latência       = fast / good
  sre.request.latency  histograma de latência (ms) das respostas 200 (o Agent gera .95percentile, .avg, .max)
"""
import collections
import os
import socket
import threading
import time

import requests
from flask import Flask, Response, jsonify

TARGET = os.getenv("TARGET", "http://router")
CUSTOMERS = int(os.getenv("CUSTOMERS", "30"))
WINDOW = int(os.getenv("WINDOW_SECONDS", "30"))
LATENCY_MS = float(os.getenv("LATENCY_THRESHOLD_MS", "300"))
DEMO_RUN = os.getenv("DEMO_RUN", "run-local")
STATSD_HOST = os.getenv("DD_DOGSTATSD_HOST", "datadog-agent")
STATSD_PORT = int(os.getenv("DD_DOGSTATSD_PORT", "8125"))
CELLS = ["cell-a", "cell-b", "cell-c", "unknown"]

customer_cell = {}
events = {c: collections.deque() for c in CELLS}
lock = threading.Lock()
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)


def statsd(lines):
    """UDP fire-and-forget: se o agente não existir, a carga continua."""
    try:
        sock.sendto("\n".join(lines).encode(), (STATSD_HOST, STATSD_PORT))
    except OSError:
        pass


def metric_lines(cell, version, ok, ms):
    tags = f"cell:{cell},version:{version},env:demo,demo_run:{DEMO_RUN}"
    lines = [f"sre.requests.total:1|c|#{tags}"]
    if ok:
        lines.append(f"sre.requests.good:1|c|#{tags}")
        lines.append(f"sre.request.latency:{ms:.1f}|h|#{tags}")
        if ms < LATENCY_MS:
            lines.append(f"sre.requests.fast:1|c|#{tags}")
    return lines


def worker(customer):
    session = requests.Session()
    while True:
        start = time.time()
        ok, cell, version = False, customer_cell.get(customer, "unknown"), "unknown"
        try:
            r = session.get(f"{TARGET}/", params={"customer": customer}, timeout=5)
            cell = r.headers.get("X-Cell", cell)
            version = r.headers.get("X-Version", version)
            customer_cell[customer] = cell
            ok = r.status_code == 200
        except Exception:
            pass
        ms = (time.time() - start) * 1000
        statsd(metric_lines(cell, version, ok, ms))
        with lock:
            events[cell].append((time.time(), ok, ms, version))
        time.sleep(1)


def compute():
    now = time.time()
    out = {}
    with lock:
        for cell in CELLS:
            dq = events[cell]
            while dq and dq[0][0] < now - WINDOW:
                dq.popleft()
            items = list(dq)
            total = len(items)
            oks = sum(1 for _, ok, _, _ in items if ok)
            lat = sorted(ms for _, ok, ms, _ in items if ok)
            versions = sorted({v for _, _, _, v in items})
            out[cell] = {
                "requests": total,
                "success_pct": round(100 * oks / total, 1) if total else None,
                "p95_ms": round(lat[int(0.95 * (len(lat) - 1))], 1) if lat else None,
                "versions": versions,
            }
    return out


app = Flask(__name__)


@app.route("/api/stats")
def api_stats():
    return jsonify(demo_run=DEMO_RUN, cells=compute())


@app.route("/")
def dashboard():
    rows = ""
    for cell, s in compute().items():
        if cell == "unknown" and not s["requests"]:
            continue
        pct = s["success_pct"]
        color = "#2e7d32" if pct is not None and pct >= 99 else ("#f9a825" if pct is not None and pct >= 90 else "#c62828")
        rows += (
            f"<tr><td>{cell}</td><td>{', '.join(s['versions']) or '-'}</td><td>{s['requests']}</td>"
            f"<td style='background:{color};color:#fff'>{pct if pct is not None else '-'}%</td>"
            f"<td>{s['p95_ms'] if s['p95_ms'] is not None else '-'}</td></tr>"
        )
    html = f"""<!doctype html><html><head><meta charset='utf-8'><meta http-equiv='refresh' content='2'>
<title>Demo SRE</title><style>body{{font-family:sans-serif;background:#111;color:#eee;padding:24px}}
table{{border-collapse:collapse;font-size:20px}}td,th{{border:1px solid #444;padding:10px 18px;text-align:center}}
th{{background:#222}}</style></head><body><h1>Demo SRE · {DEMO_RUN} (janela {WINDOW}s)</h1>
<table><tr><th>Célula</th><th>Versão</th><th>Req.</th><th>Sucesso</th><th>p95 (ms)</th></tr>{rows}</table>
<p>O SLO oficial está no Datadog; este painel é só o apoio local.</p></body></html>"""
    return Response(html, mimetype="text/html")


if __name__ == "__main__":
    for c in range(1, CUSTOMERS + 1):
        threading.Thread(target=worker, args=(c,), daemon=True).start()
    app.run(host="0.0.0.0", port=8081, threaded=True)
