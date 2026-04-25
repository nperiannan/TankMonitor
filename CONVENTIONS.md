# TankMonitor Repo Conventions

## Repository
- Monorepo: `controller_firmware/`, `web/`, `app/`
- Remote: https://github.com/nperiannan/TankMonitor.git
- Branch: `master`

## CRITICAL — Commit & Version Discipline
- **Every successful build must be immediately committed to git** — never leave built/tested changes uncommitted
- **Version strings must be updated BEFORE building**, not after — the binary must embed the correct version
- **AI agents must ALWAYS perform the full checklist below** when committing changes to any component, without waiting to be reminded
- After a successful build + test, the full checklist is:
  1. Update ALL version strings for the changed component (see list below)
  2. Update `README.md` versions table
  3. `git add` + `git commit` with descriptive message
  4. `git tag -a <component>/vX.Y.Z -m "..."` (annotated tag)
  5. `git push origin master && git push origin <tag>`
  6. Delete old GitHub release for that component, create new one via `gh release create`
  7. Rebuild binary/image for the changed component and deploy/install
- **Never let version strings drift** — the binary version, git tag, README table, and GitHub release must all agree
- **Do not skip the release checklist** — even for "small" changes like refactors or race condition fixes that affect user-facing behaviour

## Versioning & Tags
- Tag format: `controller_firmware/vX.Y.Z`, `web/vX.Y.Z`, `app/vX.Y.Z`
- **One release per component** — no combined multi-component releases
- Tags must be **annotated** (not lightweight): `git tag -a web/vX.Y.Z -m "..."`
- Version strings live in:
  - Firmware: `controller_firmware/include/Config.h` → `#define FW_VERSION`
  - Web backend: `web/backend/main.go` → `const webVersion`
  - Web frontend: `web/frontend/src/App.tsx` → `const WEB_APP_VERSION` ← must ALSO be bumped (hardcoded, not fetched from server)
  - App: Flutter `app/pubspec.yaml` → `version:` AND `app/lib/tank_service.dart` → `const mobileAppVersion` (both must be updated together)
- `README.md` versions table must also be updated on every bump

## GitHub Releases — IMPORTANT
- **Exactly one release per component** on the releases page at all times
- When creating a new release for a component, **always delete the previous release first**:
  ```bash
  gh release delete web/vX.Y.Z --yes   # delete old
  gh release create web/vX.Y.Z ...     # create new
  ```
- Release titles: `Controller Firmware vX.Y.Z`, `Web App vX.Y.Z`, `Mobile App vX.Y.Z`

## NAS Deployment (TNAS @ 192.168.0.102)
- Repo cloned at `/Volume1/docker/TankMonitor` with sparse-checkout (`web/` only)
- Docker build: `docker build -t tankmonitor-web web/` (run from monorepo root)
- Container **must** have `-e OTA_BASE_URL=http://192.168.0.102:1880`  
  The ER605 router has no hairpin NAT — without this the ESP32 (on LAN) cannot reach the public domain to download the firmware binary
- git binary: `/home/nperiannan/miniconda3/bin/git`
- docker binary: `/Volume1/@apps/DockerEngine/dockerd/bin/docker`
- Update one-liner (from Windows via plink): see `README.md` → *One-liner from Windows*

## OTA Flash Flow
1. Build firmware locally: `pio run -e nebulas3_serial` → binary at `controller_firmware/.pio/build/nebulas3_serial/firmware.bin`
2. Upload via web app **Firmware Update (OTA)** → **Upload firmware.bin**
3. Click **Flash to ESP32**
4. Backend publishes `ota_start` MQTT command with `OTA_BASE_URL`-based download URL
5. ESP32 fetches binary over HTTP and flashes itself, then reboots
6. Success detected when firmware version string changes in the next MQTT status message

> If OTA shows "failed" after 120 s — check that `FW_VERSION` in `Config.h` was actually bumped.  
> The backend detects success by watching for a version change; if the version didn't change, it times out.

## Keeping This File in Sync
- This file (`CONVENTIONS.md`) mirrors the AI session memory for this repo
- **Whenever a new rule or convention is established, update this file and push immediately**:
  ```bash
  git add CONVENTIONS.md
  git commit -m "docs: update CONVENTIONS.md — <what changed>"
  git push origin master
  ```

## Security — NEVER commit credentials without approval
- **NEVER commit passwords, tokens, secrets, or credentials to git without explicit user approval**
- Before committing any file that contains a password/secret (README, CONVENTIONS, docker-compose, shell scripts, `.env.example`), ask the user first
- Prefer placeholders: `YOUR_PASSWORD_HERE`, `<secret>`, etc.

## Git Notes
- `credential-winced` warning on push is harmless (typo in git credential helper config)
- Flutter auto-generated files (`app/linux/`, `app/macos/`, `app/windows/`) are not committed unless intentionally changed

## Terminal Hygiene
- Keep at most **1–2 terminal tabs** open at a time — close finished terminals immediately after use
- AI agents must not leave stray async terminals running after a task completes; call `kill_terminal` when done
- Before starting a new long-running command, check for and close idle terminals first
