#!/usr/bin/env python3
"""Calculadora de error budget (reproduz os exemplos dos slides do módulo 2).

Uso:
  calc_error_budget.py                       # roda os exemplos dos slides
  calc_error_budget.py 99.9 --days 30        # minutos de indisponibilidade permitidos
  calc_error_budget.py 99 --events 744000    # eventos que podem falhar
"""
import argparse


def downtime_minutes(target_pct, days):
    return (100.0 - target_pct) / 100.0 * days * 24 * 60


def error_budget_events(target_pct, total_events):
    return (100.0 - target_pct) / 100.0 * total_events


def slide_examples():
    print("Exemplos dos slides")
    print(f"  99,9% em 30 dias            -> {downtime_minutes(99.9, 30):.1f} min de indisponibilidade (slide: ~43 min)")
    print(f"  99% de 744.000 logins/mes   -> {error_budget_events(99, 744000):,.0f} logins podem falhar (slide: 7.440)")
    print(f"  99,9% de 1.000.000 reqs     -> {error_budget_events(99.9, 1_000_000):,.0f} reqs podem falhar (slide: 1.000)")
    print(f"  75% de tiquetes automaticos -> {error_budget_events(75, 1000):,.0f} de 1.000 tiquetes podem ser manuais (slide: 250)")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("target", nargs="?", type=float, help="SLO em %% (ex. 99.9)")
    p.add_argument("--days", type=float, default=30)
    p.add_argument("--events", type=float)
    a = p.parse_args()
    if a.target is None:
        slide_examples()
    elif a.events:
        print(f"{error_budget_events(a.target, a.events):,.0f} eventos podem falhar em {a.events:,.0f}")
    else:
        print(f"{downtime_minutes(a.target, a.days):.1f} min de indisponibilidade em {a.days:g} dias")


if __name__ == "__main__":
    main()
