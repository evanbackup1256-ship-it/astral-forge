-- Chat channels, slash commands, autocomplete, whisper naming and the global relay batcher.
local fs = require("@lune/fs")
local ChatRules = require("../out/Shared/AstralForge/Shared/ChatRules")

local roster = {
	{ userId = 11, name = "NovaSmith", displayName = "Nova" },
	{ userId = 22, name = "NovaKid", displayName = "Kiddo" },
	{ userId = 33, name = "Ember", displayName = "Ash" },
}

-- parse
assert(ChatRules.parse(nil).kind == "empty", "nil is empty")
assert(ChatRules.parse("   ").kind == "empty", "blank is empty")
local say = ChatRules.parse("  hello there ")
assert(say.kind == "say" and say.body == "hello there", "plain text is trimmed say")
local whisper = ChatRules.parse("/w @Ember hi you")
assert(whisper.kind == "w" and whisper.target == "Ember" and whisper.body == "hi you", "whisper parses target and body")
local openOnly = ChatRules.parse("/pm Ember")
assert(openOnly.kind == "w" and openOnly.target == "Ember" and openOnly.body == nil, "alias without body opens the whisper")
assert(ChatRules.parse("/W").kind == "w" and ChatRules.parse("/W").target == nil, "case-insensitive, missing target")
assert(ChatRules.parse("/global gg").kind == "g" and ChatRules.parse("/global gg").body == "gg", "global alias")
assert(ChatRules.parse("/s").body == nil, "channel switch without body")
assert(ChatRules.parse("/mute Ember extra").target == "Ember", "mute takes first word")
assert(ChatRules.parse("/dance").kind == "unknown", "unknown command")
assert(ChatRules.parse("/").kind == "unknown", "bare slash is unknown")

-- findPlayer
assert(ChatRules.findPlayer("ember", roster).userId == 33, "exact name, any case")
assert(ChatRules.findPlayer("ash", roster).userId == 33, "exact display name")
assert(ChatRules.findPlayer("Nova", roster).userId == 11, "display-name exact beats ambiguous prefix")
assert(ChatRules.findPlayer("NovaS", roster).userId == 11, "unambiguous prefix")
assert(ChatRules.findPlayer("Nov", roster) == nil, "ambiguous prefix refuses")
assert(ChatRules.findPlayer("", roster) == nil and ChatRules.findPlayer(nil, roster) == nil, "empty name")

