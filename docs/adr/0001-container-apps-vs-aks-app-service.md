# ADR 0001: Use Azure Container Apps instead of AKS or App Service

## Status

Accepted

## Context

The application (a containerized, browser-playable DOOM) needs a compute
target on Azure. The point of this project is not the app itself but the
surrounding platform-engineering practice — containerization, IaC, CI/CD,
observability — applied the way a real production system would be built.
The compute target needs to support that goal without either oversimplifying
the exercise or burying it in unrelated operational complexity.

Three realistic options exist on Azure for running a containerized web app:

- **Azure App Service (Web App for Containers)** — fully managed PaaS.
  Point it at a container image and it runs. Very little infrastructure to
  reason about: no cluster, no networking model to design, minimal knobs.
- **Azure Kubernetes Service (AKS)** — full Kubernetes. Maximum control and
  closest to what large-scale production systems actually run, but the
  operational surface (node pools, networking/CNI choices, ingress
  controllers, RBAC, cluster upgrades, etc.) is large enough to become its
  own project.
- **Azure Container Apps (ACA)** — a serverless-ish container platform built
  on Kubernetes/KEDA under the hood, but exposing a much smaller surface:
  container apps, revisions, ingress, scaling rules, and a Container Apps
  Environment, without needing to manage a cluster directly.

## Decision

Use **Azure Container Apps** as the compute target for this project.

## Options considered

| Option | Why not chosen as primary |
|---|---|
| App Service | Too close to "just deploy it" — not enough infrastructure surface to practice IaC, networking, or scaling concepts against. Would undersell the learning goals of the project. |
| AKS | Realistic for large production systems, but the operational overhead (cluster lifecycle, node pools, networking/CNI, ingress controller choice, RBAC at the cluster level) is a project of its own. Introducing it here would compete with, rather than support, the IaC/CI-CD/observability learning goals — those are better practiced against a simpler compute layer first. AKS is a reasonable **later** target if this project's scope grows. |
| Container Apps | Chosen — see below. |

## Rationale

Container Apps sits deliberately in the middle:

- Enough real infrastructure to model in Terraform (a Container Apps
  Environment, a Container App resource, ingress configuration, scaling
  rules) — meaningfully more than App Service's "point at an image" model.
- Managed enough that cluster administration doesn't crowd out the actual
  learning goals of this project (CI/CD, observability, hardening).
- Closer to real production container platform patterns than App Service,
  without requiring AKS-level operational investment on day one.
- A natural stepping stone: if a later phase wants to explore AKS-specific
  concepts, having already practiced the container/IaC/CI-CD fundamentals
  against Container Apps makes that a smaller incremental step.

## Consequences

- Terraform code will target the `azurerm_container_app` and
  `azurerm_container_app_environment` resources (exact resource names
  subject to whatever the AzureRM provider calls them at implementation
  time).
- Some Kubernetes-native concepts (raw Deployments, Services, Ingress
  resources, cluster-level RBAC) won't be directly practiced in this
  project. If deeper Kubernetes experience becomes a goal later, that would
  likely mean standing up AKS as a separate, later phase (see Phase 7/8 in
  the project plan) rather than migrating this environment in place.
- Networking and scaling configuration will be expressed through Container
  Apps' own abstractions (ingress, revisions, scale rules) rather than raw
  Kubernetes manifests.
