local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function childOf(parent, name)
	if typeof(parent) ~= "Instance" then
		return nil
	end
	return parent:FindFirstChild(name)
end

local function requireChild(parent, name)
	local child = childOf(parent, name)
	if child == nil or not child:IsA("ModuleScript") then
		return nil
	end
	local ok, loaded = pcall(require, child)
	if not ok or type(loaded) ~= "table" then
		return nil
	end
	return loaded
end

local function moduleScript(parent, name)
	local child = childOf(parent, name)
	if child == nil then
		return nil
	end
	if child:IsA("ModuleScript") then
		return child
	end
	local initScript = childOf(child, "init")
	if initScript ~= nil and initScript:IsA("ModuleScript") then
		return initScript
	end
	return nil
end

local include = childOf(ReplicatedStorage, "rbxts_include")
local nodes = childOf(childOf(include, "node_modules"), "@rbxts")
local importScript = childOf(include, "TSImport")
local importTsModule = nil
if importScript ~= nil and importScript:IsA("ModuleScript") then
	local ok, loaded = pcall(require, importScript)
	if ok and type(loaded) == "function" then
		importTsModule = loaded
	end
end

local servicesModule = requireChild(nodes, "services")
local Players = game:GetService("Players")
if servicesModule ~= nil and servicesModule.Players ~= nil then
	Players = servicesModule.Players
end

local maidModule = requireChild(childOf(nodes, "maid"), "Maid")
local signalModule = requireChild(childOf(nodes, "lemon-signal"), "src")
local Signal = nil
if signalModule ~= nil then
	local candidate = signalModule.Signal
	if candidate == nil then
		candidate = signalModule.default
	end
	if type(candidate) == "table" then
		Signal = candidate
	end
end
local matterModule = requireChild(childOf(nodes, "matter"), "lib")

local PageVisit = nil
local world = nil
local session = nil
pcall(function()
	if matterModule == nil or type(matterModule.component) ~= "function" or type(matterModule.World) ~= "table" or type(matterModule.World.new) ~= "function" then
		return nil
	end
	local visit = matterModule.component("PageVisit")
	local nextWorld = matterModule.World.new()
	local nextSession = nextWorld:spawn(visit({
		page = "Overview",
		at = 0,
	}))
	PageVisit = visit
	world = nextWorld
	session = nextSession
end)

local maid = nil
pcall(function()
	if maidModule ~= nil and type(maidModule.new) == "function" then
		maid = maidModule.new()
	end
end)
local navigated = nil
pcall(function()
	if Signal ~= nil and type(Signal.new) == "function" then
		navigated = Signal.new()
	end
end)
pcall(function()
	if maid ~= nil and navigated ~= nil and type(maid.GiveTask) == "function" then
		maid:GiveTask(navigated)
	end
end)

local journalState = nil
local journalReady = false
local debouncePage = nil

local journalScript = moduleScript(childOf(nodes, "action-journal"), "out")
if journalScript ~= nil and type(importTsModule) == "function" then
	local loadedJournal, journalPkg = pcall(importTsModule, journalScript)
	if loadedJournal and type(journalPkg) == "table" and type(journalPkg.StateManager) == "table" and type(journalPkg.ActionJournal) == "table" and type(journalPkg.StateManager.new) == "function" and type(journalPkg.ActionJournal.new) == "function" then
		pcall(function()
			local state = journalPkg.StateManager.new({
				page = "Overview",
			})
			journalPkg.ActionJournal.new(state, {
				mode = 0,
				historySize = 32,
			})
			journalState = state
			journalReady = true
		end)
	end
end

local function authorName()
	local ok, name = pcall(function()
		local player = Players.LocalPlayer
		if player ~= nil then
			return player.Name
		end
		return nil
	end)
	if ok and type(name) == "string" and name ~= "" then
		return name
	end
	return "player"
end

local function record(pageId)
	if journalReady and journalState ~= nil and type(journalState.setPath) == "function" then
		pcall(function()
			journalState:setPath("page", pageId, authorName())
		end)
	end
	if world ~= nil and session ~= nil and PageVisit ~= nil and type(world.insert) == "function" then
		pcall(function()
			world:insert(session, PageVisit({
				page = pageId,
				at = os.clock(),
			}))
		end)
	end
	if navigated ~= nil and type(navigated.Fire) == "function" then
		pcall(function()
			navigated:Fire(pageId)
		end)
	end
end

local timersScript = moduleScript(childOf(nodes, "set-timeout"), "out")
if timersScript ~= nil and type(importTsModule) == "function" then
	local loadedTimers, timers = pcall(importTsModule, timersScript)
	if loadedTimers and type(timers) == "table" and type(timers.debounce) == "function" then
		pcall(function()
			debouncePage = timers.debounce(record, 0.12, {
				leading = true,
				trailing = false,
			})
		end)
	end
end

local function notePage(pageId)
	if type(pageId) ~= "string" or pageId == "" then
		return nil
	end
	if debouncePage ~= nil then
		local ok = pcall(debouncePage, pageId)
		if ok then
			return nil
		end
	end
	record(pageId)
end

local function shutdown()
	pcall(function()
		if debouncePage ~= nil and debouncePage.cancel ~= nil then
			debouncePage.cancel()
		end
	end)
	pcall(function()
		if maid ~= nil and type(maid.DoCleaning) == "function" then
			maid:DoCleaning()
		elseif navigated ~= nil and type(navigated.Destroy) == "function" then
			navigated:Destroy()
		end
	end)
	debouncePage = nil
	journalReady = false
	journalState = nil
	navigated = nil
	maid = nil
end

return {
	notePage = notePage,
	shutdown = shutdown,
}
