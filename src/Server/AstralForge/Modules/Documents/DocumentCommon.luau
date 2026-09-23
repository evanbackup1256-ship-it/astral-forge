--!strict


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function requireDocumentService()

	local sibling = script.Parent:FindFirstChild("DocumentService")
	if sibling then
		return require(sibling)
	end


	sibling = script.Parent:WaitForChild("DocumentService", 5)
	if sibling then
		return require(sibling)
	end


	local candidates: { Instance? } = {}
	local node: Instance? = script
	while node do
		table.insert(candidates, node:FindFirstChild("Packages"))
		node = node.Parent
	end
	local serverAstral = ServerScriptService:FindFirstChild("AstralForge")
	if serverAstral then
		table.insert(candidates, serverAstral:FindFirstChild("Packages"))
	end
	table.insert(candidates, ReplicatedStorage:FindFirstChild("Packages"))

	for _, packages in candidates do
		if packages then
			local module = packages:FindFirstChild("DocumentService")
			if module then
				return require(module)
			end
		end
	end

	error(
		"[DocumentCommon] DocumentService module missing. Expected sibling "
			.. "ServerScriptService.AstralForge.Modules.Documents.DocumentService "
			.. "(vendored under src/server/Modules/Documents/DocumentService). "
			.. "Reconnect Rojo serving default.project.json.",
		0
	)
end

local DocumentService = requireDocumentService()

export type HookEvent = "Open" | "Close" | "Update" | "Read"
export type Migrations = {
	{
		backwardsCompatible: boolean,
		migrate: (data: any) -> any,
	}
}

local DocumentCommon = {}

DocumentCommon.DocumentService = DocumentService
DocumentCommon.DocumentStore = DocumentService.DocumentStore
DocumentCommon.Document = DocumentService.Document
DocumentCommon.SaveUtil = DocumentService.SaveUtil

function DocumentCommon.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[DocumentCommon.deepCopy(key)] = DocumentCommon.deepCopy(child)
	end
	return copy
end

function DocumentCommon.isOk(result: any): boolean
	return type(result) == "table" and result.success == true
end

function DocumentCommon.reason(result: any): string?
	if type(result) == "table" and result.success == false then
		return tostring(result.reason)
	end
	return nil
end

function DocumentCommon.okData(result: any): any
	if DocumentCommon.isOk(result) then
		return result.data
	end
	return nil
end

export type StoreProps = {
	dataStore: any,
	check: (unknown) -> (boolean, any),
	default: any,
	migrations: Migrations?,
	bindToClose: boolean?,
}


function DocumentCommon.baseStoreProps(props: StoreProps, lockSessions: boolean)
	return {
		dataStore = props.dataStore,
		check = props.check,
		default = props.default,
		migrations = props.migrations or {},
		lockSessions = lockSessions,

		bindToClose = if props.bindToClose == nil then false else props.bindToClose,
	}
end

function DocumentCommon.permissiveTableCheck(value: unknown): (boolean, any)
	if type(value) ~= "table" then
		return false, value
	end
	return true, value
end

return DocumentCommon
