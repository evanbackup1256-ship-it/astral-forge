--!nocheck
-- fs proxy for verify scripts. Merged suites hold many modules in one file; a path of
-- the form "<suite>.luau#<Member>" reads exactly that member's source (the text between
-- its `__defs["<Member>"] = function()` header and the closing `end`), so every assertion
-- keeps reading the same module body it always did. Plain paths fall through to @lune/fs.

return function(realFs)
	-- A Windows checkout (core.autocrlf) stores source with CRLF, while the header and banner
	-- searches below (and many assertions) look for plain \n. Normalize Luau text on read;
	-- binary files (WAV, GLB) are left untouched so their sizes stay exact.
	-- Files converted to TypeScript leave src/ and exist only as roblox-ts output under out/.
	-- A src path that is gone resolves to its compiled copy; a merged suite that became a
	-- folder of members (Kit/init + Kit/<member>) reads as all of its members joined.
	local function compiledPath(path: string): string?
		local rest = string.match(path, "^src/(.+)$")
		if not rest or realFs.isFile(path) then
			return nil
		end
		local out = "out/" .. rest
		if realFs.isFile(out) then
			return out
		end
		return nil
	end
	local function compiledFolder(path: string): string?
		local rest = string.match(path, "^src/(.+)%.luau$")
		if not rest or realFs.isFile(path) then
			return nil
		end
		local folder = "out/" .. rest
		if realFs.isDir(folder) then
			return folder
		end
		return nil
	end
	local function joinFolder(folder: string): string
		local parts = {}
		local function walk(dir: string)
			local names = realFs.readDir(dir)
			table.sort(names)
			for _, name in names do
				local full = dir .. "/" .. name
				if realFs.isDir(full) then
					walk(full)
				elseif string.match(name, "%.luau$") then
					table.insert(parts, (string.gsub(realFs.readFile(full), "\r\n", "\n")))
				end
			end
		end
		walk(folder)
		return table.concat(parts, "\n")
	end
	local function readText(path: string)
		local folder = compiledFolder(path)
		if folder then
			return joinFolder(folder)
		end
		local text = realFs.readFile(compiledPath(path) or path)
		if string.match(path, "%.luau?$") then
			text = string.gsub(text, "\r\n", "\n")
		end
		return text
	end
	-- a converted suite's member is its own compiled module: out/<suite>/<member>.luau
	local function compiledMember(suitePath: string, member: string): string?
		local folder = compiledFolder(suitePath)
		if not folder then
			return nil
		end
		for _, candidate in { `{folder}/{member}.luau`, `{folder}/{member}/init.luau` } do
			if realFs.isFile(candidate) then
				return candidate
			end
		end
		return nil
	end

	local function memberSlice(path: string)
		local suitePath, member = string.match(path, "^(.-)#([%w_]+)$")
		if not suitePath then
			return nil
		end
		local converted = compiledMember(suitePath, member)
		if converted then
			return (string.gsub(realFs.readFile(converted), "\r\n", "\n"))
		end
		local source = readText(suitePath)
		local header = `__defs["{member}"] = function()\n`
		local start = string.find(source, header, 1, true)
		if not start then
			error(`{suitePath}: no merged member named {member}`, 0)
		end
		local bodyStart = start + #header
		-- a member runs to the next member's header, or to the suite's entry point after the last one
		local nextDef = string.find(source, "\n__defs[\"", bodyStart, true)
		local entry = string.find(source, "\nlocal __members = {}", bodyStart, true)
		local stop = math.min(nextDef or math.huge, entry or math.huge)
		local bodyEnd = if stop == math.huge then #source else stop - 1
		local slice = string.sub(source, bodyStart, bodyEnd)
		-- drop the closure's trailing `end` (and any blank lines after it)
		slice = string.gsub(slice, "\nend%s*$", "\n")
		-- Follow the planning and crate adapters to the source that actually renders them.
		if string.find(slice, "require(script.Parent.Parent.PlanningViews)", 1, true) then
			return readText("src/Client/AstralForge/PlanningViews.luau")
		end
		if string.find(slice, "require(script.Parent.CrateRevealStage)", 1, true) then
			return readText("src/Client/AstralForge/pages/CrateRevealStage.luau")
		end
		return slice
	end

	local proxy = {}
	for key, value in realFs do
		proxy[key] = value
	end
	proxy.readFile = function(path: string)
		return memberSlice(path) or readText(path)
	end
	proxy.isFile = function(path: string)
		local suitePath, member = string.match(path, "^(.-)#([%w_]+)$")
		if suitePath then
			if compiledMember(suitePath, member) then
				return true
			end
			return realFs.isFile(suitePath)
				and string.find(readText(suitePath), `__defs["{member}"] = function()`, 1, true) ~= nil
		end
		return realFs.isFile(path) or compiledPath(path) ~= nil or compiledFolder(path) ~= nil
	end
	return proxy
end
