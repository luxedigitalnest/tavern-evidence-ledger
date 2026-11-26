package tavern_evidence_ledger

// An owner-scoped, bounded append-only set of SHA-256 commitments.
// Only fixed-length lowercase hex is stored; no plaintext or user HTML.
const maxPerOwner = 16

type ledger struct {
    owners map[string][]string
}

func newLedger() *ledger {
    return &ledger{owners: make(map[string][]string)}
}

func validDigest(digest string) bool {
    if len(digest) != 64 {
        return false
    }
    for i := 0; i < len(digest); i++ {
        c := digest[i]
        if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) {
            return false
        }
    }
    return true
}

func (l *ledger) has(owner, digest string) bool {
    if !validDigest(digest) {
        return false
    }
    for _, existing := range l.owners[owner] {
        if existing == digest {
            return true
        }
    }
    return false
}

func (l *ledger) count(owner string) int {
    return len(l.owners[owner])
}

func (l *ledger) register(owner, digest string) string {
    if owner == "" {
        return "invalid owner"
    }
    if !validDigest(digest) {
        return "invalid digest"
    }
    if l.has(owner, digest) {
        return "already recorded"
    }
    if l.count(owner) >= maxPerOwner {
        return "owner limit reached"
    }
    l.owners[owner] = append(l.owners[owner], digest)
    return "recorded"
}

func mutationAllowed(chainID string, direct, funds bool) bool {
    return (chainID == "onyx-1" || chainID == "dev") && direct && !funds
}
