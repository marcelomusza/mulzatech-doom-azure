# Phase 3: CI in Azure DevOps

## Goal

Build and validate the container image automatically on every push, and
push it to Docker Hub ([ADR 0004](../adr/0004-docker-hub-vs-acr.md)). No
deployment yet — that's Phase 4.

## What was built

- **`azure-pipelines.yml`** (repo root) — a three-step pipeline: build the
  image, actually run the freshly-built container and `curl` it to confirm
  it responds (not just "did `docker build` exit 0"), then push two tags to
  Docker Hub: a unique `$(Build.BuildId)` tag for traceability, and `latest`
  (what Terraform's `main.tf` references).
- **A GitHub repo** (`github.com/marcelomusza/mulzatech-doom-azure`),
  created and pushed to for the first time this phase — the project had no
  git history at all before this.
- **An Azure DevOps organization/project**, with its pipeline connected to
  that GitHub repo, and a Docker Hub service connection (`dockerhub-mulzatech`)
  holding a write-scoped access token.

## Troubleshooting log

Getting a green pipeline run took five real, non-obvious issues — a good
reminder that CI/CD tooling has its own sharp edges independent of
application code.

### 1. Docker Hub access token had the wrong scope

**Symptom:** `unauthorized: access token has insufficient scopes` on push.

**Cause:** the token used in the service connection was generated with
read-only permission.

**Fix:** generated a new Docker Hub access token with **Read & Write**
scope (Docker Hub tokens can't have their scope edited after creation —
must generate a new one), updated the service connection.

### 2. `Docker@2`'s build step only applies the first of multiple tags

**Symptom:** after fixing #1, push succeeded for the `$(Build.BuildId)` tag
but failed with `tag does not exist: .../mulzatech-doom:latest`.

**Investigation:** the task's own source (`dockerbuild.ts`) suggests it
splits a multi-line `tags:` input and builds a `-t` flag per tag — but the
actual executed `docker build` command in the logs showed only **one**
`-t` flag, for the first tag listed. The second tag was simply never
created locally, so the later push step had nothing to push.

**Fix:** stopped relying on the task's multi-tag build support. Build now
only requests the single `$(tag)`; a plain `docker tag` CLI command (not
the `Docker@2` task) explicitly creates the `latest` tag from the
already-built image right after. A completely standard Docker operation
with no task-specific quirks to work around.

### 3. Confusing "rerun" with "run new"

**Symptom:** after pushing the fix above, two consecutive pipeline
"reruns" both still failed with the *exact* original error, and both logs
showed the pipeline checking out the *old* pre-fix commit.

**Cause:** **"Rerun" on a completed pipeline run intentionally re-runs
against the exact commit it originally used** — that's correct, reproducible
behavior, not a bug. It does not pick up new commits pushed to the branch
since.

**Fix:** used **"Run pipeline"** / **"Run new"** from the pipeline's main
page instead, which queues a fresh run against the current `main` HEAD.

### 4. Service connection names can't be pipeline variables

**Symptom:** `The pipeline is not valid. ... containerRegistry references
service connection $(dockerHubServiceConnection) which could not be found.`

**Cause:** Azure Pipelines needs to verify authorization for a referenced
service connection **before** the job starts — which happens at a stage
before `$(variable)` substitution occurs. Inputs like `containerRegistry`
that reference a service connection must be a literal string in the YAML,
not a variable reference, even though most other task inputs happily
accept variables.

**Fix:** changed `containerRegistry: $(dockerHubServiceConnection)` to the
literal `containerRegistry: 'dockerhub-mulzatech'`, and removed the
now-pointless variable.

### 5. New Azure subscription missing resource provider registrations

(Technically hit in Phase 2, but worth cross-referencing here since it's
the same class of "one-time account setup" issue as #3/#4 above — see
[phase-2-terraform-azure.md](phase-2-terraform-azure.md#missingsubscriptionregistration-on-first-apply)
for the full writeup.)

## Tradeoffs and things deferred

- **No deployment step yet.** This pipeline's job ends at "image is on
  Docker Hub." Actually deploying it to the Phase 2 Container App via
  Terraform is Phase 4's job, deliberately kept separate.
- **`latest` is mutable and gets overwritten on every push.** Fine for now
  since there's no automated deploy consuming it yet; worth reconsidering
  once Phase 4 exists — an automated deploy that always chases a mutable
  `latest` tag is a real footgun (a bad push could silently break
  production with no easy rollback target). Likely direction: have Phase 4
  deploy the specific `$(Build.BuildId)`-tagged image instead of `latest`.
- **No image vulnerability scanning.** A reasonable Phase 3/6 addition
  later, not required for "does it build and run."
