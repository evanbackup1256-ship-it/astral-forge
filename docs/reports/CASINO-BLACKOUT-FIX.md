# Casino blackout fix

Casino actions set `arcadeBusy` while their request and reveal animation run. The main AppShell frame incorrectly used `not arcadeBusy` as a visibility condition, hiding the casino and every other element inside the shell. Its visibility now depends only on the separate crate reveal overlay.

The casino busy latch, navigation lock, animation budgets, and casino results remain intact. The fix is synchronized to the confirmed main Astral Forge Studio in Edit mode; it is not published.

`verify_client_polish.luau` executes the actual shell visibility expression for all four combinations of idle/active casino and open/closed crate reveal. All combinations pass. The existing casino double-click and rejection recovery checks also pass.
