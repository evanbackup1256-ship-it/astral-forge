--!strict


local Document = require(script:FindFirstChild("Document"))
local DocumentStore = require(script:FindFirstChild("DocumentStore"))
local Types = require(script:FindFirstChild("Types"))
local SaveUtil = require(script:FindFirstChild("SaveUtil"))

export type HookEvent = Types.HookEvent
export type Document<T> = Document.Document<T>
export type Result<T, E> = Types.Result<T, E>
export type Err<T> = Types.Err<T>
export type Ok<T> = Types.Ok<T>
export type Transform<T> = Types.Transform<T>
export type DataStoreInterface = Types.DataStoreInterface
export type Migrations = Types.Migrations
export type DocumentStore<T> = DocumentStore.DocumentStore<T>
export type DocumentStoreProps<T> = DocumentStore.DocumentStoreProps<T>


return {
	DocumentStore = DocumentStore,
	Document = Document,
	SaveUtil = SaveUtil,
}
