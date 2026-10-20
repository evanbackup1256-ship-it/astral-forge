--!strict
-- Rough 360px width check for specific player-facing lines. No TextService under Lune, so this
-- uses a conservative per-glyph estimate (Builder Sans, Bold ~0.58em, caps wider). Each case pulls
-- its string straight from source so a copy edit can't drift past the check unnoticed.

local fs = require("@lune/fs")

local ROOT = "src/Client/AstralForge/"
-- phone portrait: 360 wide, 14px page padding each side
local PHONE = 360 - 14 * 2

local function glyph(c: string, bold: boolean): number
	local w
	if string.match(c, "%u") then
		w = 0.68
	elseif string.match(c, "%d") then
		w = 0.6
	elseif c == " " then
		w = 0.27
	elseif string.match(c, "[%.,'·:;i l]") then
		w = 0.3
	elseif c == "%" or c == "m" or c == "w" then
		w = 0.85
	else
		w = 0.54
	end
	return if bold then w * 1.07 else w
end

local function measure(text: string, size: number, bold: boolean): number
	local total = 0
	for _, code in utf8.codes(text) do
		total += glyph(utf8.char(code), bold) * size
	end
	return total
end

type Case = { file: string, needle: string, fill: { [string]: string }?, size: number, bold: boolean, width: number, lines: number }

-- trade fairness: 12 Bold, fit + minSize 10, inside panel (14) + strip (10) padding; adv tops out at 100
local tradeWidth = PHONE - 14 * 2 - 10 * 2
-- guild chat box: panel padding 14, send button takes 112, textbox TextSize 14
local chatWidth = PHONE - 14 * 2 - 112 - 8

local CASES: { Case } = {
	{ file = "pages/PagesSocial.tsx", needle = "You're giving +${adv}% more than you get", fill = { adv = "100" }, size = 10, bold = true, width = tradeWidth, lines = 1 },
	{ file = "pages/PagesSocial.tsx", needle = "You're getting +${adv}% more than you give", fill = { adv = "100" }, size = 10, bold = true, width = tradeWidth, lines = 1 },
	{ file = "pages/PagesSocial.tsx", needle = "Fair trade · about even", size = 12, bold = true, width = tradeWidth, lines = 1 },
	{ file = "pages/PagesSocial.tsx", needle = "Add items or currency to see the balance", size = 10, bold = true, width = tradeWidth, lines = 1 },
	-- guild goal fallback: 11 regular, 30px box = 2 lines
	{ file = "pages/views/GuildView.ts", needle = "Every deposit and build counts toward it.", size = 11, bold = false, width = PHONE - 14 * 2 - 8, lines = 2 },
	{ file = "pages/views/GuildView.ts", needle = "Leader turned chat off", size = 14, bold = false, width = chatWidth, lines = 1 },
	{ file = "pages/views/GuildView.ts", needle = "Message your guild…", size = 14, bold = false, width = chatWidth, lines = 1 },
}

local bad = {}
for _, case in CASES do
	local source = fs.readFile(ROOT .. case.file)
	if not string.find(source, case.needle, 1, true) then
		table.insert(bad, `{case.file}: string not found (update the case): {case.needle}`)
		continue
	end
	local text = case.needle
	for key, value in case.fill or {} do
		text = string.gsub(text, "%${" .. key .. "}", value)
	end
	local w = measure(text, case.size, case.bold)
	if w > case.width * case.lines then
		table.insert(bad, `{case.file}: "{text}" ~{math.ceil(w)}px > {case.width * case.lines}px at 360`)
	end
end

-- the fairness line depends on shrink-to-fit for the 100% case
local social = fs.readFile(ROOT .. "pages/PagesSocial.tsx")
if not string.find(social, "value: balanceText,%s*size: 12,%s*fit: true,%s*minSize: 10") then
	table.insert(bad, "pages/PagesSocial.tsx: trade balance Text lost fit/minSize")
end

if #bad > 0 then
	error("Copy too wide for a 360px phone:\n  " .. table.concat(bad, "\n  "))
end
print(`[TEST] copy fit: {#CASES} lines fit at 360px`)
