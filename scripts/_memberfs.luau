--!nocheck
-- fs proxy for verify scripts. Merged suites hold many modules in one file; a path of
-- the form "<suite>.luau#<Member>" reads exactly that member's source (the text between
-- its `__defs["<Member>"] = function()` header and the closing `end`), so every assertion
-- keeps reading the same module body it always did. Plain paths fall through to @lune/fs.

return function(realFs)
	local function memberSlice(path: string)
		local suitePath, member = string.match(path, "^(.-)#([%w_]+)$")
		if not suitePath then
			return nil
		end
		local source = realFs.readFile(suitePath)
		local header = `__defs["{member}"] = function()\n`
		local start = string.find(source, header, 1, true)
		if not start then
			error(`{suitePath}: no merged member named {member}`, 0)
		end
		local bodyStart = start + #header
		local banner = string.find(source, "\n-- ======", bodyStart, true)
		local bodyEnd = banner and (banner - 1) or #source
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
		return memberSlice(path) or realFs.readFile(path)
	end
	proxy.isFile = function(path: string)
		local suitePath, member = string.match(path, "^(.-)#([%w_]+)$")
		if suitePath then
			return realFs.isFile(suitePath)
				and string.find(realFs.readFile(suitePath), `__defs["{member}"] = function()`, 1, true) ~= nil
		end
		return realFs.isFile(path)
	end
	return proxy
end
