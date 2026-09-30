--!nonstrict
--[=[
	RuntimeKit: merged module suite.
	Members (6): deepFreeze, gameplay, network, pool, reentrancy, scheduler.

	Each member keeps its original source inside its own closure (so every member
	still has its own local-register budget) and is evaluated lazily, exactly once,
	on first access.  Use `require(<this module>)("<Member>")` (or index the returned
	table with the member name) to get a member's exports.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("RuntimeKit: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("RuntimeKit: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: deepFreeze   (merged from deepFreeze.luau, 27 lines)
-- ======================================================================
__defs["deepFreeze"] = function()
-- Compiled with roblox-ts v3.0.0
local function freezeRecursive(value, visited)
	local _value = value
	if not (type(_value) == "table") then
		return nil
	end
	local target = value
	if visited[target] ~= nil or table.isfrozen(target) then
		return nil
	end
	visited[target] = true
	for _, child in pairs(target) do
		freezeRecursive(child, visited)
	end
	table.freeze(target)
end
local function deepFreeze(value)
	freezeRecursive(value, {})
	return value
end
local StaticStructureDeepFreezer = table.freeze({
	freeze = deepFreeze,
})
return {
	deepFreeze = deepFreeze,
	StaticStructureDeepFreezer = StaticStructureDeepFreezer,
}
end

-- ======================================================================
-- Module: gameplay   (merged from gameplay.luau, 620 lines)
-- ======================================================================
__defs["gameplay"] = function()
-- Compiled with roblox-ts v3.0.0
local economyScheduler = __load("scheduler").economyScheduler
local deepFreeze = __load("deepFreeze").deepFreeze
--* Immutable nested prestige evaluator; committing a layer always returns a new level vector. 
local MultiTierPrestigeEngine
do
	MultiTierPrestigeEngine = setmetatable({}, {
		__tostring = function()
			return "MultiTierPrestigeEngine"
		end,
	})
	MultiTierPrestigeEngine.__index = MultiTierPrestigeEngine
	function MultiTierPrestigeEngine.new(...)
		local self = setmetatable({}, MultiTierPrestigeEngine)
		return self:constructor(...) or self
	end
	function MultiTierPrestigeEngine:constructor(layers)
		local copied = {}
		for _, layer in layers do
			table.insert(copied, layer)
		end
		self.layers = deepFreeze(copied)
	end
	function MultiTierPrestigeEngine:evaluate(runValue, levels)
		local safeValue = math.max(0, runValue)
		local nextLevels = {}
		for _, level in levels do
			table.insert(nextLevels, level)
		end
		local multiplier = 1
		local reward = 0
		local nextRequirement = math.huge
		for index = 0, #self.layers - 1 do
			local layer = self.layers[index + 1]
			local _condition = nextLevels[index + 1]
			if _condition == nil then
				_condition = 0
			end
			local level = math.max(0, math.floor(_condition))
			nextLevels[index + 1] = level
			multiplier *= math.pow(layer.multiplierScale, level)
			if index == 0 then
				nextRequirement = layer.requirement * math.pow(1.18, level)
				reward = math.floor(math.sqrt(safeValue / math.max(1, layer.requirement)) * layer.rewardScale)
			end
		end
		return {
			canPrestige = safeValue >= nextRequirement,
			reward = reward,
			nextRequirement = nextRequirement,
			multiplier = multiplier,
			levels = table.freeze(nextLevels),
		}
	end
	function MultiTierPrestigeEngine:commit(levels, layerIndex)
		local updatedLevels = {}
		for _, level in levels do
			table.insert(updatedLevels, level)
		end
		local index = math.clamp(math.floor(layerIndex), 0, math.max(0, #self.layers - 1))
		local _condition = updatedLevels[index + 1]
		if _condition == nil then
			_condition = 0
		end
		updatedLevels[index + 1] = math.max(0, math.floor(_condition)) + 1
		return table.freeze(updatedLevels)
	end
end
--* Priority-sorted macro scheduler; the scheduler owns asynchronous execution boundaries. 
local AutomationScriptingMatrix
do
	AutomationScriptingMatrix = setmetatable({}, {
		__tostring = function()
			return "AutomationScriptingMatrix"
		end,
	})
	AutomationScriptingMatrix.__index = AutomationScriptingMatrix
	function AutomationScriptingMatrix.new(...)
		local self = setmetatable({}, AutomationScriptingMatrix)
		return self:constructor(...) or self
	end
	function AutomationScriptingMatrix:constructor(scheduler)
		if scheduler == nil then
			scheduler = economyScheduler
		end
		self.tasks = {}
		self.running = false
		self.scheduler = scheduler
	end
	function AutomationScriptingMatrix:register(task)
		local _tasks = self.tasks
		local _id = task.id
		local _task = task
		_tasks[_id] = _task
		return function()
			local _tasks_1 = self.tasks
			local _id_1 = task.id
			-- ▼ Map.delete ▼
			local _valueExisted = _tasks_1[_id_1] ~= nil
			_tasks_1[_id_1] = nil
			-- ▲ Map.delete ▲
			return _valueExisted
		end
	end
	function AutomationScriptingMatrix:tick()
		if self.running or next(self.tasks) == nil then
			return false
		end
		self.running = true
		local batch = {}
		for _, task in self.tasks do
			table.insert(batch, task)
		end
		table.sort(batch, function(left, right)
			return left.priority > right.priority
		end)
		return self.scheduler:schedule({
			compute = function()
				for _, task in batch do
					task.run()
				end
				return true
			end,
			complete = function()
				self.running = false
			end,
			failed = function()
				self.running = false
			end,
		})
	end
end
--* Bounded offline simulator that never loops once per elapsed second. 
local OfflineCatchUpProcessor
do
	OfflineCatchUpProcessor = setmetatable({}, {
		__tostring = function()
			return "OfflineCatchUpProcessor"
		end,
	})
	OfflineCatchUpProcessor.__index = OfflineCatchUpProcessor
	function OfflineCatchUpProcessor.new(...)
		local self = setmetatable({}, OfflineCatchUpProcessor)
		return self:constructor(...) or self
	end
	function OfflineCatchUpProcessor:constructor(sliceSeconds, maxSlices)
		if sliceSeconds == nil then
			sliceSeconds = 60
		end
		if maxSlices == nil then
			maxSlices = 2_880
		end
		self.sliceSeconds = sliceSeconds
		self.maxSlices = maxSlices
	end
	function OfflineCatchUpProcessor:process(initial, elapsedSeconds, step)
		local state = initial
		local remaining = math.clamp(math.floor(elapsedSeconds), 0, self.sliceSeconds * self.maxSlices)
		while remaining > 0 do
			local slice = math.min(self.sliceSeconds, remaining)
			state = step(state, slice)
			remaining -= slice
		end
		return state
	end
end
--* O(1) claimed/completed checks backed by a 32-bit milestone mask. 
local DynamicQuestMilestoneMatrix
do
	DynamicQuestMilestoneMatrix = setmetatable({}, {
		__tostring = function()
			return "DynamicQuestMilestoneMatrix"
		end,
	})
	DynamicQuestMilestoneMatrix.__index = DynamicQuestMilestoneMatrix
	function DynamicQuestMilestoneMatrix.new(...)
		local self = setmetatable({}, DynamicQuestMilestoneMatrix)
		return self:constructor(...) or self
	end
	function DynamicQuestMilestoneMatrix:constructor()
		self.rules = {}
	end
	function DynamicQuestMilestoneMatrix:register(rule)
		if #self.rules >= 31 or rule.bit <= 0 or bit32.band(rule.bit, rule.bit - 1) ~= 0 then
			return nil
		end
		local _rules = self.rules
		local _rule = rule
		table.insert(_rules, _rule)
	end
	function DynamicQuestMilestoneMatrix:evaluate(mask, context)
		local updatedMask = bit32.band(mask, 0x7fffffff)
		for _, rule in self.rules do
			if rule.test(context) then
				updatedMask = bit32.bor(updatedMask, rule.bit)
			end
		end
		return updatedMask
	end
	function DynamicQuestMilestoneMatrix:has(mask, bit)
		return bit32.band(mask, bit) ~= 0
	end
end
local function weightedIndex(rewards, randomValue)
	local total = 0
	for _, reward in rewards do
		total += math.max(0, reward.weight)
	end
	if total <= 0 then
		return 0
	end
	local low = 0
	local high = #rewards - 1
	local target = math.clamp(randomValue, 0, 0.999999) * total
	while low < high do
		local middle = math.floor((low + high) / 2)
		local middlePrefix = 0
		do
			local index = 0
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					index += 1
				else
					_shouldIncrement = true
				end
				if not (index <= middle) then
					break
				end
				middlePrefix += math.max(0, rewards[index + 1].weight)
			end
		end
		if middlePrefix > target then
			high = middle
		else
			low = middle + 1
		end
	end
	return low
end
--* Deterministic weighted wheel selection plus a render-only deceleration plan. 
local ProceduralSpinWheelMatrix
do
	ProceduralSpinWheelMatrix = setmetatable({}, {
		__tostring = function()
			return "ProceduralSpinWheelMatrix"
		end,
	})
	ProceduralSpinWheelMatrix.__index = ProceduralSpinWheelMatrix
	function ProceduralSpinWheelMatrix.new(...)
		local self = setmetatable({}, ProceduralSpinWheelMatrix)
		return self:constructor(...) or self
	end
	function ProceduralSpinWheelMatrix:constructor()
	end
	function ProceduralSpinWheelMatrix:choose(rewards, seed)
		local random = Random.new(math.floor(seed))
		return weightedIndex(rewards, random:NextNumber())
	end
	function ProceduralSpinWheelMatrix:targetRotation(start, index, count, turns)
		if turns == nil then
			turns = 7
		end
		local segment = 360 / math.max(1, count)
		local desired = -index * segment
		local correction = ((desired - start) % 360 + 360) % 360
		return start + math.max(1, turns) * 360 + correction
	end
end
local GachaCrateDropSimulator
do
	GachaCrateDropSimulator = setmetatable({}, {
		__tostring = function()
			return "GachaCrateDropSimulator"
		end,
	})
	GachaCrateDropSimulator.__index = GachaCrateDropSimulator
	function GachaCrateDropSimulator.new(...)
		local self = setmetatable({}, GachaCrateDropSimulator)
		return self:constructor(...) or self
	end
	function GachaCrateDropSimulator:constructor()
	end
	function GachaCrateDropSimulator:choose(drops, seed)
		if #drops == 0 then
			return nil
		end
		local index = weightedIndex(drops, Random.new(math.floor(seed)):NextNumber())
		return drops[index + 1]
	end
end
local OfflineTimeDilationCore
do
	OfflineTimeDilationCore = setmetatable({}, {
		__tostring = function()
			return "OfflineTimeDilationCore"
		end,
	})
	OfflineTimeDilationCore.__index = OfflineTimeDilationCore
	function OfflineTimeDilationCore.new(...)
		local self = setmetatable({}, OfflineTimeDilationCore)
		return self:constructor(...) or self
	end
	function OfflineTimeDilationCore:constructor()
		self.multiplier = 1
	end
	function OfflineTimeDilationCore:set(value)
		self.multiplier = math.clamp(value, 0.1, 16)
	end
	function OfflineTimeDilationCore:get()
		return self.multiplier
	end
	function OfflineTimeDilationCore:scale(deltaTime)
		return math.max(0, deltaTime) * self.multiplier
	end
end
local LiveOpsContentScheduler
do
	LiveOpsContentScheduler = setmetatable({}, {
		__tostring = function()
			return "LiveOpsContentScheduler"
		end,
	})
	LiveOpsContentScheduler.__index = LiveOpsContentScheduler
	function LiveOpsContentScheduler.new(...)
		local self = setmetatable({}, LiveOpsContentScheduler)
		return self:constructor(...) or self
	end
	function LiveOpsContentScheduler:constructor(windows)
		local copied = {}
		for _, window in windows do
			table.insert(copied, window)
		end
		self.windows = deepFreeze(copied)
	end
	function LiveOpsContentScheduler:active(now)
		if now == nil then
			now = os.time()
		end
		local _exp = self.windows
		-- ▼ ReadonlyArray.find ▼
		local _callback = function(entry)
			return now >= entry.startsAt and now < entry.endsAt
		end
		local _result
		for _i, _v in _exp do
			if _callback(_v, _i - 1, _exp) == true then
				_result = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		return _result
	end
end
local TelemetryAnalyticsPipeline
do
	TelemetryAnalyticsPipeline = setmetatable({}, {
		__tostring = function()
			return "TelemetryAnalyticsPipeline"
		end,
	})
	TelemetryAnalyticsPipeline.__index = TelemetryAnalyticsPipeline
	function TelemetryAnalyticsPipeline.new(...)
		local self = setmetatable({}, TelemetryAnalyticsPipeline)
		return self:constructor(...) or self
	end
	function TelemetryAnalyticsPipeline:constructor(capacity)
		if capacity == nil then
			capacity = 128
		end
		self.capacity = capacity
		self.cursor = 0
		self.count = 0
		self.events = table.create(math.max(1, capacity))
	end
	function TelemetryAnalyticsPipeline:record(kind, value, at)
		if value == nil then
			value = 1
		end
		if at == nil then
			at = os.clock()
		end
		self.events[self.cursor + 1] = {
			kind = kind,
			value = value,
			at = at,
		}
		self.cursor = (self.cursor + 1) % #self.events
		self.count = math.min(#self.events, self.count + 1)
	end
	function TelemetryAnalyticsPipeline:flush(consumer)
		local output = {}
		do
			local offset = 0
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					offset += 1
				else
					_shouldIncrement = true
				end
				if not (offset < self.count) then
					break
				end
				local _arg0 = self.events[(self.cursor - self.count + offset + #self.events) % #self.events + 1]
				table.insert(output, _arg0)
			end
		end
		self.count = 0
		consumer(output)
	end
end
--* Client telemetry counterpart; it only reports velocity anomalies, never mutates economy state. 
local HeuristicAntiCheatGuard
do
	HeuristicAntiCheatGuard = setmetatable({}, {
		__tostring = function()
			return "HeuristicAntiCheatGuard"
		end,
	})
	HeuristicAntiCheatGuard.__index = HeuristicAntiCheatGuard
	function HeuristicAntiCheatGuard.new(...)
		local self = setmetatable({}, HeuristicAntiCheatGuard)
		return self:constructor(...) or self
	end
	function HeuristicAntiCheatGuard:constructor()
		self.observations = {}
	end
	function HeuristicAntiCheatGuard:observe(subject, production, revision, at)
		if at == nil then
			at = os.clock()
		end
		local _observations = self.observations
		local _subject = subject
		local previous = _observations[_subject]
		if not previous then
			local _observations_1 = self.observations
			local _subject_1 = subject
			local _arg1 = {
				production = production,
				revision = revision,
				at = at,
				score = 0,
			}
			_observations_1[_subject_1] = _arg1
			return 0
		end
		local elapsed = math.max(0.05, at - previous.at)
		local acceleration = math.max(0, production - previous.production) / elapsed
		if acceleration > math.max(1, production) * 1_000 then
			previous.score += 1
		end
		if revision < previous.revision then
			previous.score += 2
		end
		previous.production = production
		previous.revision = revision
		previous.at = at
		return previous.score
	end
	function HeuristicAntiCheatGuard:forget(subject)
		local _observations = self.observations
		local _subject = subject
		_observations[_subject] = nil
	end
end
local StateDiffTelemetryBuffer
do
	StateDiffTelemetryBuffer = setmetatable({}, {
		__tostring = function()
			return "StateDiffTelemetryBuffer"
		end,
	})
	StateDiffTelemetryBuffer.__index = StateDiffTelemetryBuffer
	function StateDiffTelemetryBuffer.new(...)
		local self = setmetatable({}, StateDiffTelemetryBuffer)
		return self:constructor(...) or self
	end
	function StateDiffTelemetryBuffer:constructor(capacity)
		if capacity == nil then
			capacity = 64
		end
		self.capacity = capacity
		self.cursor = 0
		self.values = table.create(math.max(1, capacity))
	end
	function StateDiffTelemetryBuffer:push(previous, current)
		self.values[self.cursor + 1] = current - previous
		self.cursor = (self.cursor + 1) % #self.values
	end
	function StateDiffTelemetryBuffer:latest()
		local _condition = self.values[(self.cursor - 1 + #self.values) % #self.values + 1]
		if _condition == nil then
			_condition = 0
		end
		return _condition
	end
end
--* Fixed-size circular diagnostics stream for the isolated test dashboard. 
local StructuredLoggingSystem
do
	StructuredLoggingSystem = setmetatable({}, {
		__tostring = function()
			return "StructuredLoggingSystem"
		end,
	})
	StructuredLoggingSystem.__index = StructuredLoggingSystem
	function StructuredLoggingSystem.new(...)
		local self = setmetatable({}, StructuredLoggingSystem)
		return self:constructor(...) or self
	end
	function StructuredLoggingSystem:constructor(capacity)
		if capacity == nil then
			capacity = 128
		end
		self.capacity = capacity
		self.cursor = 0
		self.count = 0
		self.entries = table.create(math.max(1, capacity))
	end
	function StructuredLoggingSystem:write(level, message, at)
		if at == nil then
			at = os.clock()
		end
		self.entries[self.cursor + 1] = table.freeze({
			level = string.sub(level, 1, 16),
			message = string.sub(message, 1, 192),
			at = at,
		})
		self.cursor = (self.cursor + 1) % #self.entries
		self.count = math.min(#self.entries, self.count + 1)
	end
	function StructuredLoggingSystem:read()
		local output = {}
		do
			local offset = 0
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					offset += 1
				else
					_shouldIncrement = true
				end
				if not (offset < self.count) then
					break
				end
				local index = (self.cursor - self.count + offset + #self.entries) % #self.entries
				local entry = self.entries[index + 1]
				if entry ~= nil then
					table.insert(output, entry)
				end
			end
		end
		return table.freeze(output)
	end
	function StructuredLoggingSystem:clear()
		self.cursor = 0
		self.count = 0
	end
end
local LocalizationInternationalizationBridge
do
	LocalizationInternationalizationBridge = setmetatable({}, {
		__tostring = function()
			return "LocalizationInternationalizationBridge"
		end,
	})
	LocalizationInternationalizationBridge.__index = LocalizationInternationalizationBridge
	function LocalizationInternationalizationBridge.new(...)
		local self = setmetatable({}, LocalizationInternationalizationBridge)
		return self:constructor(...) or self
	end
	function LocalizationInternationalizationBridge:constructor(translations)
		local _object = table.clone(translations)
		setmetatable(_object, nil)
		self.translations = deepFreeze(_object)
	end
	function LocalizationInternationalizationBridge:text(key, fallback)
		if fallback == nil then
			fallback = key
		end
		local _condition = self.translations[key]
		if _condition == nil then
			_condition = fallback
		end
		return _condition
	end
end
local gameplayEngines = table.freeze({
	prestige = MultiTierPrestigeEngine,
	automation = AutomationScriptingMatrix,
	offline = OfflineCatchUpProcessor,
	quests = DynamicQuestMilestoneMatrix,
	wheel = ProceduralSpinWheelMatrix,
	gacha = GachaCrateDropSimulator,
	dilation = OfflineTimeDilationCore,
	liveOps = LiveOpsContentScheduler,
	telemetry = TelemetryAnalyticsPipeline,
	antiCheat = HeuristicAntiCheatGuard,
	diffs = StateDiffTelemetryBuffer,
	logs = StructuredLoggingSystem,
	localization = LocalizationInternationalizationBridge,
})
return {
	MultiTierPrestigeEngine = MultiTierPrestigeEngine,
	AutomationScriptingMatrix = AutomationScriptingMatrix,
	OfflineCatchUpProcessor = OfflineCatchUpProcessor,
	DynamicQuestMilestoneMatrix = DynamicQuestMilestoneMatrix,
	ProceduralSpinWheelMatrix = ProceduralSpinWheelMatrix,
	GachaCrateDropSimulator = GachaCrateDropSimulator,
	OfflineTimeDilationCore = OfflineTimeDilationCore,
	LiveOpsContentScheduler = LiveOpsContentScheduler,
	TelemetryAnalyticsPipeline = TelemetryAnalyticsPipeline,
	HeuristicAntiCheatGuard = HeuristicAntiCheatGuard,
	StateDiffTelemetryBuffer = StateDiffTelemetryBuffer,
	StructuredLoggingSystem = StructuredLoggingSystem,
	LocalizationInternationalizationBridge = LocalizationInternationalizationBridge,
	gameplayEngines = gameplayEngines,
}
end

-- ======================================================================
-- Module: network   (merged from network.luau, 126 lines)
-- ======================================================================
__defs["network"] = function()
-- Compiled with roblox-ts v3.0.0
local TELEMETRY_VERSION = 1
local TELEMETRY_BYTES = 30
local ECONOMY_PACKET_VERSION = 1
local ECONOMY_PACKET_BYTES = 48
local TelemetryFlags = {
	ReducedMotion = 1,
	UIEffects = 2,
	SoundEffects = 4,
	HideOtherPlots = 8,
}
local SocialFlags = {
	Friended = 1,
	Blocked = 2,
	Muted = 4,
	ChatBanned = 8,
}
local function finite(value)
	return value == value and value ~= math.huge and value ~= -math.huge
end
local function safeF32(value)
	if not finite(value) then
		return 0
	end
	return math.clamp(value, -3.4e38, 3.4e38)
end
local function safeF64(value)
	return if finite(value) then value else 0
end
local function safeU32(value)
	if not finite(value) then
		return 0
	end
	return math.floor(math.max(0, value)) % 4_294_967_296
end
local function hasFlag(flags, flag)
	return bit32.band(flags, flag) ~= 0
end
local function setFlag(flags, flag, enabled)
	return if enabled then bit32.bor(flags, flag) else bit32.band(flags, bit32.bnot(flag))
end
local function encodeTelemetry(record)
	local packed = buffer.create(TELEMETRY_BYTES)
	buffer.writeu8(packed, 0, TELEMETRY_VERSION)
	buffer.writeu8(packed, 1, bit32.band(record.flags, 0xff))
	buffer.writeu32(packed, 2, safeU32(record.revision))
	buffer.writef32(packed, 6, safeF32(record.cash))
	buffer.writef32(packed, 10, safeF32(record.vault))
	buffer.writef32(packed, 14, safeF32(record.production))
	buffer.writef32(packed, 18, safeF32(record.capacity))
	buffer.writef32(packed, 22, safeF32(record.cores))
	buffer.writef32(packed, 26, safeF32(record.stardust))
	return packed
end
local function decodeTelemetry(payload)
	if buffer.len(payload) < TELEMETRY_BYTES or buffer.readu8(payload, 0) ~= TELEMETRY_VERSION then
		return nil
	end
	return {
		revision = buffer.readu32(payload, 2),
		flags = buffer.readu8(payload, 1),
		cash = buffer.readf32(payload, 6),
		vault = buffer.readf32(payload, 10),
		production = buffer.readf32(payload, 14),
		capacity = buffer.readf32(payload, 18),
		cores = buffer.readf32(payload, 22),
		stardust = buffer.readf32(payload, 26),
	}
end
--* Compact economy mirror: two bitfields/IDs followed by f64 currency lanes. 
local function encodeEconomy(record)
	local packed = buffer.create(ECONOMY_PACKET_BYTES)
	buffer.writeu8(packed, 0, ECONOMY_PACKET_VERSION)
	buffer.writeu8(packed, 1, 0)
	buffer.writeu32(packed, 4, safeU32(record.userId))
	buffer.writeu32(packed, 8, bit32.band(record.socialFlags, 0xffffffff))
	buffer.writeu32(packed, 12, safeU32(record.revision))
	buffer.writef64(packed, 16, safeF64(record.cash))
	buffer.writef64(packed, 24, safeF64(record.vault))
	buffer.writef64(packed, 32, safeF64(record.production))
	buffer.writef64(packed, 40, safeF64(record.capacity))
	return packed
end
local function decodeEconomy(payload)
	if buffer.len(payload) < ECONOMY_PACKET_BYTES or buffer.readu8(payload, 0) ~= ECONOMY_PACKET_VERSION then
		return nil
	end
	return {
		userId = buffer.readu32(payload, 4),
		socialFlags = buffer.readu32(payload, 8),
		revision = buffer.readu32(payload, 12),
		cash = buffer.readf64(payload, 16),
		vault = buffer.readf64(payload, 24),
		production = buffer.readf64(payload, 32),
		capacity = buffer.readf64(payload, 40),
	}
end
--* Immutable-name facade used by profile/social replication code. 
local BinaryStateBitpacker = table.freeze({
	encodeTelemetry = encodeTelemetry,
	decodeTelemetry = decodeTelemetry,
	encodeEconomy = encodeEconomy,
	decodeEconomy = decodeEconomy,
})
--* O(1) relationship flag operations shared by server mirrors and chat gates. 
local BitfieldRelationshipMatrix = table.freeze({
	flags = SocialFlags,
	has = hasFlag,
	set = setFlag,
})
return {
	hasFlag = hasFlag,
	setFlag = setFlag,
	encodeTelemetry = encodeTelemetry,
	decodeTelemetry = decodeTelemetry,
	encodeEconomy = encodeEconomy,
	decodeEconomy = decodeEconomy,
	TELEMETRY_VERSION = TELEMETRY_VERSION,
	TELEMETRY_BYTES = TELEMETRY_BYTES,
	ECONOMY_PACKET_VERSION = ECONOMY_PACKET_VERSION,
	ECONOMY_PACKET_BYTES = ECONOMY_PACKET_BYTES,
	TelemetryFlags = TelemetryFlags,
	SocialFlags = SocialFlags,
	BinaryStateBitpacker = BinaryStateBitpacker,
	BitfieldRelationshipMatrix = BitfieldRelationshipMatrix,
}
end

-- ======================================================================
-- Module: pool   (merged from pool.luau, 90 lines)
-- ======================================================================
__defs["pool"] = function()
-- Compiled with roblox-ts v3.0.0
--* Fixed-capacity object recycler. Luau cannot pin memory, so this is the allocation-free equivalent. 
local MemoryPinnedTableAllocator
do
	MemoryPinnedTableAllocator = setmetatable({}, {
		__tostring = function()
			return "MemoryPinnedTableAllocator"
		end,
	})
	MemoryPinnedTableAllocator.__index = MemoryPinnedTableAllocator
	function MemoryPinnedTableAllocator.new(...)
		local self = setmetatable({}, MemoryPinnedTableAllocator)
		return self:constructor(...) or self
	end
	function MemoryPinnedTableAllocator:constructor(capacity, factory, reset)
		self.reset = reset
		self.free = {}
		self.leased = {}
		local bounded = math.max(1, math.floor(capacity))
		do
			local index = 0
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					index += 1
				else
					_shouldIncrement = true
				end
				if not (index < bounded) then
					break
				end
				local _free = self.free
				local _arg0 = factory(index)
				table.insert(_free, _arg0)
			end
		end
	end
	function MemoryPinnedTableAllocator:acquire()
		local _exp = self.free
		-- ▼ Array.pop ▼
		local _length = #_exp
		local _result = _exp[_length]
		_exp[_length] = nil
		-- ▲ Array.pop ▲
		local value = _result
		if value ~= nil then
			self.leased[value] = true
		end
		return value
	end
	function MemoryPinnedTableAllocator:release(value)
		local _leased = self.leased
		local _value = value
		-- ▼ Set.delete ▼
		local _valueExisted = _leased[_value] ~= nil
		_leased[_value] = nil
		-- ▲ Set.delete ▲
		if not _valueExisted then
			return false
		end
		self.reset(value)
		local _free = self.free
		local _value_1 = value
		table.insert(_free, _value_1)
		return true
	end
	function MemoryPinnedTableAllocator:releaseAll()
		for value in self.leased do
			self.reset(value)
			local _exp = self.free
			table.insert(_exp, value)
		end
		table.clear(self.leased)
	end
	function MemoryPinnedTableAllocator:available()
		return #self.free
	end
	function MemoryPinnedTableAllocator:active()
		-- ▼ ReadonlySet.size ▼
		local _size = 0
		for _ in self.leased do
			_size += 1
		end
		-- ▲ ReadonlySet.size ▲
		return _size
	end
end
return {
	MemoryPinnedTableAllocator = MemoryPinnedTableAllocator,
}
end

-- ======================================================================
-- Module: reentrancy   (merged from reentrancy.luau, 51 lines)
-- ======================================================================
__defs["reentrancy"] = function()
-- Compiled with roblox-ts v3.0.0
--* Per-Actor named lock. Cross-Actor state remains message-owned as required by Parallel Luau. 
local ParallelTaskReentrancyLock
do
	ParallelTaskReentrancyLock = setmetatable({}, {
		__tostring = function()
			return "ParallelTaskReentrancyLock"
		end,
	})
	ParallelTaskReentrancyLock.__index = ParallelTaskReentrancyLock
	function ParallelTaskReentrancyLock.new(...)
		local self = setmetatable({}, ParallelTaskReentrancyLock)
		return self:constructor(...) or self
	end
	function ParallelTaskReentrancyLock:constructor()
		self.active = {}
	end
	function ParallelTaskReentrancyLock:enter(key)
		local _active = self.active
		local _key = key
		if _active[_key] ~= nil then
			return false
		end
		local _active_1 = self.active
		local _key_1 = key
		_active_1[_key_1] = true
		return true
	end
	function ParallelTaskReentrancyLock:leave(key)
		local _active = self.active
		local _key = key
		_active[_key] = nil
	end
	function ParallelTaskReentrancyLock:run(key, callback)
		if not self:enter(key) then
			return false, nil
		end
		local ok, result = pcall(callback)
		self:leave(key)
		if not ok then
			error(result)
		end
		return true, result
	end
	function ParallelTaskReentrancyLock:clear()
		table.clear(self.active)
	end
end
return {
	ParallelTaskReentrancyLock = ParallelTaskReentrancyLock,
}
end

-- ======================================================================
-- Module: scheduler   (merged from scheduler.luau, 92 lines)
-- ======================================================================
__defs["scheduler"] = function()
-- Compiled with roblox-ts v3.0.0
local ParallelTaskReentrancyLock = __load("reentrancy").ParallelTaskReentrancyLock
--* Bounded pure-compute queue. It enters Parallel Luau only when hosted by an Actor. 
local AsynchronousActorScheduler
do
	AsynchronousActorScheduler = setmetatable({}, {
		__tostring = function()
			return "AsynchronousActorScheduler"
		end,
	})
	AsynchronousActorScheduler.__index = AsynchronousActorScheduler
	function AsynchronousActorScheduler.new(...)
		local self = setmetatable({}, AsynchronousActorScheduler)
		return self:constructor(...) or self
	end
	function AsynchronousActorScheduler:constructor(batchSize)
		if batchSize == nil then
			batchSize = 8
		end
		self.batchSize = batchSize
		self.queue = {}
		self.parallel = script:GetActor() ~= nil
		self.lock = ParallelTaskReentrancyLock.new()
		self.draining = false
		self.destroyed = false
	end
	function AsynchronousActorScheduler:schedule(job)
		if self.destroyed then
			return false
		end
		local _queue = self.queue
		local _job = job
		table.insert(_queue, _job)
		if not self.draining then
			self.draining = true
			task.defer(function()
				return self:drain()
			end)
		end
		return true
	end
	function AsynchronousActorScheduler:drain()
		if self.destroyed then
			return nil
		end
		if not self.lock:enter("drain") then
			return nil
		end
		local processed = 0
		while processed < self.batchSize and #self.queue > 0 do
			local job = table.remove(self.queue, 1)
			if not job then
				break
			end
			if self.parallel then
				task.desynchronize()
			end
			local ok, result = pcall(job.compute)
			if self.parallel then
				task.synchronize()
			end
			if ok then
				job.complete(result)
			else
				local _result = job.failed
				if _result ~= nil then
					_result(result)
				end
			end
			processed += 1
		end
		self.lock:leave("drain")
		if #self.queue > 0 then
			task.defer(function()
				return self:drain()
			end)
		else
			self.draining = false
		end
	end
	function AsynchronousActorScheduler:destroy()
		self.destroyed = true
		table.clear(self.queue)
		self.lock:clear()
		self.draining = false
	end
end
local economyScheduler = AsynchronousActorScheduler.new(6)
return {
	AsynchronousActorScheduler = AsynchronousActorScheduler,
	economyScheduler = economyScheduler,
}
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		return __load(name)
	end,
})
