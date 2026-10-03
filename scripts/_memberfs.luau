--!nocheck
-- fs proxy for verify scripts. Merged suites hold many modules in one file; a path of
-- the form "<suite>.luau#<Member>" reads exactly that member's source (the text between
-- its `__defs["<Member>"] = function()` header and the closing `end`), so every assertion
-- keeps reading the same module body it always did. Plain paths fall through to @lune/fs.

return function(realFs)
	-- A Windows checkout (core.autocrlf) stores source with CRLF, while the header and banner
	-- searches below (and many assertions) look for plain \n. Normalize Luau text on read;
	-- binary files (WAV, GLB) are left untouched so their sizes stay exact.
	local function readText(path: string)
		local text = realFs.readFile(path)
		if string.match(path, "%.luau?$") then
			text = string.gsub(text, "\r\n", "\n")
		end
		return text
	end

	local function memberSlice(path: string)
		local suitePath, member = string.match(path, "^(.-)#([%w_]+)$")
		if not suitePath then
			return nil
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
			return realFs.isFile(suitePath)
				and string.find(readText(suitePath), `__defs["{member}"] = function()`, 1, true) ~= nil
		end
		return realFs.isFile(path)
	end
	return proxy
end
