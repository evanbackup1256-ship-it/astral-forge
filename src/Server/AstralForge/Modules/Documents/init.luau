--!strict


local DocumentCommon = require(script:WaitForChild("DocumentCommon"))
local SessionDocument = require(script:WaitForChild("SessionDocument"))
local SessionDocumentStore = require(script:WaitForChild("SessionDocumentStore"))
local OpenDocument = require(script:WaitForChild("OpenDocument"))
local UnlockedDocumentStore = require(script:WaitForChild("UnlockedDocumentStore"))

return {
	DocumentCommon = DocumentCommon,
	SessionDocument = SessionDocument,
	SessionDocumentStore = SessionDocumentStore,
	OpenDocument = OpenDocument,
	UnlockedDocumentStore = UnlockedDocumentStore,
}
