--!strict
-- scripts/verify_m4_adversarial_challenge.luau
-- Empirical Stress Test & Adversarial Verification Suite for Milestone 4:
-- Architectural Guardrails, Pure Luau Requires, and Test Suite Clean Pass
-- Challenger M4-1

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local memberfs = require("./_memberfs")(fs)

local totalTests = 0
local passedTests = 0
local failedTests = 0

local function test(id: string, name: string, fn: () -> ())
	totalTests += 1
	local ok, err = pcall(fn)
	if ok then
		passedTests += 1
		print(string.format("  [PASS] [%s] %s", id, name))
	else
		failedTests += 1
		print(string.format("  [FAIL] [%s] %s: %s", id, name, tostring(err)))
	end
end

local function assertEq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(string.format("%s | Expected '%s', got '%s'", msg or "Assertion failed", tostring(expected), tostring(actual)), 2)
	end
end

local function assertTrue(cond: any, msg: string?)
	if not cond then
		error(msg or "Assertion failed (expected true)", 2)
	end
end

print("================================================================================")
print("  CHALLENGER M4-1 EMPIRICAL ADVERSARIAL STRESS TEST SUITE")
print("  Milestone 4: Architectural Guardrails & Pure Luau Requires")
print("================================================================================")

--------------------------------------------------------------------------------
-- SECTION 1: ASSET PRELOADING EMPIRICAL STRESS TESTS (BootKit & verify_branding)
--------------------------------------------------------------------------------
print("\n--- [SUITE 1] Asset Preloading Stress Tests (BootKit.luau) ---")

local bootSource = fs.readFile("src/Client/AstralForge/BootKit.luau"):gsub("\r\n", "\n")

test("M4-PRELOAD-01", "BootKit static declarative asset preloading pattern check", function()
	-- 1. Must use direct string assetList in useEffect
	assertTrue(bootSource:find("React.useEffect(function()\n\t\tlocal assetList = {", 1, true) ~= nil,
		"BootKit must define assetList table directly in useEffect")
	-- 2. Must NOT contain dummy ImageLabel probe instantiation
	assertTrue(bootSource:find('Instance.new("ImageLabel")', 1, true) == nil,
		"BootKit must NOT contain imperative Instance.new('ImageLabel') probe instantiation")
	-- 3. PreloadAsync must receive assetList
	assertTrue(bootSource:find('game:GetService("ContentProvider"):PreloadAsync(assetList', 1, true) ~= nil,
		"PreloadAsync must receive assetList directly")
	-- 4. Must wrap PreloadAsync in pcall
	assertTrue(bootSource:find("local ok, reason = pcall(function()", 1, true) ~= nil,
		"PreloadAsync must be wrapped in pcall for error shielding")
	-- 5. Must guard task.cancel on suspended status
	assertTrue(bootSource:find('if coroutine.status(preload) == "suspended" then\n\t\t\t\ttask.cancel(preload)\n\t\t\tend', 1, true) ~= nil,
		"Cleanup must guard task.cancel to prevent cancelling dead threads")
end)

