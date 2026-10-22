--!nocheck
-- Pacing report: active minutes to rebirths 1-5 and to the first unlock of worlds 4+, for the
-- default two-sessions-a-day policy at 4 and 1 taps/s. Run `npx rbxtsc` first.
-- Usage: lune run scripts/_pace_report.luau [days]
local Sim = require("./_balance_sim")
local days = tonumber((...)) or 4
for _, taps in { 4, 1 } do
	local r = Sim.run({ Days = days, TapsPerSecond = taps, Step = 5 })
	local out, seen = {}, {}
	for i = 1, 5 do
		local x = r.Stats.Rebirths[i]
		table.insert(out, string.format("rb%d=%s", i, x and string.format("%.1fm", x.Active / 60) or "-"))
	end
	for _, e in r.Events do
		if e.Kind == "zone" and not seen[e.Value] and e.Value >= 4 then
			seen[e.Value] = true
			table.insert(out, string.format("w%d=%.1fm(rb%d)", e.Value, e.Active / 60, e.Rebirths))
		end
	end
	print(string.format("taps %d, %d days (%.1f h active): %s | rebirths %d", taps, days, r.ActiveSeconds / 3600, table.concat(out, " "), r.Profile.Rebirths))
end
