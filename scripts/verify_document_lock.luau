local fs = require("@lune/fs")
local luau = require("@lune/luau")
local function read(path)
	return fs.readFile(path):gsub("\r\n", "\n")
end
local source = read("src/Server/AstralForge/Modules/Documents/DocumentService/Document.luau")
local first = assert(source:find("function Document.Open<T>", 1, true))
local last = assert(source:find("function Document.OpenAndUpdate<T>", first, true))
local attempts, writes, failures = 0, 0, 0
local saved = { data = { Coins = 123 }, dataSchemaVersion = 0, lastCompatibleVersion = 0, sessionLockId = "other" }
local env = {
	Document = {},
	checkKeyData = function(value)
		return value
	end,
	runMigrations = function(_, value)
		return value
	end,
	isLocked = function()
		return true
	end,
	runHooks = function(hooks)
		for _, hook in hooks do
			hook()
		end
	end,
	SaveUtil = {
		updateAsync = function(transform)
			attempts += 1
			local nextValue = transform(function()
				error("Lock conflict must not enter API retry")
			end, saved)
			if nextValue ~= nil then
				writes += 1
			end
			return true, nextValue
		end,
	},
}
setmetatable(env, { __index = getfenv(0) })
local open = luau.load(source:sub(first, last - 1) .. "\nreturn Document.Open", { environment = env })()
local document = {
	_open = false,
	_isClosing = false,
	_sessionId = "ours",
	_shouldSteal = false,
	_migrations = {},
	_default = {},
	_preHooks = { Open = {} },
	_failHooks = { Open = {
		function()
			failures += 1
		end,
	} },
	_actionSignals = { Open = {
		Fire = function(_, result)
			assert(result.reason == "SessionLockedError")
		end,
	} },
}
local result = open(document)
assert(result.success == false and result.reason == "SessionLockedError")
assert(attempts == 1 and writes == 0 and failures == 1 and not document._open)
assert(saved.data.Coins == 123 and saved.sessionLockId == "other")

-- Exercise the real bounded close method with an opening request that never finishes.
local storeSource = read("src/Server/AstralForge/Modules/Documents/DocumentService/DocumentStore.luau")
first = assert(storeSource:find("function DocumentStore.CloseAllDocuments", 1, true))
last = assert(storeSource:find("function DocumentStore.isDocumentStore", first, true))
local now = 0
local closeEnv = setmetatable({
	DocumentStore = {},
	Util = {
		getUpdateBudget = function()
			return 0
		end,
	},
	os = {
		clock = function()
			return now
		end,
	},
	task = {
		wait = function(seconds)
			now += seconds
		end,
	},
}, { __index = getfenv(0) })
local close = luau.load(
	storeSource:sub(first, last - 1) .. "\nreturn DocumentStore.CloseAllDocuments",
	{ environment = closeEnv }
)()
assert(close({ _documentsToClose = 0, _openingDocuments = 1, _documents = {} }, 0.3) == false)
assert(now >= 0.3 and now < 0.4)
assert(close({ _documentsToClose = 0, _openingDocuments = 0, _documents = {} }, 0.3) == true)
print("[TEST] document lock conflict cancels without retry/write; pending-open shutdown respects deadline")