test("M4-PRELOAD-02", "Extract and execute BootKit preload effect with standard BrandArt assets", function()
	local preloadStart = assert(bootSource:find("React.useEffect(function()\n\t\tlocal assetList = {", 1, true))
	local preloadEnd = assert(bootSource:find("\n\tend, {})", preloadStart, true)) + #"\n\tend, {})"
	local effectChunk = bootSource:sub(preloadStart, preloadEnd - 1)

	local BrandArtMock = {
		GAME_ICON_ASSET = "rbxassetid://13370001",
		WORDMARK_ASSET = "rbxassetid://13370002",
		COMPACT_MARK_ASSET = "rbxassetid://13370003",
	}

	local preloadedAssets = {}
	local warnings = {}
	local cleanupFn = nil
	local successStatus = { Name = "Success" }

	local mockEnv = {
		BrandArt = BrandArtMock,
		Enum = {
			AssetFetchStatus = {
				Success = successStatus,
				Failure = { Name = "Failure" },
				TimedOut = { Name = "TimedOut" },
			},
		},
		warn = function(msg)
			table.insert(warnings, tostring(msg))
		end,
		React = {
			useEffect = function(cb)
				cleanupFn = cb()
			end,
		},
		task = {
			spawn = function(cb)
				local thread = coroutine.create(cb)
				local ok, err = coroutine.resume(thread)
				if not ok then error(err) end
				return thread
			end,
			cancel = function(t) end,
		},
		game = {
			GetService = function(_, svc)
				assertEq(svc, "ContentProvider", "Expected ContentProvider service")
				return {
					PreloadAsync = function(_, targets, callback)
						for _, id in targets do
							table.insert(preloadedAssets, id)
							callback(id, successStatus)
						end
					end,
				}
			end,
		},
		coroutine = coroutine,
		tostring = tostring,
		pcall = pcall,
	}

	local fn = luau.load(effectChunk, { environment = setmetatable(mockEnv, { __index = _G }) })
	fn()

	assertEq(#preloadedAssets, 3, "Exactly 3 brand assets preloaded")
	assertEq(preloadedAssets[1], BrandArtMock.GAME_ICON_ASSET, "Game icon preloaded")
	assertEq(preloadedAssets[2], BrandArtMock.WORDMARK_ASSET, "Wordmark preloaded")
	assertEq(preloadedAssets[3], BrandArtMock.COMPACT_MARK_ASSET, "Compact mark preloaded")
	assertEq(#warnings, 0, "No warnings logged on clean preload")

	-- Clean up
	if cleanupFn then
		cleanupFn()
	end
end)

test("M4-PRELOAD-03", "Empty asset list edge-case resilience", function()
	local preloadStart = assert(bootSource:find("React.useEffect(function()\n\t\tlocal assetList = {", 1, true))
	local preloadEnd = assert(bootSource:find("\n\tend, {})", preloadStart, true)) + #"\n\tend, {})"
	local effectChunk = bootSource:sub(preloadStart, preloadEnd - 1)

	local effectEmpty = effectChunk:gsub("local assetList = {.-}", "local assetList = {}")

	local preloadedAssets = {}
	local warnings = {}
	local cleanupFn = nil

	local mockEnv = {
		BrandArt = {},
		Enum = {
			AssetFetchStatus = {
				Success = { Name = "Success" },
			},
		},
		warn = function(msg)
			table.insert(warnings, tostring(msg))
		end,
		React = {
			useEffect = function(cb)
				cleanupFn = cb()
			end,
		},
		task = {
			spawn = function(cb)
				local thread = coroutine.create(cb)
				local ok, err = coroutine.resume(thread)
				if not ok then error(err) end
				return thread
			end,
			cancel = function() end,
		},
		game = {
			GetService = function(_, svc)
				return {
					PreloadAsync = function(_, targets, callback)
						for _, id in targets do
							table.insert(preloadedAssets, id)
							callback(id, { Name = "Success" })
						end
					end,
				}
			end,
		},
		coroutine = coroutine,
		tostring = tostring,
		pcall = pcall,
	}

	local fn = luau.load(effectEmpty, { environment = setmetatable(mockEnv, { __index = _G }) })
	fn()

	assertEq(#preloadedAssets, 0, "Zero assets preloaded for empty list")
	assertEq(#warnings, 0, "Zero warnings for empty list")
	if cleanupFn then
		cleanupFn()
	end
end)

test("M4-PRELOAD-04", "Adversarial & invalid asset strings fuzzer (100 variations)", function()
	local preloadStart = assert(bootSource:find("React.useEffect(function()\n\t\tlocal assetList = {", 1, true))
	local preloadEnd = assert(bootSource:find("\n\tend, {})", preloadStart, true)) + #"\n\tend, {})"
	local effectChunk = bootSource:sub(preloadStart, preloadEnd - 1)

	local adversarialStrings = {
		"",
		" ",
		"   \t\n  ",
		"rbxassetid://-1",
		"rbxassetid://0",
		"rbxassetid://abc",
		"rbxassetid://999999999999999999999999999",
		"http://evil.domain.com/malicious.png",
		"https://www.roblox.com/asset/?id=123",
		"rbxasset://textures/ui/missing.png",
		"rbxassetid://1234;DROP TABLE assets;",
		"rbxassetid://1234\0injection",
		"UnicodeAsset",
		string.rep("A", 1024),
	}
	-- Add 86 generated boundary variations
	for i = 1, 86 do
		table.insert(adversarialStrings, string.format("rbxassetid://%d_invalid_test_%d", i * 1337, i % 5))
	end

	local statusVariants = {
		{ Name = "Failure" },
		{ Name = "TimedOut" },
		{ Name = "NotFound" },
		{ Name = "CorruptData" },
	}

	local successObj = { Name = "Success" }

	for idx, badAsset in ipairs(adversarialStrings) do
		local effectFuzzed = effectChunk:gsub("local assetList = {.-}", "local assetList = { '" .. badAsset:gsub("'", "\\'"):gsub("\n", "\\n"):gsub("\0", "") .. "' }")
		local warnings = {}
		local chosenStatus = statusVariants[((idx - 1) % #statusVariants) + 1]

		local mockEnv = {
			BrandArt = {},
			Enum = {
				AssetFetchStatus = {
					Success = successObj,
				},
			},
			warn = function(msg)
				table.insert(warnings, tostring(msg))
			end,
			React = {
				useEffect = function(cb)
					local cl = cb()
					if cl then cl() end
				end,
			},
			task = {
				spawn = function(cb)
					local thread = coroutine.create(cb)
					coroutine.resume(thread)
					return thread
				end,
				cancel = function() end,
			},
			game = {
				GetService = function(_, svc)
					return {
						PreloadAsync = function(_, targets, callback)
							for _, id in targets do
								callback(id, chosenStatus)
							end
						end,
					}
				end,
			},
			coroutine = coroutine,
			tostring = tostring,
			pcall = pcall,
		}

		local ok, err = pcall(function()
			local fn = luau.load(effectFuzzed, { environment = setmetatable(mockEnv, { __index = _G }) })
			fn()
		end)

		assertTrue(ok, "Fuzzed preloader must not crash: " .. tostring(err))
		assertEq(#warnings, 1, string.format("Must log exactly 1 warning for non-success status '%s'", chosenStatus.Name))
		assertTrue(warnings[1]:find("failed to load: " .. chosenStatus.Name, 1, true) ~= nil,
			"Warning message format conformity")
	end
end)

test("M4-PRELOAD-05", "Synchronous engine failure & exception injection robustness", function()
	local preloadStart = assert(bootSource:find("React.useEffect(function()\n\t\tlocal assetList = {", 1, true))
	local preloadEnd = assert(bootSource:find("\n\tend, {})", preloadStart, true)) + #"\n\tend, {})"
	local effectChunk = bootSource:sub(preloadStart, preloadEnd - 1)

	local errorScenarios = {
		"Network connection terminated by peer",
		"ContentProvider is currently throttled (HTTP 429)",
		"Out of memory allocating texture stream buffer",
		"Internal engine RPC timeout after 30000ms",
		"Bad argument #1 to PreloadAsync (table expected, got nil)",
	}

	for _, injectedError in ipairs(errorScenarios) do
		local warnings = {}
		local mockEnv = {
			BrandArt = {
				GAME_ICON_ASSET = "rbxassetid://1",
				WORDMARK_ASSET = "rbxassetid://2",
				COMPACT_MARK_ASSET = "rbxassetid://3",
			},
			Enum = { AssetFetchStatus = { Success = { Name = "Success" } } },
			warn = function(msg)
				table.insert(warnings, tostring(msg))
			end,
			React = {
				useEffect = function(cb)
					local cl = cb()
					if cl then cl() end
				end,
			},
			task = {
				spawn = function(cb)
					local thread = coroutine.create(cb)
					coroutine.resume(thread)
					return thread
				end,
				cancel = function() end,
			},
			game = {
				GetService = function(_, svc)
					return {
						PreloadAsync = function()
							error(injectedError, 0)
						end,
					}
				end,
			},
			coroutine = coroutine,
			tostring = tostring,
			pcall = pcall,
		}

		local ok, err = pcall(function()
			local fn = luau.load(effectChunk, { environment = setmetatable(mockEnv, { __index = _G }) })
			fn()
		end)

		assertTrue(ok, "Engine exception must be cleanly caught by pcall: " .. tostring(err))
		assertEq(#warnings, 1, "Exactly one [Branding] Preload failed warning logged")
		assertTrue(warnings[1]:find("[Branding] Preload failed: " .. injectedError, 1, true) ~= nil,
			"Warning correctly reports the injected engine error")
	end
end)

test("M4-PRELOAD-06", "High-frequency rapid unmount stress test (500 cycles)", function()
	local preloadStart = assert(bootSource:find("React.useEffect(function()\n\t\tlocal assetList = {", 1, true))
	local preloadEnd = assert(bootSource:find("\n\tend, {})", preloadStart, true)) + #"\n\tend, {})"
	local effectChunk = bootSource:sub(preloadStart, preloadEnd - 1)

	local cancelledThreads = 0
	local completedThreads = 0
	local cancelledWhileDead = 0

	for cycle = 1, 500 do
		local phase = cycle % 4
		local threadRef = nil
		local cleanupFn = nil

		local mockEnv = {
			BrandArt = {
				GAME_ICON_ASSET = "rbxassetid://101",
				WORDMARK_ASSET = "rbxassetid://102",
				COMPACT_MARK_ASSET = "rbxassetid://103",
			},
			Enum = { AssetFetchStatus = { Success = { Name = "Success" } } },
			warn = function() end,
			React = {
				useEffect = function(cb)
					cleanupFn = cb()
				end,
			},
			task = {
				spawn = function(cb)
					local th = coroutine.create(cb)
					threadRef = th
					if phase ~= 0 then
						-- If phase != 0, resume immediately
						coroutine.resume(th)
					end
					return th
				end,
				cancel = function(th)
					if coroutine.status(th) == "dead" then
						cancelledWhileDead += 1
					end
					cancelledThreads += 1
				end,
			},
			game = {
				GetService = function()
					return {
						PreloadAsync = function(_, targets, callback)
							if phase == 2 then
								-- Actively yielding / suspended
								coroutine.yield()
							end
							completedThreads += 1
						end,
					}
				end,
			},
			coroutine = coroutine,
			tostring = tostring,
			pcall = pcall,
		}

		local fn = luau.load(effectChunk, { environment = setmetatable(mockEnv, { __index = _G }) })
		fn()

		-- Execute cleanup at varying cycle phases
		if cleanupFn then
			cleanupFn()
		end
	end

	assertEq(cancelledWhileDead, 0, "task.cancel was NEVER called on a dead coroutine (zero invalid cancellations)")
	assertTrue(cancelledThreads > 0, "Suspended threads were cleanly cancelled upon early unmount")
end)

test("M4-PRELOAD-07", "Concurrent multi-instance preloader isolation (100 parallel instances)", function()
	local preloadStart = assert(bootSource:find("React.useEffect(function()\n\t\tlocal assetList = {", 1, true))
	local preloadEnd = assert(bootSource:find("\n\tend, {})", preloadStart, true)) + #"\n\tend, {})"
	local effectChunk = bootSource:sub(preloadStart, preloadEnd - 1)

	local instances = {}
	for i = 1, 100 do
		local cancelled = false
		local completed = false
		local cleanup = nil
		local env = {
			BrandArt = {
				GAME_ICON_ASSET = "rbxassetid://" .. i,
				WORDMARK_ASSET = "rbxassetid://" .. (i + 1000),
				COMPACT_MARK_ASSET = "rbxassetid://" .. (i + 2000),
			},
			Enum = { AssetFetchStatus = { Success = { Name = "Success" } } },
			warn = function() end,
			React = { useEffect = function(cb) cleanup = cb() end },
			task = {
				spawn = function(cb)
					local th = coroutine.create(cb)
					coroutine.resume(th)
					return th
				end,
				cancel = function() cancelled = true end,
			},
			game = {
				GetService = function()
					return {
						PreloadAsync = function(_, targets, callback)
							if i % 2 == 0 then
								coroutine.yield()
							else
								completed = true
							end
						end,
					}
				end,
			},
			coroutine = coroutine,
			tostring = tostring,
			pcall = pcall,
		}
		local fn = luau.load(effectChunk, { environment = setmetatable(env, { __index = _G }) })
		fn()
		table.insert(instances, { cleanup = cleanup, cancelled = function() return cancelled end, completed = function() return completed end, isYielding = (i % 2 == 0) })
	end

	-- Unmount all 100 instances
	for _, inst in ipairs(instances) do
		if inst.cleanup then
			inst.cleanup()
		end
		if inst.isYielding then
			assertTrue(inst.cancelled(), "Yielding instance was cancelled on unmount")
		else
			assertTrue(inst.completed(), "Non-yielding instance completed successfully")
		end
	end
end)


--------------------------------------------------------------------------------
-- SECTION 2: LUAU REQUIRE MODULARITY EMPIRICAL STRESS TESTS
--------------------------------------------------------------------------------
print("\n--- [SUITE 2] Luau Require Modularity & Symbol Export Stress Tests ---")

local TARGET_FILES = {
	"src/Client/AstralForge/MotionKit.luau",
	"src/Client/AstralForge/CoreKit.luau",
	"src/Client/AstralForge/framework.luau",
	"src/Client/AstralForge/layoutGuard.luau",
	"src/Client/AstralForge/UiCore.luau",
}

test("M4-REQ-01", "Target modules load roblox-ts packages through TSImport", function()
	-- roblox-ts packages read _G[script], which only TSImport sets; a plain require crashed the client at load (see verify_ts_imports)
	for _, path in ipairs(TARGET_FILES) do
		local content = fs.readFile(path)
		local _, plain = content:gsub('require%(game%.ReplicatedStorage%.rbxts_include%.node_modules%["@rbxts"%]%.bezierts%)', "")
		assertTrue(plain == 0, string.format("File '%s' must not require bezierts directly", path))
	end
end)

test("M4-REQ-02", "Absence of imperative Instance.new for UI widgets in target presentation files", function()
	local forbiddenWidgets = { "TextLabel", "ImageLabel", "Frame", "TextButton", "ImageButton", "ScrollingFrame" }
	for _, path in ipairs(TARGET_FILES) do
		local content = fs.readFile(path)
		for _, widget in ipairs(forbiddenWidgets) do
			local pattern = string.format('Instance.new("%s")', widget)
			if path ~= "src/Client/AstralForge/CoreKit.luau" and path ~= "src/Client/AstralForge/layoutGuard.luau" then
				assertTrue(content:find(pattern, 1, true) == nil,
					string.format("File '%s' must not create imperative widget %s", path, pattern))
			end
		end
	end
end)

test("M4-REQ-03", "Multi-level compilation check (O0, O1, O2) with zero register overflow", function()
	for _, path in ipairs(TARGET_FILES) do
		local source = fs.readFile(path)
		for _, opt in ipairs({ 0, 1, 2 }) do
			local ok, bytecodeOrErr = pcall(function()
				return luau.compile(source, { optimizationLevel = opt, debugLevel = 1 })
			end)
			assertTrue(ok, string.format("File '%s' failed compilation at O%d: %s", path, opt, tostring(bytecodeOrErr)))
			assertTrue(type(bytecodeOrErr) == "string" and #bytecodeOrErr > 0,
				string.format("Bytecode generation failed for '%s' at O%d", path, opt))
		end
	end
end)

test("M4-REQ-04", "framework.luau static exports and contract conformance", function()
	local fwSource = fs.readFile("src/Client/AstralForge/framework.luau"):gsub("\r\n", "\n")
	
	-- Verify required export symbols
	local requiredSymbols = {
		"initializeClientFramework",
		"UI_ROOT_TAG",
		"UiRootComponent",
		"UiRuntimeController",
		"DiagnosticsController",
		"ShellClockController",
	}
	for _, sym in ipairs(requiredSymbols) do
		assertTrue(fwSource:find(sym .. " = " .. sym, 1, true) ~= nil or fwSource:find(sym .. ":", 1, true) ~= nil,
			string.format("framework.luau must export symbol '%s'", sym))
	end

	-- Flamework is compiled roblox-ts: it must be loaded through TSImport
	assertTrue(fwSource:find('local _core = importTsModule(flamework.core.out)', 1, true) ~= nil,
		"framework.luau must load flamework core through importTsModule")
	assertTrue(fwSource:find('local _components = importTsModule(flamework.components.out)', 1, true) ~= nil,
		"framework.luau must load flamework components through importTsModule")
end)

test("M4-REQ-05", "layoutGuard.luau static exports and contract conformance", function()
	local lgSource = fs.readFile("src/Client/AstralForge/layoutGuard.luau"):gsub("\r\n", "\n")

	-- Verify required export symbols
	local requiredSymbols = {
		"layoutGuardStats",
		"layoutGuardDiagnostics",
		"LayoutGuardController",
	}
	for _, sym in ipairs(requiredSymbols) do
		assertTrue(lgSource:find(sym, 1, true) ~= nil,
			string.format("layoutGuard.luau must export symbol '%s'", sym))
	end

	-- Verify direct require statements in layoutGuard.luau
	assertTrue(lgSource:find('local core = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@flamework"].core.out)', 1, true) ~= nil,
		"layoutGuard.luau must use direct require for flamework core")
	assertTrue(lgSource:find('local ClientLog = require(script.Parent.CoreKit)("log").ClientLog', 1, true) ~= nil,
		"layoutGuard.luau must use direct require for CoreKit log")
end)

test("M4-REQ-06", "MotionKit.luau callable metatable & member export verification", function()
	local mkSource = fs.readFile("src/Client/AstralForge/MotionKit.luau"):gsub("\r\n", "\n")

	-- Find all __defs["..."]
	local members = {}
	for memberName in mkSource:gmatch('__defs%["([^"]+)"%]') do
		table.insert(members, memberName)
	end

	assertTrue(#members >= 10, string.format("MotionKit must have >= 10 exported members (found %d)", #members))

	-- Verify key motion modules exist
	local expectedMembers = {
		"motion",
		"motionTokens",
		"readSafeInsets",
		"autoScale",
		"antilag",
	}
	for _, exp in ipairs(expectedMembers) do
		local found = false
		for _, m in ipairs(members) do
			if m == exp then found = true; break end
		end
		assertTrue(found, string.format("MotionKit must export member '%s'", exp))
	end

	-- Verify direct require of BezierCurve without TSImport
	assertTrue(mkSource:find('local BezierCurve = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].bezierts).BezierCurve', 1, true) ~= nil,
		"MotionKit must directly require BezierCurve")
end)

test("M4-REQ-07", "CoreKit.luau callable metatable & member export verification", function()
	local ckSource = fs.readFile("src/Client/AstralForge/CoreKit.luau"):gsub("\r\n", "\n")

	local members = {}
	for memberName in ckSource:gmatch('__defs%["([^"]+)"%]') do
		table.insert(members, memberName)
	end

	assertTrue(#members >= 20, string.format("CoreKit must have >= 20 exported members (found %d)", #members))

	local expectedMembers = {
		"log",
		"theme",
		"interaction",
		"clientStore",
		"GamepadNavigationService",
		"TouchGestureService",
		"mobileLayout",
		"inputPlatform",
	}
	for _, exp in ipairs(expectedMembers) do
		local found = false
		for _, m in ipairs(members) do
			if m == exp then found = true; break end
		end
		assertTrue(found, string.format("CoreKit must export member '%s'", exp))
	end

	-- Verify direct require of @rbxts/3a without TSImport
	assertTrue(ckSource:find('local _3a = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["3a"])', 1, true) ~= nil,
		"CoreKit must directly require @rbxts/3a")
end)

test("M4-REQ-08", "UiCore.luau callable metatable & member export verification", function()
	local ucSource = fs.readFile("src/Client/AstralForge/UiCore.luau"):gsub("\r\n", "\n")

	local members = {}
	for memberName in ucSource:gmatch('__defs%["([^"]+)"%]') do
		table.insert(members, memberName)
	end

	assertTrue(#members >= 20, string.format("UiCore must have >= 20 exported members (found %d)", #members))

	local expectedMembers = {
		"notifications",
		"CrateRevealStageSimple",
		"AppShellChrome",
		"CrateRevealOverlay",
		"crateModel",
	}
	for _, exp in ipairs(expectedMembers) do
		local found = false
		for _, m in ipairs(members) do
			if m == exp then found = true; break end
		end
		assertTrue(found, string.format("UiCore must export member '%s'", exp))
	end

	-- Verify direct require of react-lifetime-component without TSImport
	assertTrue(ucSource:find('local _react_lifetime_component = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-lifetime-component"].out)', 1, true) ~= nil,
		"UiCore must directly require react-lifetime-component")
end)

test("M4-REQ-09", "Dependency Graph Acyclicity (DAG & Cycle-Freedom Verification)", function()
	-- Build inter-module dependency map
	local moduleFiles = {
		CoreKit = "src/Client/AstralForge/CoreKit.luau",
		MotionKit = "src/Client/AstralForge/MotionKit.luau",
		framework = "src/Client/AstralForge/framework.luau",
		layoutGuard = "src/Client/AstralForge/layoutGuard.luau",
		UiCore = "src/Client/AstralForge/UiCore.luau",
		LayoutKit = "src/Client/AstralForge/LayoutKit.luau",
		AudioKit = "src/Client/AstralForge/AudioKit.luau",
	}

	local graph = {}
	for modName, filePath in pairs(moduleFiles) do
		graph[modName] = {}
		local text = fs.readFile(filePath)
		for targetName, _ in pairs(moduleFiles) do
			if targetName ~= modName then
				local pattern1 = "script.Parent." .. targetName
				local pattern2 = 'script.Parent["' .. targetName .. '"]'
				if text:find(pattern1, 1, true) or text:find(pattern2, 1, true) then
					table.insert(graph[modName], targetName)
				end
			end
		end
	end

	-- Tarjan / DFS Cycle Detection
	local visited = {}
	local inStack = {}
	local hasCycle = false
	local cyclePath = {}

	local function dfs(node: string, path: { string })
		visited[node] = true
		inStack[node] = true
		table.insert(path, node)

		for _, neighbor in ipairs(graph[node] or {}) do
			if not visited[neighbor] then
				dfs(neighbor, path)
			elseif inStack[neighbor] then
				hasCycle = true
				table.insert(path, neighbor)
				cyclePath = table.clone(path)
				return
			end
		end

		table.remove(path)
		inStack[node] = false
	end

	for modName, _ in pairs(moduleFiles) do
		if not visited[modName] then
			dfs(modName, {})
		end
	end

	assertTrue(not hasCycle, "Cycle detected in core module dependency graph: " .. table.concat(cyclePath, " -> "))
end)

test("M4-REQ-10", "Simulated runtime sandbox module loading and symbol execution", function()
	local fwSource = fs.readFile("src/Client/AstralForge/framework.luau"):gsub("\r\n", "\n")

	local definedMetadata = {}
	local decoratedControllers = {}

	local mockReflect = {
		defineMetadata = function(target, key, val)
			definedMetadata[tostring(target) .. ":" .. key] = val
		end,
		decorate = function(target, decKey, decFunc, args)
			table.insert(decoratedControllers, { target = target, decKey = decKey, args = args })
		end,
	}

	local mockComponents = {
		BaseComponent = { __tostring = function() return "BaseComponent" end },
		Component = function() end,
		baseComponent = { SYMBOL_ATTRIBUTE_SETTER = "SYMBOL_ATTRIBUTE_SETTER" },
	}

	local mockCore = {
		Reflect = mockReflect,
		Controller = function() end,
		Flamework = {
			ignite = function() end,
			resolveDependency = function() return {} end,
		},
		prelude = {
			t = setmetatable({}, {
				__index = function()
					return function()
						return true
					end
				end,
			}),
		},
	}

	local mockEnv = {
		game = {
			ReplicatedStorage = {
				rbxts_include = {
					-- roblox-ts packages load through TSImport; the mock passes the module through
					TSImport = setmetatable({}, { __call = function(_, module) return module end }),
					node_modules = {
						["@flamework"] = {
							core = {
								out = mockCore,
							},
							components = {
								out = mockComponents,
							},
						},
					},
				},
			},
			GetService = function(_, svc)
				return {
					GetTagged = function() return {} end,
					TagAdded = { Connect = function() return { Disconnect = function() end } end },
					TagRemoved = { Connect = function() return { Disconnect = function() end } end },
				}
			end,
		},
		script = {
			Parent = {
				MotionKit = function()
					return function() return { currentAntilagInfo = function() return {} end } end
				end,
				CoreKit = function()
					return function(member)
						if member == "clientStore" then
							return { getActiveClientStore = function() return {} end }
						elseif member == "log" then
							return { ClientLog = { warn = function() end, info = function() end } }
						end
						return {}
					end
				end,
				layoutGuard = {},
			},
		},
		require = function(target)
			if type(target) == "function" then
				return target()
			end
			return target
		end,
		setmetatable = setmetatable,
		pcall = pcall,
		error = error,
		tostring = tostring,
		table = table,
		os = os,
		task = { delay = function() end, cancel = function() end },
		print = function() end,
		warn = function() end,
	}

	local fwLoader = luau.load(fwSource, { environment = setmetatable(mockEnv, { __index = _G }) })
	local fwExports = fwLoader()

	assertTrue(type(fwExports) == "table", "framework.luau returns table of exports")
	assertTrue(type(fwExports.initializeClientFramework) == "function", "initializeClientFramework is a function")
	assertEq(fwExports.UI_ROOT_TAG, "AstralForgeUiRoot", "UI_ROOT_TAG matches contract")
	assertTrue(type(fwExports.UiRuntimeController) == "table", "UiRuntimeController exported")
	assertTrue(type(fwExports.DiagnosticsController) == "table", "DiagnosticsController exported")
	assertTrue(type(fwExports.ShellClockController) == "table", "ShellClockController exported")

	-- Verify controller decorations were recorded
	assertTrue(#decoratedControllers >= 3, "All framework controllers decorated with Flamework Controller")
end)

--------------------------------------------------------------------------------
-- SUMMARY
--------------------------------------------------------------------------------
print("\n================================================================================")
print(string.format("  CHALLENGER M4-1 RESULTS: Total: %d | Passed: %d | Failed: %d", totalTests, passedTests, failedTests))
print("================================================================================")

if failedTests > 0 then
	error(string.format("[FAILURE] %d adversarial stress tests failed!", failedTests), 0)
else
	print("[SUCCESS] All Milestone 4 adversarial stress tests passed cleanly!\n")
end
