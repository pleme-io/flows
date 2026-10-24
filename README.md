# pleme-io/flows — the fleet's reusable workflow catalog

**93 `workflow_call` workflows** (counted by `tools/flow-standard.tlisp`, 2026-10-24). Sibling to [`pleme-io/actions`](https://github.com/pleme-io/actions)
(380 action directories, 2026-10-24): actions are the *capabilities*, flows are the
*orchestration* that composes them, and a consumer repo writes neither — it
writes a ≤15-line shim that names a flow and passes values.

```yaml
# .github/workflows/pleme.yml — the whole adoption
name: pleme
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }
  schedule: [ { cron: '0 6 * * 1' } ]
jobs:
  stack:
    uses: pleme-io/substrate/.github/workflows/pleme-stack.yml@main
    secrets: inherit
```

> **Read the `uses:` line above carefully — it names `substrate`, not this
> repo.** That is correct today. See **Status** below before changing it.

## The ladder

Reach top-down and stop at the first rung that fits. Only the last rung writes
logic; every rung above is a call with values.

| # | Rung | You write | Lives in |
|---|---|---|---|
| 0 | Adopt a general flow | a shim naming a `pleme-*` flow | your repo |
| 1 | Configure it | `with:` inputs | the same shim |
| 2 | Compose a new flow | a `workflow_call` workflow of `uses:` | **here** |
| 3 | Extend an action | one input + its branch in `run.tlisp` | `pleme-io/actions` |
| 4 | Author an action | `action.yml` + `run.tlisp` + `run.test.tlisp` | `pleme-io/actions` |

Canonical: [`theory/PIPELINE-DELIVERY.md`](https://github.com/pleme-io/theory/blob/main/PIPELINE-DELIVERY.md).
What a flow may *contain*: [`CONSTRUCTIVE-ACTIONS.md`](https://github.com/pleme-io/theory/blob/main/CONSTRUCTIVE-ACTIONS.md) §0.

## The general family — read these eleven first

Each is a dispatcher taking one `target:` input, so adopting a class of repo is
one call. `pleme-stack` is the umbrella: PR gates + push release + the weekly
sweeps in a single `uses:`.

| flow | for | default `target` |
|---|---|---|
| `pleme-stack` | everything, in one call | — |
| `pleme-rust` | Rust | `cargo-auto-release` |
| `pleme-go` | Go | `go-auto-release` |
| `pleme-ruby` | Ruby gems | `gem-release` |
| `pleme-helm` | Helm charts | `helm-auto-release` |
| `pleme-caixa` | caixa lifecycle | `caixa-auto-release` |
| `pleme-container` | OCI images | `image-push` |
| `pleme-iac` | Crossplane / Terraform / Pulumi providers | `crossplane-provider-publish` |
| `pleme-publish` | npm / python / actions / attestation | `npm-auto-release` |
| `pleme-ansible` | Ansible collections | `ansible-collection-release` |
| `pleme-ops` | stacks, gates, ops | `security-gate` |

There are also 11 **starter workflows** in the org's
[`.github`](https://github.com/pleme-io/.github/tree/main/workflow-templates)
repo — one per family member — so adopting a flow is a picker entry in
*Actions → New workflow*, not a copy-paste.

## Rules for a flow

- **No `run:` with a comparison, a loop, or an error message.** That is a
  capability in the wrong file; it belongs in a `pleme-io/actions` action, where
  the fix reaches every caller at once instead of once per copy.
- **A precondition is asserted by an action, never a header comment.** A comment
  cannot fail a build. `cargo-auto-release.yml` carried *"for workspace repos use
  rust-auto-release.yml"* from the day it was written and seven repos called it
  against a `[workspace]` root anyway.
- **A new flow ships its `<flow>.cases.tsv`.** 37 exist; `job-selection-selftest`
  runs them. Job selection that is not pinned drifts silently, because a job that
  stops running looks exactly like a job with nothing to do.
- **Ask whether it is an input before you author a flow.** A flow that differs
  from an existing one by a conditional is an input to that one.
- **Extract on the second repo, not the third.** A job shape appearing in a
  second repo belongs in the family.

## The standard shapes — one definition each, gated

[`tools/flow-standard.tlisp`](./tools/flow-standard.tlisp) holds each shape
once, and [`flow-standard`](.github/workflows/flow-standard.yml) fails a push
that breaks one. GitHub has no way to share an expression between workflow
files, so the YAML is a rendering of these definitions, and the gate keeps every
rendering equal to its definition.

| Shape | The rule |
|---|---|
| Runner route | Every job `runs-on: ${{ inputs.runner != '' && inputs.runner \|\| (github.event.repository.private && (vars.PRIVATE_BUILDER_RUNNER \|\| 'pleme-private') \|\| 'ubuntu-latest') }}`, or `${{ needs.<job>.outputs.runner }}` from a `runner-resolve` job. A typed exception (a matrix, a label array, a platform pin such as `rio` or `macos`, the oldest-glibc job) is a row in `ROUTE-EXCEPTIONS`, with its reason. |
| Runner input | A flow that routes declares the one `runner` input: type string, default `""`, the one description. |
| Header | One top-level `name:`, equal to the file stem. `on:` declares `workflow_call:` at indent 2. |
| Sibling call | A flow calls a sibling as `./.github/workflows/<flow>.yml`. A `./` call resolves in the repository of the calling flow, so the catalog calls itself and the cutover touches consumers only. |
| Permissions | A top-level `permissions:` block. The 40 flows without one are listed in `tools/permissions-ledger.txt`. The ledger only shrinks: the gate fails when a listed flow gets a block and stays listed. |
| Catalog | [`catalog/workflows.lisp`](./catalog/workflows.lisp) is the source. Each flow has one `(defworkflow …)` row, and its `:inputs` equal the inputs the flow declares. `substrate/catalog/workflows.lisp` is a mirror, and `substrate-parity` compares it. |

The gate is tatara-lisp and not blue: a CI runner has no blue binary to fetch
(blue has no release and no flake output, 2026-10-24). The same blocker holds
new `run.b` actions in `pleme-io/actions`. The first step is a blue release
that a runner can install, and then one blue runner action that every `run.b`
action reuses.

## Reuse ledger — `run:` logic still in flows, ranked

Measured 2026-10-24 over the 93 flows: 160 `run:` blocks, 86 with logic
(a comparison, a loop, `||`/`&&`, an exit code or `::error`), 1,263 lines,
in 35 flows. Each row moves to a `pleme-io/actions` action (`run.b`, after
the blue runner exists), largest first.

| # | Class | Flows | Logic lines |
|---|---|---|---|
| 1 | Binary release matrix | rust-binary-release (8 blocks), go-binary-release (3) | 230 |
| 2 | Image build, scan and push legs | image-push (7), vendor-image-mirror, nix-image-auto-release | 219 |
| 3 | caixa family | caixa-publish, caixa-forge, caixa-publish-tlisp, caixa-validate | 186 |
| 4 | Chart test and release | helm-unittest (one 147-line block), helm-auto-release, helm-monorepo-auto-release | 183 |
| 5 | Ansible collection family | integration-live, published-install, auto-bump, ci, matrix | 121 |
| 6 | Language auto-release legs | go-auto-release, rust-auto-release, auto-release, gem-auto-bump, crossplane-function-auto-release | 106 |
| 7 | Provider publish family (one general flow under `pleme-iac`) | pulumi-provider-publish, crossplane-provider-publish, steampipe-plugin-publish | 95 |
| 8 | The rest | reusable-autoheal, action-release, cse-audit, ghcr-retention, cargo-ci, nix-devshell-cargo-test | 79 |
| 9 | esteira-rio | esteira-rio-bump, esteira-rio-release | 44 |
| — | Private git credential and netrc, inside 2 and 6 | image-push, rust-auto-release (inline `insteadOf`). `pleme-io/actions/git-credentials` needs an explicit `token` input first, because these flows take `steps.token.outputs.token \|\| secrets.GHCR_TOKEN` | — |

Done in this pass: `nix-image-auto-release-slim` forwards to
`nix-image-auto-release` (434 lines to 147, logic blocks 2 to 0), and 28
sibling calls in 13 flows became `./` calls.

## Alignment with blue's pipeline

Blue's SDLC design makes a workflow a rendering of the Bluefile, run by the
blue binary (`pleme-io/blue` docs/TESTING.md and docs/REGISTRY.md; neither is
on blue `main` yet, 2026-10-24; `reusable-flakehub` already says that blue's
registry renders its callers). The shapes above are what that renderer emits:
one route expression, one `runner` input, `name:` equal to the stem, `./`
sibling calls, and one catalog row per flow whose `:inputs` the renderer reads
instead of the YAML.

## Status — this repo is the home, substrate is still the address

**Five canary repos reference this repo (2026-10-24): lava-splunk,
lava-operator, pangea-tls, shikumi-go, irodori. Do not repoint a consumer
by hand; the cutover tool does it.**

Created 2026-08-19. The fleet's 1751 references across ~759 repos still resolve
`pleme-io/substrate/.github/workflows/…@main`, and both trees are kept
byte-identical by [`substrate-parity`](.github/workflows/substrate-parity.yml)
until the cutover.

The cutover has to be a **single sweep of every reference**, not a gradual
migration, for a reason that is worth knowing before proposing otherwise:
GitHub caps reusable workflows at **4 connected levels**, and two chains already
sit at exactly 4 —

```
shim → pleme-stack → auto-release → action-release
shim → release-pipeline → auto-release → action-release
```

so leaving `substrate/.github/workflows/X.yml` behind as a forwarding shim is
**illegal**: it adds a fifth level and breaks `pleme-stack` at runtime for every
repo whose release routes through `action-release`.

That sweep should happen **together with** the pending reference-locking work,
because both rewrite the same 1751 references and doing them separately means
rewriting every consumer twice — with the second pass invalidating every lock
the first computed. Tracked as `pending-pipeline-delivery: ref-locking`.

### The cutover tool

[`tools/cutover.b`](./tools/cutover.b) (blue) rewrites every
`pleme-io/substrate/.github/workflows/X@ref` on a `uses:` line to
`pleme-io/flows/.github/workflows/X@ref`, and keeps the ref. It rewrites a
reference only when flows holds `X` and `X` declares `workflow_call:`; any
other reference stays and is listed as `missing` or `no-ref`. It skips the
`substrate` and `flows` trees. It scans `.github/workflows/*.y{a,}ml` and
`.github/workflow-templates/*.yml` one level under the root. Blue's `glob`
finds nothing for an absolute pattern, so run it from the org directory with
the root `.`.

| Mode | It does |
|---|---|
| `plan FLOWS OUT .` | Writes the ledger `OUT` (repo, path, line, flow, ref, status). Changes nothing. |
| `write FLOWS OUT .` | `plan`, and rewrites the files. Commits nothing. |
| `push FLOWS OUT .` | Per repo: refuses a dirty tree, a branch other than `main`, or a fetch that does not fast-forward; then rewrites, commits, and pushes to `main`. `OUT` lists each repo's result. A second run finds nothing to do. |
| `search FLOWS OUT` | GitHub code search, one query per flow, 7 s apart (the limit is 10 a minute). Lists the files the org holds, cloned or not. |

Dry run, 2026-10-24, over `~/code/github/pleme-io` (one level, agent
worktrees not scanned): 1,994 workflow files, 1,776 references; 1,720
rewritable in 1,620 files in 776 repos; 0 missing; 56 in the substrate and
flows trees (skipped). `rg --no-ignore --hidden` over the same files counts
the same 1,776. Not covered by the tool: `substrate/templates/fleet` (one
reference, in a template that renders new repos); change it in the
cutover commit to substrate.


## What stayed in substrate

Eight workflows and two case tables, all of them substrate's own CI rather than
anything a consumer can call: `auto-bump` (its self-bump), `flakehub`,
`nix-tests`, `sql-apply-image-release`, `catalog-check`, and the three selftests
(`job-selection-selftest`, `devshell-cargo-test-selftest`, `doca-selftest`).
None declares `workflow_call`, so none was ever callable cross-repo.

`catalog-check` is worth naming because it briefly *did* land here, and the
mistake is instructive: the move selected files containing the string
`workflow_call`, and that file's comments discuss `workflow_call:` while its
`on:` block has none — it says so itself, *"it has no `workflow_call:` and is
correctly absent from the catalog"*. Mirrored here it self-triggered on push and
failed. **The fleet-wide "91 reusable workflows" figure came from the same
substring count and is likewise one too high; the measured number is 90.**

## Licence

MIT.
