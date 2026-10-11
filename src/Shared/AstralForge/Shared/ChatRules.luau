--!strict
-- Pure chat rules shared by the server relay and the client chat hook.
-- No Roblox services here so the rules can be exercised from Lune.

local ChatRules = {}

ChatRules.MAX_INPUT = 160
ChatRules.GLOBAL_COOLDOWN = 6
-- Global chat crosses servers through MemoryStore sorted maps, not MessagingService: a broadcast
-- topic costs (publishes x servers) against the experience-wide receive budget, while polling costs
-- a fixed amount per server. Each server writes one batch per tick to its own map and reads the
-- newest entries of every map.
ChatRules.GLOBAL_SHARDS = 4
ChatRules.GLOBAL_TICK = 3 -- seconds between a server's write and read passes
ChatRules.GLOBAL_READ_COUNT = 6 -- newest entries read from each map per tick
ChatRules.GLOBAL_TTL = 120 -- seconds an entry lives in its map
ChatRules.RELAY_MAX_BYTES = 4000
ChatRules.FRIENDS_CHANNEL = "AFFriends"
ChatRules.SERVER_CHANNEL = "RBXGeneral"
ChatRules.WHISPER_PREFIX = "AFWhisper:"
ChatRules.CREW_PREFIX = "AFCrew:"
ChatRules.CHANNELS = table.freeze({ "all", "global", "server", "crew", "friends", "whispers" })

-- True when `text` @mentions the player by username or display name (case-insensitive, whole word).
function ChatRules.mentions(text: any, name: any, displayName: any): boolean
	if type(text) ~= "string" or not string.find(text, "@", 1, true) then
		return false
	end
	local lowered = string.lower(text) .. " "
	for _, candidate in { name, displayName } do
		if type(candidate) == "string" and candidate ~= "" then
			local needle = "@" .. string.lower(candidate)
			local start = 1
			while true do
				local first, last = string.find(lowered, needle, start, true)
				if first == nil then break end
				local before = if first > 1 then string.sub(lowered, first - 1, first - 1) else " "
				local after = string.sub(lowered, last + 1, last + 1)
				if not string.match(before, "[%w_]") and not string.match(after, "[%w_]") then
					return true
				end
				start = last + 1
			end
		end
	end
	return false
end

-- Short local clock for a message time ("14:05").
function ChatRules.clock(at: any): string
	if type(at) ~= "number" or at ~= at then
		return ""
	end
	return os.date("%H:%M", math.floor(at)) :: string
end

-- "Who can reach you" settings (0 anyone, 0.5 friends, 1 nobody) with the default for a missing value.
function ChatRules.allows(policy: any, isFriend: boolean): boolean
	local value = if type(policy) == "number" and policy == policy then policy else 0
	if value < 0.25 then
		return true
	elseif value < 0.75 then
		return isFriend
	end
	return false
end

function ChatRules.crewChannel(crewId: string): string
	return ChatRules.CREW_PREFIX .. crewId
end

