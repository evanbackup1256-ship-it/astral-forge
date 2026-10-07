# Arcade RNG and proof protocol

Status: implementation stage, not signed off. Public arcade only; points are not spendable or transferable and cannot be exchanged for rewards.

## Draw construction

The server exposes a SHA-256 seed commitment before a start request. The client submits its seed and the published commitment/nonce. Mismatches are rejected.

HMAC-SHA-256 uses the private server seed as key. Each block authenticates `v1:<domain byte length>:<domain>:<client-seed byte length>:<client-seed>:<nonce>:<block>`. Eight big-endian unsigned 32-bit words are consumed per digest. Domains are `Arcade.<GameId>`. Integer ranges use rejection sampling; unit draws are word / 2^32.

Interactive rounds retain exact decks/fields and accepted moves server-side. Public views omit the live seed, hidden deck and hazards. Completed rounds expose the seed, nonce, domain, draw count, numbers and moves; the seed rotates before another start.

## Evidence and limits

`verify_roll_proofs` compares independent Python hashlib/hmac fixtures, RFC cases, padding boundaries, Unicode and a million-byte vector. The distribution smoke test is not claimed as proof of uniformity; rejection sampling is the construction.

`verify_arcade_engine` covers all ten games, replay/version fences, saved-round reload, hidden-state projection, expiry and breaks. This does not establish live durability or rendered quality.

Current seed input uses Roblox engine GUIDs. No independent entropy certification or security review has occurred. Commitment checks alone do not certify honest seed generation. Full outcome-verification UI remains incomplete.

## References

- [NIST FIPS 180-4](https://csrc.nist.gov/pubs/fips/180-4/upd1/final)
- [RFC 4231](https://www.rfc-editor.org/info/rfc4231/)
- [Roblox Community Standards](https://en.help.roblox.com/hc/en-us/articles/203313410-Roblox-Community-Standards)
