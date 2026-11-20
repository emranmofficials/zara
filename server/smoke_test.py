#!/usr/bin/env python3
"""Dependency-free smoke test for server/main.py.

On hosts without FastAPI installed (or where pydantic-core has no wheel), this
stubs the small surface main.py uses and exercises the real endpoint functions:
auth, tools, confirm gate, memory, history, backup, devices and summary.

Run:  python3 server/smoke_test.py
"""
import asyncio
import importlib.util
import os
import shutil
import sys
import tempfile
import types
from pathlib import Path

HERE = Path(__file__).resolve().parent
TMP = Path(tempfile.mkdtemp(prefix="zara_smoke_"))


# ---------- minimal stubs ----------
class HTTPException(Exception):
    def __init__(self, status_code, detail):
        super().__init__(f"{status_code}: {detail}")
        self.status_code = status_code
        self.detail = detail


def Header(default=None):
    return default


class FastAPI:
    def __init__(self, **kwargs):
        self.routes = {}

    def add_middleware(self, *args, **kwargs):
        pass

    def _route(self, method, path):
        def decorator(fn):
            self.routes[(method, path)] = fn
            return fn
        return decorator

    def get(self, path, **kwargs):
        return self._route("GET", path)

    def post(self, path, **kwargs):
        return self._route("POST", path)

    def delete(self, path, **kwargs):
        return self._route("DELETE", path)


fastapi = types.ModuleType("fastapi")
fastapi.FastAPI = FastAPI
fastapi.Header = Header
fastapi.HTTPException = HTTPException
sys.modules["fastapi"] = fastapi

middleware = types.ModuleType("fastapi.middleware")
cors = types.ModuleType("fastapi.middleware.cors")
cors.CORSMiddleware = type("CORSMiddleware", (), {})
sys.modules["fastapi.middleware"] = middleware
sys.modules["fastapi.middleware.cors"] = cors


class FieldInfo:
    def __init__(self, default=None, default_factory=None, **kwargs):
        self.default = default
        self.default_factory = default_factory


def Field(default=None, default_factory=None, **kwargs):
    return FieldInfo(default, default_factory)


class BaseModel:
    def __init__(self, **kwargs):
        for name in type(self).__annotations__:
            declared = getattr(type(self), name, None)
            if name in kwargs:
                value = kwargs[name]
            elif isinstance(declared, FieldInfo):
                value = declared.default_factory() if declared.default_factory else declared.default
            else:
                value = declared
            setattr(self, name, value)


pydantic = types.ModuleType("pydantic")
pydantic.BaseModel = BaseModel
pydantic.Field = Field
sys.modules["pydantic"] = pydantic


class _AsyncClient:
    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        return False

    async def post(self, *args, **kwargs):
        raise AssertionError("smoke test must not call Gemini")


httpx = types.ModuleType("httpx")
httpx.AsyncClient = _AsyncClient
sys.modules["httpx"] = httpx

# ---------- load the real backend with test env ----------
os.environ["ZARA_DATA_FILE"] = str(TMP / "data.json")
os.environ["ZARA_TOKEN"] = "master-token"
os.environ["GEMINI_API_KEY"] = ""

spec = importlib.util.spec_from_file_location("zara_server_main", HERE / "main.py")
main = importlib.util.module_from_spec(spec)
spec.loader.exec_module(main)

run = asyncio.run
MASTER = "Bearer master-token"
results = []


def check(label, condition):
    results.append((label, bool(condition)))
    print(("  PASS  " if condition else "  FAIL  ") + label)


def expect_401(coro):
    try:
        run(coro)
        return False
    except HTTPException as exc:
        return exc.status_code == 401


def main_tests():
    print("ZaRa backend smoke test")
    check("health reports auth_required", run(main.health())["auth_required"] is True)
    check("unauthenticated /devices rejected", expect_401(main.list_devices(None)))
    check("tool catalogue has 12 tools", len(run(main.list_tools(MASTER))["tools"]) == 12)

    time_result = run(main.execute_tool(main.ToolCallRequest(tool="get_time"), MASTER))
    check("get_time returns a reply", "বাজে" in time_result.message)

    unconfirmed = run(main.execute_tool(main.ToolCallRequest(tool="send_sms"), MASTER))
    confirmed = run(main.execute_tool(
        main.ToolCallRequest(tool="send_sms", args={"to": "123"}, confirmed=True), MASTER))
    check("send_sms needs confirmation", unconfirmed.needs_confirm is True)
    check("confirmed send_sms executes", "(নিশ্চিত)" in confirmed.message and "123" in confirmed.message)

    fuzzy = run(main.execute_tool(main.ToolCallRequest(tool="get_tiem"), MASTER))
    check("fuzzy suggestion for typo", "get_time" in fuzzy.message)

    run(main.add_memory(main.MemoryRequest(text="Amma ka naam Sita"), MASTER))
    facts = run(main.get_memory(MASTER))["facts"]
    check("memory persists a fact", any("Sita" in f["text"] for f in facts))

    run(main.sync_history(main.HistoryRequest(messages=[
        {"text": "namaste", "is_user": True},
        {"text": "namaste!", "is_user": False},
    ], replace=True), MASTER))
    history = run(main.get_history(MASTER))["messages"]
    check("history sync replaces messages", len(history) == 2)

    backup = run(main.export_data(MASTER))
    check("export contains facts + history", backup["facts"] and backup["history"])
    run(main.import_data(main.ImportRequest(facts=[{"text": "restored"}], history=[]), MASTER))
    restored = run(main.export_data(MASTER))
    check("import replaces stored data", len(restored["facts"]) == 1 and restored["facts"][0]["text"] == "restored")

    reg = run(main.register_device(main.DeviceRequest(name="Phone-2"), MASTER))
    device_token = "Bearer " + reg["token"]
    check("registered device token works", run(main.list_devices(device_token))["devices"])
    run(main.revoke_device(main.DeviceRequest(name="Phone-2"), MASTER))
    check("revoked token rejected", expect_401(main.list_devices(device_token)))

    summary = run(main.summarize(MASTER))
    check("empty-history summary falls back safely", "সংক্ষেপ" in summary["summary"])

    check(
        "backend prompt is Bengali-only",
        "বাংলা" in main.BENGALI_SYSTEM and "Hinglish" in main.BENGALI_SYSTEM,
    )
    check("model fallback chain is configured", len(main.GEMINI_MODELS) > 1)

    try:
        run(main.chat(main.ChatRequest(message="hi"), MASTER))
        no_key = False
    except HTTPException as exc:
        no_key = exc.status_code == 503
    check("chat without API key returns 503", no_key)

    failed = [label for label, ok in results if not ok]
    print(f"\n{len(results) - len(failed)}/{len(results)} checks passed.")
    return 0 if not failed else 1


if __name__ == "__main__":
    try:
        code = main_tests()
    finally:
        shutil.rmtree(TMP, ignore_errors=True)
    sys.exit(code)
