# pleme-io/flows — the fleet's reusable workflow catalog

**91 `workflow_call` workflows.** Sibling to [`pleme-io/actions`](https://github.com/pleme-io/actions)
(360 composite actions): actions are the *capabilities*, flows are the
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

## Status — this repo is the home, substrate is still the address

**Nothing references this repo yet. Do not repoint a consumer by hand.**

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

## What stayed in substrate

Seven workflows and two case tables, all of them substrate's own CI rather than
anything a consumer can call: `auto-bump` (its self-bump), `flakehub`,
`nix-tests`, `sql-apply-image-release`, and the three selftests
(`job-selection-selftest`, `devshell-cargo-test-selftest`, `doca-selftest`).
None declares `workflow_call`, so none was ever callable cross-repo.

## Licence

MIT.
