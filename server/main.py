#!/usr/bin/env python3
"""Optional Python backend for ZaRa.

- Proxies Gemini requests so the Flutter client need not embed an API key.
- Tool catalogue / executor mirroring the Flutter app.
- JSON-backed memory + chat history, export/import backup.
- Device token registration (multi-device auth) on top of a master token.
- Gemini chat summarisation.

Run:  uvicorn main:app --reload --host 0.0.0.0 --port 8000
"""
import json
import os
import secrets
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="ZaRa Backend", version="0.3.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("ZARA_ALLOWED_ORIGINS", "*").split(","),
    allow_methods=["POST", "GET", "DELETE"],
    allow_headers=["*"],
)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
MASTER_TOKEN = os.getenv("ZARA_TOKEN", "")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")
# Clean-room fallback chain: quota/outage on one public model rolls to the next.
GEMINI_MODELS = [GEMINI_MODEL] + [
    model
    for model in (
        "gemini-2.5-flash-lite",
        "gemini-2.0-flash-lite",
        "gemini-flash-latest",
    )
    if model != GEMINI_MODEL
]

# Mirrors lib/core/services/language_policy.dart in the Flutter client. The
# backend must never answer in Hinglish even when the caller asks for it.
BENGALI_SYSTEM = (
    "তুমি ZaRa, একজন সংক্ষিপ্ত বাংলা-ভাষী ভয়েস অ্যাসিস্ট্যান্ট। "
    "সবসময় শুদ্ধ বাংলা ভাষায় উত্তর দাও। ইংরেজি বা Hinglish ব্যবহার করো না। "
    "উত্তর ছোট, প্রাকৃতিক এবং কথ্য বাংলা রাখো। প্রয়োজনে টুল ব্যবহার করো।"
)
BENGALI_TOOL_PROMPT = (
    'কোনো টুল লাগলে শুধু JSON দাও: {"tool":"name","args":{...}} — '
    "নাহলে সরাসরি বাংলা উত্তর দাও।"
)

# ---------- Persistent JSON store ----------
DATA_FILE = Path(os.getenv("ZARA_DATA_FILE", "zara_data.json"))
_store_lock = threading.Lock()


def _load_store() -> dict[str, Any]:
    if not DATA_FILE.exists():
        return {"facts": [], "history": [], "devices": []}
    try:
        data = json.loads(DATA_FILE.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        data = {}
    data.setdefault("facts", [])
    data.setdefault("history", [])
    data.setdefault("devices", [])
    return data


def _save_store(data: dict[str, Any]) -> None:
    tmp = DATA_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(DATA_FILE)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


# ---------- Auth: master token OR registered device token ----------
def _token_from_header(authorization: str | None) -> str:
    if not authorization:
        return ""
    return authorization[7:] if authorization.startswith("Bearer ") else authorization


def _check_auth(authorization: str | None) -> None:
    token = _token_from_header(authorization)
    if not MASTER_TOKEN and not token:
        return  # open mode when no token configured at all
    if token and token == MASTER_TOKEN:
        return
    with _store_lock:
        devices = _load_store()["devices"]
    if any(d.get("token") == token and d.get("active", True) for d in devices):
        return
    raise HTTPException(status_code=401, detail="invalid or revoked token")


# ---------- Tools (mirror of kTools) ----------
TOOLS: dict[str, dict[str, Any]] = {
    "get_time": {"description": "বর্তমান সময় বলো", "tier": 0, "confirm": False},
    "search_web": {"description": "ইন্টারনেটে তথ্য খুঁজো", "tier": 0, "confirm": False},
    "find_tool": {"description": "নাম দিয়ে টুল খুঁজো", "tier": 0, "confirm": False},
    "remember_fact": {"description": "তথ্য মনে রাখো", "tier": 0, "confirm": False},
    "recall_memory": {"description": "মনে রাখা তথ্য বের করো", "tier": 0, "confirm": False},
    "chat_text": {"description": "চ্যাটে বার্তা লেখো", "tier": 1, "confirm": False},
    "reply_to_chat": {"description": "সর্বশেষ চ্যাটে উত্তর দাও", "tier": 1, "confirm": True},
    "send_sms": {"description": "এসএমএস পাঠাও", "tier": 1, "confirm": True},
    "make_call": {"description": "ফোন কল করো", "tier": 1, "confirm": True},
    "send_email": {"description": "ইমেইল পাঠাও", "tier": 2, "confirm": True},
    "set_alarm": {"description": "অ্যালার্ম সেট করো", "tier": 1, "confirm": False},
    "play_music": {"description": "সঙ্গীত বাজাও", "tier": 1, "confirm": False},
}


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=8000)
    persona: str = "ZaRa"


class ChatResponse(BaseModel):
    reply: str


class ToolCallRequest(BaseModel):
    tool: str
    args: dict[str, Any] = Field(default_factory=dict)
    confirmed: bool = False


