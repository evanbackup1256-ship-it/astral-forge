-- Compiled with roblox-ts v3.0.0
local economyScheduler = require(script.Parent.scheduler).economyScheduler
local deepFreeze = require(script.Parent.deepFreeze).deepFreeze
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
	local prefix = 0
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
