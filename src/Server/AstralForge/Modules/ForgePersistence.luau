--!strict
-- Purpose: Astral Forge data persistence wrapper: profile load, atomic mutation, anomaly pending-action queue, save-on-leave.
-- Owner: Astral Forge server data. Dependencies: DataService, DocumentService. Last-reviewed: 2026-10-05.

export type ForgePersistence = {
	Load: (self: ForgePersistence, player: Player) -> boolean,
	Save: (self: ForgePersistence, player: Player, releaseSession: boolean?) -> boolean,
	AtomicUpdate: (self: ForgePersistence, player: Player, transform: (profile: any) -> any, reason: string?) -> boolean,
	QueueAnomalyAction: (self: ForgePersistence, player: Player, action: string) -> (),
	DrainAnomalyActions: (self: ForgePersistence, player: Player, profile: any) -> { string },
}

local ForgePersistence = {}
ForgePersistence.__index = ForgePersistence

function ForgePersistence.new(): ForgePersistence
	local self = setmetatable({}, ForgePersistence)
	return self :: any
end

function ForgePersistence:Load(_player: Player): boolean
	-- TODO: delegate to DataService + recover faulted trades / anomaly queue
	return false
end

function ForgePersistence:Save(_player: Player, _releaseSession: boolean?): boolean
	-- TODO: delegate to DataService:Save
	return false
end

function ForgePersistence:AtomicUpdate(_player: Player, _transform: (profile: any) -> any, _reason: string?): boolean
	-- TODO: delegate to DataService:AtomicUpdate with retry/logging
	return false
end

function ForgePersistence:QueueAnomalyAction(_player: Player, _action: string): ()
	-- TODO: append to runtime pending-anomaly queue
end

function ForgePersistence:DrainAnomalyActions(_player: Player, _profile: any): { string }
	-- TODO: return and clear only processed actions, preserving newly appended ones
	return {}
end

return table.freeze(ForgePersistence)