class ToolResult(BaseModel):
    tool: str
    message: str
    needs_confirm: bool = False


class MemoryRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)


class HistoryRequest(BaseModel):
    messages: list[dict[str, Any]] = Field(default_factory=list)
    replace: bool = False


class DeviceRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)


class ImportRequest(BaseModel):
    facts: list[dict[str, Any]] = Field(default_factory=list)
    history: list[dict[str, Any]] = Field(default_factory=list)


@app.get("/health")
async def health() -> dict:
    return {
        "ok": True,
        "model": GEMINI_MODEL,
        "key_configured": bool(GEMINI_API_KEY),
        "tools": len(TOOLS),
        "auth_required": bool(MASTER_TOKEN),
    }


# ---------- Devices ----------
@app.post("/devices/register")
async def register_device(
    payload: DeviceRequest,
    authorization: str | None = Header(default=None),
) -> dict:
    _check_auth(authorization)
    token = secrets.token_urlsafe(24)
    with _store_lock:
        store = _load_store()
        store["devices"].append({
            "name": payload.name,
            "token": token,
            "created_at": _now_iso(),
            "active": True,
        })
        _save_store(store)
    return {"token": token, "name": payload.name}


@app.get("/devices")
async def list_devices(authorization: str | None = Header(default=None)) -> dict:
    _check_auth(authorization)
    with _store_lock:
        devices = _load_store()["devices"]
    safe = [
        {"name": d.get("name"), "created_at": d.get("created_at"), "active": d.get("active", True)}
        for d in devices
    ]
    return {"devices": safe}


@app.post("/devices/revoke")
async def revoke_device(
    payload: DeviceRequest,
    authorization: str | None = Header(default=None),
) -> dict:
    _check_auth(authorization)
    with _store_lock:
        store = _load_store()
        changed = 0
        for d in store["devices"]:
            if d.get("name") == payload.name and d.get("active", True):
                d["active"] = False
                changed += 1
        _save_store(store)
    return {"ok": True, "revoked": changed}


# ---------- Tools ----------
@app.get("/tools")
async def list_tools(authorization: str | None = Header(default=None)) -> dict:
    _check_auth(authorization)
    return {"tools": [{"name": k, **v} for k, v in TOOLS.items()]}


@app.post("/execute", response_model=ToolResult)
async def execute_tool(
    payload: ToolCallRequest,
    authorization: str | None = Header(default=None),
) -> ToolResult:
    _check_auth(authorization)
    meta = TOOLS.get(payload.tool)
    if meta is None:
        prefix = sorted(TOOLS, key=lambda n: _distance(payload.tool, n))[:3]
        return ToolResult(
            tool=payload.tool,
            message=f"অজানা টুল: {payload.tool}। হয়তো: {', '.join(prefix)}",
        )
    if meta["confirm"] and not payload.confirmed:
        return ToolResult(
            tool=payload.tool,
            message=f"নিশ্চিত করুন: {meta['description']}?",
            needs_confirm=True,
        )
    return ToolResult(tool=payload.tool, message=_run_tool(payload.tool, payload.args))


def _run_tool(name: str, args: dict[str, Any]) -> str:
    if name == "get_time":
        return f"এখন {datetime.now():%H:%M} বাজে।"
    if name == "find_tool":
        query = str(args.get("query", "")).lower()
        hits = [n for n in TOOLS if query and query in n]
        return "টুল: " + ", ".join(hits[:5]) if hits else "কোনো টুল পাওয়া যায়নি।"
    if name == "remember_fact":
        fact = args.get("fact")
        if not fact:
            return "কী মনে রাখব?"
        with _store_lock:
            store = _load_store()
            store["facts"].append({"text": str(fact), "at": _now_iso()})
            _save_store(store)
        return f"মনে রাখব: {fact}"
    if name == "recall_memory":
        query = str(args.get("query", "")).lower()
        with _store_lock:
            facts = _load_store()["facts"]
        if not facts:
            return "এখন কিছু মনে নেই।"
        if query:
            facts = [f for f in facts if query in f["text"].lower()]
        if not facts:
            return "কিছু পাওয়া যায়নি।"
        return "মনে আছে: " + " | ".join(f["text"] for f in facts[-5:])
    if name == "play_music":
        return f"বাজাচ্ছি: {args.get('query', 'সঙ্গীত')}"
    if name == "set_alarm":
        return f"{args.get('time', '?')}-এ অ্যালার্ম সেট করা হয়েছে।"
    if name in {"chat_text", "reply_to_chat", "send_sms", "send_email", "make_call"}:
        target = args.get("to") or args.get("chat") or "অজানা"
        return f"{name} → {target} (নিশ্চিত)"
    return f"টুল {name} এখন পাওয়া যাচ্ছে না।"


