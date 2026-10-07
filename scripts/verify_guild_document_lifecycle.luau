--!strict
-- Purpose: Reproduce deleted-guild resurrection and prevent stale approvals across UpdateAsync retries.
-- Owner: Astral Forge persistence verification. Dependencies: Lune fs/luau; actual GuildService source. Last-reviewed: 2026-10-05.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

type Document = { Id: string, Activity: number, Value: number }
type Transform = (Document) -> Document?
type Callback = (Document?) -> Document?
type Store = { UpdateAsync: (Store, string, Callback) -> Document? }
type Cache = { [string]: Document }
type Host = {
	_store: Store,
	_cache: Cache,
	_studio: Cache,
	_cacheExpiry: { [string]: number },
	_queueLeaderboard: (Host, string, number) -> (),
}
type Updater = (Host, string, Transform) -> (boolean, string?, Document?)
type Mode = { Studio: boolean, Fail: boolean, RetryMissing: boolean }
type Counts = { Writes: number, Leaderboard: number }
type ReadStore = { GetAsync: (ReadStore, string) -> Document? }
type ReadHost = {
	_store: ReadStore,
	_cache: Cache,
	_studio: Cache,
	_cacheExpiry: { [string]: number },
	_pruneCache: (ReadHost) -> (),
}
type Reader = (ReadHost, string) -> Document?

local function clone(document: Document): Document
	return table.clone(document)
end

local function loadUpdate(source: string, mode: Mode): Updater
	local factory: () -> Updater = luau.load("local GuildService = {}\n" .. source .. "\nreturn GuildService._update", {
		environment = {
			RunService = {
				IsStudio = function(): boolean
					return mode.Studio
				end,
			},
			copy = clone,
			type = type,
			pcall = pcall,
			tostring = tostring,
		},
	})
	return factory()
end

local function host(document: Document?, mode: Mode): (Host, Counts)
	local counts: Counts = { Writes = 0, Leaderboard = 0 }
	local store: Store = {
		UpdateAsync = function(_self: Store, _id: string, callback: Callback): Document?
			if mode.Fail then
				error("DataStore unavailable")
			end
			local final = callback(document)
			if mode.RetryMissing then
				final = callback(nil)
			end
			if final then
				counts.Writes += 1
			end
			return final
		end,
	}
	local instance: Host = {
		_store = store,
		_cache = { guild = { Id = "guild", Activity = 0, Value = 1 } },
		_studio = {},
		_cacheExpiry = {},
		_queueLeaderboard = function(_self: Host, _id: string, _activity: number): ()
			counts.Leaderboard += 1
		end,
	}
	return instance, counts
end

local function increment(document: Document): Document
	document.Value += 1
	return document
end

local sourceRoot: string = process.args[1] or "."
local source: string = fs.readFile(sourceRoot .. "/src/Server/AstralForge/Services/CoreServices.luau")
local start = assert(source:find("function GuildService:_update(id: string, transform)", 1, true))
local finish = assert(source:find("function GuildService:_findByTag", start, true))
local current: string = source:sub(start, finish - 1)
local before: string = fs.readFile("audit/repro-fixtures/GUILD-RESURRECTION.before.txt")
local live: Mode = { Studio = false, Fail = false, RetryMissing = false }
local oldHost, oldCounts = host(nil, live)
local oldAccepted = loadUpdate(before, live)(oldHost, "guild", increment)
assert(oldAccepted and oldCounts.Writes == 1, "baseline must reproduce cached deleted-guild resurrection")

local missing, missingCounts = host(nil, live)
local accepted, _, updated = loadUpdate(current, live)(missing, "guild", increment)
assert(not accepted and updated == nil and missingCounts.Writes == 0 and missingCounts.Leaderboard == 0)
assert(missing._cache.guild.Value == 1)

local retry: Mode = { Studio = false, Fail = false, RetryMissing = true }
local retried, retryCounts = host({ Id = "guild", Activity = 0, Value = 1 }, retry)
accepted, _, updated = loadUpdate(current, retry)(retried, "guild", increment)
assert(not accepted and updated == nil and retryCounts.Writes == 0 and retryCounts.Leaderboard == 0)
assert(retried._cache.guild.Value == 1, "an earlier approval must not advance cache or report success")

local valid, validCounts = host({ Id = "guild", Activity = 0, Value = 1 }, live)
accepted, _, updated = loadUpdate(current, live)(valid, "guild", increment)
assert(accepted and updated and updated.Value == 2 and validCounts.Writes == 1 and validCounts.Leaderboard == 1)
local denied, deniedCounts = host({ Id = "guild", Activity = 0, Value = 1 }, live)
accepted = loadUpdate(current, live)(denied, "guild", function(_document: Document): Document?
	return nil
end)
assert(not accepted and deniedCounts.Writes == 0, "denied changes must cancel instead of writing an unchanged document")

local unavailable: Mode = { Studio = false, Fail = true, RetryMissing = false }
local failed, failedCounts = host(nil, unavailable)
accepted = loadUpdate(current, unavailable)(failed, "guild", increment)
assert(not accepted and failedCounts.Writes == 0 and failed._cache.guild.Value == 1)
local studio: Mode = { Studio = true, Fail = true, RetryMissing = false }
local preview, previewCounts = host(nil, studio)
accepted, _, updated = loadUpdate(current, studio)(preview, "guild", increment)
assert(accepted and updated and updated.Value == 2 and previewCounts.Writes == 0)
assert(preview._studio.guild.Value == 2, "Studio-only preview fallback remains isolated from durable live writes")
local readStart = assert(source:find("function GuildService:_read(id: string)", 1, true))
local readFinish = assert(source:find("function GuildService:_update", readStart, true))
local readFactory: () -> Reader =
	luau.load("local GuildService = {}\n" .. source:sub(readStart, readFinish - 1) .. "\nreturn GuildService._read", {
		environment = {
			RunService = {
				IsStudio = function(): boolean
					return false
				end,
			},
			copy = clone,
			type = type,
			pcall = pcall,
			os = {
				clock = function(): number
					return 100
				end,
			},
		},
	})
local reader: Reader = readFactory()
local unavailableRead = false
local reading: ReadHost = {
	_store = {
		GetAsync = function(_self: ReadStore, _id: string): Document?
			if unavailableRead then
				error("temporary read outage")
			end
			return nil
		end,
	},
	_cache = { guild = { Id = "guild", Activity = 0, Value = 1 } },
	_studio = {},
	_cacheExpiry = { guild = 1 },
	_pruneCache = function(_self: ReadHost): () end,
}
assert(reader(reading, "guild") == nil and reading._cache.guild == nil and reading._cacheExpiry.guild == nil)
reading._cache.guild = { Id = "guild", Activity = 0, Value = 1 }
unavailableRead = true
assert(reader(reading, "guild") ~= nil, "a temporary read outage must not be mistaken for a confirmed deletion")
print("[TEST] reproduced old guild resurrection; deleted/retried/denied/unavailable live mutations now fail closed")
