import pathlib

path = pathlib.Path("src/Server/AstralForge/Services/ServerServices.luau")
text = path.read_text(encoding="utf-8")

anchor = "\tfunction GameService:_guildAction(player: Player, action: string, payload: any)"
assert anchor in text, "anchor not found"

insert_before = "\tfunction GameService:_resolvePlayerName(userId: number): string"
assert insert_before in text, "insert point not found"

block = """\t-- Guild community actions. These are kept server-authoritative and filtered where
\t-- player-generated text is involved. They are intentionally separate from the
\t-- core guild lifecycle actions above so membership/role gating stays explicit.
\tif action == Protocol.Actions.SendGuildChat
\t\tor action == Protocol.Actions.CreateGuildAnnouncement
\t\tor action == Protocol.Actions.EditGuildAnnouncement
\t\tor action == Protocol.Actions.PinGuildAnnouncement
\t\tor action == Protocol.Actions.ArchiveGuildAnnouncement
\t\tor action == Protocol.Actions.SetGuildAnnouncementExpiry
\t\tor action == Protocol.Actions.MuteGuildMember
\t\tor action == Protocol.Actions.UnmuteGuildMember
\t\tor action == Protocol.Actions.BanGuildMember
\t\tor action == Protocol.Actions.UnbanGuildMember
\t\tor action == Protocol.Actions.UploadGuildLogo
\t\tor action == Protocol.Actions.ModerateGuildLogo
\tthen
\t\tlocal profile = self._data:Get(player)
\t\tif not profile then
\t\t\treturn responseError("Your profile is not ready. Please try again.")
\t\tend

\t\tif action == Protocol.Actions.SendGuildChat then
\t\t\tlocal guildId = profile.Guild and profile.Guild.Id or ""
\t\t\tif guildId == "" then
\t\t\t\treturn responseError("You are not in a guild.")
\t\t\tend

\t\t\tlocal content = type(payload.Content) == "string" and payload.Content or ""
\t\t\tif #content < 1 or #content > 1000 then
\t\t\t\treturn responseError("Guild chat messages must be between 1 and 1000 characters.")
\t\t\tend

\t\t\tlocal guild = self._guilds:GetCachedPublic(guildId)
\t\t\tif not guild then
\t\t\t\treturn responseError("Your guild records are unavailable. Try again shortly.")
\t\t\tend

\t\t\tlocal role = profile.Guild and profile.Guild.Role or ""
\t\t\tif not self._guilds:HasRole(guild, profile.UserId, role) then
\t\t\t\treturn responseError("You do not have permission to chat in this guild.")
\t\t\tend

\t\t\tif GuildCommunity:IsGuildMemberMuted(guildId, profile.UserId) then
\t\t\t\treturn responseError("You are muted in this guild.")
\t\t\tend

\t\t\tlocal filteredOk, filtered = self._security.Filter:Apply(player, content, profile.UserId, 1000)
\t\t\tif not filteredOk or type(filtered) ~= "string" or #filtered < 1 then
\t\t\t\treturn responseError("That message could not be checked. Please try different wording.")
\t\t\tend

\t\t\tlocal now = os.time()
\t\t\tlocal message = {
\t\t\t\tId = HttpService:GenerateGUID(false),
\t\t\t\tSpeakerUserId = profile.UserId,
\t\t\t\tSpeakerRole = role,
\t\t\t\tPublishedAt = now,
\t\t\t\tMessage = filtered,
\t\t\t}
\t\t\tGuildCommunity:AddChatMessage(guildId, message)

\t\t\tlocal online = {}
\t\t\tfor _, other in Players:GetPlayers() do
\t\t\t\tlocal otherProfile = self._data:Get(other)
\t\t\t\tif otherProfile and otherProfile.Guild and otherProfile.Guild.Id == guildId then
\t\t\t\t\ttable.insert(online, other)
\t\t\t\tend
\t\t\tend

\t\t\tfor _, other in online do
\t\t\t\tself._effect:FireClient(other, {
\t\t\t\t\tType = "GuildChat",
\t\t\t\t\tGuildId = guildId,
\t\t\t\t\tMessage = message,
\t\t\t\t})
\t\t\tend

\t\t\treturn responseSuccess("Guild message sent.", {
\t\t\t\tMessage = message,
\t\t\t})
\t\tend

\t\tif action == Protocol.Actions.CreateGuildAnnouncement
\t\t\tor action == Protocol.Actions.EditGuildAnnouncement
\t\t\tor action == Protocol.Actions.PinGuildAnnouncement
\t\t\tor action == Protocol.Actions.ArchiveGuildAnnouncement
\t\t\tor action == Protocol.Actions.SetGuildAnnouncementExpiry
\t\tthen
\t\t\tlocal guildId = profile.Guild and profile.Guild.Id or ""
\t\t\tif guildId == "" then
\t\t\t\treturn responseError("You are not in a guild.")
\t\t\tend

\t\t\tlocal guild = self._guilds:GetCachedPublic(guildId)
\t\t\tif not guild then
\t\t\t\treturn responseError("Your guild records are unavailable. Try again shortly.")
\t\t\tend

\t\t\tlocal role = profile.Guild and profile.Guild.Role or ""
\t\t\tif not self._guilds:HasRole(guild, profile.UserId, role) then
\t\t\t\treturn responseError("You do not have permission to manage guild announcements.")
\t\t\tend

\t\t\tlocal announcementId = type(payload.AnnouncementId) == "string" and payload.AnnouncementId or ""
\t\t\tif action ~= Protocol.Actions.CreateGuildAnnouncement and announcementId == "" then
\t\t\t\treturn responseError("Announcement id is required.")
\t\t\tend

\t\t\tlocal title = type(payload.Title) == "string" and payload.Title or ""
\t\t\tlocal body = type(payload.Body) == "string" and payload.Body or ""

\t\t\tif action == Protocol.Actions.CreateGuildAnnouncement then
\t\t\t\tif #title < 1 or #title > 120 then
\t\t\t\t\treturn responseError("Announcement title must be between 1 and 120 characters.")
\t\t\t\tend
\t\t\t\tif #body < 1 or #body > 4000 then
\t\t\t\t\treturn responseError("Announcement body must be between 1 and 4000 characters.")
\t\t\t\tend

\t\t\t\tlocal filteredTitle = title
\t\t\t\tlocal filteredBody = body
\t\t\t\tif self._security.Filter then
\t\t\t\t\tlocal ok1, f1 = self._security.Filter:Apply(player, title, profile.UserId, 120)
\t\t\t\t\tif ok1 and type(f1) == "string" then
\t\t\t\t\t\tfilteredTitle = f1
\t\t\t\t\tend
\t\t\t\t\tlocal ok2, f2 = self._security.Filter:Apply(player, body, profile.UserId, 4000)
\t\t\t\t\tif ok2 and type(f2) == "string" then
\t\t\t\t\t\tfilteredBody = f2
\t\t\t\t\tend
\t\t\t\tend

\t\t\t\tlocal announcement = {
\t\t\t\t\tId = HttpService:GenerateGUID(false),
\t\t\t\t\tAuthorUserId = profile.UserId,
\t\t\t\t\tAuthorRole = role,
\t\t\t\t\tPublishedAt = os.time(),
\t\t\t\t\tEditedAt = nil,
\t\t\t\t\tPinned = false,
\t\t\t\t\tArchived = false,
\t\t\t\t\tExpiresAt = nil,
\t\t\t\t\tTitle = filteredTitle,
\t\t\t\t\tBody = filteredBody,
\t\t\t\t}
\t\t\t\tGuildCommunity:AddAnnouncement(guildId, announcement)
\t\t\t\tself._effect:FireClient(player, {
\t\t\t\t\tType = "GuildAnnouncement",
\t\t\t\t\tGuildId = guildId,
\t\t\t\t\tAction = "Created",
\t\t\t\t\tAnnouncement = announcement,
\t\t\t\t})
\t\t\t\tfor _, other in Players:GetPlayers() do
\t\t\t\t\tif other ~= player then
\t\t\t\t\t\tlocal otherProfile = self._data:Get(other)
\t\t\t\t\t\tif otherProfile and otherProfile.Guild and otherProfile.Guild.Id == guildId then
\t\t\t\t\t\t\tself._effect:FireClient(other, {
\t\t\t\t\t\t\t\tType = "GuildAnnouncement",
\t\t\t\t\t\t\t\tGuildId = guildId,
\t\t\t\t\t\t\t\tAction = "Created",
\t\t\t\t\t\t\t\tAnnouncement = announcement,
\t\t\t\t\t\t\t})
\t\t\t\t\t\tend
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\treturn responseSuccess("Guild announcement published.", { Announcement = announcement })
\t\t\tend

\t\t\tif action == Protocol.Actions.EditGuildAnnouncement then
\t\t\t\tlocal existing = GuildCommunity:GetAnnouncements(guildId)
\t\t\t\tlocal announcement = nil
\t\t\t\tfor _, entry in existing do
\t\t\t\t\tif entry.Id == announcementId then
\t\t\t\t\t\tannouncement = entry
\t\t\t\t\t\tbreak
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\tif not announcement then
\t\t\t\t\treturn responseError("Announcement not found.")
\t\t\t\tend
\t\t\t\tif #title < 1 or #title > 120 then
\t\t\t\t\treturn responseError("Announcement title must be between 1 and 120 characters.")
\t\t\t\tend
\t\t\t\tif #body < 1 or #body > 4000 then
\t\t\t\t\treturn responseError("Announcement body must be between 1 and 4000 characters.")
\t\t\t\tend

\t\t\t\tlocal filteredTitle = title
\t\t\t\tlocal filteredBody = body
\t\t\t\tif self._security.Filter then
\t\t\t\t\tlocal ok1, f1 = self._security.Filter:Apply(player, title, profile.UserId, 120)
\t\t\t\t\tif ok1 and type(f1) == "string" then
\t\t\t\t\t\tfilteredTitle = f1
\t\t\t\t\tend
\t\t\t\t\tlocal ok2, f2 = self._security.Filter:Apply(player, body, profile.UserId, 4000)
\t\t\t\t\tif ok2 and type(f2) == "string" then
\t\t\t\t\t\tfilteredBody = f2
\t\t\t\t\tend
\t\t\t\tend

\t\t\t\tannouncement.Title = filteredTitle
\t\t\t\tannouncement.Body = filteredBody
\t\t\t\tannouncement.EditedAt = os.time()
\t\t\t\tGuildCommunity:SetAnnouncementPinned(guildId, announcementId, announcement.Pinned)
\t\t\t\tGuildCommunity:SetAnnouncementExpiry(guildId, announcementId, announcement.ExpiresAt)
\t\t\t\tself._effect:FireClient(player, {
\t\t\t\t\tType = "GuildAnnouncement",
\t\t\t\t\tGuildId = guildId,
\t\t\t\t\tAction = "Edited",
\t\t\t\t\tAnnouncement = announcement,
\t\t\t\t})
\t\t\t\tfor _, other in Players:GetPlayers() do
\t\t\t\t\tif other ~= player then
\t\t\t\t\t\tlocal otherProfile = self._data:Get(other)
\t\t\t\t\t\tif otherProfile and otherProfile.Guild and otherProfile.Guild.Id == guildId then
\t\t\t\t\t\t\tself._effect:FireClient(other, {
\t\t\t\t\t\t\t\tType = "GuildAnnouncement",
\t\t\t\t\t\t\t\tGuildId = guildId,
\t\t\t\t\t\t\t\tAction = "Edited",
\t\t\t\t\t\t\t\tAnnouncement = announcement,
\t\t\t\t\t\t\t})
\t\t\t\t\t\tend
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\treturn responseSuccess("Guild announcement updated.", { Announcement = announcement })
\t\t\tend

\t\t\tif action == Protocol.Actions.PinGuildAnnouncement then
\t\t\t\tlocal existing = GuildCommunity:GetAnnouncements(guildId)
\t\t\t\tlocal announcement = nil
\t\t\t\tfor _, entry in existing do
\t\t\t\t\tif entry.Id == announcementId then
\t\t\t\t\t\tannouncement = entry
\t\t\t\t\t\tbreak
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\tif not announcement then
\t\t\t\t\treturn responseError("Announcement not found.")
\t\t\t\tend
\t\t\t\tGuildCommunity:SetAnnouncementPinned(guildId, announcementId, true)
\t\t\t\tannouncement.Pinned = true
\t\t\t\tself._effect:FireClient(player, {
\t\t\t\t\tType = "GuildAnnouncement",
\t\t\t\t\tGuildId = guildId,
\t\t\t\t\tAction = "Pinned",
\t\t\t\t\tAnnouncement = announcement,
\t\t\t\t})
\t\t\t\tfor _, other in Players:GetPlayers() do
\t\t\t\t\tif other ~= player then
\t\t\t\t\t\tlocal otherProfile = self._data:Get(other)
\t\t\t\t\t\tif otherProfile and otherProfile.Guild and otherProfile.Guild.Id == guildId then
\t\t\t\t\t\t\tself._effect:FireClient(other, {
\t\t\t\t\t\t\t\tType = "GuildAnnouncement",
\t\t\t\t\t\t\t\tGuildId = guildId,
\t\t\t\t\t\t\t\tAction = "Pinned",
\t\t\t\t\t\t\t\tAnnouncement = announcement,
\t\t\t\t\t\t\t})
\t\t\t\t\t\tend
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\treturn responseSuccess("Announcement pinned.", { Announcement = announcement })
\t\t\tend

\t\t\tif action == Protocol.Actions.ArchiveGuildAnnouncement then
\t\t\t\tlocal existing = GuildCommunity:GetAnnouncements(guildId)
\t\t\t\tlocal announcement = nil
\t\t\t\tfor _, entry in existing do
\t\t\t\t\tif entry.Id == announcementId then
\t\t\t\t\t\tannouncement = entry
\t\t\t\t\t\tbreak
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\tif not announcement then
\t\t\t\t\treturn responseError("Announcement not found.")
\t\t\t\tend
\t\t\t\tGuildCommunity:ArchiveAnnouncement(guildId, announcementId)
\t\t\t\tannouncement.Archived = true
\t\t\t\tself._effect:FireClient(player, {
\t\t\t\t\tType = "GuildAnnouncement",
\t\t\t\t\tGuildId = guildId,
\t\t\t\t\tAction = "Archived",
\t\t\t\t\tAnnouncement = announcement,
\t\t\t\t})
\t\t\t\tfor _, other in Players:GetPlayers() do
\t\t\t\t\tif other ~= player then
\t\t\t\t\t\tlocal otherProfile = self._data:Get(other)
\t\t\t\t\t\tif otherProfile and otherProfile.Guild and otherProfile.Guild.Id == guildId then
\t\t\t\t\t\t\tself._effect:FireClient(other, {
\t\t\t\t\t\t\t\tType = "GuildAnnouncement",
\t\t\t\t\t\t\t\tGuildId = guildId,
\t\t\t\t\t\t\t\tAction = "Archived",
\t\t\t\t\t\t\t\tAnnouncement = announcement,
\t\t\t\t\t\t\t})
\t\t\t\t\t\tend
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\treturn responseSuccess("Announcement archived.", { Announcement = announcement })
\t\t\tend

\t\t\tif action == Protocol.Actions.SetGuildAnnouncementExpiry then
\t\t\t\tlocal existing = GuildCommunity:GetAnnouncements(guildId)
\t\t\t\tlocal announcement = nil
\t\t\t\tfor _, entry in existing do
\t\t\t\t\tif entry.Id == announcementId then
\t\t\t\t\t\tannouncement = entry
\t\t\t\t\t\tbreak
\t\t\t\t\tend
\t\t\t\tend
\t\t\t\tif not announcement then
\t\t\t\t\treturn responseError("Announcement not found.")
\t\t\t\tend
\t\t\t\tlocal expiresAt = payload.ExpiresAt
\t\t\t\tif expiresAt ~= nil and type(expiresAt) ~= "number" then
\t\t\t\t\texpiresAt = nil
\t\t\t\tend
\t\t\t\tif expiresAt and expiresAt <= os.time() then
\t\t\t\t\texpiresAt = nil
\t\t\t\tend
\t\t\t\tGuildCommunity:SetAnnouncementExpiry(guildId, announcementId, expiresAt)
\t\t\t\tannouncement.ExpiresAt = expiresAt
\t\t\t\tself._effect:FireClient(player, {
\t\t\t\t\tType = "GuildAnnouncement",
\t\t\t\t\tGuildId = guildId,
\t\t\t\t\tAction = "ExpiryChanged",
\t\t\t\t\tAnnouncement = announcement,
\t\t\t\t})
\t\t\t\treturn responseSuccess("Announcement expiry updated.", { Announcement = announcement })
\t\t\tend
\t\tend

\t\tif action == Protocol.Actions.MuteGuildMember or action == Protocol.Actions.UnmuteGuildMember then
\t\t\tlocal guildId = profile.Guild and profile.Guild.Id or ""
\t\t\tif guildId == "" then
\t\t\t\treturn responseError("You are not in a guild.")
\t\t\tend

\t\t\tlocal guild = self._guilds:GetCachedPublic(guildId)
\t\t\tif not guild then
\t\t\t\treturn responseError("Your guild records are unavailable. Try again shortly.")
\t\t\tend

\t\t\tlocal role = profile.Guild and profile.Guild.Role or ""
\t\t\tif not self._guilds:HasRole(guild, profile.UserId, role) then
\t\t\t\treturn responseError("You do not have permission to moderate this guild.")
\t\t\tend

\t\t\tlocal targetUserId = tonumber(payload.UserId)
\t\t\tif not targetUserId or targetUserId <= 0 then
\t\t\t\treturn responseError("Target user id is required.")
\t\t\tend

\t\t\tif targetUserId == profile.UserId then
\t\t\t\treturn responseError("You cannot moderate yourself.")
\t\t\tend

\t\t\tif action == Protocol.Actions.MuteGuildMember then
\t\t\t\tlocal ok = GuildCommunity:SetGuildMute(guildId, targetUserId, true, profile.UserId, role)
\t\t\t\tif not ok then
\t\t\t\t\treturn responseError("Failed to mute guild member.")
\t\t\t\tend
\t\t\t\tself._effect:FireClient(player, {
\t\t\t\t\tType = "GuildModeration",
\t\t\t\t\tGuildId = guildId,
\t\t\t\t\tAction = "Muted",
\t\t\t\t\tTargetUserId = targetUserId,
\t\t\t\t})
\t\t\t\treturn responseSuccess("Guild member muted.")
\t\t\tend

\t\t\tif action == Protocol.Actions.UnmuteGuildMember then
\t\t\t\tlocal ok = GuildCommunity:SetGuildMute(guildId, targetUserId, false, profile.UserId, role)
\t\t\t\tif not ok then
\t\t\t\t\treturn responseError("Failed to unmute guild member.")
\t\t\t\tend
\t\t\t\tself._effect:FireClient(player, {
\t\t\t\t\tType = "GuildModeration",
\t\t\t\t\tGuildId = guildId,
\t\t\t\t\tAction = "Unmuted",
\t\t\t\t\tTargetUserId = targetUserId,
\t\t\t\t})
\t\t\t\treturn responseSuccess("Guild member unmuted.")
\t\t\tend
\t\tend

\t\tif action == Protocol.Actions.BanGuildMember or action == Protocol.Actions.UnbanGuildMember then
\t\t\tlocal guildId = profile.Guild and profile.Guild.Id or ""
\t\t\tif guildId == "" then
\t\t\t\treturn responseError("You are not in a guild.")
\t\t\tend

\t\t\tlocal guild = self._guilds:GetCachedPublic(guildId)
\t\t\tif not guild then
\t\t\t\treturn responseError("Your guild records are unavailable. Try again shortly.")
\t\t\tend

\t\t\tlocal role = profile.Guild and profile.Guild.Role or ""
\t\t\tif not self._guilds:HasRole(guild, profile.UserId, role) then
\t\t\t\treturn responseError("You do not have permission to moderate this guild.")
\t\t\tend

\t\t\tlocal targetUserId = tonumber(payload.UserId)
\t\t\tif not targetUserId or targetUserId <= 0 then
\t\t\t\treturn responseError("Target user id is required.")
\t\t\tend

\t\t\tif targetUserId == profile.UserId then
\t\t\t\treturn responseError("You cannot moderate yourself.")
\t\t\tend

\t\t\tif action == Protocol.Actions.BanGuildMember then
\t\t\t\tlocal target = Players:GetPlayerByUserId(targetUserId)
\t\t\t\tif target then
\t\t\t\t\ttarget:Kick("You have been banned from this guild.")
\t\t\t\tend
\t\t\t\tif GuildCommunity:SetGuildMute(guildId, targetUserId, true, profile.UserId, role) then
\t\t\t\t\tself._effect:FireClient(player, {
\t\t\t\t\t\tType = "GuildModeration",
\t\t\t\t\t\tGuildId = guildId,
\t\t\t\t\t\tAction = "Banned",
\t\t\t\t\t\tTargetUserId = targetUserId,
\t\t\t\t\t})
\t\t\t\t\treturn responseSuccess("Guild member banned.")
\t\t\t\tend
\t\t\t\treturn responseError("Failed to ban guild member.")
\t\t\tend

\t\t\tif action == Protocol.Actions.UnbanGuildMember then
\t\t\t\tif GuildCommunity:SetGuildMute(guildId, targetUserId, false, profile.UserId, role) then
\t\t\t\t\tself._effect:FireClient(player, {
\t\t\t\t\t\tType = "GuildModeration",
\t\t\t\t\t\tGuildId = guildId,
\t\t\t\t\t\tAction = "Unbanned",
\t\t\t\t\t\tTargetUserId = targetUserId,
\t\t\t\t\t})
\t\t\t\t\treturn responseSuccess("Guild member unbanned.")
\t\t\t\tend
\t\t\t\treturn responseError("Failed to unban guild member.")
\t\t\tend
\t\tend

\t\tif action == Protocol.Actions.UploadGuildLogo then
\t\t\tlocal guildId = profile.Guild and profile.Guild.Id or ""
\t\t\tif guildId == "" then
\t\t\t\treturn responseError("You are not in a guild.")
\t\t\tend

\t\t\tlocal guild = self._guilds:GetCachedPublic(guildId)
\t\t\tif not guild then
\t\t\t\treturn responseError("Your guild records are unavailable. Try again shortly.")
\t\t\tend

\t\t\tlocal role = profile.Guild and profile.Guild.Role or ""
\t\t\tif not self._guilds:HasRole(guild, profile.UserId, role) then
\t\t\t\treturn responseError("You do not have permission to upload a guild logo.")
\t\t\tend

\t\t\tlocal url = type(payload.URL) == "string" and payload.URL or ""
\t\t\tif #url < 1 or #url > 1024 then
\t\t\t\treturn responseError("Logo URL must be between 1 and 1024 characters.")
\t\t\tend

\t\t\tlocal logo = {
\t\t\t\tId = HttpService:GenerateGUID(false),
\t\t\t\tUploadedBy = profile.UserId,
\t\t\t\tUploadedAt = os.time(),
\t\t\t\tStatus = "pending",
\t\t\t\tURL = url,
\t\t\t\tRejectReason = nil,
\t\t\t}
\t\t\tGuildCommunity:AddLogo(guildId, logo)
\t\t\tself._effect:FireClient(player, {
\t\t\t\tType = "GuildLogo",
\t\t\t\tGuildId = guildId,
\t\t\t\tAction = "Uploaded",
\t\t\t\tLogo = logo,
\t\t\t})
\t\t\treturn responseSuccess("Guild logo submitted for review.", { Logo = logo })
\t\tend

\t\tif action == Protocol.Actions.ModerateGuildLogo then
\t\t\tlocal guildId = profile.Guild and profile.Guild.Id or ""
\t\t\tif guildId == "" then
\t\t\t\treturn responseError("You are not in a guild.")
\t\t\tend

\t\t\tlocal guild = self._guilds:GetCachedPublic(guildId)
\t\t\tif not guild then
\t\t\t\treturn responseError("Your guild records are unavailable. Try again shortly.")
\t\t\tend

\t\t\tlocal role = profile.Guild and profile.Guild.Role or ""
\t\t\tif not self._guilds:HasRole(guild, profile.UserId, role) then
\t\t\t\treturn responseError("You do not have permission to moderate guild logos.")
\t\t\tend

\t\t\tlocal logoId = type(payload.LogoId) == "string" and payload.LogoId or ""
\t\t\tif #logoId < 1 then
\t\t\t\treturn responseError("Logo id is required.")
\t\t\tend

\t\t\tlocal decision = payload.Decision
\t\t\tif decision ~= "approved" and decision ~= "rejected" then
\t\t\t\treturn responseError("Logo decision must be approved or rejected.")
\t\t\tend

\t\t\tlocal reason = type(payload.Reason) == "string" and payload.Reason or nil
\t\t\tif decision == "rejected" and (reason == nil or #reason < 1 or #reason > 500) then
\t\t\t\treturn responseError("A rejection reason is required and must be between 1 and 500 characters.")
\t\t\tend

\t\t\tlocal ok = GuildCommunity:SetLogoStatus(guildId, logoId, decision, reason)
\t\t\tif not ok then
\t\t\t\treturn responseError("Logo not found.")
\t\t\tend

\t\t\tself._effect:FireClient(player, {
\t\t\t\tType = "GuildLogo",
\t\t\t\tGuildId = guildId,
\t\t\t\tAction = "Moderated",
\t\t\t\tLogoId = logoId,
\t\t\t\tDecision = decision,
\t\t\t})
\t\t\tfor _, other in Players:GetPlayers() do
\t\t\t\tif other ~= player then
\t\t\t\t\tlocal otherProfile = self._data:Get(other)
\t\t\t\t\tif otherProfile and otherProfile.Guild and otherProfile.Guild.Id == guildId then
\t\t\t\t\t\tself._effect:FireClient(other, {
\t\t\t\t\t\t\tType = "GuildLogo",
\t\t\t\t\t\t\tGuildId = guildId,
\t\t\t\t\t\t\tAction = "Moderated",
\t\t\t\t\t\t\tLogoId = logoId,
\t\t\t\t\t\t\tDecision = decision,
\t\t\t\t\t\t})
\t\t\t\t\tend
\t\t\t\tend
\t\t\tend
\t\t\treturn responseSuccess("Guild logo moderated.", {
\t\t\t\tLogoId = logoId,
\t\t\t\tDecision = decision,
\t\t\t})
\t\tend

\t\treturn responseError("Unknown guild community action.")
\tend

"""

idx = text.find(insert_before)
after = text[:idx] + block + text[idx:]

assert anchor in after
assert insert_before in after

path.write_text(after, encoding="utf-8")
print(f"inserted guild community actions before line containing {insert_before!r}")
print(f"new file bytes: {len(after)}")
