# Tavern Evidence Ledger

**Status: reconstructed testnet prototype; 12 native Gno VM tests passed on the pinned runtime. Local devnet smoke testing is in progress. No deployment, contest submission, or award.**

Original project design from the earlier Gnome Tavern checkpoint: a bounded, owner-scoped evidence digest ledger. The original archive could not be recovered in this session (recorded historical SHA-256 `9baf5af0ac9e9e02e9d7e001f8e911f884e4d33a09c2d81f45efcc81844e9865`). This repository is a newly written reconstruction, not that archive or a byte-identical recovery. Development is AI-assisted. Apache-2.0.

## What it does

- Accepts exactly 64 lowercase hexadecimal characters as a caller-scoped SHA-256 commitment.
- Limits each caller to 16 distinct commitments; duplicate registration is idempotent.
- Rejects non-direct origin calls, non-Onyx/non-local chains, and attached coins before storage changes.
- Exposes read-only membership/count and static explanatory rendering. Does not accept secrets, plaintext, tokens or user-controlled markup.

It is not a trusted timestamp service, oracle, identity proof, payment record, ownership proof, or financial product. Commitments are public; low-entropy source data can be guessed. The per-owner cap does not bound aggregate growth across accounts. Network fees/storage charges may apply. No custody/spending functions.

## Verified native QA

[Native CI run 45837389741](https://github.com/luxedigitalnest/tavern-evidence-ledger/actions/runs/45837389741): 12 tests passed, zero failures, official image v1.8.0-rc.1. The source reconstruction is verified, not the unavailable earlier ZIP.

## Reproduce native QA

Use the official Gno image pinned to the release index digest from the `v1.8.0-rc.1` release (Onyx-compatible; same code commit as v1.8.0). Run the unit suite without network access:

```sh
docker pull ghcr.io/gnolang/gno/gno@sha256:e14eadb1af019f49a8b66c39ded3d7cf4a8c1a786f6c62b42083f547208b1724
docker run --rm --network none -v "$PWD/realm:/workspace:ro" -w /workspace ghcr.io/gnolang/gno/gno@sha256:e14eadb1af019f49a8b66c39ded3d7cf4a8c1a786f6c62b42083f547208b1724 test -root-dir /gnoroot -v .
```

The native suite covers validation, idempotency, owner isolation, capacity, policy predicates, and read-only realm surface. It does **not** substitute for actual direct MsgCall execution, local devnet storage and runtime-origin negative tests, or Onyx transaction/explorer verification. Before deployment confirm the real account's authorized namespace; the module path here is a candidate, not claimed namespace ownership. No wallet keys or transactions are included.

References: [official release](https://github.com/gnolang/gno/releases/tag/v1.8.0-rc.1), [Gno testing](https://docs.gno.land/resources/gno-testing/), [Gno networks](https://docs.gno.land/resources/gnoland-networks/), [pinned runtime implementation](https://github.com/gnolang/gno/tree/v1.8.0-rc.1/gnovm/stdlibs/chain/runtime).
