--!strict
-- Exports from the client UI code that nothing references at all: not another file, not the
-- file itself, not a string lookup in a converted view, not a script. Those are dead code and
-- fail the build. A name counts as used if the identifier appears anywhere else in src/ or
-- scripts/, so kit lookups by string ("ui", "Button") keep their targets alive.
--
-- ALLOWED lists the few that stay on purpose: public hooks other streams call into, or code
-- another workstream owns and will clean itself.

local fs = require("@lune/fs")

local UI_ROOT = "src/Client/AstralForge"
local SEARCH_ROOTS = { "src", "scripts" }

local ALLOWED: { [string]: string } = {
	-- gamepad/touch services: controller workstream (FW)
	["CoreKit/GamepadNavigationService.ts:ResolveScrollTarget"] = "controller workstream",
	["CoreKit/GamepadNavigationService.ts:SetTabCycleCallback"] = "public hook, controller workstream",
	["CoreKit/GamepadNavigationService.ts:SetModalCloseCallback"] = "public hook, controller workstream",
	["CoreKit/GamepadNavigationService.ts:SetQuickVaultCallback"] = "public hook, controller workstream",
	["CoreKit/GamepadNavigationService.ts:SetOverchargeCallback"] = "public hook, controller workstream",
	["CoreKit/GamepadNavigationService.ts:SetSettingsCallback"] = "public hook, controller workstream",
	["CoreKit/TouchGestureService.ts:toGuiPosition"] = "controller workstream",
	["CoreKit/TouchGestureService.ts:GetThumbstickState"] = "controller workstream",
	-- Flamework finds controllers by decorator, not by name
	["Controllers/SessionControllers.ts:PresenceController"] = "Flamework controller",
	["Controllers/SessionControllers.ts:TelemetryController"] = "Flamework controller",
	["Controllers/SessionControllers.ts:PingController"] = "Flamework controller",
	-- shell components: shell memo workstream (B)
	["UiCore/NavChrome.tsx:MoreDock"] = "shell workstream",
	["UiCore/ShellFx.tsx:ConfettiBurst"] = "shell workstream",
	-- crate and forge art: crate workstream
	["UiCore/crateModel.ts:kitPiece"] = "crate workstream",
	["UiCore/crateModel.ts:skinGlow"] = "crate workstream",
	["ArtKit/ForgeAnvil2D.tsx:FORGE_LOOP_SECONDS"] = "forge art timing, read when tuning",
	["ArtKit/ForgeAnvil2D.tsx:FORGE_FINALE_SECONDS"] = "forge art timing, read when tuning",
	["ArtKit/Icon.tsx:LOCKUP_ASSET"] = "logo asset id",
	-- notice timing lives next to the notice copy (copy workstream)
	["UiCore/notifications.ts:NOTICE_LIFETIME"] = "notice workstream",
	["UiCore/notifications.ts:NOTICE_EXIT_SECONDS"] = "notice workstream",
}

local function walk(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, out)
		elseif string.match(name, "%.tsx?$") or string.match(name, "%.luau$") or string.match(name, "%.json$") then
			table.insert(out, path)
		end
	end
end

-- identifier counts, everywhere and per file
local total: { [string]: number } = {}
local perFile: { [string]: { [string]: number } } = {}
local sources: { [string]: string } = {}
local files = {}
for _, root in SEARCH_ROOTS do
	walk(root, files)
end
for _, path in files do
	-- this script names the allowances, which must not count as uses
	if path == "scripts/verify_ui_exports.luau" then
		continue
	end
	local source = fs.readFile(path)
	sources[path] = source
	local counts = {}
	for word in string.gmatch(source, "[%a_][%w_]*") do
		counts[word] = (counts[word] or 0) + 1
		total[word] = (total[word] or 0) + 1
	end
	perFile[path] = counts
end

local dead = {}
local seenAllowed = {}
local checked = 0
for _, path in files do
	if sources[path] ~= nil and string.sub(path, 1, #UI_ROOT + 1) == UI_ROOT .. "/" and string.match(path, "%.tsx?$") then
		local source = sources[path]
		for line in string.gmatch(source, "[^\n]+") do
			local name = string.match(line, "^export function ([%a_][%w_]*)")
				or string.match(line, "^export const ([%a_][%w_]*)")
				or string.match(line, "^export class ([%a_][%w_]*)")
			if name then
				checked += 1
				local key = string.sub(path, #UI_ROOT + 2) .. ":" .. name
				if total[name] == 1 then
					if ALLOWED[key] then
						seenAllowed[key] = true
					else
						table.insert(dead, key)
					end
				end
			end
		end
	end
end

-- an allowance whose export is gone or now used should be removed from the list
local stale = {}
for key in ALLOWED do
	if not seenAllowed[key] then
		table.insert(stale, key)
	end
end

if #dead > 0 then
	table.sort(dead)
	error("Exports nothing uses (delete them, or add to ALLOWED with a reason):\n  " .. table.concat(dead, "\n  "))
end
if #stale > 0 then
	table.sort(stale)
	error("ALLOWED entries that are no longer unused exports (remove them):\n  " .. table.concat(stale, "\n  "))
end
local allowedCount = 0
for _ in ALLOWED do
	allowedCount += 1
end
print(`[TEST] ui exports: {checked} checked, none unused apart from {allowedCount} listed allowances`)
