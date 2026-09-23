local fs = require("@lune/fs")
local process = require("@lune/process")
local lex = require("./_lexlib")
local file = process.args[1] or "../src/Client/AstralForge/pages/GuildView.luau"
local tokI = tonumber(process.args[2]) or 4512
local src = fs.readFile(file)
local toks = lex(src)
print("ntoks", #toks)
for i = math.max(1, tokI - 15), math.min(#toks, tokI + 15) do
	local t = toks[i]
	local _, ln = src:sub(1, t.pos):gsub("\n", "\n")
	print(i, t.t, tostring(t.v), "line " .. (ln + 1))
end
