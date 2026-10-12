--!strict
-- Purpose: Client-side visual resolution of server-authoritative Astral Forge rolls: wheel spin, crate reveal, anomaly pulse feedback.
-- Features deterministic physics-driven kinematics, spring damping, and ease-out-expo math.

export type KeyframeData = {
	time: number,
	progress: number,
	rotation: number?,
	scale: number?,
	alpha: number?,
	energy: number?,
	shake: number?,
}

export type AnimationPlan = {
	duration: number,
	keyframes: { [number]: KeyframeData },
	completed: boolean,
	evaluate: (self: AnimationPlan, t: number) -> KeyframeData,
}

export type ForgeRollResolver = {
	PlanWheelSpin: (self: ForgeRollResolver, winnerIndex: number, reducedMotion: boolean) -> AnimationPlan,
	PlanCrateReveal: (self: ForgeRollResolver, rarity: string, reducedMotion: boolean) -> AnimationPlan,
	PlanAnomalyPulse: (self: ForgeRollResolver, accurate: boolean, combo: number) -> AnimationPlan,
}

local ForgeRollResolver = {}
ForgeRollResolver.__index = ForgeRollResolver

local function easeOutExpo(x: number): number
	return if x >= 1 then 1 else 1 - math.pow(2, -10 * x)
end