-- suggest
local commands = ChatRules.suggest("/", roster, 20)
assert(#commands == #ChatRules.COMMANDS, "bare slash lists every command")
local mutes = ChatRules.suggest("/mu", roster)
assert(#mutes == 1 and mutes[1].fill == "/mute ", "command prefix narrows")
local whisperNames = ChatRules.suggest("/w nova", roster)
assert(#whisperNames == 2 and whisperNames[1].kind == "player", "whisper target completes players")
assert(whisperNames[1].fill == "/w NovaKid ", "fill keeps verb and inserts name")
local mention = ChatRules.suggest("gg @em", roster)
assert(#mention == 1 and mention[1].fill == "gg @Ember ", "mention completes at end of draft")
assert(#ChatRules.suggest("mail@em", roster) == 0, "mention needs a word boundary")
assert(#ChatRules.suggest("hello", roster) == 0, "plain text has no suggestions")
assert(#ChatRules.suggest("/w ", roster, 2) == 2, "limit is respected")

-- whisper channels
local channelName = ChatRules.whisperChannel(900, 12)
assert(channelName == ChatRules.WHISPER_PREFIX .. "12_900", "pair is ordered")
assert(ChatRules.whisperChannel(12, 900) == channelName, "order independent")
assert(ChatRules.whisperPeer(channelName, 12) == 900 and ChatRules.whisperPeer(channelName, 900) == 12, "peer from either side")
assert(ChatRules.whisperPeer(channelName, 5) == nil, "outsider gets no peer")
assert(ChatRules.whisperPeer("RBXGeneral", 12) == nil, "non-whisper channel")
assert(ChatRules.whisperPeer(ChatRules.FRIENDS_CHANNEL, 12) == nil, "friends channel is not a whisper")

-- shards and topics
local shard = ChatRules.shardFor("job-a")
assert(shard >= 1 and shard <= ChatRules.GLOBAL_SHARDS, "shard in range")
assert(ChatRules.shardFor("job-a") == shard, "shard is stable")
assert(ChatRules.shardFor("anything", 1) == 1, "single shard")
local seen = {}
for index = 1, 200 do
	seen[ChatRules.shardFor("job-" .. index)] = true
end
local spread = 0
for _ in seen do
	spread += 1
end
assert(spread == ChatRules.GLOBAL_SHARDS, "jobs spread over every shard")
assert(ChatRules.mapName(3) == "AF_GlobalChat_v2_3", "map name")
local earlier = ChatRules.entryKey(1_700_000_000_000, "jobA1")
local later = ChatRules.entryKey(1_700_000_000_001, "jobA2")
assert(earlier < later, "entry keys sort by time as strings")
assert(ChatRules.entryKey(5, "x") < ChatRules.entryKey(40, "x"), "zero padding keeps short times in order")
assert(#ChatRules.entryKey(1, string.rep("z", 60)) <= 40, "suffix is bounded")

-- Cost scales with servers, not servers squared: global chat stays a small slice of the quota
-- from a handful of servers up to tens of thousands of players.
local perServer = ChatRules.requestsPerServerMinute()
assert(perServer <= 120, "one server's global chat polling stays bounded")
for _, servers in { 1, 10, 100, 1000, 2000 } do
	local players = servers * 25
	local total = servers * perServer
	assert(total <= ChatRules.memoryStoreQuota(players) * 0.1, `global chat under 10% of quota at {servers} servers`)
	-- spread: no single map carries more than its share of reads plus its servers' writes
	local perMap = servers * (60 / ChatRules.GLOBAL_TICK) * (1 + 1 / ChatRules.GLOBAL_SHARDS)
	assert(perMap <= 60_000, `per-map load stays bounded at {servers} servers`)
end
local chatService = fs.readFile("src/Server/AstralForge/Services/ChatService.luau")
assert(not chatService:find('GetService("MessagingService")', 1, true), "global chat never broadcasts to every server")
local guildCommunity = fs.readFile("src/Server/AstralForge/Services/GuildCommunity.luau")
assert(guildCommunity:find("RELAY_PREFIX .. guildId", 1, true) and not guildCommunity:find("AF_GuildCommunity_v1", 1, true),
	"guild relay uses one topic per guild, not one shared topic")
assert(guildCommunity:find("function GuildCommunity:_reconcileRelays", 1, true), "servers subscribe only to guilds they host")

-- takeBatch
local function encode(list)
	local parts = {}
	for _, item in list do
		table.insert(parts, item)
	end
	return table.concat(parts, ",")
end
local queue = { string.rep("a", 40), string.rep("b", 40), string.rep("c", 40) }
local batch, encoded = ChatRules.takeBatch(queue, encode, 90)
assert(#batch == 2 and #queue == 1, "fills up to the budget and leaves the rest")
assert(encoded ~= nil and #encoded <= 90, "encoded fits")
local tooBig = { string.rep("x", 200), "ok" }
local empty, none = ChatRules.takeBatch(tooBig, encode, 90)
assert(#empty == 0 and none == nil and #tooBig == 1 and tooBig[1] == "ok", "oversized head is dropped so the queue moves")

-- search and tabs
local record = { text = "Anyone trading void cores?", username = "NovaSmith", displayName = "Nova", channel = "global" }
assert(ChatRules.matches(record, nil) and ChatRules.matches(record, "  "), "empty query matches")
assert(ChatRules.matches(record, "VOID"), "text match is case-insensitive")
assert(ChatRules.matches(record, "from:nova"), "from filter alone")
assert(ChatRules.matches(record, "from:nova cores"), "from filter with words")
assert(not ChatRules.matches(record, "from:ember"), "from filter rejects other authors")
assert(ChatRules.matches(record, "in:glob trading"), "in filter with words")
assert(not ChatRules.matches(record, "in:server"), "in filter rejects other channels")
assert(not ChatRules.matches(record, "relic"), "no match")
assert(ChatRules.inTab("server", "all") and ChatRules.inTab("whisper", "all"), "all shows everything")
assert(ChatRules.inTab("whisper", "whispers") and not ChatRules.inTab("system", "whispers"), "whispers tab is whispers only")
assert(ChatRules.inTab("system", "global") and not ChatRules.inTab("server", "global"), "system notes show on channel tabs")

-- mentions: whole-word @name or @display name, any case
assert(ChatRules.mentions("hey @NovaSmith look", "NovaSmith", "Nova"), "username mention")
assert(ChatRules.mentions("@nova gg", "NovaSmith", "Nova"), "display-name mention, any case")
assert(ChatRules.mentions("thanks @Nova!", "NovaSmith", "Nova"), "punctuation ends a mention")
assert(not ChatRules.mentions("@Novak is here", "NovaSmith", "Nova"), "a longer name is not a mention")
assert(not ChatRules.mentions("mail@nova.com", "NovaSmith", "Nova"), "an email address is not a mention")
assert(not ChatRules.mentions("Nova without the at", "NovaSmith", "Nova") and not ChatRules.mentions(nil, "a", "b"), "plain text")
assert(ChatRules.clock(nil) == "" and #ChatRules.clock(0) == 5, "message clock")

-- sent-message recall
do
	local history = {}
	ChatRules.remember(history, "  hello  ")
	ChatRules.remember(history, "hello")
	ChatRules.remember(history, "   ")
	ChatRules.remember(history, nil)
	ChatRules.remember(history, "/w nova gg")
	assert(#history == 2 and history[1] == "/w nova gg" and history[2] == "hello", "newest first, trimmed, no repeats or blanks")
	local index, text = ChatRules.recall(history, 0, 1)
	assert(index == 1 and text == "/w nova gg", "Up recalls the last message")
	index, text = ChatRules.recall(history, index, 1)
	assert(index == 2 and text == "hello", "Up again goes further back")
	index, text = ChatRules.recall(history, index, 1)
	assert(index == 2 and text == "hello", "Up stops at the oldest")
	index, text = ChatRules.recall(history, index, -1)
	index, text = ChatRules.recall(history, index, -1)
	assert(index == 0 and text == "", "Down returns to the draft")
	assert(select(1, ChatRules.recall({}, 0, 1)) == 0, "nothing to recall")
	for n = 1, 30 do ChatRules.remember(history, "m" .. n) end
	assert(#history == ChatRules.RECALL_LIMIT and history[1] == "m30", "history is capped")
end
local socialSource = require("@lune/fs").readFile("src/Client/AstralForge/pages/PagesSocial.luau")
assert(socialSource:find("ChatRules.remember(sentHistory.current, outgoing)", 1, true), "sending remembers the message")
assert(socialSource:find("ChatRules.recall(sentHistory.current, recallIndex.current, direction)", 1, true), "Up/Down recall is wired")
assert(socialSource:find("recallDraft.current = box.Text", 1, true), "the unsent draft is kept while recalling")
-- keyboard shortcuts: "/" opens chat focused, Tab toggles the player list, never while typing
do
	local shell = require("@lune/fs").readFile("src/Client/AstralForge/UiCore.luau")
	local bind = assert(shell:find('local actionName = "AstralForgeKeyboard"', 1, true), "keyboard binding exists")
	local body = shell:sub(bind, bind + 1600)
	assert(body:find("UserInputService:GetFocusedTextBox() ~= nil then", 1, true), "shortcuts pass while a text box has focus")
	assert(body:find('navigateRef.current("Chat")', 1, true) and body:find("requestChatFocus()", 1, true), "/ opens chat and asks for focus")
	assert(body:find("Enum.KeyCode.Slash, Enum.KeyCode.Tab)", 1, true), "both keys are bound")
	local runtime = require("@lune/fs").readFile("src/Client/AstralForge/ClientRuntime.luau")
	assert(runtime:find("setFocusRequest(os.clock())", 1, true), "focus requests are timestamped")
	assert(socialSource:find("os.clock() - requested > 1", 1, true), "a stale focus request is ignored")
	assert(socialSource:find('if box.Text == "/" then', 1, true), "the slash that opened chat is not left in the box")
end

print("verify_chat_rules: ok")
