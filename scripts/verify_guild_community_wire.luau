local fs = require("./_memberfs")(require("@lune/fs"))

local protocol = fs.readFile("src/Shared/AstralForge/Shared/Protocol.luau")
local firewall = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local guildService = fs.readFile("src/Server/AstralForge/Services/CoreServices.luau")
local community = fs.readFile("src/Server/AstralForge/Services/GuildCommunity.luau")
local validators = fs.readFile("src/Server/AstralForge/Modules/ProfileMath.luau")
local client = fs.readFile("src/Client/AstralForge/CoreKit.luau#session")
local guildPage = fs.readFile("src/Client/AstralForge/pages/PagesSocial.luau#GuildView")
local panel = fs.readFile("src/Client/AstralForge/pages/GuildCommunityPanel.luau")

local actions = {
	"SendGuildChat",
	"GetGuildChatHistory",
	"GetGuildAnnouncements",
	"GetGuildSettings",
	"SetGuildSettings",
	"GetGuildLogoReview",
	"CreateGuildAnnouncement",
	"EditGuildAnnouncement",
	"PinGuildAnnouncement",
	"ArchiveGuildAnnouncement",
	"SetGuildAnnouncementExpiry",
	"MuteGuildMember",
	"UnmuteGuildMember",
	"BanGuildMember",
	"UnbanGuildMember",
	"UploadGuildLogo",
	"ModerateGuildLogo",
	"RenameGuild",
}

local readOnly = {
	GetGuildChatHistory = true,
	GetGuildAnnouncements = true,
	GetGuildSettings = true,
	GetGuildLogoReview = true,
}

local function contains(source, value, message)
	assert(string.find(source, value, 1, true), message)
end

for _, action in actions do
	contains(protocol, action .. ' = "' .. action .. '"', "Protocol missing " .. action)
	contains(firewall, "Protocol.Actions." .. action, "RemoteFirewall missing rate or payload guard for " .. action)
	contains(server, "Protocol.Actions." .. action, "Server dispatcher missing " .. action)
	if readOnly[action] then
		contains(validators, action .. " = true", "Server read-only policy missing " .. action)
	else
		contains(client, '["' .. action .. '"] = true', "Client session grants missing " .. action)
	end
end

contains(community, "self._security.Filter:Apply", "Guild messages must be platform-filtered before saving")
contains(community, "self._store:UpdateAsync", "Guild community records must persist atomically")
contains(community, "MessagingService:SubscribeAsync", "Guild changes must be forwarded to subscribed servers")
contains(community, "MessagingService:PublishAsync", "Guild changes must be published across servers")
contains(community, "MAX_GUILD_SUBSCRIPTIONS", "Guild subscriptions must be bounded")
contains(community, "#encoded > 900", "Cross-server messages must stay below Roblox's size limit")
contains(community, "SpeakerUserId", "Guild chat must preserve author identity")
contains(community, "AnnouncementsEnabled", "Guild announcement settings missing")
contains(community, "LogoEnabled", "Guild logo settings missing")
contains(guildService, "function GuildService:Rename", "Guild rename service missing")
contains(server, "filter:Apply", "New guild names and renames must be broadcast-filtered before saving")
contains(guildPage, '"Community"', "Guild page must expose a Community tab")
contains(guildPage, '"GuildCommunityPanel"', "Guild page must route to community panel")
contains(panel, "SendGuildChat", "Guild chat composer missing")
contains(panel, "CreateGuildAnnouncement", "Guild announcements UI missing")
contains(panel, "UploadGuildLogo", "Guild logo submission UI missing")
contains(panel, "RenameGuild", "Leader guild rename UI missing")

print(
	"[TEST] guild community routes, auth, filtering, persistence, chat, announcements, logo workflow and rename parity passed"
)
