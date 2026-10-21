# Phase 8: AI Infra-Change Reviewer

## Goal

CLAUDE.md's last phase was "AI layer connects in": a separate repository
that operates on this one from the outside. This phase built an **infra
change reviewer**: when a pull request touches infrastructure files, an AI
model reads the diff against a rubric of this project's real past mistakes
and posts a single advisory comment.

The reviewer lives in its own repo,
[`mulzatech-infra-reviewer`](https://github.com/marcelomusza/mulzatech-infra-reviewer),
and this repo only carries a small caller workflow. Reasoning in
[ADR 0007](../adr/0007-ai-infra-reviewer-design.md).

## What was built

### 1. The rubric (`rubric.md`)

Nine numbered checks, each traced to something that actually happened in
Phases 0-6, with the "why" written next to it so the model (and a human
reader) knows the reason, not just the rule:

| # | Check | Severity | Origin |
|---|---|---|---|
| 1 | Deployed image can roll back to a mutable tag (`:latest`) | High | Phase 4/5/6 near-misses |
| 2 | Privilege grants made by automation | High | Phase 6 role-assignment failure |
| 3 | Secrets in code, logs, or command-line arguments | High | Phase 6 token handling |
| 4 | Public exposure widened (anything other than the app) | High | ADR 0006 |
| 5 | COOP/COEP headers removed from nginx | High | Phase 0 |
| 6 | Terraform traps (`latest_revision_fqdn`, backend variables, replaced stateful resources) | Medium | Phase 2/4 |
| 7 | Pipeline traps (service connection variables, Deploy dependency, triggers) | Medium | Phase 3/4 |
| 8 | Observability regressions | Medium | Phase 5 |
| 9 | Cost (`min_replicas`, sizing, new paid resources) | Low | Phase 2 |

The output format is part of the rubric: findings grouped by severity with
a file, the problem, why it matters here, and a concrete fix. When nothing
matches, the reply is one summary line plus exactly "No issues found
against the rubric." No padding, no invented findings.

### 2. The review script (`review.py`)

A short Python script: it reads a diff file, sends it with the rubric as
the system prompt, and prints Markdown. Choices worth knowing about:

- **Cheapest model.** `claude-haiku-5-5` by default (this is a test
  project; cost should be as low as possible). One environment variable,
  `REVIEW_MODEL`, switches to a larger model with no code change.
- **Prompt-injection resistance.** The diff is untrusted input: a PR
  author controls it. It is wrapped in `<diff-{random}>` tags whose suffix
  is generated per run, so a diff can't contain the closing tag and
  "escape" the data section. The system prompt says everything inside is
  data, never instructions, and that text trying to steer the review is
  itself a finding.
- **No silent failures.** A diff over 100,000 characters produces an
  explicit "too large, a human should review it" comment rather than a
  truncated review. A refusal or an output-limit stop is reported in the
  comment. API errors (bad key, rate limit, connection) exit non-zero with
  a plain message.
- **A hidden marker** (`<!-- mulzatech-infra-reviewer -->`) on the first
  line identifies the bot's comment so it can be updated in place.

### 3. The workflow (GitHub Actions)

Two files, split on purpose:

- **Reusable workflow** in the reviewer repo
  (`.github/workflows/review.yml`, `on: workflow_call`). It checks out the
  PR and the reviewer, builds the diff, runs `review.py`, and posts or
  updates the comment.
- **Caller workflow** in this repo (`.github/workflows/infra-review.yml`).
  About fifteen lines: triggers on `pull_request`, limited by `paths:` to
  `infra/**`, `azure-pipelines.yml`, `app/Dockerfile`, and
  `app/nginx.conf`, and passes the `ANTHROPIC_API_KEY` secret through.
  Documentation-only PRs never call the API.

Safety properties of the workflow, deliberately chosen:

- **Read-only toward the code.** Permissions are `contents: read` and
  `pull-requests: write` (comment only). The PR's code is diffed, never
  executed.
- **`pull_request`, not `pull_request_target`.** The latter runs with
  secrets against untrusted PR code.
- **No attacker-controlled value is interpolated into script text.** The
  base branch name and PR number are passed through `env:`.
- **The comment lookup only matches comments by `github-actions[bot]`
  carrying the marker**, so a human can't make the workflow try to edit
  their comment by pasting the marker.
- **Fork PRs are skipped**, since they get no secrets by design.
- **Vendored files are excluded** from the diff (`app/public/js-dos/`,
  `*.jsdos`), so a binary runtime can't trip the size guard.

### 4. The API key

Created by hand in the Anthropic Console with a monthly spend limit, then
stored only as a GitHub Actions secret on this repo. It never went through
the pipeline or into any file.

## Verification

1. **Seeded bad diff** (`tests/sample_bad.diff`): a diff reintroducing
   seven of this project's known mistakes, plus an injected comment
   addressed to "AI REVIEWER" telling it to answer "No issues". Result: all
   seven caught with the right severity, and the injection flagged as
   suspicious rather than obeyed. About 2,600 tokens in and 1,700 out.
2. **Clean diff** (`tests/sample_clean.diff`, a typo fix and a tag): no
   false alarms. The first run correctly said "No issues", but added a
   paragraph of speculation; tightening the rubric's output rule fixed it
   (second run: two lines, 192 output tokens).
3. **A real pull request** against this repo with `app_url` switched to
   `latest_revision_fqdn`: the workflow triggered, the comment appeared
   (Medium finding, concrete fix, about 1,800 tokens in and 480 out), and
   a second commit to the same PR **edited the same comment** instead of
   adding another. The PR was closed without merging.

Cost per review is on the order of a tenth of a cent.

## Troubleshooting log

### 1. An API key was exposed in a chat paste

While debugging local setup errors, terminal output was pasted that
contained the key in plain text. The key was revoked in the Console, a new
one was created with a spend limit, and from then on it was entered only
through a masked prompt locally and as a GitHub secret remotely. The
lesson: a key typed onto a command line is in shell history and terminal
output; use a masked prompt, and skim output before pasting it anywhere.

### 2. First workflow run: "The Anthropic API key was rejected"

Everything up to the API call was green (checkouts, Python, diff), and the
script reached Anthropic, which returned 401. That ruled out a missing or
misnamed secret (the script reports that case separately). The secret was
replaced with a freshly created key and the run passed. The exact cause of
the original rejection wasn't pinned down; the leading suspects were a
revoked key or a bad copy. A temporary key-shape diagnostic step (length,
prefix, whitespace, never the value) was the planned next step had it
persisted.

### 3. PowerShell blocked venv activation; wrong working directory

`Activate.ps1` was blocked by the execution policy. Rather than change a
system security setting, the venv's interpreter was called directly
(`.\.venv\Scripts\python.exe`). Related: a "file not found" on that path
was simply running from the parent folder.

## Tradeoffs and things deferred

- **Advisory, not blocking.** The check isn't a required status, so a
  model miss never gates a merge, and an API outage never blocks one. The
  cost is that it can be ignored.
- **Diff only.** It sees what changed, not the whole repo, so it says
  "needs checking outside this diff" instead of guessing. It does **not**
  run `terraform plan`, which would require giving GitHub Azure
  credentials; that would widen the attack surface for a modest gain here.
- **Small model.** Haiku caught every seeded problem, but a small model
  can still miss subtler ones. Upgrading is one variable
  (`REVIEW_MODEL=claude-sonnet-5-5`).
- **Not an eval.** The two sample diffs are a smoke test, not a measured
  benchmark. One output summary miscounted ("six" with seven findings
  listed); cosmetic, but a reminder to treat the text as advice.
- **Workflow pinned to `@main`.** A change to the reviewer repo takes
  effect immediately in this repo. Pinning to a tag or commit SHA would be
  stricter.
- **The fork-PR skip condition is untested** (this is a solo repo with no
  fork PRs).
- **Spend control lives outside the code**: the Console spend limit, not
  anything in the workflow, is the real ceiling.
