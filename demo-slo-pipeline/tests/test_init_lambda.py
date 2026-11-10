"""Testa a função Lambda embutida em infra/demo.yaml (grava segredos no SSM e limpa ao deletar)."""
import os
import re
import sys
import types
import unittest

TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "infra", "demo.yaml")


def extract_code():
    with open(TEMPLATE) as f:
        text = f.read()
    block = text.split("ZipFile: |\n", 1)[1]
    lines = []
    for line in block.splitlines():
        if line.strip() and not line.startswith("          "):  # fim do bloco (indentação menor)
            break
        lines.append(line[10:])
    return "\n".join(lines)


class FakeSSM:
    def __init__(self):
        self.params, self.deleted = {}, []

    def put_parameter(self, Name, Value, Type, Overwrite):
        self.params[Name] = (Value, Type)

    def delete_parameter(self, Name):
        self.deleted.append(Name)
        if Name.endswith("state/dashboard"):
            raise RuntimeError("ParameterNotFound")  # apagar o que não existe não pode travar o stack


class FakeBucket:
    emptied = False

    def __init__(self, fail=False):
        self.fail = fail
        self.objects = types.SimpleNamespace(all=lambda: types.SimpleNamespace(delete=self.delete))

    def delete(self):
        if self.fail:
            raise RuntimeError("AccessDenied")
        FakeBucket.emptied = True


class InitLambdaTests(unittest.TestCase):
    def setUp(self):
        self.ssm = FakeSSM()
        self.responses = []
        self.bucket_fail = False
        boto3 = types.ModuleType("boto3")
        boto3.client = lambda name: self.ssm
        boto3.resource = lambda name: types.SimpleNamespace(Bucket=lambda b: FakeBucket(self.bucket_fail))
        cfn = types.ModuleType("cfnresponse")
        cfn.SUCCESS, cfn.FAILED = "SUCCESS", "FAILED"
        cfn.send = lambda event, ctx, status, data, pid: self.responses.append((status, data, pid))
        sys.modules["boto3"], sys.modules["cfnresponse"] = boto3, cfn
        namespace = {}
        exec(extract_code(), namespace)  # noqa: S102
        self.handler = namespace["handler"]
        FakeBucket.emptied = False

    def event(self, kind):
        return {"RequestType": kind, "ResourceProperties": {
            "ApiKey": "api-secret", "AppKey": "app-secret", "Site": "datadoghq.eu", "Bucket": "b", "Run": "run-abc123"}}

    def test_create_writes_secrets_as_securestring_and_run(self):
        self.handler(self.event("Create"), None)
        self.assertEqual(self.ssm.params["/sre-demo/dd_api_key"], ("api-secret", "SecureString"))
        self.assertEqual(self.ssm.params["/sre-demo/dd_app_key"], ("app-secret", "SecureString"))
        self.assertEqual(self.ssm.params["/sre-demo/dd_site"], ("datadoghq.eu", "String"))
        self.assertEqual(self.ssm.params["/sre-demo/demo_run"], ("run-abc123", "String"))
        self.assertEqual(self.responses[-1][0], "SUCCESS")

    def test_update_keeps_current_run(self):
        self.handler(self.event("Update"), None)
        self.assertNotIn("/sre-demo/demo_run", self.ssm.params)   # o run atual (pode ter sido resetado) não é sobrescrito
        self.assertIn("/sre-demo/dd_api_key", self.ssm.params)

    def test_delete_cleans_everything_and_never_blocks_the_stack(self):
        self.handler(self.event("Delete"), None)
        self.assertEqual(len(self.ssm.deleted), 6)
        self.assertTrue(FakeBucket.emptied)
        self.assertEqual(self.responses[-1][0], "SUCCESS")

    def test_delete_succeeds_even_if_bucket_cleanup_fails(self):
        self.bucket_fail = True
        self.handler(self.event("Delete"), None)
        self.assertEqual(self.responses[-1][0], "SUCCESS")

    def test_create_failure_is_reported_without_leaking_the_secret(self):
        self.ssm.put_parameter = lambda **kw: (_ for _ in ()).throw(RuntimeError("boom api-secret"))
        self.handler(self.event("Create"), None)
        status, data, _ = self.responses[-1]
        self.assertEqual(status, "FAILED")
        self.assertNotIn("api-secret", str(data))


if __name__ == "__main__":
    unittest.main()
