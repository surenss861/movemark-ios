# Railway logs: `SIGTERM` / `Stopping Container`

If deploy logs show:

- `Stopping Container`
- `npm error signal SIGTERM`
- `command sh -c node dist/index.js`

that usually means **the platform stopped the process** (redeploy, restart, or container recycle), **not** that Node threw an uncaught exception.

Typical **code** failures look more like: stack traces, `uncaughtException`, OOM, `Cannot find module`, or exit before any graceful stop.

The API handles **SIGTERM** / **SIGINT** by closing the HTTP server and exiting cleanly so in-flight requests can finish within a short window.

**Not related to iOS uploads:** room evidence and vault files use **Supabase Storage**, not this Railway service.

Worry about Railway health if you see **tight loops** (start → immediate SIGTERM → repeat) or health checks failing right after boot.

## CORS (`CORS_ALLOWED_ORIGINS`)

The API no longer uses `Access-Control-Allow-Origin: *`. Browser clients must send an `Origin` that appears in a comma-separated allowlist:

```bash
CORS_ALLOWED_ORIGINS=https://your-admin.example.com,http://localhost:5173
```

The native iOS app does not rely on CORS. If this variable is **unset**, browser cross-origin requests to the API will not receive permissive CORS headers.
