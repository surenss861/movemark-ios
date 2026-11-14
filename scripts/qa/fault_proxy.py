"""MoveMark QA — fault-injecting reverse proxy for physical-device tests (Neon dev only, local only).

    (cd movemark-api-py && .venv/bin/python ../movemork/scripts/qa/fault_proxy.py)

Listens on 127.0.0.1:8788 and forwards to the dev API on 127.0.0.1:8787; point the Quick Tunnel at 8788.
Faults are armed through ~/.movemark-qa/dev/fault.mode so the product code carries no test hooks:

    off                    forward everything (default)
    outage-second-finalize the second `.../finalize` call starts an API outage: it and every API request
                           for the next OUTAGE_SECONDS get 503, then traffic flows again (disarms itself)

Only MoveMark API traffic passes through here; the Data API, Neon Auth and presigned object PUTs go
straight from the phone to Neon, as they do in production.
"""
import pathlib
import time

import httpx
import uvicorn
from starlette.applications import Starlette
from starlette.requests import Request
from starlette.responses import Response
from starlette.routing import Route

UPSTREAM = "http://127.0.0.1:8787"
MODE_FILE = pathlib.Path.home() / ".movemark-qa/dev/fault.mode"
OUTAGE_SECONDS = 25
HOP_BY_HOP = {"connection", "keep-alive", "transfer-encoding", "upgrade", "host", "content-length"}

state = {"finalizes": 0, "outage_until": 0.0}
client = httpx.AsyncClient(base_url=UPSTREAM, timeout=60)


def log(msg: str) -> None:
    print(f"{time.strftime('%H:%M:%S')} {msg}", flush=True)


async def proxy(request: Request) -> Response:
    path = request.url.path
    mode = MODE_FILE.read_text().strip() if MODE_FILE.exists() else "off"
    now = time.monotonic()
    if mode != "outage-second-finalize":
        state["finalizes"] = 0  # count from the moment the fault is armed
    elif path.endswith("/finalize"):
        state["finalizes"] += 1
        if state["finalizes"] == 2:
            state["outage_until"] = now + OUTAGE_SECONDS
            MODE_FILE.write_text("off\n")  # one outage per arming
            log(f"OUTAGE START for {OUTAGE_SECONDS}s at {request.method} {path}")
    if now < state["outage_until"]:
        log(f"503 (outage) {request.method} {path}")
        return Response('{"error":"Service Unavailable"}', status_code=503, media_type="application/json")
    headers = {k: v for k, v in request.headers.items() if k.lower() not in HOP_BY_HOP}
    upstream = await client.request(request.method, path, params=request.query_params, headers=headers,
                                    content=await request.body())
    log(f"{upstream.status_code} {request.method} {path}")
    return Response(upstream.content, status_code=upstream.status_code,
                    headers={k: v for k, v in upstream.headers.items()
                             if k.lower() not in HOP_BY_HOP | {"content-encoding"}})  # httpx already decoded it


app = Starlette(routes=[Route("/{path:path}", proxy, methods=["GET", "POST", "PUT", "PATCH", "DELETE"])])

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8788, log_level="warning")
