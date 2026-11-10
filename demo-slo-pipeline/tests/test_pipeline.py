import importlib.util
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, os.path.join(ROOT, "lib"))
sys.path.insert(0, os.path.join(ROOT, "app"))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, os.path.join(ROOT, path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


slo_gate = load("slo_gate", "m5-pipeline-slo-gate/slo_gate.py")
canary = load("canary_verify", "m5-pipeline-slo-gate/canary_verify.py")
cell_app = load("cell_app", "app/app.py")
toil = load("toil_roi", "m3-toil/toil_roi.py")
budget_calc = load("calc_error_budget", "m2-slo/calc_error_budget.py")


class FakeClient:
    """Simula as respostas da API do Datadog."""

    def __init__(self, sli, target=99.0, counts=None):
        self.sli, self.target, self.counts = sli, target, counts or {}

    def get_slo(self, slo_id):
        return {"data": {"name": f"slo-{slo_id}", "thresholds": [{"target": self.target, "timeframe": "7d"}]}}

    def slo_history(self, slo_id, from_ts, to_ts):
        return {"data": {"overall": {"sli_value": self.sli}}}

    def metric_query(self, query, from_ts, to_ts):
        kind = "total" if "requests.total" in query else "good"
        return {"series": [{"pointlist": [[0, self.counts[kind] / 2], [1, self.counts[kind] / 2]]}]}


class SloGateTests(unittest.TestCase):
    def test_budget_math(self):
        self.assertAlmostEqual(slo_gate.budget_remaining_pct(100, 99), 100)
        self.assertAlmostEqual(slo_gate.budget_remaining_pct(99, 99), 0)
        self.assertAlmostEqual(slo_gate.budget_remaining_pct(99.5, 99), 50)
        self.assertAlmostEqual(slo_gate.budget_remaining_pct(98, 99), -100)

    def test_evaluate(self):
        self.assertEqual(slo_gate.evaluate(99.9, 99)["status"], "ok")
        self.assertEqual(slo_gate.evaluate(99.0, 99)["status"], "blocked")   # orcamento zerado
        self.assertEqual(slo_gate.evaluate(97.0, 99)["status"], "blocked")
        self.assertEqual(slo_gate.evaluate(None, 99)["status"], "blocked")   # sem dados = fail-closed
        self.assertEqual(slo_gate.evaluate(None, 99, allow_no_data=True)["status"], "ok")

    def test_main_exit_codes(self):
        env = {"DD_SLO_IDS": "a,b"}
        self.assertEqual(slo_gate.main(FakeClient(99.8), env), 0)
        self.assertEqual(slo_gate.main(FakeClient(95.0), env), 2)
        self.assertEqual(slo_gate.main(FakeClient(99.8), {}), 1)


class CanaryTests(unittest.TestCase):
    def test_decide(self):
        self.assertEqual(canary.decide(1000, 995, 100, 99)[0], 0)
        self.assertEqual(canary.decide(1000, 900, 100, 99)[0], 1)
        self.assertEqual(canary.decide(10, 10, 100, 99)[0], 4)

    def test_main(self):
        env = {"CANARY_VERSION": "1.2.0", "DEMO_RUN": "r", "CANARY_SECONDS": "0", "ATTEMPTS": "1"}
        no_sleep = lambda s: None  # noqa: E731
        ok = FakeClient(0, counts={"total": 1000, "good": 1000})
        bad = FakeClient(0, counts={"total": 1000, "good": 700})
        self.assertEqual(canary.main(ok, env, no_sleep), 0)
        self.assertEqual(canary.main(bad, env, no_sleep), 1)


class AppTests(unittest.TestCase):
    def setUp(self):
        cell_app.BASE_FAIL_RATE = 0
        cell_app.fault.update(error_rate=0.0, db_latency_ms=0)
        self.client = cell_app.app.test_client()

    def test_ok_has_version_and_cell_headers(self):
        r = self.client.get("/?customer=7")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.headers["X-Version"], cell_app.VERSION)
        self.assertIn("X-Cell", r.headers)

    def test_health(self):
        self.assertEqual(self.client.get("/health").status_code, 200)

    def test_runtime_fault_injection_and_clear(self):
        self.client.post("/admin/fault", json={"error_rate": 100})
        self.assertEqual(self.client.get("/").status_code, 500)
        self.client.post("/admin/fault", json={"error_rate": 0})
        self.assertEqual(self.client.get("/").status_code, 200)

    def test_release_regression_from_config(self):
        cell_app.BASE_FAIL_RATE = 100
        self.assertEqual(self.client.get("/").status_code, 500)

    def test_admin_fault_endpoint_answers_200_with_state(self):
        """O instance/fault.sh usa 'curl -f': qualquer 5xx aqui derruba as ações inject-fault, clear-faults e reset."""
        r = self.client.post("/admin/fault", json={"error_rate": 30, "db_latency_ms": 800})
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.get_json()["error_rate"], 30.0)
        self.assertEqual(r.get_json()["db_latency_ms"], 800)
        self.assertEqual(r.get_json()["version"], cell_app.VERSION)

        r = self.client.post("/admin/fault", json={"error_rate": 0, "db_latency_ms": 0})   # o 'clear'
        self.assertEqual(r.status_code, 200)
        self.assertEqual(self.client.get("/admin/fault").status_code, 200)
        self.assertEqual(self.client.get("/admin/fault").get_json()["error_rate"], 0.0)


class DemoToolsTests(unittest.TestCase):
    def test_slide_examples(self):
        self.assertAlmostEqual(budget_calc.downtime_minutes(99.9, 30), 43.2)
        self.assertEqual(round(budget_calc.error_budget_events(99, 744000)), 7440)
        self.assertEqual(round(budget_calc.error_budget_events(99.9, 1_000_000)), 1000)

    def test_toil_math(self):
        steps = [
            {"step": "a", "minutes": 10, "toil": True},
            {"step": "b", "minutes": 10, "toil": False},
        ]
        summary = toil.summarize(steps, releases_per_month=4)
        self.assertEqual(summary["toil_pct"], 50.0)
        self.assertEqual(summary["toil_hours_month"], round(10 * 4 / 60, 1))
        self.assertEqual(toil.break_even_months(automation_hours=8, saved_hours_month=2), 4.0)


if __name__ == "__main__":
    unittest.main()
