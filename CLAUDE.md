# flows

> **★★★ CSE / Knowable Construction.** This repo operates under **Constructive Substrate Engineering** — canonical specification at [`pleme-io/theory/CONSTRUCTIVE-SUBSTRATE-ENGINEERING.md`](https://github.com/pleme-io/theory/blob/main/CONSTRUCTIVE-SUBSTRATE-ENGINEERING.md). The Compounding Directive (operational rules: solve once, load-bearing fixes only, idiom-first, models stay current, direction beats velocity) is in the org-level pleme-io/CLAUDE.md ★★★ section. Read both before non-trivial changes.

The fleet's reusable `workflow_call` catalog — 91 flows, sibling to
`pleme-io/actions`' 360 composite actions. Read [`README.md`](./README.md)
first; it carries the ladder, the eleven-flow general family, and the rules a
flow must obey.

## Before you touch anything here

**This repo is the home; `substrate` is still the address.** Every consumer
resolves `pleme-io/substrate/.github/workflows/…@main`, and
[`substrate-parity`](.github/workflows/substrate-parity.yml) keeps the two trees
byte-identical. So **an edit here that does not also land in substrate is drift
that reaches nobody**, and the gate will say so. Until the cutover, edit both.

**The cutover cannot be gradual.** GitHub caps reusable workflows at 4 connected
levels and two chains already sit at exactly 4, so substrate cannot stay behind
as a forwarding shim — see README § Status. Do not propose one.

## The one rule that generates the others

A workflow is a **call with values**. A `run:` block holding a comparison, a
loop, or an error message is a capability in the wrong file: it belongs in a
`pleme-io/actions` action, where one fix reaches every caller instead of being
fixed once per copy. Canonical:
[`CONSTRUCTIVE-ACTIONS.md`](https://github.com/pleme-io/theory/blob/main/CONSTRUCTIVE-ACTIONS.md) §0
and [`PIPELINE-DELIVERY.md`](https://github.com/pleme-io/theory/blob/main/PIPELINE-DELIVERY.md).

This repo holds itself to it: `substrate-parity.yml` carries no `run:` — its
comparison is [`tools/substrate-parity.tlisp`](./tools/substrate-parity.tlisp),
runnable offline.
