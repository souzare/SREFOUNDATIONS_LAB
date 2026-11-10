#!/usr/bin/env python3
"""Classifica os passos de um release manual como toil e calcula o ROI de automatizar.

Uso: toil_roi.py [toil-steps.csv] [--releases 8] [--automation-hours 16]
O CSV tem uma linha por passo: step, minutes e 6 colunas 0/1 com as características do toil
(manual, repetitive, automatable, tactical, no_lasting_value, scales_linearly).
Um passo conta como toil quando é manual, repetitivo e automatizável (as 3 características centrais).
"""
import argparse
import csv
import os

FLAGS = ["manual", "repetitive", "automatable", "tactical", "no_lasting_value", "scales_linearly"]


def load_steps(path):
    steps = []
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            flags = {k: row[k].strip() == "1" for k in FLAGS}
            steps.append({
                "step": row["step"],
                "minutes": float(row["minutes"]),
                "flags": flags,
                "toil": flags["manual"] and flags["repetitive"] and flags["automatable"],
            })
    return steps


def summarize(steps, releases_per_month):
    total = sum(s["minutes"] for s in steps)
    toil = sum(s["minutes"] for s in steps if s["toil"])
    return {
        "total_min_release": total,
        "toil_min_release": toil,
        "toil_pct": round(100.0 * toil / total, 1) if total else 0.0,
        "toil_hours_month": round(toil * releases_per_month / 60.0, 1),
    }


def break_even_months(automation_hours, saved_hours_month):
    return round(automation_hours / saved_hours_month, 1) if saved_hours_month else float("inf")


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    p = argparse.ArgumentParser()
    p.add_argument("csv", nargs="?", default=os.path.join(here, "toil-steps.csv"))
    p.add_argument("--releases", type=float, default=8, help="releases por mês")
    p.add_argument("--automation-hours", type=float, default=16, help="esforço para automatizar")
    a = p.parse_args()

    steps = load_steps(a.csv)
    print(f"{'passo':58} {'min':>4}  {'toil?':5} caracteristicas")
    for s in steps:
        marks = ",".join(k for k in FLAGS if s["flags"][k]) or "-"
        print(f"{s['step'][:58]:58} {s['minutes']:>4.0f}  {'SIM' if s['toil'] else 'nao':5} {marks}")

    r = summarize(steps, a.releases)
    print(f"\nPor release: {r['toil_min_release']:.0f} de {r['total_min_release']:.0f} min sao toil ({r['toil_pct']}%)")
    print(f"Por mes ({a.releases:g} releases): {r['toil_hours_month']} h de toil")
    if r["toil_pct"] > 50:
        print("ALERTA: acima da regra dos 50% (o trabalho operacional deveria ficar abaixo disso).")
    be = break_even_months(a.automation_hours, r["toil_hours_month"])
    print(f"Automatizar custa ~{a.automation_hours:g} h e devolve {r['toil_hours_month']} h/mes -> se paga em {be} meses")


if __name__ == "__main__":
    main()
