--!strict
-- Purpose: Client-side Astral Forge UI controller: Rodux store, React root, page routing, remote binding, effect routing.
-- Owner: Astral Forge client shell. Dependencies: React, Rodux, ReactRoblox, Protocol, CoreKit, ForgeService. Last-reviewed: 2026-10-05.

export type ForgeUIController = {
	Start: (self: ForgeUIController, parent: ScreenGui) -> (),
	Stop: (self: ForgeUIController) -> (),
	Dispatch: (self: ForgeUIController, action: string, payload: any) -> any,
	SetPage: (self: ForgeUIController, page: string) -> (),
}

local ForgeUIController = {}
ForgeUIController.__index = ForgeUIController

function ForgeUIController.new(): ForgeUIController
	local self = setmetatable({}, ForgeUIController)
	-- TODO: create/own clientStore, React root, remote binding
	return self :: any
end

function ForgeUIController:Start(_parent: ScreenGui): ()
	-- TODO: mount React tree and wire State/Toast/Effect/Shutdown remotes
end

function ForgeUIController:Stop(): ()
	-- TODO: unmount React root and disconnect remotes
end

function ForgeUIController:Dispatch(_action: string, _payload: any): any
	-- TODO: route through ForgeService client remote with optimistic patch policy
	return nil
end

function ForgeUIController:SetPage(_page: string): ()
	-- TODO: dispatch navigation action
end

return table.freeze(ForgeUIController)