function ChatRules.isCrewChannel(name: any): boolean
	return type(name) == "string" and string.sub(name, 1, #ChatRules.CREW_PREFIX) == ChatRules.CREW_PREFIX
end

export type Command = {
	kind: string,
	target: string?,
	body: string?,
}

export type CommandInfo = {
	name: string,
	usage: string,
	hint: string,
}

ChatRules.COMMANDS = table.freeze({
	table.freeze({ name = "w", usage = "/w name message", hint = "Whisper a player in this server" }),
	table.freeze({ name = "r", usage = "/r message", hint = "Reply to your last whisper" }),
	table.freeze({ name = "g", usage = "/g message", hint = "Send to global chat" }),
	table.freeze({ name = "s", usage = "/s message", hint = "Send to this server" }),
	table.freeze({ name = "f", usage = "/f message", hint = "Send to friends here" }),
	table.freeze({ name = "c", usage = "/c message", hint = "Send to your crew" }),
	table.freeze({ name = "mute", usage = "/mute name", hint = "Hide a player's messages" }),
	table.freeze({ name = "unmute", usage = "/unmute name", hint = "Show a player's messages again" }),
	table.freeze({ name = "clear", usage = "/clear", hint = "Clear messages on this device" }),
	table.freeze({ name = "help", usage = "/help", hint = "List chat shortcuts" }),
} :: { CommandInfo })

local ALIASES: { [string]: string } = {
	w = "w", whisper = "w", msg = "w", pm = "w", dm = "w",
	r = "r", reply = "r",
	g = "g", global = "g",
	s = "s", server = "s",
	f = "f", friends = "f",
	c = "c", crew = "c", party = "c",
	mute = "mute", unmute = "unmute", clear = "clear", help = "help",
}

function ChatRules.trim(text: string): string
	return (string.gsub((string.gsub(text, "^%s+", "")), "%s+$", ""))
end

-- Splits "/w name hello" into { kind = "w", target = "name", body = "hello" }.
-- Plain text returns kind = "say". Unknown slash words return kind = "unknown".
function ChatRules.parse(raw: any): Command
	if type(raw) ~= "string" then return { kind = "empty" } end
	local text = ChatRules.trim(raw)
	if text == "" then return { kind = "empty" } end
	if string.sub(text, 1, 1) ~= "/" then return { kind = "say", body = text } end
	local word, rest = string.match(text, "^/(%S+)%s*(.*)$")
	if word == nil then return { kind = "unknown", body = text } end
	local kind = ALIASES[string.lower(word)]
	if kind == nil then return { kind = "unknown", target = word, body = rest } end
	if kind == "w" then
		local target, body = string.match(rest or "", "^@?(%S+)%s*(.*)$")
		return { kind = "w", target = target, body = if body and body ~= "" then body else nil }
	elseif kind == "mute" or kind == "unmute" then
		local target = string.match(rest or "", "^@?(%S+)")
		return { kind = kind, target = target }
	end
	return { kind = kind, body = if rest and rest ~= "" then rest else nil }
end

export type Candidate = { userId: number, name: string, displayName: string }
export type Suggestion = {
	kind: string,
	label: string,
	detail: string,
	fill: string,
	userId: number?,
}

local function startsWith(text: string, prefix: string): boolean
	return string.sub(string.lower(text), 1, #prefix) == string.lower(prefix)
end

local function rankPlayers(partial: string, players: { Candidate }, limit: number): { Candidate }
	local hits = {}
	for _, candidate in players do
		local score = 0
		if partial == "" then
			score = 1
		elseif startsWith(candidate.name, partial) then
			score = 4
		elseif startsWith(candidate.displayName, partial) then
			score = 3
		elseif string.find(string.lower(candidate.name), string.lower(partial), 1, true) then
			score = 2
		elseif string.find(string.lower(candidate.displayName), string.lower(partial), 1, true) then
			score = 1
		end
		if score > 0 then table.insert(hits, { score = score, candidate = candidate }) end
	end
	table.sort(hits, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return string.lower(a.candidate.name) < string.lower(b.candidate.name)
	end)
	local out = {}
	for index = 1, math.min(limit, #hits) do out[index] = hits[index].candidate end
	return out
end

-- Autocomplete for the draft. Covers command names, "/w partial" and "@partial" at the end of the draft.
function ChatRules.suggest(draft: any, players: { Candidate }, limit: number?): { Suggestion }
	local cap = limit or 5
	if type(draft) ~= "string" or draft == "" then return {} end
	local out: { Suggestion } = {}
	local commandWord = string.match(draft, "^/(%S*)$")
	if commandWord ~= nil then
		for _, info in ChatRules.COMMANDS do
			if startsWith(info.name, commandWord) and #out < cap then
				table.insert(out, { kind = "command", label = info.usage, detail = info.hint, fill = "/" .. info.name .. " " })
			end
		end
		return out
	end
	local verb, partial = string.match(draft, "^/(%a+)%s+@?(%S*)$")
	if verb ~= nil then
		local kind = ALIASES[string.lower(verb)]
		if kind == "w" or kind == "mute" or kind == "unmute" then
			for _, candidate in rankPlayers(partial or "", players, cap) do
				table.insert(out, {
					kind = "player",
					label = candidate.displayName,
					detail = "@" .. candidate.name,
					fill = "/" .. string.lower(verb) .. " " .. candidate.name .. " ",
					userId = candidate.userId,
				})
			end
		end
		return out
	end
	local head, mention = string.match(draft, "^(.-)@(%w*)$")
	if mention ~= nil and head ~= nil and (head == "" or string.match(head, "%s$") ~= nil) then
		for _, candidate in rankPlayers(mention, players, cap) do
			table.insert(out, {
				kind = "mention",
				label = candidate.displayName,
				detail = "@" .. candidate.name,
				fill = head .. "@" .. candidate.name .. " ",
				userId = candidate.userId,
			})
		end
	end
	return out
end

function ChatRules.findPlayer(name: any, players: { Candidate }): Candidate?
	if type(name) ~= "string" or name == "" then return nil end
	local lowered = string.lower(name)
	for _, candidate in players do
		if string.lower(candidate.name) == lowered then return candidate end
	end
	for _, candidate in players do
		if string.lower(candidate.displayName) == lowered then return candidate end
	end
	local ranked = rankPlayers(name, players, 2)
	-- a partial only resolves when it is unambiguous
	if #ranked == 1 then return ranked[1] end
	if #ranked > 1 and startsWith(ranked[1].name, name) and not startsWith(ranked[2].name, name) then return ranked[1] end
	return nil
end

function ChatRules.whisperChannel(a: number, b: number): string
	local low, high = math.min(a, b), math.max(a, b)
	return string.format("%s%d_%d", ChatRules.WHISPER_PREFIX, low, high)
end

function ChatRules.whisperPeer(channelName: any, selfId: number): number?
	if type(channelName) ~= "string" then return nil end
	local low, high = string.match(channelName, "^" .. ChatRules.WHISPER_PREFIX .. "(%d+)_(%d+)$")
	if low == nil or high == nil then return nil end
	local a, b = tonumber(low), tonumber(high)
	if a == selfId then return b end
	if b == selfId then return a end
	return nil
end

-- Stable shard for a server id: a server always writes the same map, so writes spread evenly.
function ChatRules.shardFor(jobId: string, shards: number?): number
	local count = math.max(1, math.floor(shards or ChatRules.GLOBAL_SHARDS))
	local hash = 5381
	for index = 1, #jobId do
		hash = (hash * 33 + string.byte(jobId, index)) % 2147483647
	end
	return hash % count + 1
end

function ChatRules.mapName(shard: number): string
	return "AF_GlobalChat_v2_" .. tostring(shard)
end

-- Sorted-map keys order by time: zero-padded milliseconds, then a per-server suffix for uniqueness.
function ChatRules.entryKey(millis: number, suffix: string): string
	return string.format("%015d_%s", math.max(0, math.floor(millis)), string.sub(suffix, 1, 24))
end

-- MemoryStore requests one server spends per minute, at most (one write and every map read per tick).
function ChatRules.requestsPerServerMinute(): number
	return (60 / ChatRules.GLOBAL_TICK) * (1 + ChatRules.GLOBAL_SHARDS)
end

-- Roblox's documented experience-wide MemoryStore quota.
function ChatRules.memoryStoreQuota(players: number): number
	return 1000 + 100 * math.max(0, players)
end

-- Takes as many queued entries as fit under maxBytes once encoded; the rest wait for the next flush.
function ChatRules.takeBatch(queue: { any }, encode: (any) -> string, maxBytes: number?): ({ any }, string?)
	local budget = maxBytes or ChatRules.RELAY_MAX_BYTES
	local batch = {}
	local encoded: string? = nil
	while #queue > 0 do
		table.insert(batch, queue[1])
		local attempt = encode(batch)
		if #attempt > budget then
			table.remove(batch)
			break
		end
		encoded = attempt
		table.remove(queue, 1)
	end
	if #batch == 0 and #queue > 0 then
		-- a single entry that can never fit is dropped so it cannot block the queue
		table.remove(queue, 1)
	end
	return batch, encoded
end

export type SearchRecord = { text: string, username: string, displayName: string, channel: string }

function ChatRules.matches(record: SearchRecord, query: any): boolean
	if type(query) ~= "string" then return true end
	local needle = string.lower(ChatRules.trim(query))
	if needle == "" then return true end
	local from = string.match(needle, "^from:(%S+)")
	if from ~= nil then
		local rest = ChatRules.trim(string.sub(needle, #from + 6))
		if not startsWith(record.username, from) and not startsWith(record.displayName, from) then return false end
		if rest == "" then return true end
		needle = rest
	end
	local channel = string.match(needle, "^in:(%S+)")
	if channel ~= nil then
		local rest = ChatRules.trim(string.sub(needle, #channel + 4))
		if not startsWith(record.channel, channel) then return false end
		if rest == "" then return true end
		needle = rest
	end
	return string.find(string.lower(record.text), needle, 1, true) ~= nil
		or string.find(string.lower(record.username), needle, 1, true) ~= nil
		or string.find(string.lower(record.displayName), needle, 1, true) ~= nil
end

-- Which category tab a record belongs to.
function ChatRules.inTab(channel: string, tab: string): boolean
	if tab == "all" then return true end
	if tab == "whispers" then return channel == "whisper" end
	if channel == "system" then return true end
	return channel == tab
end

return table.freeze(ChatRules)
