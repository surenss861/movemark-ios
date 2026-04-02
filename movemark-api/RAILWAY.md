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
