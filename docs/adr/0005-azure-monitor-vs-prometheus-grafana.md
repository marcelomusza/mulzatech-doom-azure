# ADR 0005: Use Azure Monitor + Log Analytics instead of Prometheus + Grafana

## Status

Accepted

## Context

Phase 5 needs an observability stack: metrics, logs, and at least one
meaningful alert for the deployed Container App. The project plan
deliberately left this choice open until this phase started. Two
realistic options:

- **Azure Monitor + Log Analytics** — Azure's native observability
  platform. Container Apps already emits platform metrics (CPU, memory,
  request count, replica count, restart count) without any extra
  instrumentation; Log Analytics can additionally ingest the container's
  own stdout/stderr logs (nginx's access/error logs). Alerting is native
  via Azure Monitor alert rules + action groups.
- **Prometheus + Grafana** — the industry-standard, cloud-agnostic
  combination, widely used regardless of cloud provider. Azure offers
  managed versions of both (Azure Managed Prometheus, Azure Managed
  Grafana).

## Decision

Use **Azure Monitor + Log Analytics**, not Prometheus + Grafana. Skipped
Application Insights specifically within the Azure Monitor family — it's
built for instrumenting custom application code via SDKs (distributed
tracing, custom telemetry), and this app has no custom code to
instrument; it's a static file server.

## Rationale

- **Directly extends what's already built.** The Container Apps
  Environment (Phase 2) already has a `logs_destination` slot that was
  deliberately left unset at the time specifically to defer this decision
  to Phase 5. Wiring in a Log Analytics Workspace is a small, natural
  addition to existing Terraform, not a new subsystem bolted on
  sideways.
- **Effectively free at this project's traffic level.** Log Analytics has
  a genuine monthly free ingestion allowance; a low-traffic portfolio site
  won't come close to exceeding it. Azure Managed Grafana, by contrast,
  bills hourly regardless of usage — a real recurring cost for a project
  explicitly designed (see the Phase 2 design doc) to stay near-$0 while
  mostly idle.
- **Little for Prometheus's real strengths to actually monitor.**
  Prometheus's value is largely in custom application metrics and PromQL
  queries across many services. This app is a single static file server
  with no custom business logic — there's nothing app-specific to
  instrument beyond what Container Apps' platform metrics already surface
  natively.

## Consequences

- **A recognizable industry skill (Prometheus/Grafana) isn't practiced in
  this project.** Explicitly weighed and accepted — if that specific
  experience becomes a goal later, it's a reasonable candidate for a
  separate, purpose-built project where the app actually has custom
  metrics worth querying (e.g. a service with real business logic), rather
  than retrofitting it onto a static file server.
- Terraform gains: `azurerm_log_analytics_workspace`,
  `azurerm_monitor_diagnostic_setting` (routing Container App logs to it),
  `azurerm_monitor_action_group` (notification target), and at least one
  `azurerm_monitor_metric_alert`.
- The Container Apps Environment's `logs_destination` and
  `log_analytics_workspace_id` — left unset since Phase 2 — get set this
  phase, which Terraform will show as a change to that existing resource.
