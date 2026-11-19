# Production SQL access audit — 2026-10-22

Read-only audit after migrations 0950–0980 were executed on Neon production outside `neon/migrate.py`
(incident record: `docs/database-production-readiness.md`). Nothing in production was changed by this audit.

## Incident windows

Production compute was awake at **07:38–07:44Z, 08:26–08:31Z and 08:42–08:48Z** (03:38, 04:26 and 04:42
Toronto time), within minutes of each migration file being written or committed on the development Mac.
Catalog transaction IDs show the 0950/0970 objects predate the runner's ledger rows. The pre-incident state
is preserved as branch `production-out-of-band-2026-10-22` (`br-quiet-dust-b5dxh8dp`); keep it until the
source is found, the security gate passes and backups are operational.

## What was checked

| Mechanism | Finding | Could have executed the SQL? |
|---|---|---|
| Neon Postgres logs | No `pg_endpoint` log records exist for any window (only Object Storage logs are collected) | Can't tell. **No connection log exists, which is itself a gap** |
| Neon CLI on the Mac | Authenticated with the account's OAuth login (`~/.config/neon/credentials.json`); can fetch the owner DSN for any branch | Yes, capable. But no shell history references production, and the runner's guards resolve correctly |
| Neon API keys | None (account or organization `org-dry-resonance-69011826`) | No |
| Repository scripts | Every reference to production is a refusal guard or a sanctioned, flag-gated path (`neon/migrate.py`; `runtime_roles.py` and `backup.py` behind `--production --confirm`) | No |
| `.env` / DSN files (`~/.movemark-qa`, `~/.movemark-dr`, repos) | All point at the dev endpoint (`ep-quiet-salad`); none names production | No |
| Claude Code sessions on the Mac | A **Neon MCP server** (`https://mcp.neon.tech/mcp`) is configured; no local session transcript contains any Neon MCP tool call | Not from this Mac. A hosted session (claude.ai or another provider's connector) would not appear here |
| Claude Desktop / VS Code / Cursor | No Neon or Postgres MCP/configuration (one unrelated MSSQL extension) | No |
| GitHub Actions | 6 workflows; none references Neon, `psql`, `migrate.py` or `DATABASE_URL`; neither repository has secrets | No |
| cron / launchd | No crontab. LaunchAgents include **OpenClaw gateway** (running, with the user's PATH including the Neon CLI and `psql`) and **ChatGPT Atlas** | OpenClaw is capable, but its logs show only iMessage activity in all three windows. Atlas's agent mode can operate the Neon console; not inspected (browser history is the user's to check) |
| Railway | CLI logged out on this Mac, so variables and jobs could not be inspected | Unknown. Railway still points at Supabase, but check its variables for any Neon DSN |

**Unresolved:** the source is not on this Mac's recorded surfaces. The remaining candidates are the Neon
console SQL editor (by a person or a browser agent), a hosted assistant with a Neon connector, or another
machine. Fastest leads: browser history for `console.neon.tech` around 03:38 and 04:26 Toronto time; the
activity history of any assistant with a Neon integration; Neon console → Account → connected apps.

## Who can change production's schema today

The production schema is owned by `neondb_owner`. Anyone who can obtain that credential can run DDL, and
these can obtain it:

- the Neon console;
- the Neon CLI or API with the account's login;
- any Neon MCP/connector authorized on the account.

Runtime roles cannot run DDL. `movemark_api`/`movemark_worker` have no ownership or CREATE, and have no
password on production until the cutover.

## Controls to reach the target ("only the migration owner + `neon/migrate.py`")

1. **De-authorize Neon connectors** in every assistant that has one (claude.ai connectors; any ChatGPT/Atlas
   integration). Remove or leave unauthorized the `Neon` MCP entry in Claude Code. Neon console → connected
   OAuth apps: revoke anything not needed.
2. **Stop browser agents operating the Neon console.** Treat the SQL editor on production as off-limits;
   schema changes go only through `neon/migrate.py`.
3. **Continuous drift detection.** Schedule `neon/migrate.py … check` against production (with the backup
   job, or a separate Railway cron using a read-only connection) and alert on any non-zero exit. The runner
   now refuses to apply on top of drift, so a repeat would block, not compound.
4. **Rotate the production `neondb_owner` password** once the source is closed, and keep the migration
   credential out of every runtime environment (Railway gets only `movemark_api`/`movemark_worker`).
5. **Collect Postgres logs for production** (Neon log export/OpenTelemetry integration, with connection
   logging) so a future change is attributable to a user, application and address.
6. **Neon plan features** worth enabling when available: a protected production branch and an IP allow list
   (restricting the owner to known hosts).

## Second incident — 0990 + 1000, 2026-10-22 (after the PITR repair)

Found by the runner's drift check before applying (nothing was applied; production was not changed).

- Production holds every 0990/1000 object: the 3 new indexes (and the 2 old ones dropped), the 5 functions
  with bodies byte-identical to dev, and their EXECUTE grants to `authenticated`. The ledger still ends at
  0980, so `check` exits 1.
- Catalog xids 11319–11338 are later than the runner's 0980 ledger row (11274, 09:22:40Z).
  `pg_stat_statements` (reset 09:24:12Z) shows each statement run **once, as `neondb_owner`**, with no
  ledger insert. It also shows only 1000's text for `get_vault_summaries`: 0990's own definition never
  ran. So it happened **after 10:10Z**, when 1000 was written. Someone assembled the end state rather
  than running the files in order. The repository's commits reached GitHub at 10:49:17Z; the drift was
  seen at ~11:05Z.
- Not from this Mac's recorded surfaces: no Claude Code session ran production SQL in the window, and
  OpenClaw logged only iMessage restarts. No Neon operations exist after 09:24Z, as expected with
  scale-to-zero off.
- Same signature as the first incident: the repository's migration SQL, applied minutes after it appears,
  as the owner, bypassing the runner. The actor evidently reads this project's progress (local files,
  pushed commits or session reports) and holds owner access to production.

### Source channel identified (11:23Z read-only check)

- Production had a live session: `neondb_owner`, `application_name = neon-internal-sql-editor`, client
  `10.70.71.69` (Neon-internal), opened **11:14:56Z**. Its last statement, at 11:14:57Z, was 1000's
  `CREATE OR REPLACE FUNCTION public.get_vault_summaries()`, which bumped that function's xmin to 11452
  after the 11:08Z check. `pg_stat_statements` also holds 0990's own `auth.user_id()` version, run once.
- That application name is the **Neon console SQL editor**, which runs as the owner from inside Neon's
  network. That fits both incidents: no local trace, no Neon API keys, no CLI history. Whoever or whatever
  drives it is signed in to the Neon console as the account owner: a person, a browser agent operating
  the console, or Neon's in-console assistant.
- On this Mac, Chrome is the only browser running (since 2026-10-21 20:51 local); ChatGPT Atlas is not running.
- Inventory: Neon user/org API keys — none; org members — the owner only; Claude Code `Neon` MCP —
  configured but unauthenticated; Cursor MCP — Vercel only; no Neon editor extension; Codex inactive since
  2026-10-07; no crontab; GitHub repos have no repository secrets, and their environment secrets
  (`MoveMark`, `production`) aren't listable with this token; no file on disk holds a production password.
