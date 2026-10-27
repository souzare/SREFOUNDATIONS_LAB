"""Gerador de carga + dashboard por célula (SLI de disponibilidade e latência)."""
import collections
import os
import threading
import time

import requests
from flask import Flask, Response, jsonify

TARGET = os.getenv("TARGET", "http://router")
CUSTOMERS = int(os.getenv("CUSTOMERS", "30"))
WINDOW = int(os.getenv("WINDOW_SECONDS", "30"))
SLO = float(os.getenv("SLO_PERCENT", "99"))
CELLS = ["cell-a", "cell-b", "cell-c", "unknown"]

customer_cell = {}
events = {c: collections.deque() for c in CELLS}
lock = threading.Lock()


def worker(customer):
    session = requests.Session()
    while True:
        start = time.time()
        ok = False
        try:
            r = session.get(f"{TARGET}/", params={"customer": customer}, timeout=5)
            cell = r.headers.get("X-Cell")
            if cell:
                customer_cell[customer] = cell
            ok = r.status_code == 200
        except Exception:
            pass
        ms = (time.time() - start) * 1000
        cell = customer_cell.get(customer, "unknown")
        with lock:
            events[cell].append((time.time(), ok, ms))
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
            oks = sum(1 for _, ok, _ in items if ok)
            lat = sorted(ms for _, ok, ms in items if ok)
            out[cell] = {
                "customers": sum(1 for v in customer_cell.values() if v == cell),
                "requests": total,
                "success_pct": round(100 * oks / total, 1) if total else None,
                "avg_ms": round(sum(lat) / len(lat), 1) if lat else None,
                "p95_ms": round(lat[int(0.95 * (len(lat) - 1))], 1) if lat else None,
            }
    return out


app = Flask(__name__)


@app.route("/api/stats")
def api_stats():
    return jsonify(compute())


@app.route("/")
def dashboard():
    stats = compute()
    rows = ""
    for cell in CELLS:
        s = stats[cell]
        if cell == "unknown" and not s["requests"]:
            continue
        pct = s["success_pct"]
        color = "#2e7d32" if pct is not None and pct >= SLO else (
            "#f9a825" if pct is not None and pct >= 90 else "#c62828")
        rows += (
            f"<tr><td>{cell}</td><td>{s['customers']}</td><td>{s['requests']}</td>"
            f"<td style='background:{color};color:#fff'>{pct if pct is not None else '-'}%</td>"
            f"<td>{s['avg_ms'] if s['avg_ms'] is not None else '-'}</td>"
            f"<td>{s['p95_ms'] if s['p95_ms'] is not None else '-'}</td></tr>"
        )
    html = f"""<!doctype html><html><head><meta charset='utf-8'>
<meta http-equiv='refresh' content='2'><title>Cells dashboard</title>
<style>body{{font-family:sans-serif;background:#111;color:#eee;padding:24px}}
table{{border-collapse:collapse;font-size:20px}}td,th{{border:1px solid #444;padding:10px 18px;text-align:center}}
th{{background:#222}}</style></head><body>
<h1>Raio da explosão por célula (janela {WINDOW}s, SLO {SLO}%)</h1>
<table><tr><th>Célula</th><th>Clientes</th><th>Req.</th><th>Sucesso</th><th>Média (ms)</th><th>p95 (ms)</th></tr>
{rows}</table>
<p>Verde = dentro do SLO · Amarelo &lt; SLO · Vermelho &lt; 90%</p></body></html>"""
    return Response(html, mimetype="text/html")


if __name__ == "__main__":
    for c in range(1, CUSTOMERS + 1):
        threading.Thread(target=worker, args=(c,), daemon=True).start()
    app.run(host="0.0.0.0", port=8081, threaded=True)
