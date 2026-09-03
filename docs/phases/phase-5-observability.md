# Phase 5: Observability

## Goal

Give the deployed app real observability: metrics and logs actually
flowing somewhere queryable, plus at least one meaningful alert — not
just "resources exist," but verified end-to-end (data actually landing,
notification actually delivering).

## What was built

- **[ADR 0005](../adr/0005-azure-monitor-vs-prometheus-grafana.md)** —
  Azure Monitor + Log Analytics, not Prometheus/Grafana. Full reasoning
  there; short version: directly extends what Phase 2 already deferred,
  effectively free at this traffic level, and there's little for
  Prometheus's real strengths (custom app metrics, PromQL) to actually
  monitor on a static file server with no custom code.
- **`infra/observability.tf`** — new file:
  - `azurerm_log_analytics_workspace` — the actual log store/query engine
    (`PerGB2018` consumption pricing, 30-day retention).
  - Two separate `azurerm_monitor_diagnostic_setting` resources (see
    Troubleshooting #2 for why two, not one) — one routing
    `ContainerAppConsoleLogs`/`ContainerAppSystemLogs` from the
    **environment**, one routing `AllMetrics` from the **container app**.
  - `azurerm_monitor_action_group` — an email receiver, the notification
    target for alerts.
  - `azurerm_monitor_metric_alert` — fires on the `RestartCount` metric
    exceeding `0` over a 5-minute window.
- **`infra/main.tf`** updated — the Container Apps Environment's
  `logs_destination`/`log_analytics_workspace_id`, left unset since Phase
  2 specifically to defer this decision here, now wired to the new
  workspace.

## Why `RestartCount`, not replica count or "is it running"

Worth being explicit about this choice: an alert on "0 replicas" would be
constant false-noise for this app. Scale-to-zero when idle is *expected,
intentional* behavior (see the Phase 2 design doc's discussion of keeping
the app cheap while staying reachable) — it happens routinely and doesn't
mean anything is wrong. `RestartCount`, by contrast, only increments when
a replica actually crashes or fails its Dockerfile `HEALTHCHECK` — a
genuinely meaningful "something is broken" signal that's orthogonal to
normal idle scaling.

## Troubleshooting log

### 1. `metric` block renamed to `enabled_metric`

**Symptom:** `Error: Unsupported block type ... Blocks of type "metric" are
not expected here.`

**Cause:** another `azurerm` v5 naming-consistency rename (same pattern as
Phase 2's `enable_rbac_authorization` → `rbac_authorization_enabled`) —
`metric` became `enabled_metric` to match the existing `enabled_log` block
naming.

**Fix:** renamed the block. A quick registry-docs check (verifying the
provider's actual current example usage) confirmed the correct name
before retrying, rather than guessing again.

### 2. Log categories rejected on the Container App resource

**Symptom:** `Error: ... 400 (400 Bad Request) ... "Category
'ContainerAppConsoleLogs' is not supported."`

**Cause:** `ContainerAppConsoleLogs` and `ContainerAppSystemLogs` are
emitted at the **Container Apps Environment** level (the shared platform
boundary), not the individual Container App resource — despite both being
valid `Microsoft.App/containerApps`-namespace metric/log names in Azure's
own reference docs, which don't make this environment-vs-app scoping
distinction obvious.

**Fix:** split into two diagnostic settings targeting two different
resources — logs against `azurerm_container_app_environment.main.id`,
metrics (`AllMetrics`, which *are* per-app) against
`azurerm_container_app.main.id`.

### 3. Nearly deployed a silent image rollback

**Not a bug — a near-miss worth documenting.** Running `terraform plan`
locally after adding the observability resources showed a *second*,
unrelated change: the Container App's image reverting from the specific
build tag CD had deployed (`:91`) back to `variables.tf`'s default
(`:latest`). Applying as-is would have silently downgraded the live image.

**Why it happened:** `container_image` only gets pinned to a specific
build when the CD pipeline passes `-var="container_image=...:$(Build.BuildId)"`
explicitly. A plain local `terraform apply` — with no `-var` override —
falls back to the variable's default, which is still `:latest`.

**Resolution:** rather than pass `-var` locally to route around it,
pushed the observability changes through the CD pipeline instead, which
always builds a fresh image and deploys that exact new tag — sidestepping
the drift question entirely rather than patching around it locally.

**Worth remembering going forward:** any *local* `terraform apply` against
this project needs `-var="container_image=..."` pointing at whatever's
actually currently deployed, or it should go through CD instead. This is
a direct, concrete illustration of the risk flagged in the Phase 3 design
doc's tradeoffs section about `latest` being a mutable, chaseable target.

## Verification (not just "it applied")

Confirmed all three pieces actually work, not just that Terraform reported
success:
- Queried the Log Analytics workspace directly
  (`az monitor log-analytics query`) and found real data: nginx's own
  console output (graceful shutdown messages during a revision swap) and
  platform system events (image pulls, container lifecycle, revision
  traffic-weight changes).
- Triggered a real test notification through the action group
  (`az monitor action-group test-notifications create`) and confirmed
  delivery — `"MechanismType": "Email", "Status": "Succeeded"`.

## Tradeoffs and things deferred

- **Only one alert.** `RestartCount` was chosen deliberately as the single
  most meaningful, lowest-noise signal available without custom
  instrumentation. A more mature setup might add a response-time or 5xx
  error-rate alert (queryable from the `Requests` metric's
  `statusCodeCategory` dimension) — reasonable Phase 6 territory once
  there's a case for it.
- **No dashboard/workbook.** Logs and metrics are queryable via KQL and
  the Portal's built-in metrics views, but nothing curated. Not needed yet
  for a single-app, single-environment project; would matter more with
  multiple environments (Phase 7) or more moving parts.
- **30-day log retention**, chosen as a reasonable default balancing
  "can actually debug something from last week" against storage cost —
  not tuned against any specific requirement, since there isn't one yet.
