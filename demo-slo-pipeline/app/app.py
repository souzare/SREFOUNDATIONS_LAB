"""App de exemplo da demo SLO + pipeline: uma "célula" com versão, falhas injetáveis e traces."""
import json
import os
import random
import socket
import threading
import time
from contextlib import nullcontext

from flask import Flask, g, jsonify, request

try:  # ddtrace só existe na imagem; os testes rodam sem ele
    from ddtrace import tracer
except ImportError:
    tracer = None

CELL = os.getenv("CELL_NAME", "unknown")
CONFIG_PATH = os.getenv("APP_CONFIG", os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json"))


def load_config(path=CONFIG_PATH):
    with open(path) as f:
        return json.load(f)


CONFIG = load_config()
VERSION = CONFIG["version"]
# "fail_rate" no config.json simula uma regressão publicada junto com a versão (release ruim)
BASE_FAIL_RATE = float(CONFIG.get("fail_rate", 0))

# Falhas injetadas em runtime pelo instrutor (POST /admin/fault), independentes da versão
fault = {"error_rate": 0.0, "db_latency_ms": 0}
fault_lock = threading.Lock()

app = Flask(__name__)


def db_span():
    """Span 'db.query': é nele que a latência injetada aparece no trace (M4)."""
    if tracer is None:
        return nullcontext()
    return tracer.trace("db.query", service="orders-db", resource="SELECT * FROM orders")


def should_fail():
    with fault_lock:
        rate = max(BASE_FAIL_RATE, fault["error_rate"])
    return random.random() * 100 < rate


@app.before_request
def start_timer():
    g.start = time.time()


@app.after_request
def add_headers_and_log(resp):
    resp.headers["X-Cell"] = CELL
    resp.headers["X-Version"] = VERSION
    if request.path != "/health":
        entry = {
            "message": "request",
            "cell": CELL,
            "version": VERSION,
            "customer": request.args.get("customer", "-"),
            "http_status": resp.status_code,
            "duration_ms": round((time.time() - g.start) * 1000, 1),
        }
        if tracer is not None:
            entry.update(tracer.get_log_correlation_context())
        print(json.dumps(entry), flush=True)
    return resp


@app.route("/")
def index():
    root = tracer.current_root_span() if tracer is not None else None
    if root is not None:
        root.set_tag("cell", CELL)
        root.set_tag("customer", request.args.get("customer", "-"))

    with fault_lock:
        latency = fault["db_latency_ms"]
    with db_span():
        if latency:
            time.sleep(latency / 1000)

    x = 0
    for i in range(20000):  # pequeno trabalho de CPU
        x += i * i

    if should_fail():
        return jsonify(error="falha simulada", cell=CELL, version=VERSION), 500
    return jsonify(cell=CELL, version=VERSION, host=socket.gethostname(), ts=time.time())


@app.route("/health")
def health():
    return jsonify(status="ok", cell=CELL, version=VERSION)


@app.route("/admin/fault", methods=["GET", "POST"])
def admin_fault():
    if request.method == "POST":
        body = request.get_json(silent=True) or {}
        with fault_lock:
            if "error_rate" in body:
                fault["error_rate"] = max(0.0, min(100.0, float(body["error_rate"])))
            if "db_latency_ms" in body:
                fault["db_latency_ms"] = max(0, int(body["db_latency_ms"]))
    with fault_lock:
        return jsonify(dict(fault), cell=CELL, version=VERSION)
