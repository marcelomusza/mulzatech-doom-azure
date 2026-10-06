# ADR 0006: Key Vault stays on default public network access, RBAC-only

## Status

Accepted

## Context

Phase 6 hardening considered restricting Key Vault's network access (deny
public network access, allow only specific IP ranges) as a defense-in-depth
measure. Two things this project also needs, both already in place or
planned:

- The **CD pipeline** runs on Azure DevOps' Microsoft-hosted agents, which
  execute from a large, constantly-rotating pool of IP addresses with no
  fixed address to allowlist.
- A planned next step (giving Key Vault an actual purpose) has that same
  pipeline **read a secret from Key Vault** (the Docker Hub access token,
  replacing Azure DevOps' own service-connection credential storage).

## Decision

Leave Key Vault's network access at its default (public), and rely on
**RBAC alone** as the access control layer — not network restrictions.

## Rationale

- **Network ACLs and RBAC are independent, both-must-pass layers.** Even a
  correctly-scoped, fully-authorized identity gets blocked at the network
  layer if its calling IP isn't in the allowlist. A hosted CI agent with
  no stable IP can't practically satisfy an IP-based firewall rule.
- **Key Vault's "trusted Microsoft services" bypass doesn't cover Azure
  DevOps hosted agents.** That curated bypass list covers specific
  first-party Azure services (e.g. Azure Backup), not generic CI compute.
- **The correct network-level fix (Private Link + VNET integration) is a
  substantially larger scope jump than "harden what's already here."**
  This project's Container Apps Environment isn't VNET-integrated at all
  today; adding one specifically to let a CI agent through a firewall
  would mean standing up networking infrastructure whose only purpose is
  routing around a restriction we chose to add ourselves — solving a
  self-inflicted problem with disproportionate new complexity.
- **RBAC is already doing real, meaningful access control.** After
  the Phase 6 RBAC scope-down, exactly two identities can do anything
  with this vault: the project owner (Key Vault Administrator, scoped to
  just this vault) and the CD service principal (Contributor on
  `mulzatech-doom-rg` only, plus read-only `Key Vault Secrets User` on
  this vault, with no `roleAssignments/*` permissions at all). Nobody else — regardless of
  what network they're calling from — has a valid Azure AD identity that
  RBAC would authorize.

## Consequences

- Key Vault is reachable over the public internet at the network layer,
  though every request still must pass Azure AD authentication and RBAC
  authorization to do anything — an unauthenticated caller from any IP
  gets rejected by RBAC, not by a network rule.
- If this project ever adds VNET integration for the Container Apps
  Environment itself (a real, independent reason to have one — e.g. for
  network-level app isolation, not just to satisfy this ADR), revisiting
  Key Vault's network restriction with a Private Endpoint at that point
  would be free — the VNET would already exist for its own reason.
- This is a deliberate, documented tradeoff — not an oversight. Revisit if
  the CD pipeline ever moves to self-hosted agents with a stable, known
  IP range, which would make IP-based restriction practical again.
