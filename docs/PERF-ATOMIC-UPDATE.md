# AtomicUpdate cost and copy-on-write options (stage 9)

## What actually runs

- `label === "production"` (the 0.5 s production tick) already uses
  `AtomicState.TransactInPlace`: no full copy, only root fields + the declared
  `PRODUCTION_DEEP_KEYS` / `PRODUCTION_SHALLOW_KEYS` are backed up.
- Every other label uses `AtomicState.Transact`: one full deep copy of the profile
  (`clone`, `table.clone` per level), then the callback, then `sanitize(draft)` (a full
  profile normalisation pass) and `ProfileIntegrity.Record` (hash of the critical snapshot).

So the "~0.5 s" figure matches the production tick *interval*, not the cost of a copy.
Measured in Lune (same Luau VM, native `table.clone`): a synthetic profile of ~12,000 tables
(6,000 star-grid nodes, 3,000 relics with roll arrays) deep-copies in about **2.2 ms**.
In a non-production transaction the full `sanitize` pass is likely the larger share; it was
not changed here, because skipping or narrowing it changes what gets saved for damaged data.

## Rollback contract (now pinned by `scripts/verify_atomic_state.luau`, run in `npm test`)

For 400 randomized `Transact` and 300 `TransactInPlace` transactions (scalar edits, nested
edits, new/removed keys, replaced sections, array pushes; then throw, `{ ok = false }`, or commit):

1. throw / `{ ok = false }`: the live value is the same table, deep-equal to its pre-image,
   every nested table keeps its identity, revision unchanged; a throw reports failure.
2. commit: the new value carries every write, revision +1 and `Meta.Revision` stamped
   (unless `incrementRevision === false`), and the *previous* value is not written through
   (anything still holding the old profile sees the old data).
3. `TransactInPlace`: the same for edits confined to root fields and the declared sections.

Any faster implementation must pass this test unchanged.

## Options considered

| Option | Saves | Why not done now |
| --- | --- | --- |
| Metatable proxy draft (Immer-style CoW on write) | most of the copy | roblox-ts emits `pairs()`, `table.insert`, `table.clone`, `rawget`, `#`; these bypass `__index/__newindex` on a proxy, so reads/writes would silently miss. Not provably equivalent. |
| Root-level lazy section clone (clone a section on first read) | copy of untouched sections | `sanitize(draft)` reads every section after the callback, so all sections get cloned anyway; also breaks `pairs(draft)`. |
| Per-label declared touch sets (extend the production fast path) | copy for hot actions | needs an audit per action; a missed section = rollback leaves partial writes. Possible later, one action at a time, each added to the randomized test with its own section list. |
| Structural sharing after commit | copy at commit | the next transaction then needs write detection on shared subtrees (same proxy problem). |
| Undo journal | copy | requires write interception (same proxy problem). |

Recommendation: keep `Transact` as is (2-ms class copy); if profiling in Studio shows a hot
non-production action, move that action to `TransactInPlace` with an audited key list and add
it to the randomized test.
