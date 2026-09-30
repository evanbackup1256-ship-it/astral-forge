--!strict
-- Source-level gates for the server audit fixes (GuildService / WorldService).
-- Mirrors the repo's other verify scripts: these services need Roblox APIs, so the
-- behaviours are pinned by the exact guards that implement them.

local fs = require("./_memberfs")(require("@lune/fs"))

local guildSrc = fs.readFile("src/Server/AstralForge/Services/CoreServices.luau#GuildService")
local worldSrc = fs.readFile("src/Server/AstralForge/Services/WorldServices.luau#WorldService")
local oreSrc = fs.readFile("src/Server/AstralForge/Services/WorldServices.luau#OreService")

local function has(src: string, needle: string, message: string)
	assert(string.find(src, needle, 1, true), message)
end
local function lacks(src: string, needle: string, message: string)
	assert(not string.find(src, needle, 1, true), message)
end

-- Disband: releasing the tag must RemoveAsync (UpdateAsync returning nil cancels the write),
-- after a fresh (uncached) read of both the guild and the tag reservation.
has(guildSrc, 'self._store:RemoveAsync("tag:" .. tag)', "Disband must release the tag with RemoveAsync")
has(guildSrc, 'self._store:GetAsync("tag:" .. tag) == guildId', "Disband must re-read the tag before removing it")
lacks(guildSrc, "if existing == guildId then return nil end", "Disband must not release the tag via a nil UpdateAsync transform")
has(guildSrc, "self._cache[guildId] = nil\n\t\tself._cacheExpiry[guildId] = nil\n\t\tlocal guild = self:_read(guildId)", "Disband must drop the cache before its fresh read")

-- Kick: an Officer must not be able to kick another Officer.
has(guildSrc, 'if actor.Role == "Officer" and target.Role == "Officer" then return nil end', "Kick must block Officer kicking Officer")

-- Closure flags are reset at the top of every UpdateAsync transform (transforms can retry).
has(guildSrc, "documentCreated = false\n\t\t\t\tif existing ~= nil", "Create doc transform must reset documentCreated")
has(guildSrc, "tagClaimed = false\n\t\t\t\tif existing == nil", "Create tag transform must reset tagClaimed")
has(guildSrc, "blockedFull = false\n\t\t\tlocal key", "JoinByTag transform must reset blockedFull")
has(guildSrc, "blockedLastMember = false\n\t\t\tlocal key", "Leave transform must reset blockedLastMember")
has(guildSrc, "failure = nil\n\t\t\trewardTypeId = nil", "ClaimGoal transform must reset failure/rewardTypeId")

-- Create / JoinByTag reject non-string name/tag before any string method runs.
has(guildSrc, 'type(rawName) ~= "string" or type(rawTag) ~= "string"', "Create must type-check name and tag")
has(guildSrc, 'if type(rawTag) ~= "string" then return false, "No guild has that tag." end', "JoinByTag must type-check tag")

-- WorldService clears the travel cooldown entry when a player leaves.
has(worldSrc, "if self._travelAt then self._travelAt[player] = nil end", "WorldService must clear _travelAt on PlayerRemoving")

-- OreService reserves the node cooldown before mutate() can yield (no double-mine race).
has(oreSrc, "cooldowns[nodeId] = nextReady\n\tlocal result = self._host:mutate(player", "Mine must reserve the node cooldown before yielding")
has(oreSrc, "cooldowns[nodeId] = readyAt\n\t\treturn", "a failed mine must restore the previous cooldown")

-- CharacterIntegrity stays dormant: nothing here may flip CharacterAutoLoads.
lacks(worldSrc, "CharacterAutoLoads = true", "CharacterAutoLoads must stay false")

print("verify_server_audit_fixes: ok")
