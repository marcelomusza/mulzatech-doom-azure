# Phase 1: Containerize + Local Dev

## Goal

Take the working-but-rough Phase 0 setup and turn it into something a real
team would hand a new contributor: a Dockerfile that reflects deliberate
choices instead of just "whatever got it running," a `docker compose`
workflow for fast local iteration, and a README that explains what this
project is and how to run it — without needing to read the ADRs first.

## What changed

### Dockerfile

Two changes, both small but real production habits:

- **Pinned `nginx:alpine` → `nginx:1.31-alpine`.** The floating `alpine` tag
  currently resolves to nginx 1.31.4, but that's not guaranteed to stay
  true — a rebuild next month could silently pull a different major
  version. Pinning to the `1.31` minor version is a deliberate middle
  ground: reproducible enough that builds don't drift unexpectedly, loose
  enough to still receive patch-level fixes without editing the Dockerfile.
- **Added a `HEALTHCHECK`.** `curl -f http://localhost/` on a 30s interval,
  3s timeout, 5s start grace period, 3 retries before declaring the
  container unhealthy. This makes container health visible in `docker ps`
  today, and is the same underlying concept Container Apps health probes
  (Phase 2) and any future observability/alerting (Phase 5) will build on —
  introducing it now means it's one less new concept to absorb later.

### `docker-compose.yml`

Added at the repo root (a sibling of `app/`, since it's a whole-project dev
convenience and later phases add more siblings like `infra/`). The
meaningful addition over a plain `docker run` is the **volume mount**:

```yaml
volumes:
  - ./app/public:/usr/share/nginx/html:ro
```

This overlays the local `app/public/` folder directly onto the container's
web root. Verified it actually works by editing `index.html`'s `<title>`
while the container was running and confirming the change appeared on the
next request with **no rebuild, no restart**. That's the real payoff of
Phase 1's "local dev" goal — the difference between "runs in a container"
(Phase 0) and "pleasant to iterate on while it's containerized" (this
phase).

This is explicitly dev-only: production deployments (Phase 2+) won't use
compose at all, so they'll always run whatever was actually baked into the
image at build time — same as Phase 0.

### README

First real README, covering: what the project is and why (linking out to
the ADRs rather than re-explaining them), current phase status as a
checklist, both ways to run it locally (compose for dev, plain
build/run for what actually ships), the repo's folder structure, and a
license/attribution note for the bundled DOOM shareware files.

## Tradeoffs and things deferred

- **No `.dockerignore` yet.** The build context (`app/`) is small and clean
  right now, so it hasn't mattered. Worth adding once the repo has more
  files that shouldn't ride along into the build context (e.g. `infra/`
  once Terraform exists as a sibling — though a root-level `.dockerignore`
  wouldn't even apply to a build context scoped to `app/`, so this may
  simply never become necessary given the current structure).
- **No multi-stage build.** Nothing to compile or bundle — `app/public/` is
  already the final static output — so a multi-stage build wouldn't buy
  anything here. Revisit if that ever changes.
- **Image scanning and size optimization are Phase 3 (CI) territory,** not
  this phase — Phase 1's bar was dev ergonomics and a couple of honest
  production habits, not a hardened image.
