# ADR 0007: AI infra reviewer as a separate repo, advisory and diff-only

## Status

Accepted

## Context

Phase 8 adds an AI model that reviews infrastructure pull requests. Three
design questions had to be settled:

1. Where does the reviewer live: in this repo or in its own?
2. What does it look at, and what can it do?
3. How much should it cost?

## Decision

- **Separate repository** (`mulzatech-infra-reviewer`), consumed from this
  repo through a small caller workflow that calls a reusable GitHub Actions
  workflow.
- **Advisory and read-only.** It posts one comment per PR (updated in
  place), not a blocking check, and has no permission to change code.
- **Diff only.** It reviews the pull request's diff against a written
  rubric. It does not run `terraform plan` and has no Azure credentials.
- **Cheapest model by default** (`claude-haiku-5-5`), overridable with one
  environment variable, with a hard monthly spend limit set in the API
  provider's console.

## Rationale

- **Separate repo.** The reviewer is reusable tooling, not part of the app,
  and CLAUDE.md always framed this phase as an external layer operating on
  this repo. A reusable workflow lets any repo adopt it with a handful of
  lines. It runs on GitHub Actions while this repo's own CI/CD stays on
  Azure DevOps, which is a deliberate and documented split: the reviewer
  reacts to GitHub PRs, and the pipeline deploys.
- **Advisory.** A language model can be wrong, and it can be unavailable.
  Making it a required check would let either failure block a merge. A
  comment gives a second opinion without that power.
- **Diff only, no credentials.** `terraform plan` would give a richer
  review (it shows what will actually change), but it needs Azure access
  from GitHub. A reviewer that reads untrusted PR content should hold as
  little privilege as possible. This follows the same principle as ADR
  0006's RBAC-only reasoning and the Phase 6 rule that automation does not
  get the ability to grant itself more.
- **Untrusted input.** A pull request author controls the diff, so it is
  treated as data: wrapped in per-run random tags, never executed, and the
  workflow uses `pull_request` (no secrets exposed to forks) rather than
  `pull_request_target`.
- **Cost.** This is a test and portfolio project. A tenth of a cent per
  review and a path filter that skips docs-only PRs keep the spend
  negligible; the console spend limit bounds the worst case.

## Consequences

- A model miss costs nothing automatically, but nothing enforces the
  rubric either. A human still reviews and merges.
- The reviewer sees only the diff, so context outside it (for example
  whether a referenced image tag exists) is reported as "needs checking"
  rather than verified.
- Because the caller references the reusable workflow at `@main`, changes
  to the reviewer take effect immediately; pinning to a commit would trade
  that convenience for stricter supply-chain hygiene.
- If a future change wants plan-aware review, it would need a read-only
  Azure identity with a federated credential for GitHub, scoped narrowly.
  That is a deliberate step up in privilege and would get its own ADR.
