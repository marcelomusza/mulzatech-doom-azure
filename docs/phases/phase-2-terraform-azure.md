# Phase 2: Terraform — Minimum Viable Azure Environment

## Goal

Get `terraform apply` to produce a real, working, publicly reachable URL
serving DOOM — the first time this project touches actual cloud
infrastructure rather than `localhost`.

## What was built

```
infra/
  providers.tf   # Terraform + azurerm provider version pins, provider features
  variables.tf    # location, project_name, container_image
  main.tf          # resource group, Container Apps Environment, Container App
  keyvault.tf       # Key Vault (provisioned now, empty — see ADR 0004 note below)
  outputs.tf         # app_url
```

Deployed resources, in the order Terraform creates them:

| Resource | Purpose |
|---|---|
| `azurerm_resource_group` | Top-level container for everything below. Deleting it tears down the whole environment cleanly. |
| `azurerm_container_app_environment` | The shared boundary a Container App runs inside. Minimal here — no Log Analytics wired up (that's Phase 5 scope). |
| `azurerm_container_app` | The actual running app: pulls `marcelomusza/mulzatech-doom:latest` from public Docker Hub ([ADR 0004](../adr/0004-docker-hub-vs-acr.md)), external HTTP ingress on port 80, 0.25 vCPU / 0.5Gi memory. |
| `azurerm_key_vault` | Provisioned now with RBAC authorization, even though nothing needs a secret yet — a deliberate "learn the resource before you're under pressure to use it" choice (see Phase 2 discussion in chat / this doc's tradeoffs section). |
| `azurerm_role_assignment` | Grants the deploying user (via `data.azurerm_client_config`) the *Key Vault Administrator* role — without this, RBAC mode means nobody has access by default, not even the creator. |

**Result:** live and publicly reachable at
`https://mulzatech-doom.gentlesmoke-5d69cfd2.eastus.azurecontainerapps.io`,
serving the exact same image that was verified locally in Phase 0/1,
headers and all (`Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy`
confirmed present in production responses).

> **Correction (found in Phase 4):** `outputs.tf` originally read
> `latest_revision_fqdn` here, which produced a *revision-specific* URL
> (with an extra `--<suffix>` segment) rather than the stable app-level one
> shown above. It broke the first time CD deployed a new revision. See
> [phase-4-cd-azure-devops.md](phase-4-cd-azure-devops.md) for the fix and
> why it happened.

## A key design question: registry choice

The original phase plan didn't specify where the Container App's image
would come from. Settled via [ADR 0004](../adr/0004-docker-hub-vs-acr.md):
**public Docker Hub**, not Azure Container Registry — trading away the
"private registry + managed identity pull" pattern (a real production
practice) in exchange for zero extra infrastructure and the ability to
share the image publicly with the js-dos/DOS-emulation community. Flagged
as something to revisit in Phase 6 if practicing that pattern becomes a
goal later.

## A key design question: keeping it running vs. tearing it down

This deployment is meant to be a **standing, shareable portfolio piece**
(LinkedIn, interviews) — not a disposable dev sandbox. That changes the
right operational answer for "how do I avoid this costing money":

- **`terraform destroy` between uses was considered and rejected.** Azure
  Container Apps generates the public hostname with a semi-random
  component tied to the environment; destroying and recreating would very
  likely produce a **different URL** each time, breaking a link already
  shared with someone.
- **The actual answer: scale-to-zero, which requires no extra config.**
  Container Apps defaults to `minReplicas: 0` / `maxReplicas: 10` with a
  default HTTP scale rule — and `main.tf` never overrides that. Per
  Microsoft's own docs: *"You aren't billed usage charges if your container
  app scales to zero."* Because `ingress.external_enabled = true`, an
  incoming request automatically wakes a replica back up — no manual
  on/off toggle needed at all. The one honest trade-off: a brief cold-start
  delay on the first request after idling, typically a few seconds for an
  image this small.
- Net effect: the environment can simply stay applied indefinitely. At
  near-zero traffic, Container Apps' Consumption free grant and Key
  Vault's per-operation (no base fee) pricing keep this at effectively $0/
  month.

## Troubleshooting log

### Deprecated attribute: `enable_rbac_authorization`

The `azurerm` provider (v5) renamed several boolean flags to a consistent
`<noun>_enabled` pattern. `enable_rbac_authorization` →
`rbac_authorization_enabled`. The old name still works but warns; fixed
before ever applying.

### `MissingSubscriptionRegistration` on first apply

```
Error: creating Key Vault ...: unexpected status 409 (409 Conflict) with error:
MissingSubscriptionRegistration: The subscription is not registered to use
namespace 'Microsoft.KeyVault'.
```
(and the identical error for `Microsoft.App`.)

**Cause:** Azure subscriptions only come with a handful of resource
providers ("namespaces") pre-registered. Namespaces for services you
haven't used yet in that subscription — here, Container Apps
(`Microsoft.App`) and Key Vault (`Microsoft.KeyVault`) — need a one-time
registration before any resource of that type can be created.

**Fix:** Registered both namespaces via the Portal (Subscriptions → your
subscription → Resource providers → search → Register), waited for status
to flip to "Registered," then re-ran `terraform apply`. Terraform's state
already had the successfully-created resource group recorded, so the retry
only touched the two resources that had failed — no need to `destroy`
anything first. This is a one-time-per-subscription step; it won't
resurface on future applies.

## Tradeoffs and things deferred

- **Local Terraform state**, not a remote backend (e.g. Azure Storage
  Account). Reasonable for a solo project with nothing yet to coordinate
  across — worth revisiting once CI/CD (Phase 4) or multi-environment
  (Phase 7) needs multiple things touching the same state.
- **No Log Analytics / observability wiring** — explicitly Phase 5 scope.
- **Key Vault has no secrets in it yet.** Provisioned deliberately ahead of
  need, per the discussion above — it'll get something real to hold once a
  later phase introduces one (e.g. Phase 4 pipeline credentials, though
  those are more likely to live in Azure DevOps pipeline secrets per ADR
  0004's consequences, not Key Vault — Key Vault is for the *running app's*
  secrets, and the app doesn't have any config/secrets of its own).
- **No custom domain, no WAF/Front Door, no scaling tuned beyond
  Azure's defaults** — none of that is needed for a static-file-serving
  portfolio demo at this stage.