local function easeOutBack(x: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * math.pow(x - 1, 3) + c1 * math.pow(x - 1, 2)
end

local function springEvaluate(t: number, mass: number, stiffness: number, damping: number): number
	local w0 = math.sqrt(stiffness / mass)
	local zeta = damping / (2 * math.sqrt(stiffness * mass))
	if zeta < 1 then
		local wd = w0 * math.sqrt(1 - zeta * zeta)
		return 1 - math.exp(-zeta * w0 * t) * (math.cos(wd * t) + (zeta * w0 / wd) * math.sin(wd * t))
	else
		return 1 - (1 + w0 * t) * math.exp(-w0 * t)
	end
end

local function createEvaluator(keyframes: { KeyframeData }, duration: number)
	return function(_self: AnimationPlan, t: number): KeyframeData
		local clampedTime = math.clamp(t, 0, duration)
		if #keyframes == 0 then
			return { time = clampedTime, progress = 1 }
		end
		if clampedTime <= keyframes[1].time then
			return keyframes[1]
		end
		if clampedTime >= keyframes[#keyframes].time then
			return keyframes[#keyframes]
		end
		for i = 1, #keyframes - 1 do
			local k1 = keyframes[i]
			local k2 = keyframes[i + 1]
			if clampedTime >= k1.time and clampedTime <= k2.time then
				local span = math.max(0.0001, k2.time - k1.time)
				local alpha = (clampedTime - k1.time) / span
				return {
					time = clampedTime,
					progress = k1.progress + (k2.progress - k1.progress) * alpha,
					rotation = if k1.rotation and k2.rotation then k1.rotation + (k2.rotation - k1.rotation) * alpha else k1.rotation,
					scale = if k1.scale and k2.scale then k1.scale + (k2.scale - k1.scale) * alpha else k1.scale,
					alpha = if k1.alpha and k2.alpha then k1.alpha + (k2.alpha - k1.alpha) * alpha else k1.alpha,
					energy = if k1.energy and k2.energy then k1.energy + (k2.energy - k1.energy) * alpha else k1.energy,
					shake = if k1.shake and k2.shake then k1.shake + (k2.shake - k1.shake) * alpha else k1.shake,
				}
			end
		end
		return keyframes[#keyframes]
	end
end

function ForgeRollResolver.new(): ForgeRollResolver
	local self = setmetatable({}, ForgeRollResolver)
	return self :: any
end

function ForgeRollResolver:PlanWheelSpin(winnerIndex: number, reducedMotion: boolean): AnimationPlan
	if reducedMotion then
		local kfs: { KeyframeData } = {
			{ time = 0, progress = 0, rotation = 0, energy = 0 },
			{ time = 0.25, progress = 1, rotation = winnerIndex * 45, energy = 0 },
		}
		return {
			duration = 0.25,
			keyframes = kfs,
			completed = false,
			evaluate = createEvaluator(kfs, 0.25),
		}
	end

	local duration = 3.8
	local sampleCount = 38
	local revolutions = 5
	local targetAngle = revolutions * 360 + (winnerIndex * 45)
	local keyframes: { KeyframeData } = {}

	for i = 0, sampleCount do
		local t = (i / sampleCount) * duration
		local normT = t / duration
		local easedProgress = easeOutExpo(normT)
		local energy = math.max(0, 1 - easedProgress * 1.1)
		local currentAngle = targetAngle * easedProgress

		table.insert(keyframes, {
			time = t,
			progress = easedProgress,
			rotation = currentAngle,
			energy = energy,
			scale = 1 + energy * 0.04,
		})
	end

	return {
		duration = duration,
		keyframes = keyframes,
		completed = false,
		evaluate = createEvaluator(keyframes, duration),
	}
end

function ForgeRollResolver:PlanCrateReveal(rarity: string, reducedMotion: boolean): AnimationPlan
	local isMythic = rarity == "MYTHIC" or rarity == "TRANSCENDENT" or rarity == "DIVINE"
	local isLegendary = rarity == "LEGENDARY" or isMythic

	if reducedMotion then
		local kfs: { KeyframeData } = {
			{ time = 0, progress = 0, scale = 1, alpha = 0, shake = 0, energy = 0 },
			{ time = 0.35, progress = 1, scale = 1, alpha = 1, shake = 0, energy = 0 },
		}
		return {
			duration = 0.35,
			keyframes = kfs,
			completed = false,
			evaluate = createEvaluator(kfs, 0.35),
		}
	end

	local duration = if isMythic then 4.2 elseif isLegendary then 3.2 else 2.4
	local keyframes: { KeyframeData } = {}
	local sampleCount = 32

	for i = 0, sampleCount do
		local t = (i / sampleCount) * duration
		local normT = t / duration
		local shake = 0
		local scale = 1
		local energy = 0
		local alpha = 0

		if normT < 0.4 then
			-- Phase 1: Suspense build / crate rumble
			local phaseNorm = normT / 0.4
			shake = phaseNorm * (if isMythic then 1.5 else 1.0)
			energy = phaseNorm * 0.5
			scale = 1 + phaseNorm * 0.05
		elseif normT < 0.65 then
			-- Phase 2: Pop / Spring burst
			local phaseNorm = (normT - 0.4) / 0.25
			shake = (1 - phaseNorm) * 0.8
			energy = 1.0 - phaseNorm * 0.3
			scale = 1 + springEvaluate(phaseNorm, 1, 140, 16) * 0.2
			alpha = phaseNorm
		else
			-- Phase 3: Settle & Trophy pedestal reveal
			local phaseNorm = (normT - 0.65) / 0.35
			scale = 1.2 - phaseNorm * 0.2
			energy = (1 - phaseNorm) * 0.4
			alpha = 1
			shake = 0
		end

		table.insert(keyframes, {
			time = t,
			progress = normT,
			scale = scale,
			alpha = alpha,
			shake = shake,
			energy = energy,
		})
	end

	return {
		duration = duration,
		keyframes = keyframes,
		completed = false,
		evaluate = createEvaluator(keyframes, duration),
	}
end

function ForgeRollResolver:PlanAnomalyPulse(accurate: boolean, combo: number): AnimationPlan
	local duration = if accurate then 0.65 else 0.4
	local sampleCount = 16
	local keyframes: { KeyframeData } = {}
	local comboScale = math.clamp(1 + combo * 0.08, 1, 2.2)

	for i = 0, sampleCount do
		local t = (i / sampleCount) * duration
		local normT = t / duration
		local decay = math.exp(-6 * normT)
		local scale = 1 + (if accurate then 0.22 else 0.08) * comboScale * decay
		local energy = decay * comboScale

		table.insert(keyframes, {
			time = t,
			progress = normT,
			scale = scale,
			energy = energy,
			alpha = decay,
		})
	end

	return {
		duration = duration,
		keyframes = keyframes,
		completed = false,
		evaluate = createEvaluator(keyframes, duration),
	}
end

return table.freeze(ForgeRollResolver)
