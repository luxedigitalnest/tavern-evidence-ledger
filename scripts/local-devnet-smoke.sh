#!/usr/bin/env bash
# LOCAL SYNTHETIC FIXTURES ONLY. No public RPC, user wallet, or external ports.
set -euo pipefail
KEY_IMAGE=ghcr.io/gnolang/gno/gnokey@sha256:58ee190a85c94f72824a033cb9356eca95ccccedc71e46fc302657a5a620598a
NODE_IMAGE=ghcr.io/gnolang/gno/gnodev@sha256:6951d0688a60e55f46c9dcab8210bb813d1b42140acd7000009b409c331ecc27
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NODE="ldn-gno-smoke-${GITHUB_RUN_ID:-$$}"
KEYS="$NODE-keys"
PKG=gno.land/r/ldn/tavern_evidence_ledger
RPC=http://127.0.0.1:26657
PW='local-disposable-ci-fixture-only'
trap 'docker rm -f "$NODE" >/dev/null 2>&1 || true; docker volume rm "$KEYS" >/dev/null 2>&1 || true' EXIT
docker pull "$KEY_IMAGE"
docker pull "$NODE_IMAGE"
docker volume create "$KEYS" >/dev/null
create_fixture() {
  local name="$1" out
  # Generated only inside the disposable key volume. Never show mnemonic.
  out="$(printf '%s\n%s\n' "$PW" "$PW" | docker run --rm -i --network none -v "$KEYS:/keys" "$KEY_IMAGE" add -home /keys -insecure-password-stdin -nobackup "$name" 2>&1)" || { echo "fixture creation failed" >&2; return 1; }
  printf '%s\n' "$out" | grep -oE 'addr: g1[a-z0-9]+' | head -1 | cut -d' ' -f2
}
A="$(create_fixture fixture_a)"
B="$(create_fixture fixture_b)"
[[ "$A" == g1* && "$B" == g1* && "$A" != "$B" ]]
echo "Synthetic account A: $A"
echo "Synthetic account B: $B"
docker run -d --name "$NODE" --network none -v "$KEYS:/keys" -v "$ROOT/realm:/workspace:ro" -w /workspace "$NODE_IMAGE" local -home /keys -deploy-key fixture_a -chain-id dev -node-rpc-listener 127.0.0.1:26657 -no-web -no-watch -unsafe-api=false -no-examples . >/dev/null
cli() { docker run --rm -i --network "container:$NODE" -v "$KEYS:/keys" -v "$ROOT/scripts:/fixtures:ro" "$KEY_IMAGE" "$@"; }
query() { cli query vm/qeval -home /keys -remote "$RPC" -data "$PKG.$1"; }
ready=0
for attempt in $(seq 1 30); do
  if query 'Render("")' > /tmp/ldn-gno-ready.log 2>&1 && grep -q 'Tavern Evidence Ledger' /tmp/ldn-gno-ready.log; then ready=1; break; fi
  if [[ "$(docker inspect -f '{{.State.Running}}' "$NODE")" != true ]]; then
    echo "local node exited"; docker logs "$NODE" 2>&1 | grep -Ei 'error|panic|failed|fatal' | tail -15 || true; exit 1
  fi
  sleep 1
done
[[ "$ready" == 1 ]] || { cat /tmp/ldn-gno-ready.log; exit 1; }
echo "LOCAL realm ready; private loopback RPC only."
call() {
  local account="$1" digest="$2"; shift 2
  printf '%s\n' "$PW" | cli maketx call -home /keys -insecure-password-stdin -remote "$RPC" -chainid dev -broadcast -pkgpath "$PKG" -func Register -args "$digest" -gas-fee 1000000ugnot -gas-wanted 20000000 -max-deposit 10000000ugnot "$@" "$account"
}
check_query() { local result; result="$(query "$1")"; printf '%s\n' "$result"; grep -Fq "$2" <<< "$result"; }
D="$(printf 'a%.0s' {1..64})"
E="$(printf 'b%.0s' {1..64})"
check_query "Count(\"$A\")" '(0 int)'
check_query "Count(\"$B\")" '(0 int)'
result="$(call fixture_a "$D")"; printf '%s\n' "$result"; grep -Fq 'recorded' <<< "$result"; grep -Fq 'OK!' <<< "$result"
check_query "Has(\"$A\",\"$D\")" '(true bool)'
check_query "Count(\"$A\")" '(1 int)'
check_query "Has(\"$B\",\"$D\")" '(false bool)'
result="$(call fixture_a "$D")"; printf '%s\n' "$result"; grep -Fq 'already recorded' <<< "$result"; grep -Fq 'OK!' <<< "$result"
check_query "Count(\"$A\")" '(1 int)'
result="$(call fixture_a invalid)"; printf '%s\n' "$result"; grep -Fq 'invalid digest' <<< "$result"; grep -Fq 'OK!' <<< "$result"
check_query "Count(\"$A\")" '(1 int)'
result="$(call fixture_b "$D")"; printf '%s\n' "$result"; grep -Fq 'recorded' <<< "$result"; grep -Fq 'OK!' <<< "$result"
check_query "Has(\"$B\",\"$D\")" '(true bool)'
check_query "Count(\"$A\")" '(1 int)'
check_query "Count(\"$B\")" '(1 int)'
set +e
result="$(call fixture_a "$E" -send 1ugnot 2>&1)"
rc=$?
set -e
printf '%s\n' "$result"
! grep -Fq 'OK!' <<< "$result"
grep -Fq 'direct testnet or local call with no attached funds required' <<< "$result"
check_query "Has(\"$A\",\"$E\")" '(false bool)'
check_query "Count(\"$A\")" '(1 int)'
echo "PASS: local direct MsgCall, persisted owner isolation, duplicate idempotency, invalid input and attached-funds rejection."
