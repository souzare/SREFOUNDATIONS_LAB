#!/usr/bin/env python3
"""Gate de SLO do pipeline: bloqueia o deploy quando o orçamento de erro acabou.

Entrada (env): DD_API_KEY, DD_APP_KEY, DD_SITE, DD_SLO_IDS (lista separada por vírgula),
               WINDOW_DAYS (padrão 7), MIN_BUDGET_PCT (padrão 0), ALLOW_NO_DATA (padrão false)
Saída: código 0 = liberado, 2 = bloqueado. Escreve o resumo em $GITHUB_STEP_SUMMARY se existir.
"""
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
from ddclient import Client, DatadogError  # noqa: E402


def budget_remaining_pct(sli, target):
    """100% = nenhum erro consumido; 0% = orçamento esgotado; negativo = estourou."""
    allowed = 100.0 - target
    if allowed <= 0:
        return 100.0 if sli >= target else float("-inf")
    return 100.0 * (1.0 - (100.0 - sli) / allowed)


def evaluate(sli, target, min_budget_pct=0.0, allow_no_data=False):
    if sli is None:
        status = "ok" if allow_no_data else "blocked"
        return {"status": status, "reason": "sem dados no periodo", "budget": None}
    budget = budget_remaining_pct(sli, target)
    if budget <= min_budget_pct:
        return {"status": "blocked", "reason": f"orcamento restante {budget:.1f}% <= {min_budget_pct:.1f}%", "budget": budget}
    return {"status": "ok", "reason": f"orcamento restante {budget:.1f}%", "budget": budget}


def extract_sli(history):
    overall = (history.get("data") or {}).get("overall") or {}
    value = overall.get("sli_value")
    if value is None:
        value = overall.get("uptime")
    return value


def extract_target(slo):
    thresholds = (slo.get("data") or {}).get("thresholds") or []
    if not thresholds:
        raise DatadogError("SLO sem thresholds")
    return float(thresholds[0]["target"])


def check_slo(client, slo_id, window_days, min_budget_pct, allow_no_data, now=None):
    now = now or time.time()
    slo = client.get_slo(slo_id)
    target = extract_target(slo)
    name = (slo.get("data") or {}).get("name", slo_id)
    sli = extract_sli(client.slo_history(slo_id, now - window_days * 86400, now))
    result = evaluate(sli, target, min_budget_pct, allow_no_data)
    result.update(name=name, sli=sli, target=target, id=slo_id)
    return result


def render(results):
    lines = ["| SLO | SLI | Alvo | Orçamento | Decisão |", "|---|---|---|---|---|"]
    for r in results:
        sli = "-" if r["sli"] is None else f"{r['sli']:.3f}%"
        budget = "-" if r["budget"] is None else f"{r['budget']:.1f}%"
        lines.append(f"| {r['name']} | {sli} | {r['target']}% | {budget} | {r['status'].upper()} ({r['reason']}) |")
    return "\n".join(lines)


def main(client=None, env=os.environ):
    ids = [i.strip() for i in env.get("DD_SLO_IDS", "").split(",") if i.strip()]
    if not ids:
        print("DD_SLO_IDS vazio: crie os SLOs (m2-slo/create-slos.sh) e publique os ids.", file=sys.stderr)
        return 1
    client = client or Client()
    window = int(env.get("WINDOW_DAYS", "7"))
    min_budget = float(env.get("MIN_BUDGET_PCT", "0"))
    allow_no_data = env.get("ALLOW_NO_DATA", "false").lower() == "true"

    results = [check_slo(client, i, window, min_budget, allow_no_data) for i in ids]
    table = render(results)
    print(table)
    if env.get("GITHUB_STEP_SUMMARY"):
        with open(env["GITHUB_STEP_SUMMARY"], "a") as f:
            f.write("### Gate de SLO\n\n" + table + "\n")

    blocked = [r for r in results if r["status"] == "blocked"]
    if blocked:
        print(f"\nDEPLOY BLOQUEADO: {', '.join(r['name'] for r in blocked)}", file=sys.stderr)
        return 2
    print("\nGate liberado.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
