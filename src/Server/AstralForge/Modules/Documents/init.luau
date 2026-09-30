--!strict


local DocumentCommon = require(script:WaitForChild("DocumentKit"))("DocumentCommon")
local SessionDocument = require(script:WaitForChild("DocumentKit"))("SessionDocument")
local SessionDocumentStore = require(script:WaitForChild("DocumentKit"))("SessionDocumentStore")
local OpenDocument = require(script:WaitForChild("DocumentKit"))("OpenDocument")
local UnlockedDocumentStore = require(script:WaitForChild("DocumentKit"))("UnlockedDocumentStore")

return {
	DocumentCommon = DocumentCommon,
	SessionDocument = SessionDocument,
	SessionDocumentStore = SessionDocumentStore,
	OpenDocument = OpenDocument,
	UnlockedDocumentStore = UnlockedDocumentStore,
}
