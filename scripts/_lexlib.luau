local function lex(src)
	local toks = {}
	local i, n = 1, #src
	while i <= n do
		local c = src:sub(i, i)
		local pos = i
		if c:match("%s") then
			i += 1
		elseif c == "-" and src:sub(i + 1, i + 1) == "-" then
			if src:sub(i + 2, i + 3) == "[[" then
				local e = src:find("]]", i + 4, true)
				i = e and (e + 2) or (n + 1)
			else
				local e = src:find("\n", i, true)
				i = e or (n + 1)
			end
		elseif c == '"' or c == "'" then
			local j = i + 1
			while j <= n do
				local d = src:sub(j, j)
				if d == "\\" then
					j += 2
				elseif d == c then
					break
				else
					j += 1
				end
			end
			toks[#toks + 1] = { t = "str", v = src:sub(i + 1, j - 1), pos = pos }
			i = j + 1
		elseif c == "`" then
			local j = i + 1
			local depth = 0
			while j <= n do
				local d = src:sub(j, j)
				if d == "\\" then
					j += 2
				elseif d == "$" and src:sub(j + 1, j + 1) == "{" then
					depth += 1
					j += 2
				elseif d == "{" and depth > 0 then
					depth += 1
					j += 1
				elseif d == "}" and depth > 0 then
					depth -= 1
					j += 1
				elseif d == "`" and depth == 0 then
					break
				else
					j += 1
				end
			end
			toks[#toks + 1] = { t = "str", v = "INTERP", pos = pos }
			i = j + 1
		elseif c:match("%d") then
			local j = i
			while j <= n and src:sub(j, j):match("[%w%.]") do
				j += 1
			end
			toks[#toks + 1] = { t = "num", v = tonumber(src:sub(i, j - 1)), pos = pos }
			i = j
		elseif c:match("[%a_]") then
			local j = i
			while j <= n and src:sub(j, j):match("[%w_]") do
				j += 1
			end
			local w = src:sub(i, j - 1)
			toks[#toks + 1] = { t = "name", v = w, pos = pos }
			i = j
		elseif src:sub(i, i + 1) == ".." or src:sub(i, i + 1) == "==" or src:sub(i, i + 1) == "~="
			or src:sub(i, i + 1) == "<=" or src:sub(i, i + 1) == ">=" or src:sub(i, i + 1) == "+=" or src:sub(i, i + 1) == "-=" then
			toks[#toks + 1] = { t = "sym", v = src:sub(i, i + 1), pos = pos }
			i += 2
		elseif src:sub(i, i + 2) == "..." then
			toks[#toks + 1] = { t = "name", v = "...", pos = pos }
			i += 3
		else
			toks[#toks + 1] = { t = "sym", v = c, pos = pos }
			i += 1
		end
	end
	toks[#toks + 1] = { t = "eof", pos = n + 1 }
	return toks
end


return lex
