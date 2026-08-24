# Project context: DOOM on Azure — Infra Portfolio Project

**Brand/project name: MulzaTech** — use this name for the repo, docs site, and
any branding related to this infrastructure/platform-engineering portfolio work.
(Not to be confused with any unrelated personal projects the author has under a
similar-sounding name — this one is strictly infra/platform engineering.)

## What this project is

A hands-on infrastructure/platform-engineering practice project. The application
itself is intentionally simple and a bit fun: a containerized, browser-playable
version of the original DOOM (1993), running via a WebAssembly DOS emulator
(JS-DOS). **The point of the project is not the app — it's everything around it:**
containerization, Infrastructure as Code, CI/CD, cloud deployment, observability,
and operational best practices, applied like it's a real production system.

This is explicitly a learning exercise, not just a build task. Every time code or
configuration is proposed, it should come with a plain-language explanation of
what it does and why — enough to refresh or teach the underlying concept, not just
hand over working code.

The project will eventually be published as a public repo, alongside professional,
team-style documentation (see "Documentation practice" below). Nothing gets
published until it's in a working state.

## The application

- Game: original DOOM, **shareware episode** (freely distributable — not DOOM 2,
  whose WAD file is not legally free to redistribute).
- Runtime approach: **JS-DOS** (WebAssembly-based DOS emulation that runs in the
  browser). This was chosen over VNC/streaming-based approaches (e.g., noVNC,
  Kasm) because it's pure HTTP — no persistent VNC/websocket connection, no
  special container flags like `--shm-size`, and much smaller images (tens of MB
  vs. 900MB+). This matters because the app is going to run behind an Azure
  Container Apps ingress, where plain HTTP is the path of least resistance.
- The Dockerfile should be built from scratch for this project (a static file
  server + the js-dos runtime + the shareware WAD), rather than pulling an
  existing finished image — the point is to understand and own every layer of
  the container, not just run someone else's.

## Infrastructure decisions (already made)

- **Cloud:** Azure (user has a premium subscription).
- **Compute target:** Azure Container Apps — deliberately chosen as a middle
  ground between full PaaS (App Service) and full Kubernetes (AKS). Simpler to
  start with than AKS, closer to real production patterns than basic App Service.
- **IaC tool:** Terraform.
- **CI/CD platform:** Azure DevOps.
- **Environments:** single environment for now. Multi-environment (dev/test/prod)
  is a later, optional phase — not a day-one requirement.
- **Repo structure:** one repo containing both the application (Dockerfile +
  static assets) and the Terraform infrastructure code.

## Phased build plan

Rule across phases: **each phase must produce something visibly working before
the next one starts.** Don't work on two phases in parallel.

1. **Phase 0 — App skeleton.** Dockerfile serving DOOM shareware via JS-DOS,
   runnable locally with plain `docker run`.
2. **Phase 1 — Containerize + local dev.** Clean Dockerfile, docker-compose for
   local development, first real README section.
3. **Phase 2 — Terraform: minimum viable Azure environment.** Resource group,
   Container Apps Environment, one Container App, Key Vault. Goal: `terraform
   apply` produces a working public URL serving the game.
4. **Phase 3 — CI in Azure DevOps.** Build and validate the container image,
   push to a registry (e.g., ACR). No deployment yet.
5. **Phase 4 — CD in Azure DevOps.** Pipeline deploys via Terraform to the Phase
   2 environment. This is the real "it's live" milestone.
6. **Phase 5 — Observability.** Prometheus/Grafana or Azure Monitor +
   Application Insights (decide which when this phase starts), structured
   logging, at least one meaningful alert.
7. **Phase 6 — Hardening & best practices.** RBAC, network security rules,
   resource tagging, secret rotation patterns.
8. **Phase 7 — Multi-environment (optional).** Only if it adds value at that
   point — mirrors the dev/test/demo/prod pattern from the user's prior work
   experience.
9. **Phase 8 — AI layer connects in.** Separate, later repositories (e.g., a PR
   review agent) that operate on top of this repo from the outside. Out of
   scope until the flagship project is stable and deployed.

## Documentation practice

Alongside each phase, produce professional, team-style documentation — the kind
a real engineering team writes when starting a project from scratch:

- **Architecture Decision Records (ADRs)** — one short doc per significant
  decision: context, options considered, decision made. Already owed: ADR for
  Container Apps vs. AKS/App Service, ADR for JS-DOS vs. VNC-based approaches,
  ADR for DOOM shareware vs. Freedoom.
- **Per-phase design docs** — what the phase set out to do, what was built,
  tradeoffs encountered.
- **Resource/config reference** — what each Terraform resource does and why,
  written to double as a learning aid.
- **Runbooks** — added as the project matures (deploy steps, rollback,
  troubleshooting).

Target platform for publishing docs: **MkDocs Material (or Docusaurus) deployed
via GitHub Pages** — chosen deliberately over Notion/Confluence/GitBook because
it's docs-as-code (markdown in the repo, versioned with git), free with no
limits, and can itself be deployed via a CI/CD pipeline — which turns the docs
site into its own small platform-engineering exercise rather than an external
tool disconnected from the rest of the work.

## Working conventions

- Every code/config suggestion includes a plain-language explanation of what
  it does and why (see "learning exercise" above).
- Architecture decisions get discussed before being implemented, not decided
  unilaterally in code.
- Documentation gets produced alongside each phase, not retrofitted at the end.
- Do not add scope from later phases early (e.g., no multi-environment setup
  during Phase 2, no observability tooling before Phase 5).
- The user wants to type/paste code and config themselves rather than have
  files written wholesale. Default mode: explain the piece, hand over the
  snippet, let the user create/edit the file, then confirm before moving on.
  Only write files directly when the user explicitly asks for that (as with
  this file).
- Same hands-on principle extends to actually provisioning things: Terraform
  stays the IaC tool (per "Infrastructure decisions" above) and Claude still
  writes/explains the `.tf` files, but the user runs `terraform init/plan/apply`
  themselves in their own terminal rather than Claude executing it for them.
  Likewise for account/platform-level setup (Azure resources via the Portal
  where relevant, GitHub repo creation, GitHub Actions, Azure DevOps org/
  project/pipelines) — Claude gives step-by-step navigation/command
  instructions, the user performs the actual clicks/commands themselves.
- Git: as of the CI phase, the user handles all `git add`/`commit`/`push`
  themselves. Claude prepares the commit message and tells the user what to
  run, but does not execute git commit/push commands on their behalf.

## Current status

Phases 0, 1, and 2 complete and documented (`docs/phases/`). DOOM is live on
Azure Container Apps via Terraform (`infra/`), image pulled from public
Docker Hub (ADR 0004), deployed at:
https://mulzatech-doom--rdezegm.gentlesmoke-5d69cfd2.eastus.azurecontainerapps.io
Left running indefinitely (not destroyed between uses) — relies on Container
Apps' default scale-to-zero behavior to stay near-$0 while idle, since this
is a standing portfolio piece with a URL meant to stay stable, not a
throwaway dev sandbox. Next: Phase 3 — CI in Azure DevOps.

Working convention in effect since Phase 2: for anything that provisions or
configures real infrastructure/accounts (Terraform apply, Azure resources,
GitHub repo/Actions, Azure DevOps), Claude writes/explains, the user
executes — see "Working conventions" below.
