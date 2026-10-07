--!strict
-- Purpose: Server-owned arcade gateway with validated requests, transaction callbacks, save boundaries and outcome logs.
-- Owner: Astral Forge arcade. Dependencies: Shared ArcadeEngine/types/RemoteRegistry. Last-reviewed: 2026-10-05.
local Types = require("@game/ReplicatedStorage/AstralForge/Shared/ArcadeTypes")
local Engine = require("@game/ReplicatedStorage/AstralForge/Shared/ArcadeEngine")
local Registry = require("@game/ReplicatedStorage/AstralForge/Shared/RemoteRegistry")
export type Context = {
	mutate: (player: Player, transform: (profile: Types.Profile) -> Types.Reply) -> Types.Reply,
	get: (player: Player) -> Types.Profile?,
	save: (player: Player) -> boolean,
	newSeed: () -> string,
	newId: () -> string,
	now: () -> number,
	log: (player: Player, result: Types.FinishedRound) -> (),
}
export type API = {
	request: (player: Player, payload: Registry.WireValue) -> Types.Reply,
	get: (player: Player) -> Types.Reply,
	snapshot: (profile: Types.Profile) -> Types.PublicState?,
}

return function(context: Context): API
	local dependencies: Types.Dependencies = { now = context.now, newSeed = context.newSeed, newId = context.newId }
	local function ensure(profile: Types.Profile): Types.State
		if not profile.Arcade then
			profile.Arcade = Engine.new(dependencies)
		end
		return profile.Arcade
	end
	local function snapshot(profile: Types.Profile): Types.PublicState?
		return if profile.Arcade then Engine.snapshot(profile.Arcade) else nil
	end
	local function get(player: Player): Types.Reply
		local completed: Types.FinishedRound? = nil
		local initialized = false
		local reply = context.mutate(player, function(profile: Types.Profile): Types.Reply
			initialized = profile.Arcade == nil
			local state = ensure(profile)
			completed = Engine.tick(state, dependencies)
			return { ok = true, Arcade = Engine.snapshot(state) }
		end)
		if not reply.ok then
			return reply
		end
		if (initialized or completed) and not context.save(player) then
			return { ok = false, error = "The arcade checkpoint is waiting for a save. Please retry shortly." }
		end
		if completed then
			context.log(player, completed)
		end
		return reply
	end
	local function request(player: Player, payload: Registry.WireValue): Types.Reply
		local parsed, problem = Registry.arcade(payload)
		if not parsed then
			return { ok = false, error = problem }
		end
		local reply = context.mutate(player, function(profile: Types.Profile): Types.Reply
			return Engine.apply(ensure(profile), parsed, dependencies)
		end)
		if not reply.ok then
			return reply
		end
		-- Save accepted starts and completed outcomes, including replay retries after a failed save.
		-- Intermediate card/tile progress also participates in normal profile autosave and leave-save.
		if (parsed.Action == "Start" or reply.Result) and not context.save(player) then
			return { ok = false, error = "The round checkpoint is waiting for a save. Retry the same action." }
		end
		if reply.Result and not reply.Replayed then
			context.log(player, reply.Result)
		end
		local profile = context.get(player)
		if profile then
			reply.Arcade = snapshot(profile)
		end
		return reply
	end
	local api: API = { request = request, get = get, snapshot = snapshot }
	return table.freeze(api)
end
