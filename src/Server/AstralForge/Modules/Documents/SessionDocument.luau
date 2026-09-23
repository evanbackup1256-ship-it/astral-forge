--!strict


local DocumentCommon = require(script.Parent:WaitForChild("DocumentCommon"))

export type SessionDocument = {
	_doc: any,
	GetKey: (self: SessionDocument) -> string,
	IsOpen: (self: SessionDocument) -> boolean,
	IsClosing: (self: SessionDocument) -> boolean,
	Open: (self: SessionDocument) -> any,
	Steal: (self: SessionDocument) -> (),
	Close: (self: SessionDocument) -> any,
	GetCache: (self: SessionDocument) -> any,
	SetCache: (self: SessionDocument, newCache: any) -> any,
	Save: (self: SessionDocument) -> any,
	Update: (self: SessionDocument, transform: any) -> any,
	Erase: (self: SessionDocument) -> any,
	HookBefore: (self: SessionDocument, event: DocumentCommon.HookEvent, hook: () -> ()) -> () -> (),
	HookAfter: (self: SessionDocument, event: DocumentCommon.HookEvent, hook: () -> ()) -> () -> (),
	HookFail: (self: SessionDocument, event: DocumentCommon.HookEvent, hook: () -> ()) -> () -> (),
	GetCacheChangedSignal: (self: SessionDocument) -> any,
	GetOpenedSignal: (self: SessionDocument) -> any,
	GetClosedSignal: (self: SessionDocument) -> any,
	Unwrap: (self: SessionDocument) -> any,
}

local SessionDocument = {}
SessionDocument.__index = SessionDocument

function SessionDocument.wrap(document: any): SessionDocument
	return setmetatable({
		_doc = document,
	}, SessionDocument) :: any
end

function SessionDocument:GetKey(): string
	return tostring(self._doc)
end

function SessionDocument:IsOpen(): boolean
	return self._doc:IsOpen()
end

function SessionDocument:IsClosing(): boolean
	return self._doc:IsClosing()
end

function SessionDocument:Open()
	return self._doc:Open()
end

function SessionDocument:Steal()
	self._doc:Steal()
end

function SessionDocument:Close()
	return self._doc:Close()
end

function SessionDocument:GetCache()
	return self._doc:GetCache()
end

function SessionDocument:SetCache(newCache: any)
	return self._doc:SetCache(newCache)
end

function SessionDocument:Save()
	return self._doc:Save()
end

function SessionDocument:Update(transform: any)
	return self._doc:Update(transform)
end

function SessionDocument:Erase()
	return self._doc:Erase()
end

function SessionDocument:HookBefore(event: DocumentCommon.HookEvent, hook: () -> ())
	return self._doc:HookBefore(event, hook)
end

function SessionDocument:HookAfter(event: DocumentCommon.HookEvent, hook: () -> ())
	return self._doc:HookAfter(event, hook)
end

function SessionDocument:HookFail(event: DocumentCommon.HookEvent, hook: () -> ())
	return self._doc:HookFail(event, hook)
end

function SessionDocument:GetCacheChangedSignal()
	return self._doc:GetCacheChangedSignal()
end

function SessionDocument:GetOpenedSignal()
	return self._doc:GetOpenedSignal()
end

function SessionDocument:GetClosedSignal()
	return self._doc:GetClosedSignal()
end

function SessionDocument:Unwrap()
	return self._doc
end

return SessionDocument
