--!strict
-- Search, category and sort logic shared by every browsable page and Quick Find.
-- Pure Luau (no Roblox APIs) so the Lune suite can test it directly.

local Model = {}

export type Category = { id: string, label: string, icon: string?, test: ((any) -> boolean)? }
export type Sort = { id: string, label: string, compare: ((any, any) -> boolean)? }
export type Options = {
	text: (any) -> { string? }?,
	fields: ((any) -> { string })?,
	categories: { Category }?,
	sorts: { Sort }?,
	aliases: { [string]: { string } }?,
}

-- Words players type for things the game names differently.
Model.ALIASES = {
	money = { "flux", "cash", "vault" },
	cash = { "flux", "vault" },
	gems = { "stardust", "dust" },
	pet = { "relic", "companion" },
	pets = { "relics", "companions" },
	items = { "relics", "inventory" },
	upgrade = { "research", "machine", "level" },
	upgrades = { "research", "machines" },
	friends = { "crew", "guild", "trade" },
	daily = { "rewards", "missions", "streak" },
	spin = { "wheel" },
	market = { "bazaar", "supplies", "shipments" },
	quest = { "mission", "milestone", "story" },
	quests = { "missions", "milestones" },
	options = { "settings" },
	sound = { "audio", "volume", "music" },
	inbox = { "mail" },
	rank = { "leaderboards", "ranks", "level" },
	top = { "leaderboards" },
	potion = { "boost" },
	potions = { "boosts" },
	buff = { "boost" },
	zone = { "worlds", "world" },
	map = { "worlds" },
}

function Model.normalize(value: any): string
	if type(value) ~= "string" then
		value = if value == nil then "" else tostring(value)
	end
	local text = string.lower(value)
	-- strip rich text tags and punctuation so "<b>Auto-Gear</b>" matches "auto gear"
	text = string.gsub(text, "<[^>]->", " ")
	text = string.gsub(text, "[^%w%s]", " ")
	text = string.gsub(text, "%s+", " ")
	return (string.match(text, "^%s*(.-)%s*$") or "")
end

function Model.tokens(query: string): { string }
	local list = {}
	for word in string.gmatch(Model.normalize(query), "%S+") do
		table.insert(list, word)
	end
	return list
end

-- Levenshtein distance capped at `limit` (returns limit + 1 when farther).
local function distance(a: string, b: string, limit: number): number
	local la, lb = #a, #b
	if math.abs(la - lb) > limit then
		return limit + 1
	end
	local previous = table.create(lb + 1, 0)
	for j = 0, lb do
		previous[j + 1] = j
	end
	for i = 1, la do
		local current = table.create(lb + 1, 0)
		current[1] = i
		local best = i
		local ca = string.byte(a, i)
		for j = 1, lb do
			local cost = if ca == string.byte(b, j) then 0 else 1
			local value = math.min(previous[j + 1] + 1, current[j] + 1, previous[j] + cost)
			current[j + 1] = value
			if value < best then
				best = value
			end
		end
		if best > limit then
			return limit + 1
		end
		previous = current
	end
	return previous[lb + 1]
end
Model.distance = distance

