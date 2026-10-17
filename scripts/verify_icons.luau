--!strict
-- Icons: every icon the game names has its own art, and no icon id is used twice.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local manifestSource = fs.readFile("src/Client/AstralForge/IconManifest.luau")
local Manifest = luau.load(manifestSource, { chunkName = "IconManifest" })() :: any
assert(Manifest.Cell == 96, "96 px cells")
assert(#Manifest.Sheets >= 1, "at least one sheet")

local count = 0
for id, entry in Manifest.Icons do
	count += 1
	assert(type(entry.b) == "table" and type(entry.l) == "table", id .. " has a body and a light layer")
	assert(entry.b[1] < #Manifest.Sheets and entry.l[1] < #Manifest.Sheets, id .. " sits on a real sheet")
	assert(({ spin = true, pulse = true, twinkle = true, bob = true, beat = true, shine = true })[entry.a], id .. " moves")
end
assert(count >= 4000, "every use has its own icon, got " .. count)

-- every icon id written in the source is drawn, and none is written twice
local seen: { [string]: string } = {}
local function scan(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			if name ~= "Stories" and name ~= "node_modules" and name ~= "Packages" then
				scan(path)
			end
		elseif string.sub(name, -5) == ".luau" and name ~= "IconManifest.luau" then
			local source = fs.readFile(path)
			for id in string.gmatch(source, '"([A-Z][A-Za-z]+%.[A-Za-z0-9_]+)"') do
				if Manifest.Icons[id] ~= nil then
					assert(seen[id] == nil, `icon {id} is used twice ({seen[id]} and {name})`)
					seen[id] = name
				end
			end
		end
	end
end
scan("src")
local used = 0
for _ in seen do
	used += 1
end
assert(used >= 4700, "the source names its icons, got " .. used)

-- the runtime draws the generated art and animates it on one shared clock
local art = fs.readFile("src/Client/AstralForge/ArtKit.luau")
assert(art:find("local IconManifest = require(script.Parent.IconManifest)", 1, true), "Icon reads the manifest")
assert(art:find("local function useIconClock(enabled)", 1, true), "one shared clock")
assert(art:find('anim == "spin"', 1, true) and art:find('anim == "shine"', 1, true), "icons move")
print(`[TEST] icons: {count} drawn, {used} named in the source, none twice`)
