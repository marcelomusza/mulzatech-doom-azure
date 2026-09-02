# Phase 4: CD in Azure DevOps

## Goal

Close the loop from `git push` all the way to a redeployed live app,
automatically — the real "it's live via pipeline" milestone. Extends
Phase 3's CI (build/validate/push) with a Deploy stage that runs
`terraform apply` against the Phase 2 environment, deploying the exact
image tag CI just built.

## What was built

- **Remote Terraform state**, migrated off local disk onto an Azure
  Storage Account (`mulzatechtfstate`, resource group
  `mulzatech-tfstate-rg`, container `tfstate`) — a prerequisite for CD,
  since a pipeline agent has no access to a state file sitting on a
  laptop. Created manually via the Portal (a deliberate one-time exception
  to "everything is Terraform" — the storage account that *holds*
  Terraform's state can't be created *by* that same Terraform config,
  since nothing exists yet for the backend to point at).
- **`backend "azurerm" { ... }`** added to `providers.tf`, using
  `use_azuread_auth = true` — state access via Azure AD role assignment
  (`Storage Blob Data Contributor`), not a stored storage account key.
- **An Azure Resource Manager service connection** (`azure-mulzatech-doom`)
  in Azure DevOps, using Workload Identity Federation — no long-lived
  secret stored anywhere; Azure DevOps and Azure trust each other via a
  federated token exchanged at run time.
- **`azure-pipelines.yml` converted to two stages**: `Build` (unchanged
  from Phase 3) and a new `Deploy` stage that installs Terraform inline,
  runs `init`/`apply` via the service connection, and passes
  `-var="container_image=docker.io/marcelomusza/mulzatech-doom:$(Build.BuildId)"`
  — deploying the specific image Build just pushed, not the mutable
  `latest` tag (the exact concern flagged at the end of Phase 3).
