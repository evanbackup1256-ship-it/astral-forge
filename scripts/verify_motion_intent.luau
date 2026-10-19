local MotionIntent = require("../out/Shared/AstralForge/Shared/MotionIntent")

local failures = 0
local function check(cond: boolean, label: string)
	if not cond then
		failures += 1
		print("[FAIL] " .. label)
	end
end

check(MotionIntent.classify("Claim reward") == "reward", "claim reward -> reward")
check(MotionIntent.classify("Delete preset") == "dangerButton", "delete -> danger")
check(MotionIntent.classify("Confirm") == "primaryButton", "confirm -> primary")
check(MotionIntent.classify("RebirthPanel") == "ceremony", "rebirth -> ceremony")
check(MotionIntent.classify("CrateRevealStage") == "reveal", "crate -> reveal")
check(MotionIntent.classify(nil) == "card", "nil -> card")

for _, role in MotionIntent.roles() do
	local plan = MotionIntent.resolve({ role = role })
	check(plan.role == role, role .. " keeps role")
	check(plan.enter.stiffness > 0 and plan.enter.damping > 0, role .. " enter spring valid")
	local reduced = MotionIntent.resolve({ role = role, reduced = true })
	check(reduced.particles == 0 and reduced.shake == 0 and reduced.travel == 0, role .. " reduced removes motion")
	local ratio = reduced.enter.damping / (2 * math.sqrt(reduced.enter.stiffness))
	check(math.abs(ratio - 1) < 1e-6, role .. " reduced is critically damped")
end

local common = MotionIntent.resolve({ role = "reveal", rarity = "Common" })
local mythic = MotionIntent.resolve({ role = "reveal", rarity = "Mythic" })
local astral = MotionIntent.resolve({ role = "reveal", rarity = "Astral" })
check(mythic.particles > common.particles, "rarity scales particles")
check(mythic.cue == "crateRevealMythic", "mythic cue")
check(MotionIntent.resolve({ role = "reveal", rarity = "Epic" }).cue == "crateRevealEpic", "epic cue")
check(astral.celebrate and not mythic.celebrate, "only top tiers celebrate")
check(not MotionIntent.resolve({ role = "reveal", rarity = "Astral", allowConfetti = false }).celebrate, "confetti budget respected")

local low = MotionIntent.resolve({ role = "reveal", rarity = "Astral", tier = 0, particleBudget = 3 })
check(low.particles <= 3, "particle budget cap")
check(low.shake < astral.shake, "low tier shakes less")

check(MotionIntent.resolve({ role = "toast", tone = "Error" }).cue == "noticeError", "toast tone cue")

local plan = MotionIntent.resolve({ role = "listRow" })
local last = -1
for i = 0, 200 do
	local d = MotionIntent.delay(plan, i)
	check(d >= last and d <= 0.42, "stagger monotone + capped @" .. i)
	last = d
end

if failures > 0 then
	error(`motion intent guard failed ({failures})`)
end
print("[TEST] motion intent passed | roles=" .. #MotionIntent.roles())
