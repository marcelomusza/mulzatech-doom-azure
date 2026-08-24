# ADR 0004: Use public Docker Hub instead of Azure Container Registry

## Status

Accepted

## Context

Azure Container Apps needs to pull the application's container image from
somewhere. The original phase plan (Phase 2: minimum viable Azure
environment) didn't settle this — its resource list (resource group,
Container Apps Environment, Container App, Key Vault) has no registry, and
Phase 3 only says "push to a registry (e.g., ACR)," leaving the choice open.

Two realistic options:

- **Azure Container Registry (ACR)** — a private, Azure-native registry.
  Would be provisioned via Terraform alongside the rest of the environment.
  Supports pulling into Container Apps via managed identity, with no
  registry credentials stored anywhere — a common real-world production
  pattern.
- **Public Docker Hub** — free, no additional Azure resource, and the image
  can be shared publicly with the DOS-emulation/js-dos community.

## Decision

Use **public Docker Hub** as the registry for this project.

## Rationale

- The bundled game data (`DOOM1.WAD`, `doom.exe`) is the freely
  redistributable shareware release (see
  [ADR 0003](0003-doom-shareware-vs-freedoom.md)), so there's no legal
  barrier to publishing the built image publicly.
- No extra Azure resource or cost.
- Directly supports a goal the author has for this project: sharing a
  purpose-built "DOOM via js-dos, containerized" image with the community,
  rather than keeping it locked inside a private registry only this project
  can see.
- Container Apps can pull a public image with zero registry authentication
  configured — simpler Terraform for Phase 2.

## Consequences

- **A real production pattern gets skipped for now:** pulling from a
  private registry via managed identity (no stored credentials) is a
  standard hardening practice this project won't get to practice through
  its primary registry. This was explicitly weighed against the decision
  above and accepted as a reasonable trade-off given the sharing goal.
- **Revisit in Phase 6 (Hardening).** If practicing private-registry /
  managed-identity pull patterns becomes a goal later, the plan is to add a
  private ACR as a secondary, non-public mirror at that point — Docker Hub
  would remain the public-facing source of the image regardless.
- Phase 3's CI pipeline will build and `docker push` to Docker Hub (not
  ACR). Credentials for that push (a Docker Hub access token) will need to
  live in Azure DevOps pipeline secrets — not Key Vault, since Key Vault is
  provisioned for the *running application's* secrets, not CI credentials.
- The Container App resource in Terraform references a public Docker Hub
  image reference directly (e.g. `docker.io/<namespace>/mulzatech-doom:tag`)
  with no `registry` credentials block needed.
