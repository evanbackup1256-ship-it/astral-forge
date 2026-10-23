# Social: Guild, Crew, Chat, Mailbox
Research: /workspace/research/forge-ui-2.md P2.4 (Guild, Crew, Chat, Mail budgets), forge-ui-1 "Phone fit";
tap floor 44px (https://create.roblox.com/docs/production/publishing/accessibility, P2.2 sources).

Audit at 1920x1080 / 1366x768 / 844x390 (719 wide, 219 fold) and 640x286 (588 wide):
- Guild: member rows are 60 (phone, compact) / 84 / 112 / 122: all >= 44 tap floor. No change.
- Crew: rows 52; 844x390 shows floor((219-48)/52) = 3 rows. No change (text sizes are owned by the QA sweep).
- Chat: phones already use the 44px peer chip rail; the 220px side list only from 1280. Messages fill (minHeight 120). No change.
- Mailbox (changed): the push-navigation route now only applies to pages under 560px or portrait phones.
  Landscape phones get the list | reader split (list 0.38, reader 0.62):
  | viewport | page W | list | reader |
  |---|---|---|---|
  | 1920x1080 | 1601 | 608 | 993 |
  | 1366x768 | 1047 | 398 | 649 |
  | 844x390 | 719 | 273 | 446 |
  | 640x286 | 588 | 223 | 365 |
  The reader uses the stacked parcel layout on phones (buttons full width, 44px TapTarget).
