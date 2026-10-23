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

-- Mirrors Text in UiCore/ui.tsx: rendered size is at least MIN_UI_TEXT_SIZE (11); with fit the
-- floor is max(minSize, min(12, size)), so a minSize under 12 doesn't shrink a 12px line further.
local MIN_UI_TEXT_SIZE = 11
local function smallest(size: number, minSize: number?): number
	local rendered = math.max(size, MIN_UI_TEXT_SIZE)
	if minSize == nil then
		return rendered
	end
	return math.clamp(math.max(minSize, math.min(12, rendered)), 1, rendered)
end

type Case = {
	file: string,
	needle: string,
	fill: { [string]: string }?,
	size: number,
	minSize: number?, -- nil: no fit
	bold: boolean,
	width: number,
	box: number?, -- wrapped: box height; nil: single line
	phone: number?, -- screen width the case is checked at (default 360)
}

-- trade fairness: 12 Bold fit, inside panel (14) + strip (10) padding; adv tops out at 100
local tradeWidth = PHONE - 14 * 2 - 10 * 2
-- guild chat box: panel padding 14, send button takes 112, textbox TextSize 14
local chatWidth = PHONE - 14 * 2 - 112 - 8
-- Shop panels pad 14; Hero text starts after the 56px icon tile
local shopPanel = PHONE - 14 * 2
local heroWidth = shopPanel - 56

local CASES: { Case } = {
	{ file = "pages/PagesSocial.tsx", needle = "You're giving +${adv}% more than you get", fill = { adv = "100" }, size = 12, minSize = 10, bold = true, width = tradeWidth },
	{ file = "pages/PagesSocial.tsx", needle = "You're getting +${adv}% more than you give", fill = { adv = "100" }, size = 12, minSize = 10, bold = true, width = tradeWidth },
	{ file = "pages/PagesSocial.tsx", needle = "About even", size = 12, minSize = 10, bold = true, width = tradeWidth },
	{ file = "pages/PagesSocial.tsx", needle = "Add items or currency to see the balance", size = 12, minSize = 10, bold = true, width = tradeWidth },
	{ file = "pages/views/GuildView.ts", needle = "Every deposit and build counts toward it.", size = 11, bold = false, width = PHONE - 14 * 2 - 8, box = 30 },
	{ file = "pages/views/GuildView.ts", needle = "Leader turned chat off", size = 14, bold = false, width = chatWidth },
	{ file = "pages/views/GuildView.ts", needle = "Message your guild…", size = 14, bold = false, width = chatWidth },
	-- player list at its 286px minimum (inner width 266)
	{ file = "UiCore/PlayerlistOverlay.ts", needle = "Just you in here. Invite friends for a production boost, trades, crews and visits.", size = 12, minSize = 11, bold = false, width = 266 - 24, box = 54 },
	{ file = "UiCore/PlayerlistOverlay.ts", needle = "Thanks for helping keep the server friendly.", size = 12, minSize = 11, bold = false, width = 266 - 20, box = 34 },
	{ file = "UiCore/PlayerlistOverlay.ts", needle = "Couldn't head home. Try again.", size = 12, bold = false, width = 266 },
	{ file = "UiCore/PlayerlistOverlay.ts", needle = "Back at your workshop.", size = 12, bold = false, width = 266 },
	-- trade chat placeholder at 360 (textbox leaves 78 for SEND), 13px
	{ file = "pages/PagesSocial.tsx", needle = "Say something to ${session.PartnerName}", fill = { ["session.PartnerName"] = "WWWWWWWWWWWW" }, size = 13, bold = false, width = PHONE - 14 * 2 - 78 },
	-- Shop
	{ file = "pages/PagesShop.tsx", needle = "Passes, packs and codes", size = 18, minSize = 14, bold = true, width = shopPanel },
	{ file = "pages/PagesShop.tsx", needle = "Type a code to claim it. Each one works once.", size = 12, minSize = 10, bold = false, width = shopPanel, box = 26 },
	{ file = "pages/PagesShop.tsx", needle = "Follow the creator on Roblox, then check here for a one-time reward.", size = 11, minSize = 9, bold = false, width = shopPanel - 52, box = 42 },
	{ file = "pages/PagesShop.tsx", needle = "Reward claimed. Thanks for the follow.", size = 11, minSize = 9, bold = false, width = shopPanel - 52, box = 42 },
	{ file = "pages/PagesShop.tsx", needle = "Six offers a day. The first is the Deal of the Day.", size = 12, minSize = 10, bold = false, width = heroWidth, box = 34 },
	{ file = "pages/PagesShop.tsx", needle = "Odds for every crate, up to Astral.", size = 12, minSize = 10, bold = false, width = heroWidth, box = 34 },
	{ file = "pages/PagesShop.tsx", needle = "The Celestial Ark is only sold in the Daily Shop.", size = 12, minSize = 10, bold = false, width = heroWidth, box = 34 },
	-- Settings (stacked layout on phones, so the header text gets the full width)
	{ file = "pages/PagesSystem/SettingsView.tsx", needle = "Saves automatically  ·  v", fill = {}, size = 12, minSize = 9, bold = false, width = PHONE - 60 },
	{ file = "pages/PagesSystem/SettingsView.tsx", needle = "What you changed from the default.", size = 12, bold = false, width = PHONE - 110 },
	{ file = "pages/PagesSystem/SettingsView.tsx", needle = "From every section.", size = 12, bold = false, width = PHONE - 110 },
	{ file = "pages/PagesSystem/SettingsView.tsx", needle = "Everything is on its default.", size = 13, bold = false, width = PHONE },
	{ file = "pages/PagesSystem/SettingsView.tsx", needle = 'No match. Try "music" or "text".', size = 13, bold = false, width = PHONE },
}

