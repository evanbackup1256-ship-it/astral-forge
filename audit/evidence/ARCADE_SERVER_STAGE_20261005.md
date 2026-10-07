# Arcade server-stage evidence

Status: partial evidence, not a release or section sign-off.

- Source sync: 19 arcade/shared/gateway/session modules matched their source checksums in place 135153679037687 before launch.
- Native Studio server run: `ProofHash.hex("abc")` matched the SHA-256 vector; the new relative-path shared modules loaded successfully.
- Isolated gateway test used a real test Player identity but a separate in-memory profile, save spy and log spy. One Dice round completed; a repeated request replayed without adding another score. Observed: ten catalog games, one played round, three save calls (initial/start/retry), one outcome log.
- This test did not invoke the production player request remote, mutate the real player's arcade/currency state, or prove a live DataStore write. No such claim is made.
- Headless suite: `REGRESSION_SUITE/run.luau` exited 0 with ten-game, proof, replay/version, hidden-state, save/load and refund cases included.
- Live game startup loaded the new server modules and client session routing. Historical console output still includes the previously recorded CorePackages timeout; this run is not a global clean-console sign-off.
- The attempt to end the scripted session lost its original Studio connection before an acknowledgement. A newly discovered Studio connection was then read-only verified as the same place, in Edit mode with no active test. The mechanism of that session transition is not claimed.

Remaining: full request/session/firewall path, real save failures/rejoin, complete transcript verifier, UI controls, ten bespoke models, responsive rendered comparisons, and strict analysis.
