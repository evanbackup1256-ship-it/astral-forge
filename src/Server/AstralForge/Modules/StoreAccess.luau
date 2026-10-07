--!strict
-- Purpose: select native persistence or an explicitly allowed unpublished Studio preview.
-- Owner: persistence. Dependencies: ServerConfig, PreviewStores, PreviewDataStores.
-- Last-reviewed: 2026-10-06.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ServerConfig = require(script.Parent.Parent.ServerConfig)
local PreviewStores = require(script.Parent.PreviewStores)
local PreviewDataStores = require(script.Parent.PreviewDataStores)

local preview =
	PreviewStores.enabled(RunService:IsStudio(), game.GameId, ServerConfig.AllowStudioMemoryFallback == true)
local Access = {}

function Access.isPreview(): boolean
	return preview
end

function Access.data(name: string): PreviewDataStores.NativeOrPreview
	return PreviewDataStores.data(name, preview, function(storeName: string): GlobalDataStore
		return DataStoreService:GetDataStore(storeName)
	end)
end

function Access.ordered(name: string): PreviewStores.Store
	return PreviewStores.ordered(name, preview, function(storeName: string): OrderedDataStore
		return DataStoreService:GetOrderedDataStore(storeName)
	end)
end

return table.freeze(Access)
