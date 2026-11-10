"""Cliente mínimo da API do Datadog (só stdlib, para rodar igual no laptop e no GitHub Actions)."""
import json
import os
import urllib.error
import urllib.parse
import urllib.request


class DatadogError(RuntimeError):
    pass


class Client:
    def __init__(self, site=None, api_key=None, app_key=None, opener=urllib.request.urlopen):
        self.site = site or os.environ.get("DD_SITE", "datadoghq.com")
        self.api_key = api_key or os.environ.get("DD_API_KEY", "")
        self.app_key = app_key or os.environ.get("DD_APP_KEY", "")
        self.opener = opener

    def request(self, method, path, params=None, body=None):
        url = f"https://api.{self.site}{path}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method, headers={
            "DD-API-KEY": self.api_key,
            "DD-APPLICATION-KEY": self.app_key,
            "Content-Type": "application/json",
        })
        try:
            with self.opener(req, timeout=30) as resp:
                return json.loads(resp.read().decode() or "{}")
        except urllib.error.HTTPError as e:
            raise DatadogError(f"{method} {path} -> HTTP {e.code}: {e.read().decode()[:500]}") from e

    def get_slo(self, slo_id):
        return self.request("GET", f"/api/v1/slo/{slo_id}")

    def slo_history(self, slo_id, from_ts, to_ts):
        return self.request("GET", f"/api/v1/slo/{slo_id}/history", {"from_ts": int(from_ts), "to_ts": int(to_ts)})

    def metric_query(self, query, from_ts, to_ts):
        return self.request("GET", "/api/v1/query", {"query": query, "from": int(from_ts), "to": int(to_ts)})


def sum_points(query_response):
    """Soma todos os pontos de todas as séries de uma resposta de /api/v1/query."""
    total = 0.0
    for series in query_response.get("series", []):
        for point in series.get("pointlist", []):
            if len(point) > 1 and point[1] is not None:
                total += point[1]
    return total
