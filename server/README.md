# ZaRa Backend (optional)

Python backend for ZaRa: Gemini proxy, tool executor, JSON-backed memory + history,
backup/export-import, device tokens and chat summary. The Flutter app keeps working
fully on-device when no backend URL is configured.

## Run

```sh
pip install -r requirements.txt
GEMINI_API_KEY="your-key" ZARA_TOKEN="master-secret" uvicorn main:app --reload --port 8000
```

`ZARA_TOKEN` is the **master token**. Set it to require auth; leave it unset for open mode.

## Endpoints

| Method | Path | Body / purpose |
|---|---|---|
| GET | `/health` | status, model, tool count, `auth_required` |
| POST | `/chat` | `{"message":"...","persona":"ZaRa"}` → `{"reply":"..."}` (Gemini proxy) |
| GET | `/tools` | tool catalogue (name, description, tier, confirm) |
| POST | `/execute` | `{"tool":"get_time","args":{},"confirmed":false}` → `{"tool":...,"message":...,"needs_confirm":...}` |
| GET/POST | `/memory` | list facts / add `{"text":"..."}` |
| GET/POST/DELETE | `/history` | sync messages: `{"messages":[{"text":"...","is_user":true,"at":"..."}],"replace":true}` |
| GET | `/export` | full backup JSON (`facts` + `history`) |
| POST | `/import` | `{"facts":[...],"history":[...]}` — replaces stored data |
| POST | `/devices/register` | `{"name":"Phone-2"}` → `{"token":"...","name":"..."}` |
| GET | `/devices` | registered devices (tokens never returned) |
| POST | `/devices/revoke` | `{"name":"Phone-2"}` → deactivate its token |
| POST | `/summary` | Gemini summary of last 40 messages → `{"summary":"..."}` |

## Auth (multi-device)

All endpoints except `/health` accept either:
- the master token (`ZARA_TOKEN`), or
- a token from `POST /devices/register` (created by presenting the master token once).

Revoke a device with `/devices/revoke`; its token stops working immediately.
In the Flutter app, Settings → Devices → Register creates a token and saves it as the
local Bearer token automatically.

## Persistence

Data lives in `zara_data.json` (`ZARA_DATA_FILE` overrides the path), written atomically
with a thread lock. **Backup** in Settings exports that data as JSON text; paste a previous
export into the Import box to restore.

## Flutter side

Settings → **Backend URL** (e.g. `http://192.168.1.5:8000`; emulator: `http://10.0.2.2:8000`).
Leave empty to use the on-device Gemini key and local-only data.
Debug builds allow cleartext HTTP (`usesCleartextTraffic="true"`); use HTTPS in production.