- **A stable `admin_object_id` variable** replacing a dynamic
  `data.azurerm_client_config.current.object_id` reference for the Key
  Vault role assignment (see Troubleshooting #4).
- **A corrected `outputs.tf`**, now reading the app-level `ingress[0].fqdn`
  instead of the revision-specific `latest_revision_fqdn` (see
  Troubleshooting #5).

## Troubleshooting log

This phase had the deepest troubleshooting log of any so far — five real
issues, each teaching something that generalizes well beyond this project.

### 1. Service connection couldn't select "one resource group" during setup

**Symptom:** the Azure DevOps "New service connection" wizard forced a
choice between one specific resource group or "All," with no plain
"Subscription, unscoped" option visible.

**Cause:** a UI refinement layer on top of "Subscription" scope level, not
a real constraint — "All" *is* the unscoped subscription-wide option.

**Fix:** selected "All."

### 2. Newly-created service principal didn't show up in the role-assignment search

**Symptom:** searching by the app registration's exact Application
(client) ID in the storage account's "Add role assignment" → "Select
members" panel returned no results.

**Cause:** propagation delay — Azure AD directory search indexes used by
that particular picker can lag a few minutes behind actual object
creation.

**Fix:** confirmed the service principal existed via **Microsoft Entra ID
→ Enterprise Applications** (a different, faster-updating view), waited a
few minutes, retried the storage account search — it appeared.

### 3. `git commit`/`push` silently skipped the pipeline file

**Symptom:** after "pushing" the multi-stage pipeline YAML, a fresh CI run
still showed the old single-stage `steps:` structure — generic "Stage" /
"Job" names instead of the custom `Build/Deploy` names, confirmed by
fetching the file straight from GitHub's raw content and finding the old
Phase 3 version still live.

**Cause:** the commit was made from a subdirectory of the repo, not the
repo root — `git add`/`commit` from inside a subfolder only captures
changes within that subtree, silently excluding `azure-pipelines.yml` at
the root.

**Fix:** re-ran the edit/commit/push from the repo root. Worth
remembering: **whenever a pushed fix doesn't seem to take effect, verify
via GitHub's raw file content directly** rather than trusting the local
working tree — this is the second time in this project that technique
(see Phase 3, Troubleshooting #3) has been the fastest way to confirm
what's actually live.

### 4. Key Vault role assignment broke the moment a *different* identity ran Terraform

**Symptom:** the first CD run's `terraform apply` largely succeeded
(including the actual Container App image update) but failed with:
```
Error: unexpected status 403 (403 Forbidden) with error: AuthorizationFailed:
... does not have authorization to perform action
'Microsoft.Authorization/roleAssignments/delete' ...
```

**Cause:** `keyvault.tf`'s role assignment used
`principal_id = data.azurerm_client_config.current.object_id` — "whoever
is currently authenticated." That was always the human deploying manually
in Phase 2. The instant CD ran Terraform as the **service principal**
instead, that same expression resolved to a *different* ID, and Terraform
concluded the intended admin had changed — attempting to delete the old
role assignment and create a new one. The service principal doesn't hold
the `roleAssignments/delete` permission, so the destroy step failed
partway through.

**Lesson:** "current identity" data sources are for reading facts about
*whoever happens to be running Terraform right now* (like `tenant_id`,
which is genuinely the same regardless of identity) — never for defining
**who should have standing access**, which needs to be a stable, explicit
value that doesn't silently change when a different automated identity
takes over running `apply`.

**Fix:** added a pinned `admin_object_id` variable holding the human
owner's actual object ID, and pointed the role assignment at that instead.

**Silver lining:** Terraform's partial-apply behavior meant the Container
App's image update — the actual point of the run — had already succeeded
before this later resource failed. Confirmed via `az containerapp revision
list` that the new revision was live and healthy despite the pipeline
reporting a failure.

### 5. The "live URL" was never actually stable

**Symptom:** immediately after the first successful end-to-end CD deploy,
the previously-working public URL started returning Azure's own
"Container App - Unavailable" platform page (a 404, but not nginx's 404).

**Investigation:** `az containerapp revision list` showed the new revision
as `Healthy` / `Active` / 100% traffic — so the app itself was fine.
`az containerapp show --query properties.configuration.ingress.fqdn`
revealed the actual current hostname had **no revision suffix**, while the
URL that had been documented everywhere (in the README, CLAUDE.md, and the
Phase 2 doc) had one — an extra `--<random suffix>` segment.

**Root cause:** `outputs.tf` (written back in Phase 2) used
`azurerm_container_app.main.latest_revision_fqdn` — a hostname pointing at
one *specific* revision, which is exactly expected to change every time a
new revision deploys. What was actually wanted was
`azurerm_container_app.main.ingress[0].fqdn` — the stable, app-level
hostname that stays constant across revisions. This bug existed since
Phase 2 but was invisible until CD produced its first new revision and the
old revision-pinned URL stopped resolving.

**Fix:** corrected `outputs.tf` to read `ingress[0].fqdn`. No
infrastructure change needed — `terraform apply` reported zero resource
changes, just a corrected output value. Updated the URL everywhere it had
been documented (README, CLAUDE.md, Phase 2 doc, with a note explaining
the correction).

**Why this matters beyond fixing it:** this is exactly the failure mode
flagged as a risk back in the Phase 2 design doc's "keeping it running"
discussion — a URL shared with an interviewer that silently breaks. It
surfaced the first time it actually mattered (the first real CD deploy),
which is itself a small case for why getting to a working CD pipeline
early is valuable — Phase 2's local-only `apply` had run several times
without ever exercising the code path that exposed this.

## Tradeoffs and things deferred

- **`latest` is still pushed to Docker Hub alongside the build-ID tag**,
  even though Deploy no longer uses it — kept for now since the public
  Docker Hub listing benefits from a conventional `latest` tag for anyone
  pulling the image manually (per the "share with the community" goal
  behind [ADR 0004](../adr/0004-docker-hub-vs-acr.md)).
- **No rollback mechanism yet.** If a bad deploy ships, the fix today is
  "push a fix and let CD redeploy" — there's no one-click "redeploy the
  previous build ID" story. Reasonable to revisit once Phase 5/6
  (observability/hardening) exist to actually detect a bad deploy in the
  first place.
- **No approval gate before Deploy.** Every push to `main` deploys
  automatically with no manual confirmation step. Fine for a solo
  portfolio project; a real team project would likely want at least an
  optional approval check here.
