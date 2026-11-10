#!/usr/bin/env python3
"""Verifica o canário: compara o SLI da célula canário (na versão nova) com o limite aceitável.

Entrada (env): DD_API_KEY, DD_APP_KEY, DD_SITE, DEMO_RUN, CANARY_CELL (cell-a), CANARY_VERSION,
               CANARY_SECONDS (espera antes de medir, padrão 180), MIN_SAMPLES (padrão 100),
               THRESHOLD_PCT (padrão 99), ATTEMPTS (padrão 3)
Saída: 0 = canário saudável, 1 = SLI abaixo do limite (rollback), 4 = poucos dados para decidir.
"""
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from ddclient import Client, sum_points  # noqa: E402


def canary_sli(client, run, cell, version, now=None, lookback=900):
    now = now or time.time()
    scope = f"demo_run:{run},cell:{cell},version:{version}"
    total = sum_points(client.metric_query(f"sum:sre.requests.total{{{scope}}}.as_count()", now - lookback, now))
    good = sum_points(client.metric_query(f"sum:sre.requests.good{{{scope}}}.as_count()", now - lookback, now))
    return total, good


def decide(total, good, min_samples, threshold_pct):
    if total < min_samples:
        return 4, f"amostras insuficientes ({int(total)} < {min_samples})"
    sli = 100.0 * good / total
    if sli < threshold_pct:
        return 1, f"SLI do canario {sli:.2f}% < {threshold_pct}% ({int(good)}/{int(total)})"
    return 0, f"SLI do canario {sli:.2f}% >= {threshold_pct}% ({int(good)}/{int(total)})"


def main(client=None, env=os.environ, sleep=time.sleep):
    cell = env.get("CANARY_CELL", "cell-a")
    version = env["CANARY_VERSION"]
    run = env["DEMO_RUN"]
    wait = int(env.get("CANARY_SECONDS", "180"))
    min_samples = int(env.get("MIN_SAMPLES", "100"))
    threshold = float(env.get("THRESHOLD_PCT", "99"))
    attempts = int(env.get("ATTEMPTS", "3"))
    client = client or Client()

    print(f"canario {cell} v{version}: aguardando {wait}s de trafego antes de medir...")
    sleep(wait)
    code = 4
    for attempt in range(1, attempts + 1):
        total, good = canary_sli(client, run, cell, version)
        code, message = decide(total, good, min_samples, threshold)
        print(f"tentativa {attempt}/{attempts}: {message}")
        if code != 4:  # dados suficientes: decide agora
            break
        if attempt < attempts:
            sleep(60)  # o Datadog leva ~1 min para disponibilizar as metricas
    return code


if __name__ == "__main__":
    sys.exit(main())
