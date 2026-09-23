--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataTemplate = require(script.Parent:WaitForChild("DataTemplate"))
local Economy = require(script.Parent:WaitForChild("Modules"):WaitForChild("Economy"))
local ProfileIntegrity = require(script.Parent:WaitForChild("Services"):WaitForChild("ServerServices")).ProfileIntegrity
local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))

local ReleaseReadiness = {}
local MAX_VALUE = 1e308

local function finite(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and math.abs(value) <= MAX_VALUE
end

local function expect(condition: boolean, message: string): ()
	if not condition then error(message, 2) end
end

local function uniqueIds(list: { any }, label: string): ()
	local seen = {}
	for index, item in list do
		local id = type(item) == "table" and item.Id or nil
		expect(
			(type(id) == "string" and id ~= "") or (type(id) == "number" and id == math.floor(id)),
			label .. " has an invalid Id"
		)
		local key = tostring(id)
		expect(not seen[key], string.format("%s contains duplicate Id %s", label, key))
		seen[key] = index
	end
end

local function idSet(list: { any }): { [any]: boolean }
	local result = {}
	for _, item in list do result[item.Id] = true end
	return result
end

local function validateProfile(profile): ()
	for _, key in { "Cash", "Vault", "Cores", "Stardust", "Rebirths", "RunCash", "LifetimeCash" } do
		expect(finite(profile[key]) and profile[key] >= 0, key .. " left its finite persistence envelope")
	end
	expect(finite(Economy.Production(profile)), "production is not finite")
	expect(finite(Economy.Capacity(profile)), "capacity is not finite")
	expect(finite(Economy.TapPower(profile)), "tap power is not finite")
end

local function quickChecks(): { string }
	local checks = {}
	local function passed(name: string)
		table.insert(checks, name)
	end

	expect(type(GameConfig.Game.Version) == "string" and GameConfig.Game.Version ~= "", "game version is missing")
	expect(type(GameConfig.Game.DataVersion) == "number" and GameConfig.Game.DataVersion >= 1, "data version is invalid")
	passed("version and data schema")

	uniqueIds(GameConfig.Machines, "machines")
	uniqueIds(GameConfig.Research, "research")
	uniqueIds(GameConfig.GridUpgrades, "star grid")
	uniqueIds(GameConfig.Zones, "worlds")
	uniqueIds(GameConfig.Items.Definitions, "relic definitions")
	uniqueIds(GameConfig.Items.Crates, "crates")
	uniqueIds(GameConfig.Operations.Artifacts, "artifacts")
	uniqueIds(GameConfig.Operations.Expeditions, "expeditions")
	uniqueIds(GameConfig.Operations.WeeklyDirectives, "weekly directives")
	passed("configuration identity")

	local machineIds = idSet(GameConfig.Machines)
	local researchIds = idSet(GameConfig.Research)
	local gridIds = idSet(GameConfig.GridUpgrades)
	local artifactIds = idSet(GameConfig.Operations.Artifacts)
	local crateIds = idSet(GameConfig.Items.Crates)
	for _, machine in GameConfig.Machines do
		if machine.PreviousId then expect(machineIds[machine.PreviousId] == true, machine.Id .. " references a missing machine prerequisite") end
	end
	for _, research in GameConfig.Research do
		if research.PreviousId then expect(researchIds[research.PreviousId] == true, research.Id .. " references a missing research prerequisite") end
	end
	for _, node in GameConfig.GridUpgrades do
		if node.PreviousId then expect(gridIds[node.PreviousId] == true, node.Id .. " references a missing Star Grid prerequisite") end
	end
	for _, expedition in GameConfig.Operations.Expeditions do
		expect(artifactIds[expedition.ArtifactId] == true, expedition.Id .. " references a missing artifact")
	end
	for _, offer in GameConfig.Items.ShopOffers do
		if offer.CrateId then expect(crateIds[offer.CrateId] == true, offer.Id .. " references a missing crate") end
	end
	local seen = {}
	local function validateRewards(value, path: string)
		if type(value) ~= "table" or seen[value] then return end
		seen[value] = true
		if type(value.Boost) == "string" then
			expect(GameConfig.Boosts[value.Boost] ~= nil, path .. " references a missing boost " .. value.Boost)
		end
		if type(value.Keys) == "table" then
			for crateId in value.Keys do expect(crateIds[crateId] == true, path .. " references a missing crate key " .. tostring(crateId)) end
		end
		for key, child in value do
			if type(child) == "table" then validateRewards(child, path .. "." .. tostring(key)) end
		end
	end
	validateRewards(GameConfig, "GameConfig")
	passed("configuration references")

	local profile = DataTemplate.New()
	validateProfile(profile)
	for _, machine in GameConfig.Machines do
		local previous = 0
		for _, level in { 0, 1, 10, 100, 10_000, machine.MaxLevel } do
			local cost = Economy.MachineCost(machine.Id, level)
			expect(finite(cost) and cost >= previous, machine.Id .. " machine cost is invalid or regressed")
			previous = cost
		end
	end
	for _, research in GameConfig.Research do
		local previous = 0
		for _, level in { 0, 1, 10, 100, 10_000, research.MaxLevel } do
			local cost = Economy.ResearchCost(research.Id, level)
			expect(finite(cost) and cost >= previous, research.Id .. " research cost is invalid or regressed")
			previous = cost
		end
	end
	for _, rank in { 0, 1, 10, 100, 10_000, 9_000_000_000_000_000 } do
		local flux, stardust = Economy.ContinuumCosts(rank)
		local rebirths, cores = Economy.DomainRequirements(rank)
		local essence, domainDust = Economy.DomainRewards(rank)
		expect(finite(flux) and finite(stardust), "Continuum cost overflow")
		expect(finite(rebirths) and finite(cores), "Domain requirement overflow")
		expect(finite(essence) and finite(domainDust), "Domain reward overflow")
	end
	passed("endless economy envelope")

	ProfileIntegrity.Record(profile, "release-test", 0)
	ProfileIntegrity.Seal(profile)
	local expectedCash = profile.Cash
	profile.Cash = math.huge
	local healthy = ProfileIntegrity.VerifyAndRecover(profile)
	expect(not healthy and profile.Cash == expectedCash, "integrity journal did not recover the last known-good state")
	local malformed = DataTemplate.New()
	local branch = {}
	malformed.UnknownMigrationBranch = branch
	for _ = 1, 24 do
		local child = {}
		branch.Next = child
		branch = child
	end
	local verifyOk, malformedHealthy = pcall(ProfileIntegrity.VerifyAndRecover, malformed)
	expect(verifyOk and not malformedHealthy, "malformed profile verification escaped its recovery boundary")
	passed("profile corruption recovery")

	return checks
end

local function simulationStep(profile, random: Random): ()
	local machine = GameConfig.Machines[random:NextInteger(1, #GameConfig.Machines)]
	local current = profile.Machines[machine.Id] or 0
	local cost = Economy.MachineCost(machine.Id, current)
	local production = math.max(1, Economy.Production(profile))
	profile.Cash = math.min(MAX_VALUE, profile.Cash + production * random:NextNumber(0.25, 4))
	profile.RunCash = math.min(MAX_VALUE, profile.RunCash + production)
	profile.LifetimeCash = math.min(MAX_VALUE, profile.LifetimeCash + production)
	if profile.Cash >= cost and current < machine.MaxLevel then
		profile.Cash -= cost
		profile.Machines[machine.Id] = current + 1
	end
	if random:NextNumber() < 0.002 then
		profile.Cores = math.min(MAX_VALUE, profile.Cores + Economy.PrestigeReward(profile.RunCash))
		profile.Rebirths = math.min(MAX_VALUE, profile.Rebirths + 1)
		profile.Cash = 0
		profile.RunCash = 0
	end
end

function ReleaseReadiness.RunQuick()
	local startedAt = os.clock()
	local checks = quickChecks()
	local profile = DataTemplate.New()
	local random = Random.new(0xA57A1)
	for iteration = 1, 50_000 do
		simulationStep(profile, random)
		if iteration % 1_000 == 0 then validateProfile(profile) end
	end
	ProfileIntegrity.Record(profile, "quick-soak", profile.Meta.Revision)
	ProfileIntegrity.Seal(profile)
	validateProfile(profile)
	table.insert(checks, "50,000-action deterministic economy soak")
	return {
		Ok = true,
		Checks = checks,
		Iterations = 50_000,
		ElapsedSeconds = os.clock() - startedAt,
	}
end

function ReleaseReadiness.RunSoak(minutes: number?)
	expect(RunService:IsStudio(), "long release soaks are Studio-only")
	local duration = math.clamp(minutes or 30, 1, 60) * 60
	local startedAt = os.clock()
	local deadline = startedAt + duration
	local checks = quickChecks()
	local profile = DataTemplate.New()
	local random = Random.new(0xF047E)
	local iterations = 0
	while os.clock() < deadline do
		for _ = 1, 500 do
			simulationStep(profile, random)
			iterations += 1
		end
		validateProfile(profile)
		ProfileIntegrity.Record(profile, "soak-checkpoint", iterations)
		ProfileIntegrity.Seal(profile)
		task.wait()
	end
	table.insert(checks, string.format("%.0f-minute economy and integrity soak", duration / 60))
	return {
		Ok = true,
		Checks = checks,
		Iterations = iterations,
		ElapsedSeconds = os.clock() - startedAt,
	}
end

return table.freeze(ReleaseReadiness)
