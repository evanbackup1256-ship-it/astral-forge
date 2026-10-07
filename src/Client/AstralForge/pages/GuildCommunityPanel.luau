--!nonstrict

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Palette = require(script.Parent.Parent.CoreKit)("theme").Palette
local scrollTail = require(script.Parent.Parent.CoreKit)("theme").scrollTail
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local ui = require(script.Parent.Parent.UiCore)("ui")
local Button = ui.Button
local Panel = ui.Panel
local SectionLabel = ui.SectionLabel
local Text = ui.Text
local function GuildCommunityPanel(_param)
	local guild = _param.guild
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local role = _param.role
	local onBack = _param.onBack
	local community = guild.Community or {}
	local settings, setSettings =
		React.useState(community.Settings or { ChatEnabled = true, AnnouncementsEnabled = true, LogoEnabled = true })
	local messages, setMessages = React.useState(community.Chat or {})
	local announcements, setAnnouncements = React.useState(community.Announcements or {})
	local logos, setLogos = React.useState({})
	local chatDraft, setChatDraft = React.useState("")
	local announcementTitle, setAnnouncementTitle = React.useState("")
	local announcementBody, setAnnouncementBody = React.useState("")
	local logoAsset, setLogoAsset = React.useState("")
	local guildNameDraft, setGuildNameDraft = React.useState(guild.Name or "")
	local moderationUserId, setModerationUserId = React.useState("")
	local busy, setBusy = React.useState("")
	local leader = role == "Leader"
	local manager = leader or role == "Officer"
	local requestCommunity = React.useCallback(function()
		dispatch("GetGuildChatHistory", { Limit = 50 }, function(result)
			if result.ok then
				setMessages(result.Messages or {})
			end
		end)
		dispatch("GetGuildAnnouncements", {}, function(result)
			if result.ok then
				setAnnouncements(result.Announcements or {})
			end
		end)
		dispatch("GetGuildSettings", {}, function(result)
			if result.ok then
				setSettings(result.Settings or {})
			end
		end)
		if leader then
			dispatch("GetGuildLogoReview", {}, function(result)
				if result.ok then
					setLogos(result.Logos or {})
				end
			end)
		end
	end, { dispatch, manager, guild.Id })
	React.useEffect(function()
		requestCommunity()
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(8)
				if alive then
					requestCommunity()
				end
			end
		end)
		local connection = game:GetService("ReplicatedStorage")
			:WaitForChild("__AFX_BRIDGE_31")
			:WaitForChild("re_e31").OnClientEvent
			:Connect(function(packet)
				if not alive or type(packet) ~= "table" or packet.GuildId ~= guild.Id then
					return
				end
				if packet.Type == "GuildChat" and type(packet.Message) == "table" then
					setMessages(function(previous)
						local updated = table.clone(previous)
						for _, existing in updated do
							if existing.Id == packet.Message.Id then
								return previous
							end
						end
						updated[#updated + 1] = packet.Message

						while #updated > 50 do
							table.remove(updated, 1)
						end
						return updated
					end)
				elseif
					packet.Type == "GuildAnnouncement"
					or packet.Type == "GuildSettings"
					or packet.Type == "GuildLogo"
					or packet.Type == "GuildModeration"
				then
					requestCommunity()
				end
			end)
		return function()
			alive = false
			connection:Disconnect()
			pcall(task.cancel, worker)
		end
	end, { requestCommunity, guild.Id })
	local run = function(action, payload, done)
		if busy ~= "" then
			return
		end
		setBusy(action)
		dispatch(action, payload, function(result)
			setBusy("")
			if result.ok then
				requestCommunity()
			end
			if done then
				done(result)
			end
		end)
	end
	local fieldStyle = {
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		TextColor3 = Palette.cream,
		PlaceholderColor3 = Palette.muted,
		TextSize = 14,
		ClearTextOnFocus = false,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
	}
	local function input(placeholder, value, onChange, height, position, width)
		return React.createElement(
			"textbox",
			{
				Size = width or UDim2.new(1, 0, 0, height or 42),
				Position = position or UDim2.fromOffset(0, 0),
				PlaceholderText = placeholder,
				Text = value,
				TextXAlignment = Enum.TextXAlignment.Left,
				Change = {
					Text = function(box)
						onChange(string.sub(box.Text, 1, 800))
					end,
				},
				BackgroundColor3 = fieldStyle.BackgroundColor3,
				BorderSizePixel = fieldStyle.BorderSizePixel,
				TextColor3 = fieldStyle.TextColor3,
				PlaceholderColor3 = fieldStyle.PlaceholderColor3,
				TextSize = fieldStyle.TextSize,
				ClearTextOnFocus = false,
				FontFace = fieldStyle.FontFace,
			},
			React.createElement("uicorner", { CornerRadius = UDim.new(0, 10) }),
			React.createElement("uipadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
		)
	end
	local chatRows = {}
	for index = #messages, math.max(1, #messages - 4), -1 do
		local message = messages[index]
		if message then
			chatRows[#chatRows + 1] = React.createElement(Text, {
				key = message.Id,
				value = `{message.SpeakerName or tostring(message.SpeakerUserId)}  ·  {message.Message}`,
				size = 12,
				color = Palette.creamSoft,
				wrap = true,
				sizeConstraint = UDim2.new(1, 0, 0, 38),
			})
		end
	end
	if #chatRows == 0 then
		chatRows[1] = React.createElement(Text, {
			key = "no-chat",
			value = "No messages yet. Chat is visible only to this guild's members.",
			size = 12,
			color = Palette.muted,
			wrap = true,
			sizeConstraint = UDim2.new(1, 0, 0, 34),
		})
	end
	local announcementRows = {}
	for index, item in announcements do
		local label = `{if item.Pinned then "[PINNED] " else ""}{item.Title}  ·  {item.AuthorName or "Guild staff"}`
		announcementRows[index] = React.createElement(
			Panel,
			{
				key = item.Id,
				size = UDim2.new(1, 0, 0, 116),
				accent = item.Pinned and Palette.mango or Palette.cyan,
				padding = 12,
				reducedMotion = reducedMotion,
			},
			React.createElement(Text, {
				value = label,
				size = 13,
				weight = Enum.FontWeight.Bold,
				fit = true,
				sizeConstraint = UDim2.new(1, 0, 0, 22),
			}),
			React.createElement(Text, {
				value = item.Body,
				size = 11,
				color = Palette.creamSoft,
				wrap = true,
				position = UDim2.fromOffset(0, 28),
				sizeConstraint = UDim2.new(1, 0, 0, 52),
			}),
			manager
				and React.createElement(Button, {
					text = item.Pinned and "UNPIN" or "PIN",
					onClick = function()
						run("PinGuildAnnouncement", { AnnouncementId = item.Id, Pinned = not item.Pinned })
					end,
					color = Palette.panelSoft,
					size = UDim2.fromOffset(92, 32),
					position = UDim2.new(1, -96, 1, -32),
					disabled = busy ~= "",
					reducedMotion = reducedMotion,
				})
		)
	end
	if #announcementRows == 0 then
		announcementRows[1] = React.createElement(
			Text,
			{ key = "no-announcements", value = "No current announcements.", size = 12, color = Palette.muted }
		)
	end
	local logoRows = {}
	for index, logo in logos do
		logoRows[index] = React.createElement(
			Panel,
			{ key = logo.Id, size = UDim2.new(1, 0, 0, 84), accent = Palette.violet, padding = 10 },

			React.createElement("imagelabel", {
				Size = UDim2.fromOffset(52, 52),
				Position = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Image = logo.URL or "",
				ScaleType = Enum.ScaleType.Fit,
			}),
			React.createElement(Text, {
				value = `Logo {string.sub(logo.Id, 1, 8)} · pending`,
				size = 12,
				fit = true,
				position = UDim2.fromOffset(58, 4),
				sizeConstraint = UDim2.new(1, -220, 0, 22),
			}),

			React.createElement(Button, {
				text = "APPROVE",
				onClick = function()
					run("ModerateGuildLogo", { LogoId = logo.Id, Decision = "approved" })
				end,
				color = Palette.mint,
				size = UDim2.fromOffset(92, 34),
				position = UDim2.new(1, -196, 0, 12),
				disabled = busy ~= "",
				reducedMotion = reducedMotion,
			}),
			React.createElement(Button, {
				text = "REJECT",
				onClick = function()
					run(
						"ModerateGuildLogo",
						{ LogoId = logo.Id, Decision = "rejected", Reason = "Did not meet guild logo guidelines." }
					)
				end,
				color = Palette.panelSoft,
				textColor = Palette.coral,
				size = UDim2.fromOffset(92, 34),
				position = UDim2.new(1, -98, 0, 12),
				disabled = busy ~= "",
				reducedMotion = reducedMotion,
			})
		)
	end
	local settingsRows = {}
	if leader then
		for index, key in { "ChatEnabled", "AnnouncementsEnabled", "LogoEnabled" } do
			local title = string.gsub(key, "Enabled", "")
			settingsRows[index] = React.createElement(Button, {
				key = key,
				text = `{string.upper(title)}  {settings[key] == false and "OFF" or "ON"}`,
				onClick = function()
					local updated = table.clone(settings)
					updated[key] = settings[key] == false
					setSettings(updated)
					run("SetGuildSettings", { Settings = { [key] = updated[key] } })
				end,
				color = settings[key] == false and Palette.panelSoft or Palette.mint,
				textColor = settings[key] == false and Palette.cream or Palette.ink,
				size = UDim2.new(1 / 3, -6, 0, 42),
				position = UDim2.new((index - 1) / 3, 0, 0, 0),
				disabled = busy ~= "",
				reducedMotion = reducedMotion,
			})
		end
	end
	local settingsAccessRows = {}
	local memberCount = 0
	for _ in guild.Members or {} do
		memberCount += 1
	end
	local memberCap = math.floor(tonumber(settings.MemberCap) or tonumber(settings.MemberCapMax) or 20)
	local memberCapMax = math.floor(tonumber(settings.MemberCapMax) or 20)
	local memberCapMin = math.max(2, memberCount)
	local joinMode = if settings.JoinMode == "Closed" then "Closed" else "Open"
	local function saveAccessSetting(key, value)
		local previous = table.clone(settings)
		local updated = table.clone(settings)
		updated[key] = value
		setSettings(updated)
		run("SetGuildSettings", { Settings = { [key] = value } }, function(result)
			if not result.ok then
				setSettings(previous)
			end
		end)
	end
	if leader then
		settingsAccessRows[1] = React.createElement(Button, {
			text = if joinMode == "Open" then "JOIN · OPEN" else "JOIN · CLOSED",
			onClick = function()
				saveAccessSetting("JoinMode", if joinMode == "Open" then "Closed" else "Open")
			end,
			color = if joinMode == "Open" then Palette.mint else Palette.panelSoft,
			textColor = if joinMode == "Open" then Palette.ink else Palette.cream,
			size = UDim2.new(0.46, -4, 0, 38),
			position = UDim2.fromOffset(0, 0),
			disabled = busy ~= "",
			reducedMotion = reducedMotion,
		})
		settingsAccessRows[2] = React.createElement(
			"frame",
			{
				Name = "MemberCapControl",
				Size = UDim2.new(0.54, 0, 0, 38),
				Position = UDim2.new(0.46, 4, 0, 0),
				BackgroundTransparency = 1,
			},
			React.createElement(Button, {
				text = "−",
				onClick = function()
					saveAccessSetting("MemberCap", memberCap - 1)
				end,
				color = Palette.panelSoft,
				size = UDim2.fromOffset(36, 38),
				position = UDim2.fromOffset(0, 0),
				disabled = busy ~= "" or memberCap <= memberCapMin,
				reducedMotion = reducedMotion,
			}),
			React.createElement(Text, {
				value = `{memberCount} / {memberCap} MEMBERS`,
				size = 10,
				color = Palette.cream,
				alignX = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(38, 0),
				sizeConstraint = UDim2.new(1, -76, 0, 38),
			}),
			React.createElement(Button, {
				text = "+",
				onClick = function()
					saveAccessSetting("MemberCap", memberCap + 1)
				end,
				color = Palette.panelSoft,
				size = UDim2.fromOffset(36, 38),
				position = UDim2.new(1, -36, 0, 0),
				disabled = busy ~= "" or memberCap >= memberCapMax,
				reducedMotion = reducedMotion,
			})
		)
	end
	local sections = {
		{
			id = "guild-community-back",
			height = 48,
			element = React.createElement(Button, {
				text = "‹  GUILD OVERVIEW",
				onClick = onBack,
				color = Palette.panelSoft,
				textColor = Palette.cream,
				size = UDim2.new(1, 0, 0, 44),
				reducedMotion = reducedMotion,
			}),
		},
		{
			id = "guild-community-chat",
			height = 390,
			element = React.createElement(
				Panel,
				{
					size = UDim2.fromScale(1, 1),
					accent = Palette.cyan,
					padding = 14,
					reducedMotion = reducedMotion,
					clips = false,
				},
				React.createElement(Text, {
					value = "MEMBERS-ONLY CHAT",
					size = 12,
					color = Palette.cyan,
					weight = Enum.FontWeight.Heavy,
					sizeConstraint = UDim2.new(1, 0, 0, 20),
				}),
				React.createElement(
					"frame",
					{
						Size = UDim2.new(1, 0, 0, 242),
						Position = UDim2.fromOffset(0, 24),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ClipsDescendants = true,
					},
					React.createElement("uilistlayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					chatRows
				),
				input("Write a guild message…", chatDraft, setChatDraft, 42, UDim2.fromOffset(0, 272)),
				React.createElement(Button, {
					text = settings.ChatEnabled == false and "CHAT DISABLED" or "SEND MESSAGE",
					onClick = function()
						run("SendGuildChat", { Content = chatDraft }, function(result)
							if result.ok then
								setChatDraft("")
							end
						end)
					end,
					color = Palette.cyan,
					textColor = Palette.ink,
					size = UDim2.new(1, 0, 0, 40),
					position = UDim2.fromOffset(0, 320),
					disabled = busy ~= "" or settings.ChatEnabled == false or chatDraft == "",
					loading = busy == "SendGuildChat",
					reducedMotion = reducedMotion,
				})
			),
		},
		{
			id = "guild-community-announcements",
			height = math.max(168, #announcementRows * 126 + (manager and 164 or 64)),
			element = React.createElement(
				"frame",
				{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 },
				React.createElement("uilistlayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10),
				}),
				React.createElement(SectionLabel, { value = "ANNOUNCEMENTS", color = Palette.mango }),
				manager
					and React.createElement(
						Panel,
						{ size = UDim2.new(1, 0, 0, 154), accent = Palette.mango, padding = 12, clips = false },
						input("Announcement title", announcementTitle, function(value)
							setAnnouncementTitle(string.sub(value, 1, 120))
						end, 40, UDim2.fromOffset(0, 0)),
						input("Announcement body", announcementBody, setAnnouncementBody, 46, UDim2.fromOffset(0, 44)),
						React.createElement(Button, {
							text = "PUBLISH",
							onClick = function()
								run(
									"CreateGuildAnnouncement",
									{ Title = announcementTitle, Body = announcementBody },
									function(result)
										if result.ok then
											setAnnouncementTitle("")
											setAnnouncementBody("")
										end
									end
								)
							end,
							color = Palette.mango,
							textColor = Palette.ink,
							size = UDim2.new(1, 0, 0, 36),
							position = UDim2.new(0, 0, 1, -36),
							disabled = busy ~= ""
								or settings.AnnouncementsEnabled == false
								or announcementTitle == ""
								or announcementBody == "",
							reducedMotion = reducedMotion,
						}),
						settings.AnnouncementsEnabled == false
							and React.createElement(Text, {
								value = "Announcements are disabled by the guild leader.",
								size = 11,
								color = Palette.coral,
								position = UDim2.fromOffset(0, -16),
							})
					),
				announcementRows
			),
		},
	}
	if manager then
		local moderationButtons = {}
		for index, action in { "MuteGuildMember", "BanGuildMember", "UnmuteGuildMember", "UnbanGuildMember" } do
			local labels = {
				MuteGuildMember = "MUTE",
				BanGuildMember = "BAN",
				UnmuteGuildMember = "UNMUTE",
				UnbanGuildMember = "UNBAN",
			}
			local colors = {
				MuteGuildMember = Palette.mango,
				BanGuildMember = Palette.coral,
				UnmuteGuildMember = Palette.cyan,
				UnbanGuildMember = Palette.violet,
			}
			moderationButtons[index] = React.createElement(Button, {
				key = action,
				text = labels[action],
				onClick = function()
					local id = tonumber(moderationUserId)
					if id and id > 0 then
						run(action, { UserId = math.floor(id) })
					end
				end,
				color = colors[action],
				textColor = Palette.ink,
				size = UDim2.new(0.25, -6, 0, 40),
				position = UDim2.new((index - 1) * 0.25, 0, 0, 0),
				disabled = busy ~= "" or tonumber(moderationUserId) == nil,
				reducedMotion = reducedMotion,
			})
		end
		table.insert(sections, {
			id = "guild-community-moderation",
			height = 146,
			element = React.createElement(
				Panel,
				{ size = UDim2.fromScale(1, 1), accent = Palette.coral, padding = 14, clips = false },
				React.createElement(SectionLabel, { value = "MEMBER MODERATION · USER ID", color = Palette.coral }),
				input("Guild member user ID", moderationUserId, function(value)
					setModerationUserId(string.sub(value, 1, 20))
				end, 42, UDim2.fromOffset(0, 28)),
				React.createElement(
					"frame",
					{ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 76), BackgroundTransparency = 1 },
					moderationButtons
				)
			),
		})
	end
	if leader then
		table.insert(sections, {
			id = "guild-community-settings",
			height = 210,
			element = React.createElement(
				Panel,
				{ size = UDim2.fromScale(1, 1), accent = Palette.violet, padding = 14, clips = false },
				React.createElement(SectionLabel, { value = "GUILD SETTINGS", color = Palette.violet }),
				React.createElement(
					"frame",
					{ Size = UDim2.new(1, 0, 0, 42), Position = UDim2.fromOffset(0, 26), BackgroundTransparency = 1 },
					settingsRows
				),
				React.createElement(
					"frame",
					{ Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 72), BackgroundTransparency = 1 },
					settingsAccessRows
				),
				React.createElement(Text, {
					value = "Guild name",
					size = 11,
					color = Palette.muted,
					position = UDim2.fromOffset(0, 118),
					sizeConstraint = UDim2.new(1, 0, 0, 16),
				}),
				input("3–28 letters, numbers, spaces, - or _", guildNameDraft, function(value)
					setGuildNameDraft(string.sub(value, 1, 28))
				end, 40, UDim2.fromOffset(0, 138), UDim2.new(1, -142, 0, 40)),
				React.createElement(Button, {
					text = "SAVE NAME",
					onClick = function()
						run("RenameGuild", { Name = guildNameDraft })
					end,
					color = Palette.violet,
					textColor = Palette.cream,
					size = UDim2.fromOffset(132, 40),
					position = UDim2.new(1, -132, 0, 138),
					disabled = busy ~= "" or #guildNameDraft < 3,
					reducedMotion = reducedMotion,
				})
			),
		})
	end
	if manager then
		local activeLogo = community.Logo
		local logoPreview = activeLogo
			and activeLogo.URL
			and React.createElement("imagelabel", {
				Size = UDim2.fromOffset(56, 56),
				Position = UDim2.new(1, -60, 0, 0),
				BackgroundTransparency = 1,
				Image = activeLogo.URL,
				ScaleType = Enum.ScaleType.Fit,
			})
		table.insert(sections, {
			id = "guild-community-logo",
			height = 164 + #logoRows * 94,
			element = React.createElement(
				Panel,
				{ size = UDim2.fromScale(1, 1), accent = Palette.violet, padding = 14, clips = false },
				React.createElement(
					SectionLabel,
					{ value = "ROBLOX IMAGE LOGO · REVIEW REQUIRED", color = Palette.violet }
				),
				logoPreview,
				input("Roblox image asset ID", logoAsset, setLogoAsset, 42, UDim2.fromOffset(0, 28)),
				React.createElement(Button, {
					text = "SUBMIT FOR REVIEW",
					onClick = function()
						run("UploadGuildLogo", { URL = logoAsset }, function(result)
							if result.ok then
								setLogoAsset("")
							end
						end)
					end,
					color = Palette.violet,
					textColor = Palette.cream,
					size = UDim2.new(1, 0, 0, 38),
					position = UDim2.fromOffset(0, 76),
					disabled = busy ~= "" or settings.LogoEnabled == false or logoAsset == "",
					reducedMotion = reducedMotion,
				}),
				React.createElement(
					"frame",
					{
						Size = UDim2.new(1, 0, 0, #logoRows * 90),
						Position = UDim2.fromOffset(0, 120),
						BackgroundTransparency = 1,
					},
					React.createElement("uilistlayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					logoRows
				)
			),
		})
	end
	return React.createElement(PageScaffold, {
		gap = 10,
		tailPad = scrollTail(stack, 0, 72),
		scrollBarColor = Palette.cyan,
		scrollBarThickness = 4,
		sections = sections,
	})
end
return GuildCommunityPanel
