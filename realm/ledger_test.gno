package tavern_evidence_ledger

import (
    "strconv"
    "strings"
    "testing"
)

func digest(n int) string {
    tail := strconv.FormatInt(int64(n), 16)
    return strings.Repeat("0", 64-len(tail)) + tail
}

func TestValidDigest(t *testing.T) {
    if !validDigest(digest(42)) || !validDigest(strings.Repeat("f", 64)) {
        t.Fatal("valid digest rejected")
    }
}

func TestMalformedDigest(t *testing.T) {
    for _, bad := range []string{"", strings.Repeat("0", 63), strings.Repeat("0", 65), strings.Repeat("A", 64), strings.Repeat("g", 64), "0x"+strings.Repeat("0", 64), strings.Repeat(" ", 64)} {
        if validDigest(bad) { t.Fatalf("accepted malformed digest %q", bad) }
    }
}

func TestEmptyOwnerRejected(t *testing.T) {
    l := newLedger()
    if l.register("",digest(1)) != "invalid owner" || l.count("") != 0 { t.Fatal("empty owner mutated state") }
}

func TestInitialRead(t *testing.T) {
    l := newLedger()
    if l.count("alice") != 0 || l.has("alice",digest(1)) { t.Fatal("unexpected initial state") }
}

func TestRegisterRead(t *testing.T) {
    l := newLedger()
    if l.register("alice",digest(1)) != "recorded" || !l.has("alice",digest(1)) || l.count("alice") != 1 { t.Fatal("write/read mismatch") }
}

func TestDuplicateIdempotent(t *testing.T) {
    l := newLedger()
    l.register("alice",digest(1))
    if l.register("alice",digest(1)) != "already recorded" || l.count("alice") != 1 { t.Fatal("duplicate not idempotent") }
}

func TestOwnerIsolation(t *testing.T) {
    l := newLedger()
    l.register("alice",digest(1))
    if l.has("bob",digest(1)) || l.count("bob") != 0 { t.Fatal("owner scope leaked") }
    if l.register("bob",digest(1)) != "recorded" || l.count("alice") != 1 || l.count("bob") != 1 { t.Fatal("independent owner failed") }
}

func TestBoundAndNoMutation(t *testing.T) {
    l := newLedger()
    for i:=0;i<maxPerOwner;i++ {
        if l.register("alice",digest(i)) != "recorded" { t.Fatal("premature cap") }
    }
    if l.register("alice",digest(maxPerOwner)) != "owner limit reached" || l.count("alice") != maxPerOwner || l.has("alice",digest(maxPerOwner)) { t.Fatal("cap failed") }
    if l.register("alice",digest(0)) != "already recorded" { t.Fatal("duplicate at cap not idempotent") }
    if l.register("bob",digest(maxPerOwner)) != "recorded" { t.Fatal("per-owner cap leaked") }
}

func TestInvalidInputDoesNotConsumeCapacity(t *testing.T) {
    l := newLedger()
    if l.register("alice","malformed") != "invalid digest" || l.count("alice") != 0 || l.has("alice","malformed") { t.Fatal("invalid input mutated state") }
}

func TestAllowedChainPolicy(t *testing.T) {
    if !mutationAllowed("onyx-1",true,false) || !mutationAllowed("dev",true,false) { t.Fatal("test chain rejected") }
    for _, chain := range []string{"gnoland-1", "", "onyx-2", "mainnet"} {
        if mutationAllowed(chain,true,false) { t.Fatalf("unexpected chain accepted: %s",chain) }
    }
}

func TestRejectIndirectAndFunds(t *testing.T) {
    if mutationAllowed("onyx-1",false,false) || mutationAllowed("onyx-1",true,true) || mutationAllowed("dev",false,true) { t.Fatal("unsafe mutation accepted") }
}

func TestReadOnlyRealmSurface(t *testing.T) {
    if Count("not-an-owner") != 0 || Has("not-an-owner",digest(1)) { t.Fatal("unexpected realm state") }
    if !strings.Contains(Render(""),"Testnet demonstration") { t.Fatal("missing testnet warning") }
}
