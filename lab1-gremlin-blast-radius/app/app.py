import os
import socket
import time

from flask import Flask, jsonify

app = Flask(__name__)
CELL = os.getenv("CELL_NAME", "unknown")


@app.route("/")
def index():
    # pequeno trabalho de CPU para que ataques de CPU tenham efeito visível
    x = 0
    for i in range(20000):
        x += i * i
    resp = jsonify(cell=CELL, host=socket.gethostname(), ts=time.time())
    resp.headers["X-Cell"] = CELL
    return resp


@app.route("/health")
def health():
    return jsonify(status="ok", cell=CELL)