-- How well one query token matches one normalized field. 0 means no match.
function Model.tokenScore(token: string, field: string): number
	if token == "" or field == "" then
		return 0
	end
	if field == token then
		return 10
	end
	local at = string.find(field, token, 1, true)
	if at ~= nil then
		local wordStart = at == 1 or string.sub(field, at - 1, at - 1) == " "
		if at == 1 then
			return 8
		elseif wordStart then
			return 6
		end
		return 3
	end
	-- initials: "ag" finds "auto gear", "sg" finds "star grid"
	if #token >= 2 then
		local initials = string.gsub(" " .. field, " (%w)%w*", "%1")
		if string.find(initials, token, 1, true) == 1 then
			return 4
		end
	end
	-- one typo per four letters, compared against each word's leading slice
	if #token >= 4 then
		local limit = if #token >= 8 then 2 else 1
		for word in string.gmatch(field, "%S+") do
			if #word >= #token - limit then
				local slice = string.sub(word, 1, math.max(#token, math.min(#word, #token + limit)))
				if distance(token, slice, limit) <= limit or distance(token, word, limit) <= limit then
					return 2
				end
			end
		end
	end
	return 0
end

-- Normalizes every searchable field once; the result is cached per item by `index`.
function Model.fieldsOf(item: any, text: ((any) -> { string? }?)?): { string }
	local raw: { string? }
	if text ~= nil then
		raw = text(item) or {}
	elseif type(item) == "table" then
		raw = { item.Name or item.name or item.label or item.Label, item.Description or item.description or item.Desc }
	else
		raw = { tostring(item) }
	end
	local fields = {}
	-- `{ a, nil, c }` leaves holes, so walk the declared length rather than ipairs
	local count = 0
	for key in raw :: any do
		if type(key) == "number" and key > count then
			count = key
		end
	end
	for i = 1, count do
		local value = raw[i]
		if value ~= nil then
			table.insert(fields, Model.normalize(value))
		end
	end
	return fields
end

-- Total relevance of `query` against an item's fields; 0 when any token misses.
-- Earlier fields weigh more (the name beats the description).
function Model.score(query: string | { string }, fields: { string }, aliases: { [string]: { string } }?): number
	local list = if type(query) == "table" then query else Model.tokens(query)
	if #list == 0 then
		return 1
	end
	local aliasMap = aliases or Model.ALIASES
	local total = 0
	for _, token in list do
		local best = 0
		for index, field in fields do
			local weight = if index == 1 then 2 elseif index == 2 then 1.25 else 1
			local value = Model.tokenScore(token, field) * weight
			if value > best then
				best = value
			end
		end
		if best == 0 then
			local synonyms = aliasMap[token]
			if synonyms ~= nil then
				for _, synonym in synonyms do
					for index, field in fields do
						local weight = if index == 1 then 2 elseif index == 2 then 1.25 else 1
						local value = Model.tokenScore(synonym, field) * weight * 0.8
						if value > best then
							best = value
						end
					end
				end
			end
		end
		if best == 0 then
			return 0
		end
		total += best
	end
	return total
end

function Model.matches(query: string, item: any, text: ((any) -> { string? }?)?): boolean
	return Model.score(query, Model.fieldsOf(item, text)) > 0
end

local function findById(list: { any }?, id: string?): any
	if list == nil or id == nil then
		return nil
	end
	for _, entry in list do
		if entry.id == id then
			return entry
		end
	end
	return nil
end
Model.findById = findById

export type Result = {
	results: { any },
	counts: { [string]: number },
	matched: number,
	total: number,
	relevance: boolean,
}

-- Applies the query, then counts every category against the query matches,
-- then keeps the chosen category and sorts. With a query and the default sort,
-- results come back best match first.
function Model.run(items: { any }, options: Options, query: string, categoryId: string?, sortId: string?): Result
	local list = Model.tokens(query)
	local matched = {}
	local scores = {}
	for index, item in items do
		local value = if #list == 0
			then 1
			else Model.score(list, if options.fields then options.fields(item) else Model.fieldsOf(item, options.text), options.aliases)
		if value > 0 then
			table.insert(matched, item)
			scores[item] = value - index * 1e-6
		end
	end
	local counts: { [string]: number } = {}
	local category = findById(options.categories, categoryId)
	local results = {}
	for _, entry in options.categories or {} do
		local n = 0
		for _, item in matched do
			if entry.test == nil or entry.test(item) then
				n += 1
			end
		end
		counts[entry.id] = n
	end
	for _, item in matched do
		if category == nil or category.test == nil or category.test(item) then
			table.insert(results, item)
		end
	end
	local sorts = options.sorts
	local sort = findById(sorts, sortId) or (if sorts then sorts[1] else nil)
	local relevance = false
	if sort ~= nil and sort.compare ~= nil then
		local compare = sort.compare
		local order = {}
		for index, item in results do
			order[item] = index
		end
		table.sort(results, function(a, b)
			if compare(a, b) then
				return true
			elseif compare(b, a) then
				return false
			end
			return order[a] < order[b]
		end)
	elseif #list > 0 then
		relevance = true
		table.sort(results, function(a, b)
			return scores[a] > scores[b]
		end)
	end
	return {
		results = results,
		counts = counts,
		matched = #matched,
		total = #items,
		relevance = relevance,
	}
end

-- Escapes rich text and bolds the first hit of each query token, for result rows.
function Model.highlight(text: string, query: string, color: string?): string
	local function escape(value: string): string
		return (string.gsub(string.gsub(string.gsub(value, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
	end
	local list = Model.tokens(query)
	if #list == 0 then
		return escape(text)
	end
	local lower = string.lower(text)
	local marks: { { number } } = {}
	for _, token in list do
		local at = string.find(lower, token, 1, true)
		if at ~= nil then
			table.insert(marks, { at, at + #token - 1 })
		end
	end
	if #marks == 0 then
		return escape(text)
	end
	table.sort(marks, function(a, b)
		return a[1] < b[1]
	end)
	local out = {}
	local cursor = 1
	local open = if color then `<b><font color="{color}">` else "<b>"
	local close = if color then "</font></b>" else "</b>"
	for _, mark in marks do
		if mark[1] >= cursor then
			table.insert(out, escape(string.sub(text, cursor, mark[1] - 1)))
			table.insert(out, open .. escape(string.sub(text, mark[1], mark[2])) .. close)
			cursor = mark[2] + 1
		end
	end
	table.insert(out, escape(string.sub(text, cursor)))
	return table.concat(out)
end

-- Session memory so a page keeps its search, category and sort when you come back.
local memory: { [string]: { query: string, category: string?, sort: string? } } = {}
function Model.remember(id: string, entry: { query: string, category: string?, sort: string? })
	memory[id] = entry
end
function Model.recall(id: string): { query: string, category: string?, sort: string? }?
	return memory[id]
end

-- Deep links (Quick Find -> a page): remembered for a page that mounts later, and pushed
-- live to a page that is already open.
local listeners: { [string]: { (any) -> () } } = {}
function Model.link(id: string, entry: { query: string, category: string?, sort: string? })
	local previous = memory[id]
	memory[id] = {
		query = entry.query,
		category = entry.category,
		sort = entry.sort or (if previous then previous.sort else nil),
	}
	for _, listener in table.clone(listeners[id] or {}) do
		listener(memory[id])
	end
end
function Model.listen(id: string, listener: (any) -> ()): () -> ()
	local list = listeners[id] or {}
	listeners[id] = list
	table.insert(list, listener)
	return function()
		local at = table.find(list, listener)
		if at ~= nil then
			table.remove(list, at)
		end
	end
end

-- Recent Quick Find picks, newest first.
local recents: { string } = {}
function Model.pushRecent(key: string, limit: number?)
	local at = table.find(recents, key)
	if at ~= nil then
		table.remove(recents, at)
	end
	table.insert(recents, 1, key)
	while #recents > (limit or 6) do
		table.remove(recents)
	end
end
function Model.recent(): { string }
	return table.clone(recents)
end

return Model
