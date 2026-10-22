--!nocheck
-- Locale key lint: every English key is named Scope.Name, has copy with no stray edge whitespace,
-- and (via verify_locale) is used with the right argument count. Exits non-zero on any problem.
-- Run `npx rbxtsc` first.
local H = require("./_server_harness")
local Locale = H.load("Shared/AstralForge/Shared/Locale")
local Pipeline = H.load("Shared/AstralForge/Shared/LocalePipeline")

local problems = Pipeline.lintTable(Locale.EN, Locale.EN, true)
for _, p in problems do
	print(string.format("  %-12s %s  %s", p.kind, p.key, p.detail))
end
if #problems > 0 then
	error(string.format("lint_locale: %d problems", #problems))
end
local count = 0
for _ in Locale.EN do count += 1 end
print(string.format("[TEST] lint_locale: %d keys clean", count))
