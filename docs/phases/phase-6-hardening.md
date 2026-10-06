# Phase 6: Hardening & Best Practices

## Goal

CLAUDE.md lists four hardening areas: RBAC, network security rules,
resource tagging, and secret rotation patterns. As written they're
abstract, so this phase translated each into a concrete action that fits
what this project actually is (a deliberately public static site, deployed
by a CI/CD pipeline running on ephemeral hosted agents).

## What was done

### 1. Resource tagging

`infra/locals.tf` defines one shared tag set (`project`, `managed_by`,
`environment`), applied via `tags = local.common_tags` to every resource
that supports tags: resource group, Container Apps Environment, Container
App, Key Vault, Log Analytics workspace, and action group. The two
diagnostic settings and the metric alert don't support tags — they're
configuration attachments, not standalone resources.

### 2. RBAC scope-down for the CD service principal

Phase 4 created the Azure Resource Manager service connection with
subscription-wide scope (`All` resource groups), because at the time we
didn't know exactly what it would need. In practice it only ever touches
`mulzatech-doom-rg`.

Removed the subscription-level Contributor assignment and re-granted
Contributor on **just that resource group**. Verified with
`az role assignment list --assignee <app-id> --all`: the service
principal's assignments are now exactly:

| Role | Scope |
|---|---|
| Contributor | `mulzatech-doom-rg` |
| Storage Blob Data Contributor | the `mulzatechtfstate` storage account only |
| Key Vault Secrets User | the Key Vault only (added in item 4 below) |

A full CD deploy ran green under the narrower scope.

### 3. Key Vault network access — deliberately *not* restricted

Considered denying public network access to Key Vault. Decided against it:
Azure DevOps' Microsoft-hosted agents have no stable IP to allowlist, and
aren't in Key Vault's "trusted Microsoft services" bypass. The real fix
(Private Link + VNET) would mean building networking infrastructure whose
only purpose is routing around a restriction we added ourselves. RBAC
remains the sole access control layer. Full reasoning in
[ADR 0006](../adr/0006-key-vault-network-access.md).

The other half of the "network security rules" item — restricting access to
the app itself — doesn't apply: the game is public by design.

### 4. Key Vault gets a real job: the Docker Hub token

The vault had sat empty since Phase 2, provisioned "ahead of need." It now
holds the Docker Hub access token as a secret (`dockerhub-token`).

- The pipeline's new `AzureKeyVault@2` step fetches the secret at runtime
  using the existing `azure-mulzatech-doom` service connection.
- The `Docker@2` push task (which authenticated through the Azure DevOps
  service connection's own credential store) was replaced with an explicit
  `docker login --password-stdin`, `docker push` of both tags, and
  `docker logout`. The token reaches the script through an `env:` mapping,
  not inline in the script text, and Azure DevOps masks it in logs.
- The old `dockerhub-mulzatech` service connection was deleted and the old
  Docker Hub token revoked, so exactly **one** copy of the credential
  exists, in Key Vault.

Verified from the Build log: the Key Vault step prints the vault and secret
*name* (never the value), `Login Succeeded`, and both pushed tags report the
identical digest.

## Secret rotation procedure

Rotation is now a three-step manual process, not a pipeline change:

1. Docker Hub → Account Settings → Security → generate a new access token
   (Read & Write).
2. Key Vault → Secrets → `dockerhub-token` → **New Version**, paste the new
   token.
3. Delete the old token on Docker Hub.

The pipeline always reads the latest version of the secret, so no code or
pipeline edit is needed. Not automated: Docker Hub tokens can't be rotated
through Azure natively, so automating this would need custom tooling for a
single low-risk credential.

## Troubleshooting log

### 1. Local `terraform plan` tried to roll back the live image — again

The tagging plan showed the Container App image reverting from `:94` to
`:latest`, the same near-miss from Phase 5: a local plan with no
`-var="container_image=..."` falls back to the variable's default. Same
resolution: push through CD instead of applying locally.

### 2. CD couldn't create a role assignment — and my earlier advice caused it

The first attempt at item 4 managed the Key Vault role grant in Terraform:
an `azurerm_role_assignment` giving the CD service principal
`Key Vault Secrets User`. The pipeline's `terraform apply` failed:

```
AuthorizationFailed: ... does not have authorization to perform action
'Microsoft.Authorization/roleAssignments/write' ...
```

**Cause:** the built-in Contributor role deliberately excludes
`Microsoft.Authorization/*/write`. When scoping the service principal down
I had said plain Contributor was "genuinely sufficient for everything CD
does." That was only true for resources that *already exist* — the existing
Key Vault admin assignment never changes between applies. Adding a **new**
role assignment needs a permission Contributor doesn't have. The advice
was wrong for this case.

**Options:** give the pipeline `User Access Administrator` (or
`Role Based Access Control Administrator`), or keep grants out of the
pipeline.

**Decision:** keep them out. A pipeline that can grant roles can grant
*itself* more access, so a compromised pipeline could escalate its own
privileges — the opposite of this phase's goal. Backed the resource out of
Terraform and created the role assignment by hand in the Portal.

**Principle adopted: privilege grants are done by a human, never by the
pipeline.** The existing `kv_admin` assignment already followed this
pattern (created by a human running Terraform locally); this just makes it
explicit.

**Cost:** the `Key Vault Secrets User` assignment lives outside Terraform —
a deliberate, documented exception, like the state storage account. If it's
ever deleted, nothing in the repo will recreate it; this doc is the record.

## Tradeoffs and things deferred

- **Contributor on the resource group is still broad.** It's far narrower
  than subscription-wide, and the pipeline needs to create and modify
  several resource types in that group, but a custom role listing exactly
  those actions would be tighter. Reasonable future refinement, not worth
  the maintenance for a single-app project today.
- **One manually-created role assignment** (above) sits outside IaC.
- **Key Vault is reachable at the network layer** (ADR 0006) — mitigated by
  Azure AD auth plus tightly-scoped RBAC, not by a firewall.
- **No automatic secret rotation**, for the reason given above.
- **No image vulnerability scanning in CI** — still open from Phase 3's
  tradeoffs; a natural next hardening addition.