def _distance(a: str, b: str) -> int:
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


async def _gemini(system: str, user_text: str) -> str:
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=503, detail="GEMINI_API_KEY not configured on server")
    body = {
        "contents": [{"role": "user", "parts": [{"text": f"{system}\n\n{user_text}"}]}],
        "generationConfig": {"temperature": 0.4, "maxOutputTokens": 1024},
    }
    last_error = ""
    async with httpx.AsyncClient(timeout=25.0) as client:
        for model in GEMINI_MODELS:
            url = (
                "https://generativelanguage.googleapis.com/"
                f"v1beta/models/{model}:generateContent"
            )
            response = await client.post(
                url, params={"key": GEMINI_API_KEY}, json=body
            )
            if response.status_code == 200:
                data = response.json()
                try:
                    return data["candidates"][0]["content"]["parts"][0]["text"]
                except (KeyError, IndexError, TypeError):
                    return "কোনো উত্তর পাওয়া যায়নি।"
            last_error = f"Gemini error {response.status_code}: {response.text[:120]}"
            if response.status_code not in (429, 500, 502, 503, 504):
                break
    raise HTTPException(status_code=502, detail=last_error or "Gemini unavailable")


@app.post("/chat", response_model=ChatResponse)
async def chat(
    payload: ChatRequest,
    authorization: str | None = Header(default=None),
) -> ChatResponse:
    _check_auth(authorization)
    system = (
        f"{BENGALI_SYSTEM} বর্তমান persona: {payload.persona}। "
        f"{BENGALI_TOOL_PROMPT}"
    )
    return ChatResponse(reply=await _gemini(system, payload.message))


# ---------- Memory + history ----------
@app.get("/memory")
async def get_memory(authorization: str | None = Header(default=None)) -> dict:
    _check_auth(authorization)
    with _store_lock:
        facts = _load_store()["facts"]
    return {"facts": facts}


@app.post("/memory")
async def add_memory(
    payload: MemoryRequest,
    authorization: str | None = Header(default=None),
) -> dict:
    _check_auth(authorization)
    with _store_lock:
        store = _load_store()
        store["facts"].append({"text": payload.text, "at": _now_iso()})
        _save_store(store)
    return {"ok": True, "count": len(store["facts"])}


@app.get("/history")
async def get_history(authorization: str | None = Header(default=None)) -> dict:
    _check_auth(authorization)
    with _store_lock:
        history = _load_store()["history"]
    return {"messages": history}


@app.post("/history")
async def sync_history(
    payload: HistoryRequest,
    authorization: str | None = Header(default=None),
) -> dict:
    _check_auth(authorization)
    with _store_lock:
        store = _load_store()
        if payload.replace:
            store["history"] = []
        for msg in payload.messages:
            store["history"].append({
                "text": str(msg.get("text", "")),
                "is_user": bool(msg.get("is_user", False)),
                "at": msg.get("at") or _now_iso(),
            })
        _save_store(store)
        count = len(store["history"])
    return {"ok": True, "count": count}


@app.delete("/history")
async def clear_history(authorization: str | None = Header(default=None)) -> dict:
    _check_auth(authorization)
    with _store_lock:
        store = _load_store()
        store["history"] = []
        _save_store(store)
    return {"ok": True}


# ---------- Backup / export / import ----------
@app.get("/export")
async def export_data(authorization: str | None = Header(default=None)) -> dict:
    _check_auth(authorization)
    with _store_lock:
        store = _load_store()
    return {
        "app": "ZaRa",
        "version": 1,
        "exported_at": _now_iso(),
        "facts": store["facts"],
        "history": store["history"],
    }


@app.post("/import")
async def import_data(
    payload: ImportRequest,
    authorization: str | None = Header(default=None),
) -> dict:
    _check_auth(authorization)
    with _store_lock:
        store = _load_store()
        store["facts"] = list(payload.facts)
        store["history"] = list(payload.history)
        _save_store(store)
    return {"ok": True, "facts": len(store["facts"]), "history": len(store["history"])}


# ---------- Chat summary ----------
@app.post("/summary")
async def summarize(authorization: str | None = Header(default=None)) -> dict:
    _check_auth(authorization)
    with _store_lock:
        history = _load_store()["history"]
    if not history:
        return {"summary": "এখন সংক্ষেপ করার মতো কোনো চ্যাট নেই।"}
    transcript = "\n".join(
        f"{'User' if m.get('is_user') else 'ZaRa'}: {m.get('text', '')}"
        for m in history[-40:]
    )
    summary = await _gemini(
        "নিচের কথোপকথনটি ৩–৫টি ছোট বাংলা বুলেটে সংক্ষেপ করো। "
        "শুধু সারাংশ দাও, কোনো ভূমিকা বা ব্যাখ্যা নয়।",
        transcript,
    )
    return {"summary": summary}
