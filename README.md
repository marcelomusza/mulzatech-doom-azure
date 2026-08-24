# MulzaTech — DOOM on Azure

A hands-on infrastructure/platform-engineering portfolio project. The app is
the original DOOM (1993) shareware episode, running entirely client-side in
the browser via a WebAssembly DOS emulator ([js-dos](https://js-dos.com/)) —
no game server, no VNC/streaming backend, just a static file server.

**Live demo:** https://mulzatech-doom--rdezegm.gentlesmoke-5d69cfd2.eastus.azurecontainerapps.io

**The app is intentionally simple. The point of the project is everything
around it:** containerization, Infrastructure as Code, CI/CD, cloud
deployment, and observability, built out phase by phase like a real
production system — and documented like one too. See [`docs/`](docs/) for
the architecture decisions and per-phase design docs behind each step.

## Status

**Phase 3 of 8** — see the full roadmap in [`docs/`](docs/) (or ask; it's
also tracked in this repo's project context). Each phase ships something
visibly working before the next one starts:

- [x] Phase 0 — App skeleton: DOOM playable via a plain `docker run`
- [x] Phase 1 — Clean Dockerfile, `docker compose` for local dev, this README
- [x] Phase 2 — Terraform: minimum viable Azure environment (see live demo above)
- [x] Phase 3 — CI in Azure DevOps: builds, validates, and pushes to [Docker Hub](https://hub.docker.com/r/marcelomusza/mulzatech-doom) on every push to `main`
- [ ] Phase 4 — CD in Azure DevOps (first real "it's live" milestone)
- [ ] Phase 5 — Observability
- [ ] Phase 6 — Hardening & best practices
- [ ] Phase 7 — Multi-environment (optional)
- [ ] Phase 8 — AI layer connects in (separate repo)

## Running it locally

Requires [Docker](https://www.docker.com/products/docker-desktop/).

**Option A — `docker compose` (recommended for local dev):**

```bash
docker compose up --build
```

Then open **http://localhost:8080**. Editing files under `app/public/`
reflects immediately on refresh — no rebuild needed, thanks to the volume
mount in `docker-compose.yml`.

**Option B — plain `docker build` / `docker run`** (this is what actually
ships — no compose, no dev conveniences, exactly what Phase 0 targeted):

```bash
cd app
docker build -t mulzatech-doom .
docker run -d -p 8080:80 mulzatech-doom
```

Either way, open http://localhost:8080, click the play button, and give it
a second or two to boot — you're running a full x86 DOS emulator compiled to
WebAssembly, executing the real 1993 DOOM binary.

> **No sound?** This is a known upstream limitation in js-dos's audio
> initialization timing, not a bug in this repo — see
> [`docs/phases/phase-0-app-skeleton.md`](docs/phases/phase-0-app-skeleton.md)
> for details.

## Project structure

```
mulzatech-doom-azure/
  app/
    Dockerfile        # builds the static-file-server image
    nginx.conf         # serves app/public/ with the headers js-dos needs
    public/             # everything actually shipped to the browser
      index.html
      js-dos/            # self-hosted js-dos v8 runtime (JS + WASM)
      doom.jsdos          # DOOM1.WAD + doom.exe + dosbox.conf, zipped
  docker-compose.yml   # local dev convenience only — not used in production
  docs/
    adr/                # Architecture Decision Records
    phases/              # per-phase design docs (what was built, tradeoffs)
```

## Why DOOM? Why js-dos? Why Container Apps?

Every non-obvious decision in this repo is written down as it's made — see
[`docs/adr/`](docs/adr/) for the reasoning behind the game data used (DOOM
shareware vs. Freedoom), the runtime approach (js-dos vs. VNC-based
alternatives), and the Azure compute target (Container Apps vs. AKS/App
Service).

## License note

This repo ships the original **DOOM shareware episode** (`DOOM1.WAD` and
`doom.exe`), which id Software has freely permitted redistribution of since
1993. It is not the full retail game. See
[`docs/adr/0003-doom-shareware-vs-freedoom.md`](docs/adr/0003-doom-shareware-vs-freedoom.md)
for details.
