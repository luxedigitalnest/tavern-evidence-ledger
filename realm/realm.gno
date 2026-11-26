package tavern_evidence_ledger

import (
    "chain/runtime"
    "chain/runtime/unsafe"
)

var records = newLedger()

// Register accepts only a direct, user-originated call on the designated
// testnet or local dev chain. Never use tx.origin for owner authentication.
// Reject attached funds before modifying storage; no banker or transfers.
func Register(cur realm, digest string) string {
    runtime.AssertOriginCall()
    caller := cur.Previous()
    if !mutationAllowed(runtime.ChainID(), caller.IsUserCall(), !unsafe.OriginSend().IsZero()) {
        panic("direct testnet or local call with no attached funds required")
    }
    return records.register(string(caller.Address()), digest)
}

func Has(owner, digest string) bool {
    return records.has(owner, digest)
}

func Count(owner string) int {
    return records.count(owner)
}

func Render(_ string) string {
    return "# Tavern Evidence Ledger\n\nTestnet demonstration. Register a lowercase 64-character SHA-256 digest with a direct MsgCall, no attached coins. Each caller can record 16 distinct commitments. Has(owner,digest) and Count(owner) are read-only queries. A commitment is not proof of truth, identity, authorship, timestamp of creation, or payment. Do not register personal information or secrets. Network fees/storage requirements may apply."
}
