--!strict


local DocumentCommon = require(script.Parent:WaitForChild("DocumentCommon"))

export type OpenDocument = {
	_doc: any,
	GetKey: (self: OpenDocument) -> string,
	IsOpen: (self: OpenDocument) -> boolean,
	IsClosing: (self: OpenDocument) -> boolean,
	Open: (self: OpenDocument) -> any,
	OpenAndUpdate: (self: OpenDocument, transform: any) -> any,
	Close: (self: OpenDocument) -> any,
	Update: (self: OpenDocument, transform: any) -> any,
	Read: (self: OpenDocument) -> any,
	Erase: (self: OpenDocument) -> any,
	IsOpenAvailable: (self: OpenDocument) -> any,
	HookBefore: (self: OpenDocument, event: DocumentCommon.HookEvent, hook: () -> ()) -> () -> (),
	HookAfter: (self: OpenDocument, event: DocumentCommon.HookEvent, hook: () -> ()) -> () -> (),
	HookFail: (self: OpenDocument, event: DocumentCommon.HookEvent, hook: () -> ()) -> () -> (),
	GetOpenedSignal: (self: OpenDocument) -> any,
	GetClosedSignal: (self: OpenDocument) -> any,
	GetUpdatedSignal: (self: OpenDocument) -> any,
	GetReadSignal: (self: OpenDocument) -> any,
	Unwrap: (self: OpenDocument) -> any,
}

local OpenDocument = {}
OpenDocument.__index = OpenDocument

function OpenDocument.wrap(document: any): OpenDocument
	return setmetatable({
		_doc = document,
	}, OpenDocument) :: any
end

function OpenDocument:GetKey(): string
	return tostring(self._doc)
end

function OpenDocument:IsOpen(): boolean
	return self._doc:IsOpen()
end

function OpenDocument:IsClosing(): boolean
	return self._doc:IsClosing()
end

function OpenDocument:Open()
	return self._doc:Open()
end

function OpenDocument:OpenAndUpdate(transform: any)
	return self._doc:OpenAndUpdate(transform)
end

function OpenDocument:Close()
	return self._doc:Close()
end

function OpenDocument:Update(transform: any)
	return self._doc:Update(transform)
end

function OpenDocument:Read()
	return self._doc:Read()
end

function OpenDocument:Erase()
	return self._doc:Erase()
end

function OpenDocument:IsOpenAvailable()
	return self._doc:IsOpenAvailable()
end

function OpenDocument:HookBefore(event: DocumentCommon.HookEvent, hook: () -> ())
	return self._doc:HookBefore(event, hook)
end

function OpenDocument:HookAfter(event: DocumentCommon.HookEvent, hook: () -> ())
	return self._doc:HookAfter(event, hook)
end

function OpenDocument:HookFail(event: DocumentCommon.HookEvent, hook: () -> ())
	return self._doc:HookFail(event, hook)
end

function OpenDocument:GetOpenedSignal()
	return self._doc:GetOpenedSignal()
end

function OpenDocument:GetClosedSignal()
	return self._doc:GetClosedSignal()
end

function OpenDocument:GetUpdatedSignal()
	return self._doc:GetUpdatedSignal()
end

function OpenDocument:GetReadSignal()
	return self._doc:GetReadSignal()
end

function OpenDocument:Unwrap()
	return self._doc
end

return OpenDocument
