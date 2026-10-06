--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

type Reporter = (actionType: string, penaltyCode: string) -> ()

local Probe = {}

local NATIVE_GETFENV = getfenv
local SAMPLE_CALLS = 0x80
local BASELINE_WINDOWS = 0x7
local TIMING_RATIO_LIMIT = 0x8
local REQUIRED_TIMING_WINDOWS = 0x4
local REQUIRED_MOTION_WINDOWS = 0x2
local REPORT_COOLDOWN_SECONDS = 0x1F

local function bytes(values: { number }): string
	return string.char(table.unpack(values))
end


local ENVIRONMENT_HEADER = bytes({
	69, 78, 86, 73, 82, 79, 78, 77, 69, 78, 84, 95, 72, 79, 79, 75, 95, 86, 73, 79, 76, 65, 84, 73, 79,
	78,
})
local ENVIRONMENT_CODE = bytes({
	71, 69, 84, 70, 69, 78, 86, 95, 84, 73, 77, 73, 78, 71, 95, 80, 82, 79, 88, 89, 95, 86, 49,
})
local MOTION_HEADER = bytes({
	80, 72, 89, 83, 73, 67, 83, 95, 73, 78, 84, 69, 71, 82, 73, 84, 89, 95, 86, 73, 79, 76, 65, 84, 73,
	79, 78,
})
local MOTION_CODE = bytes({
	67, 76, 73, 69, 78, 84, 95, 77, 79, 84, 73, 79, 78, 95, 69, 78, 86, 69, 76, 79, 80, 69, 95, 86, 49,
})

local running = false
local generation = 0
local lastReportAt = -math.huge

local function median(samples: { number }): number
	table.sort(samples)
	local middle = math.ceil(#samples / 2)
	return samples[middle] or 0
end

local function benchmarkEnvironment(reader: any): number
	local sink: any = nil
	local startedAt = os.clock()
	for _ = 1, SAMPLE_CALLS do
		sink = reader(0)
	end
	local elapsed = os.clock() - startedAt
	if sink == nil then
		return math.huge
	end
	return math.max(elapsed, 1e-7)
end

local function calibrate(): number
	local samples: { number } = table.create(BASELINE_WINDOWS)
	for _ = 1, BASELINE_WINDOWS do
		table.insert(samples, benchmarkEnvironment(NATIVE_GETFENV))
		task.wait()
	end
	return median(samples)
end

local function collisionBaseline(character: Model): { [BasePart]: boolean }
	local result: { [BasePart]: boolean } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.CanCollide then
			result[descendant] = true
		end
	end
	return result
end

local function hasHighForceMover(root: BasePart): boolean
	local hasVelocity = false
	local hasGyro = false
	for _, child in root:GetChildren() do
		if child:IsA("BodyVelocity") then
			hasVelocity = child.MaxForce.Magnitude >= 1e8
		elseif child:IsA("BodyGyro") then
			hasGyro = child.MaxTorque.Magnitude >= 1e8
		end
	end
	return hasVelocity and hasGyro
end

local function motionAnomaly(character: Model, baseline: { [BasePart]: boolean }): boolean
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local graceUntil = character:GetAttribute("AF_MovementGraceUntil")
	if type(graceUntil) == "number" and Workspace:GetServerTimeNow() < graceUntil then
		return false
	end

	local velocity = root.AssemblyLinearVelocity
	local impossibleVelocity = velocity.Magnitude > 350
	local forcedPlatformMotion = humanoid.PlatformStand and velocity.Magnitude > 40
	local suspiciousMover = hasHighForceMover(root)

	local collisionOverrides = 0
	for part in baseline do
		if part.Parent ~= nil and not part.CanCollide then
			collisionOverrides += 1
			if collisionOverrides >= 2 then
				break
			end
		end
	end

	return impossibleVelocity or forcedPlatformMotion or suspiciousMover or collisionOverrides >= 2
end

local function report(reporter: Reporter, actionType: string, penaltyCode: string): ()
	local now = os.clock()
	if now - lastReportAt < REPORT_COOLDOWN_SECONDS then
		return
	end
	lastReportAt = now
	pcall(reporter, actionType, penaltyCode)
end

function Probe.Start(reporter: Reporter): ()
	if running or type(reporter) ~= "function" then
		return
	end
	running = true
	generation += 1
	local workerGeneration = generation

	task.spawn(function()
		local baselineTiming = calibrate()
		local timingWindows = 0
		local motionWindows = 0
		local observedCharacter: Model? = nil
		local baselineCollisions: { [BasePart]: boolean } = {}

		while running and workerGeneration == generation do
			local currentReader: any = getfenv
			local currentTiming = benchmarkEnvironment(currentReader)
			local timingChanged = currentReader ~= NATIVE_GETFENV
				or currentTiming >= baselineTiming * TIMING_RATIO_LIMIT
			if timingChanged then
				timingWindows += 1
			else
				timingWindows = math.max(0, timingWindows - 1)
			end

			local player = Players.LocalPlayer
			local character = if player then player.Character else nil
			if character ~= observedCharacter then
				observedCharacter = character
				baselineCollisions = if character then collisionBaseline(character) else {}
				motionWindows = 0
			end
			if character and motionAnomaly(character, baselineCollisions) then
				motionWindows += 1
			else
				motionWindows = math.max(0, motionWindows - 1)
			end

			if timingWindows >= REQUIRED_TIMING_WINDOWS then
				report(reporter, ENVIRONMENT_HEADER, ENVIRONMENT_CODE)
				timingWindows = 0
			elseif motionWindows >= REQUIRED_MOTION_WINDOWS then
				report(reporter, MOTION_HEADER, MOTION_CODE)
				motionWindows = 0
			end

			task.wait(3)
		end
	end)
end

function Probe.Stop(): ()
	running = false
	generation += 1
end

return table.freeze(Probe)