-- day-b mobile audit (B36/B37): stacked-layout lines in Command, Lab and Shop, at 360 and at 286
-- (the narrowest phone width we lay out for). Real phone page width, from CoreKit/mobileLayout.ts
-- and the shell: AppShell edgePad = max(8, sideSafe >= 12, floor(pagePadding 14 * density)) with
-- density 0.82..1.18 (UiDensity 0..1), so 12..16 per side, worst case 16; WorkspaceChrome then
-- insets the page by contentInset (14) per side. Panels pad 14 each side.
local PHONE_EDGE_MAX = math.floor(14 * 1.18)
local PHONE_CONTENT_INSET = 14
local function phoneCases(phone: number)
	local page = phone - PHONE_EDGE_MAX * 2 - PHONE_CONTENT_INSET * 2
	local panel = page - 14 * 2
	return {
		{ file = "pages/PagesProgress/LabView.tsx", needle = "Move cells whenever you like.", size = 16, minSize = 12, bold = true, width = panel - 8, phone = phone },
		{ file = "pages/PagesProgress/LabView.tsx", needle = "Bonuses apply at once. A new cell unlocks every 8 rebirths.", size = 11, minSize = 10, bold = false, width = panel - 8, box = 32, phone = phone },
		{ file = "pages/PagesSystem/CommandView.tsx", needle = "Title wardrobe", size = 18, minSize = 12, bold = true, width = panel, phone = phone },
		{ file = "pages/PagesSystem/CommandView.tsx", needle = "Each title shows as it looks on you.", size = 11, bold = false, width = panel, phone = phone },
		{ file = "pages/PagesShop.tsx", needle = "Passes, packs and codes", size = 18, minSize = 14, bold = true, width = panel, phone = phone },
	}
end
for _, phone in { 360, 286 } do
	for _, case in phoneCases(phone) do
		table.insert(CASES, case :: any)
	end
end

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
	local size = smallest(case.size, case.minSize)
	local w = measure(text, size, case.bold)
	local room = case.width
	if case.box then
		-- wrapped: whole lines at 1.12 line height, and word breaks waste ~12% of each line
		local lines = math.max(1, math.floor(case.box / (size * 1.12)))
		room = case.width * lines * 0.88
	end
	if w > room then
		table.insert(bad, `{case.file}: "{text}" ~{math.ceil(w)}px > {math.floor(room)}px at {case.phone or 360} ({size}px)`)
	end
end

-- the fairness line depends on shrink-to-fit for the 100% case
local social = fs.readFile(ROOT .. "pages/PagesSocial.tsx")
if not string.find(social, "value: balanceText,%s*size: 12,%s*fit: true") then
	table.insert(bad, "pages/PagesSocial.tsx: trade balance Text lost fit/minSize")
end

if #bad > 0 then
	error("Copy too wide for a phone:\n  " .. table.concat(bad, "\n  "))
end
print(`[TEST] copy fit: {#CASES} lines fit (360px, plus 286px for the day-b mobile cases)`)
