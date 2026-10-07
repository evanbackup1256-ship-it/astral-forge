--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then
		return hit.value
	end
	local def = __defs[name]
	if def == nil then
		error("PagesShop: unknown module " .. tostring(name), 2)
	end
	if __loading[name] then
		error("PagesShop: cyclic require of member " .. name, 2)
	end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then
		error(value, 0)
	end
	__cache[name] = { value = value }
	return value
end

__defs["ShopView"] = function()
	return require(script.Parent.Parent.PremiumShop)
end

__defs["StoreFront"] = function()
	local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local _motion = require(script.Parent.Parent.MotionKit)("motion")
	local useViewport = _motion.useViewport
	local useStagger = _motion.useStagger
	local useWallClock = _motion.useWallClock
	local _theme = require(script.Parent.Parent.CoreKit)("theme")
	local Palette = _theme.Palette
	local TapTarget = _theme.TapTarget
	local chromeFor = _theme.chromeFor
	local darken = _theme.darken
	local scrollTail = _theme.scrollTail
	local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
	local _ui = require(script.Parent.Parent.UiCore)("ui")
	local Badge = _ui.Badge
	local Button = _ui.Button
	local IconTile = _ui.IconTile
	local Meter = _ui.Meter
	local Panel = _ui.Panel
	local SegmentedTabs = _ui.SegmentedTabs
	local Text = _ui.Text
	local _crate = require(script.Parent.Parent.UiCore)("crateModel")
	local CrateModel = _crate.CrateModel
	local skinAccent = _crate.skinAccent
	local _prism = require(script.Parent.Parent.UiCore)("prismFx")
	local PrismAura = _prism.PrismAura
	local isAscended = _prism.isAscended
	local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
	local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
	local SharedData =
		require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))
	local ShopCatalog = SharedData("ShopCatalog")
	local RelicSystem = SharedData("RelicSystem")
	local Browse = require(script.Parent.Parent.BrowseKit)

	local h = React.createElement
	local GAP = 10
	local SECTIONS = {
		{ id = "Daily", label = "Daily" },
		{ id = "Crates", label = "Crates" },
		{ id = "Skins", label = "Skins" },
		{ id = "Codex", label = "Codex" },
		{ id = "Premium", label = "Premium" },
	}
	local CURRENCY_ICON = { Stardust = "Dust", Cores = "Core" }
	local KIND_ICON =
		{ Key = "Crate", Essence = "Artifact", Flux = "Flux", Boost = "Boost", Cache = "Gift", Skin = "Crate" }
	local TIER_COLOR = {
		Common = Color3.fromRGB(200, 196, 188),
		Rare = Color3.fromRGB(110, 190, 255),
		Epic = Color3.fromRGB(190, 120, 255),
		Legendary = Color3.fromRGB(255, 190, 70),
		Mythic = Color3.fromRGB(255, 110, 150),
	}

	local function commas(value)
		local text = tostring(math.floor(math.max(0, tonumber(value) or 0)))
		local spaced = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
		return (string.gsub(spaced, "^,", ""))
	end

	local function currencyColor(currency)
		return if currency == "Cores" then Palette.cyan else Palette.violet
	end

	local function rarityColor(config, rarity)
		local rarities = config and config.Items and config.Items.Rarities
		local entry = rarities and rarities[rarity]
		return if entry ~= nil and entry.Color ~= nil then entry.Color else Palette.cream
	end

	local function crateById(config, id)
		for _, crate in (config and config.Items and config.Items.Crates) or {} do
			if crate.Id == id then
				return crate
			end
		end
		return nil
	end

	local function clockText(seconds)
		local left = math.max(0, math.floor(seconds))
		local hours = left // 3600
		local minutes = (left % 3600) // 60
		if hours > 0 then
			return `{hours}h {minutes}m`
		end
		return `{minutes}m {left % 60}s`
	end

	local function rowsHeight(count, columns, cell)
		local rows = math.max(1, math.ceil(count / math.max(1, columns)))
		return rows * cell + (rows - 1) * GAP
	end

	local function Grid(props)
		local children = table.clone(props.cells)
		children.Layout = h("uigridlayout", {
			CellSize = UDim2.new(
				1 / props.columns,
				-math.ceil(GAP * (props.columns - 1) / props.columns),
				0,
				props.cell
			),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			FillDirectionMaxCells = props.columns,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		return h("frame", {
			Size = UDim2.new(1, 0, 0, props.height),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, children)
	end

	local function Wallet(props)
		local state = props.state or {}
		local chips = {
			Layout = h("uilistlayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = if props.left
					then Enum.HorizontalAlignment.Left
					else Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for index, currency in { "Stardust", "Cores" } do
			chips[currency] = h(
				"frame",
				{
					Size = UDim2.fromOffset(112, 30),
					BackgroundColor3 = Palette.panelSoft,
					BackgroundTransparency = 0.15,
					BorderSizePixel = 0,
					LayoutOrder = index,
				},
				h("uicorner", { CornerRadius = UDim.new(1, 0) }),
				h("uistroke", {
					Color = currencyColor(currency),
					Transparency = 0.55,
					Thickness = 1,
				}),
				h(Icon, {
					kind = CURRENCY_ICON[currency],
					color = Palette.cream,
					accent = currencyColor(currency),
					size = 20,
					position = UDim2.fromOffset(6, 5),
					spin = false,
				}),
				h(Text, {
					value = commas(state[currency]),
					size = 13,
					color = Palette.cream,
					weight = Enum.FontWeight.Bold,
					fit = true,
					minSize = 9,
					position = UDim2.fromOffset(32, 6),
					sizeConstraint = UDim2.new(1, -40, 0, 18),
				})
			)
		end
		return h("frame", {
			Size = props.size,
			Position = props.position,
			AnchorPoint = props.anchorPoint,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, chips)
	end

	local function Hero(props)
		local stack = props.stack
		local textW = if stack then -56 else -300
		return h(
			Panel,
			{
				size = UDim2.fromScale(1, 1),
				accent = props.accent,
				background = Palette.panelRaised,
				padding = 14,
				reveal = props.reveal,
				highlight = true,
				reducedMotion = props.reducedMotion,
				clips = false,
			},
			h(IconTile, {
				kind = props.icon,
				accent = props.accent,
				size = 44,
				radius = 12,
				position = UDim2.fromOffset(0, 2),
				glow = true,
				reducedMotion = props.reducedMotion,
			}),
			h(Text, {
				value = props.title,
				size = if stack then 18 else 22,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				fit = true,
				minSize = 13,
				position = UDim2.fromOffset(56, 0),
				sizeConstraint = UDim2.new(1, textW, 0, 28),
			}),
			h(Text, {
				value = props.body,
				size = 12,
				color = Palette.creamSoft,
				wrap = true,
				position = UDim2.fromOffset(56, 30),
				sizeConstraint = UDim2.new(1, textW, 0, 34),
			}),
			h(Wallet, {
				state = props.state,
				left = stack,
				size = if stack then UDim2.new(1, 0, 0, 30) else UDim2.fromOffset(240, 30),
				position = if stack then UDim2.new(0, 0, 1, -30) else UDim2.fromScale(1, 0),
				anchorPoint = if stack then nil else Vector2.new(1, 0),
			}),
			props.extra
		)
	end

	local function heroHeight(stack)
		return if stack then 124 else 92
	end

	local function offerDetail(offer, config)
		if offer.Kind == "Key" then
			local crate = crateById(config, offer.CrateId)
			return `{offer.Amount} key{if offer.Amount == 1 then "" else "s"} for the {if crate
				then crate.Name
				else offer.CrateId}. Open them under Crates.`
		elseif offer.Kind == "Essence" then
			return `+{commas(offer.Amount)} relic essence, for levelling relics.`
		elseif offer.Kind == "Flux" then
			local span = if offer.Minutes >= 60
				then `{offer.Minutes // 60} hour{if offer.Minutes >= 120 then "s" else ""}`
				else `{offer.Minutes} minutes`
			return `{span} of your current flux output, paid at once.`
		elseif offer.Kind == "Boost" then
			return `{offer.Amount} charge of {offer.BoostId}. Fire it from Boosts.`
		elseif offer.Kind == "Cache" then
			return `One {offer.Rarity} relic, guaranteed, revealed on the spot.`
		elseif offer.Kind == "Skin" then
			local skin = ShopCatalog.skin(offer.SkinId)
			return `Crate skin. {if skin then skin.Blurb else ""}`
		end
		return ""
	end

	local function offerAccent(offer, config)
		if offer.Kind == "Skin" then
			return skinAccent(offer.SkinId)
		elseif offer.Kind == "Cache" then
			return rarityColor(config, offer.Rarity)
		elseif offer.Kind == "Key" then
			local crate = crateById(config, offer.CrateId)
			return if crate ~= nil and typeof(crate.Color) == "Color3" then crate.Color else Palette.cyan
		end
		return if offer.Deal then Palette.mango else Palette.cyan
	end

	local function OfferCard(props)
		local offer = props.offer
		local accent = offerAccent(offer, props.config)
		local reveal = useStagger(props.index, props.reducedMotion, 0.04, 0.26)
		local left = props.left
		local soldOut = left <= 0
		local have = tonumber(props.state[offer.Currency]) or 0
		local short = math.max(0, offer.Price - have)
		local canBuy = not soldOut and short == 0 and not props.busy
		local fullPrice = if offer.Deal then math.floor(offer.Price / (1 - ShopCatalog.DEAL_DISCOUNT) + 0.5) else nil
		local cta = if soldOut
			then "SOLD OUT"
			elseif short > 0 then `NEED {commas(short)}`
			elseif props.pending then "BUYINGÃ¢â‚¬Â¦"
			else "BUY"
		return h(
			Panel,
			{
				size = UDim2.fromScale(1, 1),
				accent = accent,
				background = Palette.panelRaised,
				padding = 12,
				reveal = reveal,
				interactive = canBuy,
				highlight = offer.Deal,
				reducedMotion = props.reducedMotion,
				clips = false,
				layoutOrder = props.index,
			},
			h(
				"frame",
				{
					Size = UDim2.fromOffset(62, 62),
					BackgroundColor3 = darken(accent, 0.4),
					BorderSizePixel = 0,
					ClipsDescendants = true,
				},
				h("uicorner", { CornerRadius = UDim.new(0, 12) }),
				h("uistroke", {
					Color = accent,
					Thickness = 1.5,
					Transparency = 0.3,
				}),
				if offer.Kind == "Skin"
					then h(CrateModel, {
						skin = offer.SkinId,
						live = offer.Deal and not props.reducedMotion,
						spin = true,
						zoom = 0.95,
					})
					else h(Icon, {
						kind = KIND_ICON[offer.Kind] or "Shop",
						color = Palette.cream,
						accent = accent,
						size = 38,
						position = UDim2.fromOffset(12, 12),
						spin = false,
						reducedMotion = props.reducedMotion,
					})
			),
			h(Text, {
				value = offer.Name,
				size = 15,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				fit = true,
				minSize = 11,
				position = UDim2.fromOffset(74, 0),
				sizeConstraint = UDim2.new(1, -74 - (if offer.Deal then 76 else 0), 0, 22),
			}),
			h(Text, {
				value = offerDetail(offer, props.config),
				size = 12,
				color = Palette.creamSoft,
				wrap = true,
				position = UDim2.fromOffset(74, 24),
				sizeConstraint = UDim2.new(1, -74, 0, 44),
			}),
			offer.Deal
				and h(Badge, {
					value = `DEAL -{math.floor(ShopCatalog.DEAL_DISCOUNT * 100)}%`,
					accent = Palette.mango,
					filled = true,
					size = UDim2.fromOffset(72, 20),
					position = UDim2.new(1, -72, 0, 0),
				}),
			h(Text, {
				value = if soldOut then "Bought out today" else `{left} left today`,
				size = 11,
				color = if soldOut then Palette.muted else accent,
				weight = Enum.FontWeight.Bold,
				position = UDim2.fromOffset(0, 74),
				sizeConstraint = UDim2.new(1, 0, 0, 16),
			}),
			h(Icon, {
				kind = CURRENCY_ICON[offer.Currency] or "Dust",
				color = Palette.cream,
				accent = currencyColor(offer.Currency),
				size = 22,
				position = UDim2.new(0, 0, 1, if fullPrice ~= nil then -38 else -31),
				spin = false,
			}),
			h(Text, {
				value = commas(offer.Price),
				size = 18,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				position = UDim2.new(0, 28, 1, if fullPrice ~= nil then -40 else -32),
				sizeConstraint = UDim2.fromOffset(80, 24),
			}),
			fullPrice ~= nil
				and h(Text, {
					value = `was {commas(fullPrice)}`,
					size = 11,
					color = Palette.muted,
					position = UDim2.new(0, 28, 1, -15),
					sizeConstraint = UDim2.fromOffset(80, 14),
				}),
			h(
				"frame",
				{
					Name = "DailyBuy",
					Size = UDim2.fromOffset(124, 40),
					Position = UDim2.new(1, -124, 1, -40),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				},
				h(Button, {
					text = cta,
					icon = if soldOut then "Check" elseif short > 0 then "Lock" else "Shop",
					onClick = props.onBuy,
					color = if canBuy then accent else Palette.panelSoft,
					textColor = if canBuy then Palette.ink else Palette.creamSoft,
					size = UDim2.fromScale(1, 1),
					disabled = not canBuy,
					reducedMotion = props.reducedMotion,
					highlight = canBuy,
					selectable = canBuy,
				})
			)
		)
	end

	local function useDay()
		local day, setDay = React.useState(function()
			return ShopCatalog.day(workspace:GetServerTimeNow())
		end)
		React.useEffect(function()
			local job = task.delay(ShopCatalog.secondsLeft(workspace:GetServerTimeNow()) + 1, function()
				setDay(ShopCatalog.day(workspace:GetServerTimeNow()))
			end)
			return function()
				pcall(task.cancel, job)
			end
		end, { day })
		return day
	end

	local function DailySection(props)
		local state = props.state
		local config = props.config
		local stack = props.stack
		local day = useDay()
		local wall = useWallClock(true)
		local pendingSlot, setPendingSlot = React.useState(nil)
		local mounted = React.useRef(true)
		React.useEffect(function()
			mounted.current = true
			return function()
				mounted.current = false
			end
		end, {})
		local daily = state.DailyShop or {}
		local current = daily.Day == day
		local owned = if current and type(daily.Owned) == "table"
			then daily.Owned
			else (state.Cosmetics and state.Cosmetics.CrateSkins) or {}
		local bought = if current then daily.Bought or {} else {}
		local offers = ShopCatalog.roll(Players.LocalPlayer.UserId, day, owned)
		local columns = if stack then 1 elseif props.width >= 1000 then 3 else 2
		local cellH = 178
		local buy = function(offer)
			if pendingSlot ~= nil then
				return
			end
			setPendingSlot(offer.Slot)
			props.dispatch("BuyDailyOffer", { Slot = offer.Slot }, function(response)
				if not mounted.current then
					return
				end
				setPendingSlot(nil)
				if
					response.ok
					and type(response.Rolls) == "table"
					and #response.Rolls > 0
					and props.onCrateReveal ~= nil
				then
					local roll = response.Rolls[1]
					props.onCrateReveal({
						crateId = "ForgeCrate",
						crateName = offer.Name,
						accent = rarityColor(config, roll.Rarity),
						rolls = response.Rolls,
					})
				elseif response.ok then
					Audio:play("purchase")
				end
			end)
		end
		local cells = {}
		for index, offer in offers do
			cells[`Offer{offer.Slot}`] = h(OfferCard, {
				key = `{day}-{offer.Id}`,
				offer = offer,
				index = index,
				config = config,
				state = state,
				left = ShopCatalog.remaining(offer, bought),
				busy = pendingSlot ~= nil,
				pending = pendingSlot == offer.Slot,
				reducedMotion = props.reducedMotion,
				onBuy = function()
					buy(offer)
				end,
			})
		end
		local gridH = rowsHeight(#offers, columns, cellH)
		local resetText = wall:map(function(now)
			return `New offers in {clockText(ShopCatalog.secondsLeft(now))}`
		end)
		local marketH = if stack then 132 else 96
		return React.createElement(PageScaffold, {
			gap = GAP,
			tailPad = props.tailPad,
			scrollBarColor = Palette.mango,
			sections = {
				{
					id = "hero",
					height = heroHeight(stack),
					element = h(Hero, {
						title = "Daily Shop",
						body = "Six offers picked for you each day. The first is the Deal of the Day.",
						accent = Palette.mango,
						icon = "Calendar",
						state = state,
						stack = stack,
						reveal = props.reveal,
						reducedMotion = props.reducedMotion,
					}),
				},
				{
					id = "clock",
					height = 22,
					element = h(Text, {
						value = resetText,
						size = 13,
						color = Palette.mango,
						weight = Enum.FontWeight.Bold,
						sizeConstraint = UDim2.new(1, 0, 0, 20),
					}),
				},
				{
					id = "offers",
					height = gridH,
					element = h(Grid, { columns = columns, cell = cellH, height = gridH, cells = cells }),
				},
				{
					id = "market",
					height = marketH,
					element = h(
						Panel,
						{
							size = UDim2.fromScale(1, 1),
							accent = Palette.coral,
							background = Palette.panel,
							padding = 14,
							reducedMotion = props.reducedMotion,
							clips = false,
						},
						h(Icon, {
							kind = "Jackpot",
							color = Palette.cream,
							accent = Palette.coral,
							size = 38,
							position = UDim2.fromOffset(0, 4),
							spin = false,
						}),
						h(Text, {
							value = "The Black Market",
							size = 16,
							color = Palette.cream,
							weight = Enum.FontWeight.Heavy,
							position = UDim2.fromOffset(50, 0),
							sizeConstraint = UDim2.new(1, if stack then -50 else -220, 0, 22),
						}),
						h(Text, {
							value = "Rare relics and odd stock from the Bazaar, restocked through the day.",
							size = 12,
							color = Palette.creamSoft,
							wrap = true,
							position = UDim2.fromOffset(50, 24),
							sizeConstraint = UDim2.new(1, if stack then -50 else -220, 0, 36),
						}),
						h(Button, {
							text = "VISIT MARKET",
							icon = "Visit",
							onClick = function()
								if props.navigate then
									props.navigate("Bazaar")
								end
							end,
							color = Palette.coral,
							textColor = Palette.ink,
							size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(190, 44),
							position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -190, 0.5, -22),
							reducedMotion = props.reducedMotion,
							highlight = true,
						})
					),
				},
			},
		})
	end

	local function OddsRow(props)
		local row = props.row
		local color = rarityColor(props.config, row.rarity)
		return h(
			"frame",
			{
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundColor3 = color,
				BackgroundTransparency = if isAscended(row.rarity) then 0.86 else 1,
				BorderSizePixel = 0,
				LayoutOrder = props.order,
			},
			h("uicorner", { CornerRadius = UDim.new(0, 6) }),
			isAscended(row.rarity)
				and h(PrismAura, {
					rarity = row.rarity,
					intensity = 0.8,
					rays = false,
					sparks = false,
					thickness = 1.5,
					corner = 6,
				}),
			h("frame", {
				Size = UDim2.fromOffset(8, 8),
				Position = UDim2.new(0, 6, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Rotation = 45,
				BackgroundColor3 = color,
				BorderSizePixel = 0,
			}),
			h(Text, {
				value = row.rarity,
				size = 12,
				color = if isAscended(row.rarity) then Palette.cream else color,
				weight = Enum.FontWeight.Bold,
				position = UDim2.fromOffset(22, 2),
				sizeConstraint = UDim2.new(0.6, -22, 0, 16),
			}),
			h(Text, {
				value = RelicSystem.chanceText(row.chance),
				size = 12,
				color = Palette.cream,
				weight = Enum.FontWeight.Bold,
				align = Enum.TextXAlignment.Right,
				position = UDim2.new(0.4, 0, 0, 2),
				sizeConstraint = UDim2.new(0.6, -8, 0, 16),
			})
		)
	end

	local function CrateStage(props)
		local crate = props.crate
		local config = props.config
		local stack = props.stack
		local keys = props.keys
		local odds = RelicSystem.odds(crate.Weights)
		local accent = if typeof(crate.Color) == "Color3" then crate.Color else Palette.violet
		local oddsRows = {
			Layout = h("uilistlayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for index = #odds, 1, -1 do
			local row = odds[index]
			oddsRows[row.rarity] = h(OddsRow, { row = row, config = config, order = #odds - index })
		end
		local modelH = if stack then 190 else 280
		local infoX = if stack then 0 else 300
		local infoY = if stack then modelH + 6 else 0
		local pity = (props.pity or 0)
		local pityLine = if crate.PityAfter and crate.PityRarity
			then `Pity: a {crate.PityRarity} or better within {math.max(1, crate.PityAfter - pity)} opens.`
			else ""
		local openButton = function(count, order)
			local can = keys >= count and not props.busy
			return h(Button, {
				text = if keys >= count
					then `OPEN {count}`
					else `NEED {count - keys} KEY{if count - keys == 1 then "" else "S"}`,
				icon = if keys >= count then "Crate" else "Lock",
				onClick = function()
					props.onOpen(count)
				end,
				color = if can then accent else Palette.panelSoft,
				textColor = if can then Palette.ink else Palette.creamSoft,
				size = UDim2.new(0.5, -4, 1, 0),
				position = UDim2.fromScale(if order == 1 then 0 else 0.5, 0),
				disabled = not can,
				reducedMotion = props.reducedMotion,
				highlight = can,
				selectable = can,
			})
		end
		return h(
			Panel,
			{
				size = UDim2.fromScale(1, 1),
				accent = accent,
				background = Palette.panelRaised,
				padding = 14,
				reveal = props.reveal,
				reducedMotion = props.reducedMotion,
				clips = false,
			},
			h(
				"frame",
				{
					Size = if stack then UDim2.new(1, 0, 0, modelH) else UDim2.fromOffset(286, modelH),
					BackgroundColor3 = Palette.void,
					BackgroundTransparency = 0.25,
					BorderSizePixel = 0,
				},
				h("uicorner", { CornerRadius = UDim.new(0, 14) }),
				h("uigradient", {
					Color = ColorSequence.new(darken(accent, 0.55), Palette.void),
					Rotation = 90,
				}),
				h(CrateModel, {
					skin = require(game.ReplicatedStorage.AstralForge.Shared.CrateAppearance).resolve(props.skin, crate.Id, config.Items.Crates),
					spin = true,
					open = if props.busy then 0.35 else 0,
					shake = if props.busy then 1 else 0,
					live = not props.reducedMotion,
					zoom = 0.85,
				}),
				h(Badge, {
					value = `{keys} KEY{if keys == 1 then "" else "S"}`,
					accent = if keys > 0 then accent else Palette.lineSoft,
					filled = keys > 0,
					size = UDim2.fromOffset(78, 22),
					position = UDim2.fromOffset(10, 10),
				})
			),
			h(
				"frame",
				{
					Size = if stack then UDim2.new(1, 0, 1, -infoY) else UDim2.new(1, -infoX, 1, 0),
					Position = UDim2.fromOffset(infoX, infoY),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				},
				h(Text, {
					value = crate.Name,
					size = 20,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = true,
					minSize = 13,
					sizeConstraint = UDim2.new(1, 0, 0, 26),
				}),
				h(Text, {
					value = crate.Description or "",
					size = 12,
					color = Palette.creamSoft,
					wrap = true,
					position = UDim2.fromOffset(0, 28),
					sizeConstraint = UDim2.new(1, 0, 0, 30),
				}),
				h(Text, {
					value = pityLine,
					size = 11,
					color = accent,
					weight = Enum.FontWeight.Bold,
					position = UDim2.fromOffset(0, 60),
					sizeConstraint = UDim2.new(1, 0, 0, 16),
				}),
				h("frame", {
					Size = UDim2.new(1, 0, 0, #odds * 22),
					Position = UDim2.fromOffset(0, 82),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, oddsRows),
				h("frame", {
					Name = "CrateOpen",
					Size = UDim2.new(1, 0, 0, TapTarget),
					Position = UDim2.new(0, 0, 1, -TapTarget),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, openButton(1, 1), openButton(5, 2))
			)
		)
	end

	local function crateStageHeight(stack, crate)
		local rows = #RelicSystem.odds(crate and crate.Weights)
		local info = 82 + rows * 22 + 10 + TapTarget + 28
		return if stack then 190 + 6 + info else math.max(280, info) + 28
	end

	local function CrateChip(props)
		local crate = props.crate
		local accent = if typeof(crate.Color) == "Color3" then crate.Color else Palette.violet
		return h(
			"textbutton",
			{
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = if props.selected then darken(accent, 0.45) else Palette.panel,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = props.order,
				Event = {
					Activated = function()
						Audio:play("tabSwitch")
						props.onSelect()
					end,
				},
			},
			h("uicorner", { CornerRadius = UDim.new(0, 12) }),
			h("uistroke", {
				Color = accent,
				Thickness = if props.selected then 2 else 1,
				Transparency = if props.selected then 0 else 0.6,
			}),
			h(Icon, {
				kind = "Crate",
				color = Palette.cream,
				accent = accent,
				size = 30,
				position = UDim2.new(0, 10, 0.5, -15),
				spin = false,
			}),
			h(Text, {
				value = crate.Name,
				size = 13,
				color = Palette.cream,
				weight = Enum.FontWeight.Bold,
				fit = true,
				minSize = 10,
				position = UDim2.fromOffset(48, 8),
				sizeConstraint = UDim2.new(1, -56, 0, 18),
			}),
			h(Text, {
				value = if props.keys > 0 then `{props.keys} key{if props.keys == 1 then "" else "s"}` else "No keys",
				size = 11,
				color = if props.keys > 0 then accent else Palette.muted,
				weight = Enum.FontWeight.Bold,
				position = UDim2.fromOffset(48, 28),
				sizeConstraint = UDim2.new(1, -56, 0, 16),
			})
		)
	end

	local function CratesSection(props)
		local state = props.state
		local config = props.config
		local stack = props.stack
		local crates = (config.Items and config.Items.Crates) or {}
		local items = state.Items or {}
		local keys = items.Keys or {}
		local firstWithKeys = nil
		for _, crate in crates do
			if (keys[crate.Id] or 0) > 0 then
				firstWithKeys = crate.Id
				break
			end
		end
		local selected, setSelected = React.useState(firstWithKeys or (crates[1] and crates[1].Id))
		local busy, setBusy = React.useState(false)
		local attempt = React.useRef(0)
		local mounted = React.useRef(true)
		React.useEffect(function()
			mounted.current = true
			return function()
				mounted.current = false
			end
		end, {})
		local crate = crateById(config, selected) or crates[1]
		if crate == nil then
			return h(Text, { value = "No crates available yet..", size = 14, color = Palette.creamSoft })
		end
		local skin = state.Cosmetics and state.Cosmetics.CrateSkin
		local onOpen = function(count)
			if busy or props.crateRevealActive then
				return
			end
			attempt.current += 1
			local mine = attempt.current
			setBusy(true)
			props.dispatch("OpenItemCrate", { Id = crate.Id, Count = count }, function(response)
				if not mounted.current or attempt.current ~= mine then
					return
				end
				setBusy(false)
				if
					response.ok
					and type(response.Rolls) == "table"
					and #response.Rolls > 0
					and props.onCrateReveal ~= nil
				then
					props.onCrateReveal({
						crateId = crate.Id,
						crateName = crate.Name,
						accent = crate.Color,
						rolls = response.Rolls,
					})
				end
			end)
		end
		local columns = if stack then 2 elseif props.width >= 1000 then 4 else 3
		local chips = {}
		for index, entry in crates do
			chips[entry.Id] = h(CrateChip, {
				crate = entry,
				order = index,
				keys = keys[entry.Id] or 0,
				selected = entry.Id == crate.Id,
				onSelect = function()
					setSelected(entry.Id)
				end,
			})
		end
		local chipsH = rowsHeight(#crates, columns, 58)
		return React.createElement(PageScaffold, {
			gap = GAP,
			tailPad = props.tailPad,
			scrollBarColor = Palette.violet,
			sections = {
				{
					id = "hero",
					height = heroHeight(stack),
					element = h(Hero, {
						title = "Crates",
						body = "Every crate's odds, all the way up to Celestial and Astral. Your crate skin opens every one.",
						accent = Palette.violet,
						icon = "Crate",
						state = state,
						stack = stack,
						reveal = props.reveal,
						reducedMotion = props.reducedMotion,
					}),
				},
				{
					id = "stage",
					height = crateStageHeight(stack, crate),
					element = h(CrateStage, {
						key = crate.Id,
						crate = crate,
						config = config,
						stack = stack,
						keys = keys[crate.Id] or 0,
						pity = items.Pity and items.Pity[crate.Id] or 0,
						skin = skin,
						busy = busy or props.crateRevealActive == true,
						onOpen = onOpen,
						reducedMotion = props.reducedMotion,
					}),
				},
				{
					id = "chips",
					height = chipsH,
					element = h(Grid, { columns = columns, cell = 58, height = chipsH, cells = chips }),
				},
			},
		})
	end

	local function skinStatus(skin, cosmetics)
		local owned = cosmetics.CrateSkins and cosmetics.CrateSkins[skin.Id] == true or skin.Default == true
		local equipped = (cosmetics.CrateSkin or ShopCatalog.DEFAULT_SKIN) == skin.Id
		return owned, equipped
	end

	local function SkinPreview(props)
		local skin = props.skin
		local stack = props.stack
		local owned, equipped = skinStatus(skin, props.cosmetics)
		local accent = skinAccent(skin.Id)
		local price = skin.Price
		local have = if price then tonumber(props.state[price.Currency]) or 0 else 0
		local short = if price then math.max(0, price.Amount - have) else 0
		local peek, setPeek = React.useState(false)
		local action, label, enabled
		if equipped then
			action, label, enabled = nil, "EQUIPPED", false
		elseif owned then
			action, label, enabled = "EquipCrateSkin", "EQUIP", true
		elseif skin.DailyOnly then
			action, label, enabled = nil, "DAILY SHOP ONLY", false
		elseif short > 0 then
			action, label, enabled = nil, `NEED {commas(short)} {string.upper(price.Currency)}`, false
		else
			action, label, enabled =
				"BuyCrateSkin", `BUY Ã‚Â· {commas(price.Amount)} {string.upper(price.Currency)}`, true
		end
		enabled = enabled and not props.busy
		local modelSize = if stack then 200 else 250
		return h(
			Panel,
			{
				size = UDim2.fromScale(1, 1),
				accent = accent,
				background = Palette.panelRaised,
				padding = 14,
				highlight = true,
				reducedMotion = props.reducedMotion,
				clips = false,
			},
			h(
				"textbutton",
				{
					Size = if stack then UDim2.new(1, 0, 0, modelSize) else UDim2.fromOffset(modelSize, modelSize),
					BackgroundColor3 = Palette.void,
					BackgroundTransparency = 0.2,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Text = "",
					Event = {
						Activated = function()
							setPeek(not peek)
							Audio:play(if peek then "close" else "crateOpen")
						end,
					},
				},
				h("uicorner", { CornerRadius = UDim.new(0, 14) }),
				h("uigradient", {
					Color = ColorSequence.new(darken(accent, 0.5), Palette.void),
					Rotation = 90,
				}),
				h(CrateModel, {
					skin = skin.Id,
					spin = true,
					open = if peek then 1 else 0,
					live = not props.reducedMotion,
					zoom = 0.82,
				}),
				h(Text, {
					value = if peek then "Tap to close" else "Tap to look inside",
					size = 11,
					color = Palette.muted,
					align = Enum.TextXAlignment.Center,
					position = UDim2.new(0, 0, 1, -20),
					sizeConstraint = UDim2.new(1, 0, 0, 16),
				})
			),
			h(
				"frame",
				{
					Size = if stack
						then UDim2.new(1, 0, 1, -(modelSize + 8))
						else UDim2.new(1, -(modelSize + 16), 1, 0),
					Position = if stack
						then UDim2.fromOffset(0, modelSize + 8)
						else UDim2.fromOffset(modelSize + 16, 0),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				},
				h(Badge, {
					value = string.upper(skin.Tier or "Common"),
					accent = TIER_COLOR[skin.Tier] or accent,
					filled = true,
					size = UDim2.fromOffset(92, 20),
				}),
				h(Text, {
					value = skin.Name,
					size = 22,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = true,
					minSize = 14,
					position = UDim2.fromOffset(0, 26),
					sizeConstraint = UDim2.new(1, 0, 0, 30),
				}),
				h(Text, {
					value = skin.Blurb,
					size = 13,
					color = Palette.creamSoft,
					wrap = true,
					position = UDim2.fromOffset(0, 60),
					sizeConstraint = UDim2.new(1, 0, 0, 40),
				}),
				h(Text, {
					value = if owned
						then "Yours. Every crate you open wears the equipped skin."
						else "Equip this skin for its guaranteed essence bonus.",
					size = 11,
					color = accent,
					weight = Enum.FontWeight.Bold,
					wrap = true,
					position = UDim2.fromOffset(0, 104),
					sizeConstraint = UDim2.new(1, 0, 0, 30),
				}),
				h(
					"frame",
					{
						Name = "SkinClaim",
						Size = UDim2.new(1, 0, 0, TapTarget),
						Position = UDim2.new(0, 0, 1, -TapTarget),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
					},
					h(Button, {
						text = label,
						icon = if equipped then "Check" elseif enabled then "Shop" else "Lock",
						onClick = function()
							if action ~= nil then
								props.onAction(action, skin.Id)
							end
						end,
						color = if enabled then accent else Palette.panelSoft,
						textColor = if enabled then Palette.ink else Palette.creamSoft,
						size = UDim2.fromScale(1, 1),
						disabled = not enabled,
						reducedMotion = props.reducedMotion,
						highlight = enabled,
						selectable = enabled,
					})
				)
			)
		)
	end

	local function SkinCard(props)
		local skin = props.skin
		local owned, equipped = skinStatus(skin, props.cosmetics)
		local accent = skinAccent(skin.Id)
		return h(
			"textbutton",
			{
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = if props.selected then darken(accent, 0.5) else Palette.panel,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = props.order,
				Event = {
					Activated = function()
						Audio:play("tabSwitch")
						props.onSelect()
					end,
				},
			},
			h("uicorner", { CornerRadius = UDim.new(0, 14) }),
			h("uistroke", {
				Color = accent,
				Thickness = if props.selected then 2 else 1,
				Transparency = if props.selected then 0 else 0.55,
			}),
			h(CrateModel, {
				skin = skin.Id,
				live = false,
				size = UDim2.new(1, 0, 1, -40),
				zoom = 0.9,
			}),
			skin.Id == "Celestial"
				and h(PrismAura, {
					rarity = "Celestial",
					intensity = 0.7,
					rays = false,
					corner = 14,
				}),
			h(Text, {
				value = skin.Name,
				size = 13,
				color = Palette.cream,
				weight = Enum.FontWeight.Bold,
				fit = true,
				minSize = 10,
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 6, 1, -38),
				sizeConstraint = UDim2.new(1, -12, 0, 18),
			}),
			h(Text, {
				value = if equipped
					then "EQUIPPED"
					elseif owned then "OWNED"
					elseif skin.DailyOnly then "DAILY SHOP"
					else `{commas(skin.Price.Amount)} {string.upper(skin.Price.Currency)}`,
				size = 11,
				color = if equipped then Palette.mint elseif owned then Palette.creamSoft else accent,
				weight = Enum.FontWeight.Bold,
				align = Enum.TextXAlignment.Center,
				position = UDim2.new(0, 6, 1, -20),
				sizeConstraint = UDim2.new(1, -12, 0, 16),
			})
		)
	end

	local function SkinsSection(props)
		local state = props.state
		local stack = props.stack
		local cosmetics = state.Cosmetics or { CrateSkins = { Classic = true }, CrateSkin = ShopCatalog.DEFAULT_SKIN }
		local selected, setSelected = React.useState(cosmetics.CrateSkin or ShopCatalog.DEFAULT_SKIN)
		local busy, setBusy = React.useState(false)
		local mounted = React.useRef(true)
		React.useEffect(function()
			mounted.current = true
			return function()
				mounted.current = false
			end
		end, {})
		local skin = ShopCatalog.skin(selected) or ShopCatalog.skin(ShopCatalog.DEFAULT_SKIN)
		local onAction = function(action, id)
			if busy then
				return
			end
			setBusy(true)
			props.dispatch(action, { Id = id }, function(response)
				if not mounted.current then
					return
				end
				setBusy(false)
				if response.ok then
					Audio:play(if action == "BuyCrateSkin" then "purchase" else "confirm")
				end
			end)
		end
		local columns = if stack then 2 elseif props.width >= 1000 then 4 else 3
		local ownedSkins = cosmetics.CrateSkins or {}
		local skinBrowse = Browse.useBrowse({
			id = "Skins",
			items = ShopCatalog.SKINS,
			text = function(entry)
				return { entry.Name, entry.Description, entry.Rarity }
			end,
			categories = {
				{ id = "All", label = "All" },
				{
					id = "Owned",
					label = "Owned",
					test = function(entry)
						return ownedSkins[entry.Id] == true
					end,
				},
				{
					id = "Locked",
					label = "Not owned",
					test = function(entry)
						return ownedSkins[entry.Id] ~= true
					end,
				},
			},
		})
		local cells = {}
		for index, entry in skinBrowse.results do
			cells[entry.Id] = h(SkinCard, {
				skin = entry,
				order = index,
				cosmetics = cosmetics,
				selected = entry.Id == skin.Id,
				onSelect = function()
					setSelected(entry.Id)
				end,
			})
		end
		local cellH = 156
		local gridH = rowsHeight(math.max(1, #skinBrowse.results), columns, cellH)
		return React.createElement(PageScaffold, {
			gap = GAP,
			tailPad = props.tailPad,
			scrollBarColor = Palette.cyan,
			sections = {
				{
					id = "hero",
					height = heroHeight(stack),
					element = h(Hero, {
						title = "Crate Skins",
						body = "Dress the crate you open. The Celestial Ark only ever turns up in the Daily Shop.",
						accent = Palette.cyan,
						icon = "Crate",
						state = state,
						stack = stack,
						reveal = props.reveal,
						reducedMotion = props.reducedMotion,
					}),
				},
				{
					id = "preview",
					height = if stack then 200 + 8 + 140 + TapTarget + 28 else 278,
					element = h(SkinPreview, {
						key = skin.Id,
						skin = skin,
						state = state,
						cosmetics = cosmetics,
						stack = stack,
						busy = busy,
						onAction = onAction,
						reducedMotion = props.reducedMotion,
					}),
				},
				{
					id = "filter",
					height = Browse.CHIP_H,
					element = h(Browse.ChipRow, {
						options = skinBrowse.categories,
						value = skinBrowse.category,
						onChange = skinBrowse.setCategory,
						counts = skinBrowse.counts,
						accent = Palette.cyan,
					}),
				},
				{
					id = "grid",
					height = gridH,
					element = h(Grid, { columns = columns, cell = cellH, height = gridH, cells = cells }),
				},
			},
		})
	end

	local function CodexProgress(props)
		local config = props.config
		local progress = props.progress
		local bonuses = (config.Items and config.Items.CodexBonus) or {}
		local rows = {
			Layout = h("uilistlayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for index, rarity in RelicSystem.ORDER do
			local row = progress[rarity]
			if row == nil or row.total == 0 then
				continue
			end
			local done = row.found == row.total
			local color = rarityColor(config, rarity)
			rows[rarity] = h(
				"frame",
				{
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = index,
				},
				h(Text, {
					value = rarity,
					size = 12,
					color = color,
					weight = Enum.FontWeight.Bold,
					position = UDim2.fromOffset(0, 3),
					sizeConstraint = UDim2.new(0, 84, 0, 16),
				}),
				h(Meter, {
					value = row.found / row.total,
					color = color,
					size = UDim2.new(1, -230, 0, 8),
					position = UDim2.fromOffset(90, 7),
					reducedMotion = props.reducedMotion,
				}),
				h(Text, {
					value = `{row.found}/{row.total}`,
					size = 12,
					color = Palette.cream,
					weight = Enum.FontWeight.Bold,
					align = Enum.TextXAlignment.Right,
					position = UDim2.new(1, -134, 0, 3),
					sizeConstraint = UDim2.fromOffset(44, 16),
				}),
				h(Text, {
					value = `{if done then "Ã¢Å“â€œ " else ""}+{math.floor((tonumber(bonuses[rarity]) or 0) * 1000 + 0.5) / 10}%`,
					size = 12,
					color = if done then Palette.mint else Palette.muted,
					weight = Enum.FontWeight.Bold,
					align = Enum.TextXAlignment.Right,
					position = UDim2.new(1, -84, 0, 3),
					sizeConstraint = UDim2.fromOffset(84, 16),
				})
			)
		end
		return h(
			Panel,
			{
				size = UDim2.fromScale(1, 1),
				accent = Palette.mint,
				background = Palette.panelRaised,
				padding = 14,
				reducedMotion = props.reducedMotion,
				clips = false,
			},
			h(Text, {
				value = `Codex bonus: +{math.floor((tonumber(props.bonus) or 0) * 1000 + 0.5) / 10}% production`,
				size = 16,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				sizeConstraint = UDim2.new(1, 0, 0, 22),
			}),
			h(Text, {
				value = "Find every relic of a rarity to earn its bonus for good.",
				size = 12,
				color = Palette.creamSoft,
				position = UDim2.fromOffset(0, 24),
				sizeConstraint = UDim2.new(1, 0, 0, 18),
			}),
			h("frame", {
				Size = UDim2.new(1, 0, 1, -50),
				Position = UDim2.fromOffset(0, 50),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, rows)
		)
	end

	local function RelicCell(props)
		local definition = props.definition
		local found = props.found
		local color = rarityColor(props.config, definition.Rarity)
		local ascended = isAscended(definition.Rarity)
		return h(
			"frame",
			{
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = if found then darken(color, 0.72) else Palette.panel,
				BorderSizePixel = 0,
				LayoutOrder = props.order,
			},
			h("uicorner", { CornerRadius = UDim.new(0, 12) }),
			h("uistroke", {
				Color = if found then color else Palette.line,
				Thickness = 1,
				Transparency = if found then 0.25 else 0.5,
			}),
			found
				and ascended
				and h(PrismAura, {
					rarity = definition.Rarity,
					intensity = 1,
					rays = false,
					corner = 12,
				}),
			h(Text, {
				value = if found then definition.Name else "???",
				size = 13,
				color = if found then Palette.cream else Palette.muted,
				weight = Enum.FontWeight.Bold,
				fit = true,
				minSize = 10,
				position = UDim2.fromOffset(10, 8),
				sizeConstraint = UDim2.new(1, -20, 0, 18),
			}),
			h(Text, {
				value = if found
					then (if props.copies > 0
						then `{props.copies} owned{if props.stars > 0
							then "  " .. string.rep("Ã¢Ëœâ€¦", props.stars)
							else ""}`
						else "Found before")
					else `{definition.Slot} relic Ã‚Â· not found yet`,
				size = 11,
				color = if found then color else Palette.muted,
				weight = Enum.FontWeight.Bold,
				fit = true,
				minSize = 9,
				position = UDim2.fromOffset(10, 28),
				sizeConstraint = UDim2.new(1, -20, 0, 16),
			}),
			props.canFuse
				and h(Button, {
					text = "FUSE",
					icon = "Forge",
					onClick = props.onFuse,
					color = color,
					textColor = Palette.ink,
					size = UDim2.new(1, -20, 0, 30),
					position = UDim2.new(0, 10, 1, -38),
					disabled = props.busy,
					reducedMotion = props.reducedMotion,
					highlight = not props.busy,
				})
		)
	end

	local function CodexSection(props)
		local state = props.state
		local config = props.config
		local stack = props.stack
		local items = state.Items or {}
		local discovered = items.Discovered or {}
		local inventory = items.Inventory or {}
		local definitions = (config.Items and config.Items.Definitions) or {}
		local maxStars = (config.Items and config.Items.MaxStars) or 5
		local busy, setBusy = React.useState(false)
		local mounted = React.useRef(true)
		React.useEffect(function()
			mounted.current = true
			return function()
				mounted.current = false
			end
		end, {})
		local progress = RelicSystem.codex(discovered, config.Items)
		local copies, stars = {}, {}
		for _, instance in inventory do
			if type(instance) == "table" and type(instance.DefinitionId) == "string" then
				local id = instance.DefinitionId
				copies[id] = (copies[id] or 0) + 1
				stars[id] = math.max(stars[id] or 0, RelicSystem.stars(instance))
			end
		end
		local function isFound(definition)
			return discovered[definition.Id] == true or (copies[definition.Id] or 0) > 0
		end
		local function canFuseRelic(definition)
			return (copies[definition.Id] or 0) >= 2
				and RelicSystem.fusionPair(inventory, items.Equipped, definition.Id, maxStars) ~= nil
		end
		local codexBrowse = Browse.useBrowse({
			id = "Codex",
			items = definitions,
			textKey = tostring(#inventory),
			text = function(definition)
				-- undiscovered relics only match on slot and rarity, so search never spoils names
				if isFound(definition) then
					return {
						definition.Name,
						definition.Description,
						definition.Rarity,
						definition.Slot,
						definition.EffectKind,
					}
				end
				return { nil, nil, definition.Rarity, definition.Slot }
			end,
			categories = {
				{ id = "All", label = "All" },
				{ id = "Found", label = "Found", test = isFound },
				{
					id = "Missing",
					label = "Missing",
					test = function(definition)
						return not isFound(definition)
					end,
				},
				{
					id = "Owned",
					label = "Owned",
					test = function(definition)
						return (copies[definition.Id] or 0) > 0
					end,
				},
				{ id = "Fuse", label = "Can fuse", test = canFuseRelic },
			},
		})
		local shownIds = {}
		for _, definition in codexBrowse.results do
			shownIds[definition.Id] = true
		end
		local fuse = function(definition)
			if busy then
				return
			end
			setBusy(true)
			props.dispatch("FuseRelics", { Id = definition.Id }, function(response)
				if not mounted.current then
					return
				end
				setBusy(false)
				if response.ok then
					Audio:play("autoForge")
				end
			end)
		end
		local columns = if stack then 2 elseif props.width >= 1000 then 4 else 3
		local cellH = 96
		local sections = {
			{
				id = "hero",
				height = heroHeight(stack),
				element = h(Hero, {
					title = "Relic Codex",
					body = `Every relic in the forge. Fuse a spare copy into a relic for a star: +{math.floor(
						((config.Items and config.Items.StarBonus) or 0.25) * 100
					)}% effect each, up to {maxStars}.`,
					accent = Palette.mint,
					icon = "Artifact",
					state = state,
					stack = stack,
					reveal = props.reveal,
					reducedMotion = props.reducedMotion,
				}),
			},
		}
		local progressRows = 0
		for _, rarity in RelicSystem.ORDER do
			if progress[rarity] and progress[rarity].total > 0 then
				progressRows += 1
			end
		end
		table.insert(sections, {
			id = "progress",
			height = 50 + progressRows * 26 + 24,
			element = h(CodexProgress, {
				config = config,
				progress = progress,
				bonus = items.CodexBonus,
				reducedMotion = props.reducedMotion,
			}),
		})
		table.insert(sections, {
			id = "browse",
			height = Browse.barHeight(stack, true),
			element = h(Browse.BrowseBar, {
				browse = codexBrowse,
				placeholder = "Search relics by name, slot or rarity",
				accent = Palette.mint,
				stack = stack,
				reducedMotion = props.reducedMotion,
				zIndex = 30,
			}),
		})
		if #codexBrowse.results == 0 then
			table.insert(sections, {
				id = "none",
				height = 220,
				element = h(Browse.NoResults, {
					browse = codexBrowse,
					noun = "relics",
					icon = "Artifact",
					accent = Palette.mint,
					reducedMotion = props.reducedMotion,
					size = UDim2.fromScale(1, 1),
				}),
			})
		end
		for index = #RelicSystem.ORDER, 1, -1 do
			local rarity = RelicSystem.ORDER[index]
			local cells = {}
			local count = 0
			for order, definition in definitions do
				if definition.Rarity ~= rarity or not shownIds[definition.Id] then
					continue
				end
				count += 1
				local canFuse = canFuseRelic(definition)
				cells[definition.Id] = h(RelicCell, {
					definition = definition,
					order = order,
					config = config,
					found = discovered[definition.Id] == true or (copies[definition.Id] or 0) > 0,
					copies = copies[definition.Id] or 0,
					stars = stars[definition.Id] or 0,
					canFuse = canFuse,
					busy = busy,
					onFuse = function()
						fuse(definition)
					end,
					reducedMotion = props.reducedMotion,
				})
			end
			if count == 0 then
				continue
			end
			local gridH = rowsHeight(count, columns, cellH)
			local color = rarityColor(config, rarity)
			table.insert(sections, {
				id = `label{rarity}`,
				height = 22,
				element = h(Text, {
					value = `{string.upper(rarity)}  Ã‚Â·  {progress[rarity].found}/{progress[rarity].total}`,
					size = 13,
					color = color,
					weight = Enum.FontWeight.Heavy,
					sizeConstraint = UDim2.new(1, 0, 0, 20),
				}),
			})
			table.insert(sections, {
				id = `grid{rarity}`,
				height = gridH,
				element = h(Grid, { columns = columns, cell = cellH, height = gridH, cells = cells }),
			})
		end
		return React.createElement(PageScaffold, {
			gap = GAP,
			tailPad = props.tailPad,
			scrollBarColor = Palette.mint,
			sections = sections,
		})
	end

	local function StoreFront(props)
		local viewport = useViewport()
		local chrome = chromeFor(viewport)
		local stack = chrome.contentStack
		local softMotion = props.reducedMotion
		local linked = Browse.Model.recall("Shop")
		local section, setSection = React.useState(props.initialSection or (linked and linked.category) or "Daily")
		-- Quick Find opens a section directly ("crates", "codex", "skins" ...)
		React.useEffect(function()
			return Browse.Model.listen("Shop", function(entry)
				if entry.category ~= nil then
					setSection(entry.category)
				end
			end)
		end, {})
		React.useEffect(function()
			Browse.Model.remember("Shop", { query = "", category = section })
		end, { section })
		local reveal = useStagger(0, softMotion)
		local tabH = if stack then TapTarget else 44
		local shared = {
			key = section,
			state = props.state or {},
			config = props.config or {},
			dispatch = props.dispatch,
			reducedMotion = softMotion,
			stack = stack,
			width = viewport.width,
			reveal = reveal,
			tailPad = scrollTail(stack, chrome.bottomSafe, 32),
			navigate = props.navigate,
			onCrateReveal = props.onCrateReveal,
			crateRevealActive = props.crateRevealActive,
		}
		local body
		if section == "Daily" then
			body = h(DailySection, shared)
		elseif section == "Crates" then
			body = h(CratesSection, shared)
		elseif section == "Skins" then
			body = h(SkinsSection, shared)
		elseif section == "Codex" then
			body = h(CodexSection, shared)
		else
			body = h(__load("ShopView").ShopView, {
				state = props.state,
				dispatch = props.dispatch,
				reducedMotion = softMotion,
				onPurchasePresentationChange = props.onPurchasePresentationChange,
			})
		end
		return h(
			"frame",
			{
				Name = "StoreFrontHost",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
			},
			h(
				"frame",
				{
					Name = "StoreSections",
					Size = UDim2.new(1, 0, 0, tabH),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				},
				h(SegmentedTabs, {
					options = SECTIONS,
					value = section,
					onChange = function(entry)
						setSection(entry)
					end,
					accent = Palette.mango,
					columns = #SECTIONS,
					gap = 6,
					size = UDim2.fromScale(1, 1),
					reducedMotion = softMotion,
				})
			),
			h("frame", {
				Name = "StoreSection",
				Size = UDim2.new(1, 0, 1, -(tabH + GAP)),
				Position = UDim2.fromOffset(0, tabH + GAP),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
			}, body)
		)
	end

	return {
		StoreFront = StoreFront,
	}
end

__defs["WheelView"] = function()
	local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
	local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
	local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
	local _format = require(script.Parent.Parent.CoreKit)("format")
	local clockText = _format.clockText
	local compactNumber = _format.compactNumber
	local formatReward = _format.formatReward
	local _Icon = require(script.Parent.Parent.ArtKit)("Icon")
	local Icon = _Icon.Icon
	local WheelPrizeViewport = _Icon.WheelPrizeViewport
	local prizeShapeFromReward = _Icon.prizeShapeFromReward
	local InteractionFeedback = require(script.Parent.Parent.CoreKit)("interaction").InteractionFeedback
	local _motion = require(script.Parent.Parent.MotionKit)("motion")
	local useFlash = _motion.useFlash
	local useGlowStroke = _motion.useGlowStroke
	local useRotation = _motion.useRotation
	local useStagger = _motion.useStagger
	local useViewport = _motion.useViewport
	local useWallClock = _motion.useWallClock
	local _theme = require(script.Parent.Parent.CoreKit)("theme")
	local Layout = _theme.Layout
	local Palette = _theme.Palette
	local chromeFor = _theme.chromeFor
	local darken = _theme.darken
	local lighten = _theme.lighten
	local scrollTail = _theme.scrollTail
	local surfaceGradient = _theme.surfaceGradient
	local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
	local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
	local _ui = require(script.Parent.Parent.UiCore)("ui")
	local Badge = _ui.Badge
	local Button = _ui.Button
	local Meter = _ui.Meter
	local Panel = _ui.Panel
	local Text = _ui.Text
	local IMPACT_RAYS = { 0, 60, 120, 180, 240, 300 }
	local RIM_NOTCHES = { 0, 45, 90, 135, 180, 225, 270, 315 }
	local WHEEL_OMEGA = 1440
	local WHEEL_OMEGA_LOW = 1080
	local WHEEL_LAUNCH_SECONDS = 0.65
	local WHEEL_MIN_CRUISE_SECONDS = 0.35
	local WHEEL_WINDUP_SECONDS = 0.26
	local WHEEL_WINDUP_DEGREES = 16
	local WHEEL_SETTLE_DEGREES = 2.6
	local function sampleSpin(plan, elapsed)
		local omega = plan.omega
		if elapsed < WHEEL_WINDUP_SECONDS then
			local u = elapsed / WHEEL_WINDUP_SECONDS
			return plan.base - WHEEL_WINDUP_DEGREES * math.sin(u * math.pi / 2), 0
		end
		local start = plan.base - WHEEL_WINDUP_DEGREES
		local launched = elapsed - WHEEL_WINDUP_SECONDS
		if launched < WHEEL_LAUNCH_SECONDS then
			return start + omega * launched * launched / (2 * WHEEL_LAUNCH_SECONDS),
				omega * launched / WHEEL_LAUNCH_SECONDS
		end
		return start + omega * WHEEL_LAUNCH_SECONDS / 2 + omega * (launched - WHEEL_LAUNCH_SECONDS), omega
	end
	local function positiveModulo(value, modulus)
		return ((value % modulus) + modulus) % modulus
	end
	local function useWheelController(_param)
		local state = _param.state
		local config = _param.config
		local dispatch = _param.dispatch
		local reducedMotion = _param.reducedMotion
		local onLand = _param.onLand
		local antilag = useAntilag()
		local rewardCount = math.max(1, #config.Wheel.Rewards)
		local segment = 360 / rewardCount
		local phase, setPhase = React.useState("idle")
		local winner, setWinner = React.useState(-1)
		local failure, setFailure = React.useState()
		local launchNonce, setLaunchNonce = React.useState(0)
		local impactNonce, setImpactNonce = React.useState(0)
		local rotation, setRotation = React.useBinding(0)
		local pointerKick, setPointerKick = React.useBinding(0)
		local spinEnergy, setSpinEnergy = React.useBinding(0)
		local rotationValue = React.useRef(0)
		local pointerKickValue = React.useRef(0)
		local busy = React.useRef(false)
		local mounted = React.useRef(true)
		local token = React.useRef(0)
		local timeout = React.useRef()
		local pendingResult = React.useRef()
		local launchFinished = React.useRef(false)
		local beginBrakeRef = React.useRef(function()
			return nil
		end)
		local motor = React.useRef({
			active = false,
			mode = "spin",
			base = 0,
			omega = WHEEL_OMEGA,
			startedAt = 0,
			lastSegment = 0,
			lastSoundAt = -math.huge,
		})
		local omegaRef = React.useRef(WHEEL_OMEGA)
		omegaRef.current = if antilag.tier <= 1 then WHEEL_OMEGA_LOW else WHEEL_OMEGA
		local spinning = phase == "launch" or phase == "coast" or phase == "brake"
		local audioTicks = not reducedMotion and antilag.fxBudget > 0.22
		local audioTicksRef = React.useRef(audioTicks)
		audioTicksRef.current = audioTicks
		local completeLanding = React.useCallback(function(result, finalRotation)
			if not mounted.current or not busy.current then
				return nil
			end
			local normalized = positiveModulo(finalRotation, 360)
			rotationValue.current = normalized
			pointerKickValue.current = 0
			setRotation(normalized)
			setPointerKick(0)
			setSpinEnergy(0)
			setWinner(result.index)
			setImpactNonce(function(value)
				return value + 1
			end)
			setPhase("landed")
			busy.current = false
			pendingResult.current = nil
			Audio:play("wheelLand")
			InteractionFeedback.reward()
			local _result = onLand
			if _result ~= nil then
				_result(result.message)
			end
		end, { onLand, setPointerKick, setRotation, setSpinEnergy })
		local beginBrake = React.useCallback(function(result)
			if not mounted.current or not busy.current then
				return nil
			end
			local wanted = positiveModulo(360 - result.index * segment, 360)
			if reducedMotion then
				Audio:play("wheelBrake")
				completeLanding(result, wanted)
				return nil
			end
			local now = os.clock()
			local plan = motor.current
			local current, speed = sampleSpin(plan, now - plan.startedAt)
			local delta = positiveModulo(wanted - positiveModulo(current, 360), 360)
			local distance = (if antilag.tier <= 1 then 720 else 1080) + delta
			motor.current = {
				active = true,
				mode = "brake",
				base = current,
				omega = plan.omega,
				distance = distance,
				duration = 3 * distance / math.max(speed, 240),
				startedAt = now,
				lastSegment = math.floor(current / segment),
				lastSoundAt = plan.lastSoundAt,
				result = result,
			}
			rotationValue.current = current
			setPhase("brake")
			Audio:play("wheelBrake")
		end, { antilag.tier, completeLanding, reducedMotion, segment })
		beginBrakeRef.current = beginBrake
		React.useEffect(function()
			if not spinning then
				return nil
			end
			local connection = RunService.RenderStepped:Connect(function(deltaTime)
				if pointerKickValue.current > 0 then
					pointerKickValue.current = math.max(0, pointerKickValue.current - deltaTime * 11.5)
					setPointerKick(pointerKickValue.current)
				end
				local plan = motor.current
				if not plan.active then
					return nil
				end
				local now = os.clock()
				local elapsed = now - plan.startedAt
				local braking = plan.mode == "brake"
				local value, speed, progress
				if braking then
					progress = math.clamp(elapsed / plan.duration, 0, 1)
					local remaining = 1 - progress
					local settle = WHEEL_SETTLE_DEGREES * math.sin(math.pi * math.clamp((progress - 0.84) / 0.16, 0, 1))
					value = plan.base + plan.distance * (1 - remaining * remaining * remaining) - settle
					speed = 3 * plan.distance / plan.duration * remaining * remaining
				else
					progress = 0
					value, speed = sampleSpin(plan, elapsed)
				end
				rotationValue.current = value
				setRotation(value)
				setSpinEnergy(math.clamp(speed / plan.omega, 0, 1))
				local currentSegment = math.floor(value / segment)
				if currentSegment ~= plan.lastSegment then
					plan.lastSegment = currentSegment
					pointerKickValue.current = if braking and progress > 0.66 then 1 else 0.58
					setPointerKick(pointerKickValue.current)
					local interval = if braking then 0.06 + progress * 0.16 else 0.14
					if audioTicksRef.current and now - plan.lastSoundAt >= interval then
						plan.lastSoundAt = now
						Audio:play(
							if braking and progress > 0.65 then "wheelSlow" else "wheelTick",
							0.92 + (1 - progress) * 0.16
						)
					end
				end
				if not braking then
					local result = pendingResult.current
					if
						result ~= nil
						and elapsed >= WHEEL_WINDUP_SECONDS + WHEEL_LAUNCH_SECONDS + WHEEL_MIN_CRUISE_SECONDS
					then
						beginBrakeRef.current(result)
					end
					return nil
				end
				if progress >= 1 then
					plan.active = false
					completeLanding(plan.result, plan.base + plan.distance)
				end
			end)
			return function()
				return connection:Disconnect()
			end
		end, { completeLanding, segment, setPointerKick, setRotation, setSpinEnergy, spinning })
		React.useEffect(function()
			return function()
				mounted.current = false
				busy.current = false
				token.current += 1
				motor.current.active = false
				motor.current.onComplete = nil
				if timeout.current ~= nil then
					pcall(task.cancel, timeout.current)
				end
			end
		end, {})
		local spin = function()
			if busy.current or not state.Wheel.CanSpin then
				return nil
			end
			busy.current = true
			local requestToken = token.current + 1
			token.current = requestToken
			pendingResult.current = nil
			launchFinished.current = false
			pointerKickValue.current = 0
			setPointerKick(0)
			setWinner(-1)
			setFailure(nil)
			setLaunchNonce(function(value)
				return value + 1
			end)
			Audio:play("wheelStart")
			InteractionFeedback.tap()
			if reducedMotion then
				launchFinished.current = true
				motor.current.active = false
				setPhase("coast")
			else
				motor.current = {
					active = true,
					mode = "spin",
					base = rotationValue.current,
					omega = omegaRef.current,
					startedAt = os.clock(),
					lastSegment = math.floor(rotationValue.current / segment),
					lastSoundAt = -math.huge,
				}
				setPhase("launch")
			end
			if timeout.current ~= nil then
				pcall(task.cancel, timeout.current)
			end
			timeout.current = task.delay(12, function()
				timeout.current = nil
				if not mounted.current or token.current ~= requestToken or not busy.current then
					return nil
				end
				token.current += 1
				busy.current = false
				pendingResult.current = nil
				motor.current.active = false
				pointerKickValue.current = 0
				setPointerKick(0)
				setSpinEnergy(0)
				setPhase("error")
				setFailure("That spin took too long. Check Rewards before trying again.")
				Audio:play("requestTimeout")
			end)
			dispatch("SpinWheel", {}, function(response)
				if not mounted.current or token.current ~= requestToken then
					return nil
				end
				if timeout.current ~= nil then
					pcall(task.cancel, timeout.current)
					timeout.current = nil
				end
				if not response.ok or response.PrizeIndex == nil then
					busy.current = false
					pendingResult.current = nil
					motor.current.active = false
					pointerKickValue.current = 0
					setPointerKick(0)
					setSpinEnergy(0)
					setPhase("error")
					local _condition = response.error
					if _condition == nil then
						_condition = "The draw could not be completed."
					end
					setFailure(_condition)
					Audio:play("error")
					return nil
				end
				local result = {
					index = math.clamp(math.floor(response.PrizeIndex) - 1, 0, rewardCount - 1),
					message = response.message,
				}
				pendingResult.current = result
				if reducedMotion then
					beginBrakeRef.current(result)
				end
			end)
		end
		return {
			phase = phase,
			spinning = spinning,
			winner = winner,
			failure = failure,
			launchNonce = launchNonce,
			impactNonce = impactNonce,
			rotation = rotation,
			pointerKick = pointerKick,
			spinEnergy = spinEnergy,
			spin = spin,
		}
	end
	local function WheelBurst(_param)
		local flash = _param.flash
		local active = _param.active
		local accent = _param.accent
		local budget = _param.budget
		local launch = _param.launch
		if launch == nil then
			launch = false
		end
		local contained = _param.contained
		if contained == nil then
			contained = false
		end
		if not active then
			return React.createElement(React.Fragment)
		end
		local ringCount = if launch then (if budget >= 0.55 then 2 else 1) elseif budget >= 0.3 then 2 else 1
		local rings = {}
		for index = 0, ringCount - 1 do
			local _index = index
			table.insert(rings, _index)
		end
		local overscan = if contained then 0 else 80
		local _exp = not launch
			and React.createElement(
				"frame",
				{
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Palette.cream,
					BackgroundTransparency = flash:map(function(amount)
						return 1 - amount * (0.035 + budget * 0.025)
					end),
					BorderSizePixel = 0,
				},
				React.createElement("uicorner", {
					CornerRadius = UDim.new(1, 0),
				})
			)
		local _newValue = table.create(#rings)
		local _callback = function(ring)
			return React.createElement(
				"frame",
				{
					key = `ring-{ring}`,
					Size = flash:map(function(amount)
						local decay = 1 - amount
						local freeScale = 0.64 + ring * 0.14 + decay * (0.48 + ring * 0.14)
						local scale = if contained
							then math.min(0.96, 0.54 + ring * 0.08 + decay * (0.3 + ring * 0.05))
							else freeScale
						return UDim2.fromScale(scale, scale)
					end),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Rotation = ring * 17,
				},
				React.createElement("uicorner", {
					CornerRadius = UDim.new(1, 0),
				}),
				React.createElement("uistroke", {
					Color = if ring == 1 then Palette.cream else accent,
					Thickness = if ring == 0 then 2.2 else 1.25,
					Transparency = flash:map(function(amount)
						return 1 - amount * (0.58 - ring * 0.1)
					end),
				})
			)
		end
		for _k, _v in rings do
			_newValue[_k] = _callback(_v, _k - 1, rings)
		end
		local _condition = not launch and budget >= 0.62
		if _condition then
			local _newValue_1 = table.create(#IMPACT_RAYS)
			local _callback_1 = function(angle, index)
				return React.createElement(
					"frame",
					{
						key = `ray-{angle}`,
						Size = flash:map(function(amount)
							return UDim2.new(
								0,
								((if contained then 38 else 50) + index % 3 * (if contained then 10 else 16))
									* (1 - amount),
								0,
								2
							)
						end),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0, 0.5),
						Rotation = angle + 5,
						BackgroundColor3 = if index % 3 == 0
							then Palette.cream
							elseif index % 2 == 0 then accent
							else Palette.cyan,
						BackgroundTransparency = flash:map(function(amount)
							return 1 - amount * 0.48
						end),
						BorderSizePixel = 0,
					},
					React.createElement("uigradient", {
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.08),
							NumberSequenceKeypoint.new(1, 1),
						}),
					})
				)
			end
			for _k, _v in IMPACT_RAYS do
				_newValue_1[_k] = _callback_1(_v, _k - 1, IMPACT_RAYS)
			end
			_condition = _newValue_1
		end
		return React.createElement("frame", {
			Size = UDim2.new(1, overscan, 1, overscan),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = false,
			ZIndex = 70,
		}, _exp, _newValue, _condition)
	end
	local function FlatPrizeWheel(_param)
		local rewards = _param.rewards
		local controller = _param.controller
		local diameter = _param.diameter
		local canSpin = _param.canSpin
		local reducedMotion = _param.reducedMotion
		local containedEffects = _param.containedEffects
		if containedEffects == nil then
			containedEffects = false
		end
		local antilag = useAntilag()
		local softMotion = reducedMotion
		local count = math.max(1, #rewards)
		local segment = 360 / count
		local innerDiameter = math.floor(diameter * 0.84)
		local compactMachine = diameter < 230
		local roughRadius = innerDiameter / 2 - 24
		local span = (2 * math.pi * math.max(48, roughRadius)) / count
		local medallionSize = math.floor(math.clamp(math.min(diameter * 0.11, span * 0.56), 22, 40))
		local hubSize = math.floor(math.clamp(diameter * 0.2, if compactMachine then 52 else 60, 84))
		local orbitRadius = innerDiameter / 2 - medallionSize / 2 - 10
		local landing = useFlash(controller.impactNonce, reducedMotion, if antilag.tier < 1 then 0.34 else 0.56)
		local launch = useFlash(controller.launchNonce, reducedMotion, 0.58)
		local decorateOrbit = true
		local hubStroke = useGlowStroke(
			canSpin and not controller.spinning and decorateOrbit,
			reducedMotion or not decorateOrbit,
			0.58,
			0.12,
			0.7,
			1.8
		)
		local idleOrbit = useRotation(not reducedMotion and not controller.spinning and canSpin and decorateOrbit, 5.5)
		local reverseOrbit = idleOrbit:map(function(angle)
			return -angle * 0.62
		end)
		local carrierScale = React.joinBindings({
			landing = landing,
			launch = launch,
			energy = controller.spinEnergy,
		}):map(function(_param_1)
			local hit = _param_1.landing
			local start = _param_1.launch
			local energy = _param_1.energy
			return 1 + hit * (0.045 + antilag.fxBudget * 0.025) - start * 0.025 + energy * 0.012
		end)
		local carrierPosition = React.joinBindings({
			landing = landing,
			energy = controller.spinEnergy,
		}):map(function(_param_1)
			local hit = _param_1.landing
			local energy = _param_1.energy
			return UDim2.new(
				0.5,
				0,
				0.5,
				-math.round(energy * 2) + math.round(math.sin((1 - hit) * math.pi * 3) * hit * 3)
			)
		end)
		local pointerScale = React.joinBindings({
			tick = controller.pointerKick,
			landing = landing,
		}):map(function(_param_1)
			local tick = _param_1.tick
			local hit = _param_1.landing
			return 1 + tick * 0.16 + hit * 0.22
		end)
		local pointerY = React.joinBindings({
			tick = controller.pointerKick,
			landing = landing,
		}):map(function(_param_1)
			local tick = _param_1.tick
			local hit = _param_1.landing
			return UDim2.new(0.5, 0, 0, 10 - tick * 3 - hit * 3)
		end)
		local wheelGlow = controller.spinEnergy:map(function(energy)
			return 0.95 - energy * 0.16 * antilag.glowScale
		end)
		local _exp = React.createElement(WheelBurst, {
			flash = launch,
			active = controller.launchNonce > 0 and not reducedMotion,
			accent = Palette.mango,
			budget = antilag.fxBudget,
			launch = true,
			contained = containedEffects,
		})
		local _attributes = {
			flash = landing,
			active = controller.impactNonce > 0 and not reducedMotion,
		}
		local _result = rewards[controller.winner + 1]
		if _result ~= nil then
			_result = _result.Color
		end
		local _condition = _result
		if _condition == nil then
			_condition = Palette.mango
		end
		_attributes.accent = _condition
		_attributes.budget = antilag.fxBudget
		_attributes.contained = containedEffects
		local _exp_1 = React.createElement(WheelBurst, _attributes)
		local _exp_2 = React.createElement("uiscale", {
			Scale = carrierScale,
		})
		local _exp_3 = React.createElement(
			"frame",
			{
				Size = UDim2.new(1, -16, 1, -16),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = idleOrbit,
				BackgroundColor3 = Palette.mango,
				BackgroundTransparency = wheelGlow,
				BorderSizePixel = 0,
				ZIndex = 0,
			},
			React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			React.createElement("uigradient", {
				Color = ColorSequence.new(Palette.cyan, Palette.mango),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.08),
					NumberSequenceKeypoint.new(0.5, 0.9),
					NumberSequenceKeypoint.new(1, 0.08),
				}),
			})
		)
		local _exp_4 = React.createElement(
			"frame",
			{
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Palette.panel,
				BorderSizePixel = 0,
				ZIndex = 1,
			},
			React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			React.createElement("uigradient", {
				Color = surfaceGradient(Palette.panelRaised, 0.72),
				Rotation = 90,
			}),
			React.createElement("uistroke", {
				Color = Palette.lineSoft,
				Thickness = 2,
				Transparency = 0.2,
			})
		)
		local _exp_5 = React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})
		local _exp_6 = React.createElement("uistroke", {
			Color = Palette.mango,
			Thickness = 2,
			Transparency = 0.46,
		})
		local _newValue = table.create(#RIM_NOTCHES)
		local _callback = function(angle)
			return React.createElement(
				"frame",
				{
					key = `rim-{angle}`,
					Size = UDim2.fromScale(1, 1),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = angle,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				},
				React.createElement(
					"frame",
					{
						Size = UDim2.fromOffset(if angle % 90 == 0 then 20 else 12, 4),
						Position = UDim2.new(0.5, 0, 0, -2),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = if angle % 90 == 0 then Palette.mango else Palette.creamSoft,
						BackgroundTransparency = 0.16,
						BorderSizePixel = 0,
					},
					React.createElement("uicorner", {
						CornerRadius = UDim.new(1, 0),
					})
				)
			)
		end
		for _k, _v in RIM_NOTCHES do
			_newValue[_k] = _callback(_v, _k - 1, RIM_NOTCHES)
		end
		local _exp_7 = React.createElement("frame", {
			Size = UDim2.new(1, -14, 1, -14),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Rotation = reverseOrbit,
			ZIndex = 2,
		}, _exp_5, _exp_6, _newValue)
		local _exp_8 = React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})
		local _exp_9 = React.createElement("uigradient", {
			Color = ColorSequence.new(lighten(Palette.panel, 0.04), darken(Palette.ink, 0.22)),
			Rotation = 90,
		})
		local _exp_10 = React.createElement("uistroke", {
			Color = Palette.creamSoft,
			Thickness = 1,
			Transparency = 0.62,
		})
		local _exp_11 = React.createElement(
			"frame",
			{
				Size = UDim2.fromScale(0.66, 0.66),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			},
			React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			React.createElement("uistroke", {
				Color = Palette.lineSoft,
				Thickness = 1,
				Transparency = 0.66,
			})
		)
		local _newValue_1 = table.create(#rewards)
		local _callback_1 = function(reward, index)
			return React.createElement(
				"frame",
				{
					key = `divider-{reward.Id}`,
					Size = UDim2.fromScale(1, 1),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = index * segment - segment / 2,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				},
				React.createElement(
					"frame",
					{
						Size = UDim2.fromOffset(2, orbitRadius - hubSize * 0.22),
						Position = UDim2.new(0.5, 0, 0.5, -(orbitRadius - hubSize * 0.22) / 2),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = reward.Color,
						BackgroundTransparency = 0.58,
						BorderSizePixel = 0,
					},
					React.createElement("uigradient", {
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.15),
							NumberSequenceKeypoint.new(1, 1),
						}),
					})
				)
			)
		end
		for _k, _v in rewards do
			_newValue_1[_k] = _callback_1(_v, _k - 1, rewards)
		end
		local _newValue_2 = table.create(#rewards)
		local _callback_2 = function(reward, index)
			local won = controller.winner == index
			local counterRotation = controller.rotation:map(function(turn)
				return -(turn + index * segment)
			end)
			return React.createElement(
				"frame",
				{
					key = reward.Id,
					Size = UDim2.fromScale(1, 1),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = index * segment,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 4,
				},
				React.createElement(
					"frame",
					{
						Size = UDim2.new(0, medallionSize + 16, 0, 5),
						Position = UDim2.new(0.5, 0, 0.5, -orbitRadius - 4),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = reward.Color,
						BackgroundTransparency = if won then 0.02 else 0.26,
						BorderSizePixel = 0,
					},
					React.createElement("uicorner", {
						CornerRadius = UDim.new(1, 0),
					}),
					React.createElement("uigradient", {
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(0.24, 0),
							NumberSequenceKeypoint.new(0.76, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					})
				),
				React.createElement(
					"frame",
					{
						Size = UDim2.fromOffset(medallionSize, medallionSize),
						Position = UDim2.new(0.5, 0, 0.5, -orbitRadius),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Rotation = counterRotation,
						BackgroundColor3 = darken(reward.Color, 0.72):Lerp(Palette.panelRaised, 0.42),
						BorderSizePixel = 0,
						ClipsDescendants = false,
					},
					won
						and React.createElement("uiscale", {
							Scale = landing:map(function(amount)
								return 1 + amount * 0.18
							end),
						}),
					React.createElement("uicorner", {
						CornerRadius = UDim.new(0, math.floor(medallionSize * 0.28)),
					}),
					React.createElement("uigradient", {
						Color = ColorSequence.new(
							lighten(Palette.panelRaised, 0.08),
							darken(Palette.panelRaised, 0.22)
						),
						Rotation = 90,
					}),
					React.createElement("uistroke", {
						Color = if won then Palette.cream else reward.Color,
						Thickness = if won then 2.5 else 1.25,
						Transparency = if won then 0.02 else 0.18,
					}),
					React.createElement(
						"frame",
						{
							Size = UDim2.new(1, -8, 1, -8),
							Position = UDim2.fromOffset(4, 4),
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
						},
						React.createElement(WheelPrizeViewport, {
							color = reward.Color,
							shape = prizeShapeFromReward(reward.Reward, reward.Rarity),
							size = medallionSize - 8,
							spin = won and not reducedMotion,
						})
					)
				)
			)
		end
		for _k, _v in rewards do
			_newValue_2[_k] = _callback_2(_v, _k - 1, rewards)
		end
		return React.createElement(
			"frame",
			{
				Size = UDim2.fromOffset(diameter, diameter),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
			},
			_exp,
			_exp_1,
			React.createElement(
				"frame",
				{
					Size = UDim2.fromScale(1, 1),
					Position = carrierPosition,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = false,
				},
				_exp_2,
				_exp_3,
				_exp_4,
				_exp_7,
				React.createElement("frame", {
					Size = UDim2.fromOffset(innerDiameter, innerDiameter),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = controller.rotation,
					BackgroundColor3 = Palette.ink,
					BorderSizePixel = 0,
					ClipsDescendants = false,
					ZIndex = 3,
				}, _exp_8, _exp_9, _exp_10, _exp_11, _newValue_1, _newValue_2),
				React.createElement(
					"frame",
					{
						Size = UDim2.fromOffset(hubSize + 16, hubSize + 16),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Palette.shadow,
						BackgroundTransparency = 0.12,
						BorderSizePixel = 0,
						ZIndex = 6,
					},
					React.createElement("uicorner", {
						CornerRadius = UDim.new(1, 0),
					}),
					React.createElement("uistroke", {
						Color = Palette.mango,
						Thickness = 2,
						Transparency = 0.5,
					})
				),
				React.createElement(
					"frame",
					{
						Size = UDim2.fromOffset(hubSize, hubSize),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Palette.panelRaised,
						BorderSizePixel = 0,
						ZIndex = 7,
					},
					React.createElement("uicorner", {
						CornerRadius = UDim.new(1, 0),
					}),
					React.createElement("uigradient", {
						Color = surfaceGradient(Palette.panelRaised, 0.75),
						Rotation = 90,
					}),
					React.createElement("uistroke", {
						Color = Palette.mango,
						Thickness = 3,
						Transparency = hubStroke,
					}),
					React.createElement(Icon, {
						kind = "Wheel",
						color = Palette.cream,
						accent = Palette.mango,
						size = math.floor(hubSize * 0.58),
						position = UDim2.fromScale(0.5, 0.5),
						anchorPoint = Vector2.new(0.5, 0.5),
						spin = controller.spinning,
						clipSafe = true,
						reducedMotion = reducedMotion,
					})
				)
			),
			React.createElement(
				"frame",
				{
					Size = UDim2.fromOffset(38, 42),
					Position = pointerY,
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 90,
					ClipsDescendants = false,
				},
				React.createElement("uiscale", {
					Scale = pointerScale,
				}),
				React.createElement(
					"frame",
					{
						Size = UDim2.fromOffset(28, 18),
						Position = UDim2.fromOffset(19, 2),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Palette.panelSoft,
						BorderSizePixel = 0,
					},
					React.createElement("uicorner", {
						CornerRadius = UDim.new(0, 7),
					}),
					React.createElement("uistroke", {
						Color = Palette.creamSoft,
						Thickness = 1,
						Transparency = 0.28,
					})
				),
				React.createElement(
					"frame",
					{
						Size = UDim2.fromOffset(20, 20),
						Position = UDim2.fromOffset(19, 18),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Rotation = 45,
						BackgroundColor3 = Palette.mango,
						BorderSizePixel = 0,
						ZIndex = 91,
					},
					React.createElement("uicorner", {
						CornerRadius = UDim.new(0, 5),
					}),
					React.createElement("uistroke", {
						Color = Palette.cream,
						Thickness = 2,
						Transparency = 0.08,
					})
				),
				React.createElement(
					"frame",
					{
						Size = UDim2.fromOffset(7, 7),
						Position = UDim2.fromOffset(19, 18),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Palette.ink,
						BorderSizePixel = 0,
						ZIndex = 92,
					},
					React.createElement("uicorner", {
						CornerRadius = UDim.new(1, 0),
					})
				)
			)
		)
	end
	local _kit = require(script.Parent.Parent.UiCore)("crateModel")
	local kitPiece = _kit.kitPiece
	local useKitReady = _kit.useKitReady
	local kitFolder = _kit.kitFolder
	local subscribeContinuous = _motion.subscribeContinuous
	local KIT_WEDGE_LIFT = 1.4714
	local KIT_WEDGE_DEPTH = -0.025
	local KIT_FACE_DEPTH = -0.125
	local KIT_FRAME_DEPTH = 0.005
	local KIT_POINTER_HINGE = 2.98
	local KIT_POINTER_CENTRE = 0.0838
	local KIT_POINTER_PIN = 0.42
	local KIT_BULB_RADIUS = 2.74
	local KIT_BULB_COUNT = 24
	local KIT_HALF_VIEW = 3.3
	local KIT_CAMERA_DISTANCE = 15
	local KIT_ICON_RADIUS = 1.5
	local BULB_WARM = Color3.fromRGB(255, 236, 190)
	local BULB_GOLD = Color3.fromRGB(255, 186, 72)
	local BULB_OFF = Color3.fromRGB(70, 44, 30)
	local PRIZE_LIGHT = Vector3.new(-0.35, -0.55, 1)
	local function prizeIcon(reward)
		local prize = reward.Reward or {}
		if reward.Rarity == "MYTHIC" then
			return "Casino_Nova"
		elseif prize.Cores ~= nil then
			return "Casino_Core"
		elseif prize.Stardust ~= nil then
			return "Casino_Dust"
		elseif prize.Boost == "Hyperdrive" then
			return "Casino_Star"
		elseif prize.Boost ~= nil then
			return "Casino_Comet"
		end
		return "Casino_Coin"
	end
	local function wheelCamera(viewport, roll)
		local camera = viewport.CurrentCamera
		if camera == nil then
			return
		end
		local spin = CFrame.Angles(0, 0, -math.rad(roll))
		camera.CFrame = spin * CFrame.lookAt(Vector3.new(0, 0, -KIT_CAMERA_DISTANCE), Vector3.zero)
		viewport.LightDirection = spin:VectorToWorldSpace(PRIZE_LIGHT)
	end
	local function newViewportCamera(viewport)
		viewport:ClearAllChildren()
		local camera = Instance.new("Camera")
		camera.FieldOfView = math.deg(2 * math.atan(KIT_HALF_VIEW / KIT_CAMERA_DISTANCE))
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local model = Instance.new("Model")
		model.Parent = viewport
		return model
	end
	local function buildSpinningWheel(viewport, rewards)
		local model = newViewportCamera(viewport)
		local count = math.max(1, #rewards)
		local face = kitPiece("Casino_PrizeFace")
		if face ~= nil then
			face.CFrame = CFrame.new(0, 0, KIT_FACE_DEPTH)
			face.Parent = model
		end
		local wedges = {}
		for index, reward in rewards do
			local angle = math.rad((index - 1) * 360 / count)
			local wedge = kitPiece("Casino_PrizeWedge")
			if wedge ~= nil then
				for _, child in wedge:GetChildren() do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
				pcall(function()
					wedge.TextureID = ""
				end)
				wedge.Material = Enum.Material.SmoothPlastic
				wedge.Color = Palette.panel:Lerp(reward.Color, 0.55)
				wedge.CFrame = CFrame.Angles(0, 0, angle) * CFrame.new(0, KIT_WEDGE_LIFT, KIT_WEDGE_DEPTH)
				wedge.Parent = model
				wedges[index] = wedge
			end
			-- Prize artwork lives in the result card; sectors stay unobstructed.
		end
		return { wedges = wedges }
	end
	local function buildStaticWheel(viewport)
		local model = newViewportCamera(viewport)
		local frame = kitPiece("Casino_PrizeFrame")
		if frame ~= nil then
			for _, child in frame:GetChildren() do
				if child:IsA("SurfaceAppearance") then
					child:Destroy()
				end
			end
			pcall(function()
				frame.TextureID = ""
			end)
			frame.Color = Palette.steel
			frame.Material = Enum.Material.Metal
			frame.CFrame = CFrame.new(0, 0, KIT_FRAME_DEPTH)
			frame.Parent = model
		end
		local bulbs = {}
		for k = 0, KIT_BULB_COUNT - 1 do
			local a = math.rad(360 * k / KIT_BULB_COUNT)
			local bulb = Instance.new("Part")
			bulb.Shape = Enum.PartType.Ball
			bulb.Size = Vector3.one * 0.15
			bulb.Anchored = true
			bulb.CanCollide = false
			bulb.CanQuery = false
			bulb.CanTouch = false
			bulb.CastShadow = false
			bulb.Material = Enum.Material.Neon
			bulb.Color = BULB_OFF
			bulb.CFrame = CFrame.new(-math.sin(a) * KIT_BULB_RADIUS, math.cos(a) * KIT_BULB_RADIUS, -0.2)
			bulb.Parent = model
			bulbs[k + 1] = bulb
		end
		local pointer = kitPiece("Casino_PrizePointer")
		local hinge = CFrame.new(0, KIT_POINTER_HINGE, -0.46)
		if pointer ~= nil then
			for _, child in pointer:GetChildren() do
				if child:IsA("SurfaceAppearance") then
					child:Destroy()
				end
			end
			pcall(function()
				pointer.TextureID = ""
			end)
			pointer.Color = Palette.cyan
			pointer.Material = Enum.Material.Metal
			pointer.CFrame = hinge * CFrame.new(0, KIT_POINTER_CENTRE - KIT_POINTER_PIN, 0)
			pointer.Parent = model
		end
		return { bulbs = bulbs, pointer = pointer, hinge = hinge }
	end
	local function bulbPattern(phase, mode)
		local lit = {}
		if mode == "celebrate" then
			local on = math.floor(phase * 8) % 2 == 0
			for k = 1, KIT_BULB_COUNT do
				lit[k] = on
			end
			return lit, if on then 1 else 0
		end
		local step = math.floor(phase)
		for k = 1, KIT_BULB_COUNT do
			lit[k] = (k + step) % 3 == 0
		end
		return lit, step
	end
	local function KitPrizeWheel(_param)
		local rewards = _param.rewards
		local controller = _param.controller
		local diameter = _param.diameter
		local canSpin = _param.canSpin
		local reducedMotion = _param.reducedMotion
		local containedEffects = _param.containedEffects == true
		local antilag = useAntilag()
		local count = math.max(1, #rewards)
		local spinHost = React.useRef(nil)
		local staticHost = React.useRef(nil)
		local scenes = React.useRef({})
		local live = React.useRef({})
		live.current.controller = controller
		live.current.reducedMotion = reducedMotion
		live.current.canSpin = canSpin
		local landing = useFlash(controller.impactNonce, reducedMotion, 0.7)
		local launch = useFlash(controller.launchNonce, reducedMotion, 0.58)
		local winnerColor = (rewards[controller.winner + 1] and rewards[controller.winner + 1].Color) or Palette.mango
		React.useEffect(function()
			local spinViewport = spinHost.current
			local staticViewport = staticHost.current
			if spinViewport == nil or staticViewport == nil then
				return nil
			end
			local spinning = buildSpinningWheel(spinViewport, rewards)
			local static = buildStaticWheel(staticViewport)
			scenes.current = { spinning = spinning, static = static }
			wheelCamera(spinViewport, 0)
			wheelCamera(staticViewport, 0)
			local state = {
				t = 0,
				chase = 0,
				lastStep = -1,
				lastRoll = nil,
				celebrateUntil = 0,
				lastImpact = 0,
				swing = 0,
				lastKick = 0,
				glowWinner = -1,
			}
			local release = subscribeContinuous(function(dt)
				local now = live.current
				local ctl = now.controller
				state.t += dt
				local roll = ctl.rotation:getValue()
				if roll ~= state.lastRoll then
					state.lastRoll = roll
					wheelCamera(spinViewport, roll)
				end
				if ctl.impactNonce ~= state.lastImpact then
					state.lastImpact = ctl.impactNonce
					if ctl.impactNonce > 0 then
						state.celebrateUntil = state.t + 1.8
					end
				end
				local energy = ctl.spinEnergy:getValue()
				local celebrating = state.t < state.celebrateUntil
				local rate = if now.reducedMotion then 2 elseif celebrating then 1 else 5 + energy * 22
				state.chase += dt * rate
				local lit, step = bulbPattern(
					if celebrating then state.t else state.chase,
					if celebrating then "celebrate" else "chase"
				)
				local stepKey = (if celebrating then 1000 else 0) + step
				if stepKey ~= state.lastStep then
					state.lastStep = stepKey
					for k, bulb in static.bulbs do
						bulb.Color = if lit[k] then (if k % 2 == 0 then BULB_WARM else BULB_GOLD) else BULB_OFF
					end
				end
				local kick = ctl.pointerKick:getValue()
				local target = -kick * 24
				state.swing += (target - state.swing) * (1 - math.exp(-dt * 30))
				if static.pointer ~= nil and math.abs(state.swing - state.lastKick) > 0.05 then
					state.lastKick = state.swing
					static.pointer.CFrame = static.hinge
						* CFrame.Angles(0, 0, math.rad(state.swing))
						* CFrame.new(0, KIT_POINTER_CENTRE - KIT_POINTER_PIN, 0)
				end
				local winner = if celebrating then ctl.winner + 1 else -1
				local pulse = if celebrating then 0.5 + 0.5 * math.sin(state.t * 18) else 0
				if winner ~= state.glowWinner or celebrating then
					state.glowWinner = winner
					for index, wedge in spinning.wedges do
						local base = Palette.panel:Lerp(rewards[index].Color, 0.55)
						if winner == -1 then
							wedge.Material = Enum.Material.SmoothPlastic
							wedge.Color = base
						elseif index == winner then
							wedge.Material = Enum.Material.Neon
							wedge.Color = base:Lerp(Color3.new(1, 1, 1), 0.15 + pulse * 0.35)
						else
							wedge.Material = Enum.Material.SmoothPlastic
							wedge.Color = base:Lerp(Color3.new(0.05, 0.04, 0.08), 0.55)
						end
					end
				end
			end)
			return function()
				release()
				spinViewport:ClearAllChildren()
				staticViewport:ClearAllChildren()
			end
		end, { rewards })
		local glow = React.joinBindings({ landing, controller.spinEnergy, launch }):map(function(values)
			return math.clamp(0.92 - values[1] * 0.5 - values[2] * 0.12 * antilag.glowScale - values[3] * 0.15, 0.2, 1)
		end)
		local shake = React.joinBindings({ landing, controller.spinEnergy }):map(function(values)
			local hit = values[1]
			local wobble = math.sin((1 - hit) * math.pi * 5) * hit * 4
			return UDim2.new(0.5, math.round(wobble), 0.5, -math.round(values[2] * 2))
		end)
		local labelRadius = diameter / 2 * (1.98 / KIT_HALF_VIEW)
		local labels = {}
		for index, reward in rewards do
			local won = controller.winner == index - 1
			labels[`label{index}`] = React.createElement(
				"frame",
				{
					Size = UDim2.fromScale(1, 1),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = (index - 1) * 360 / count,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				},
				React.createElement(Text, {
					value = tostring(index),
					size = math.clamp(math.floor(diameter * 0.045), 11, 18),
					color = if won then Palette.cream else Color3.new(1, 1, 1),
					weight = Enum.FontWeight.Heavy,
					align = Enum.TextXAlignment.Center,
					fit = true,
					minSize = 8,
					position = UDim2.new(0.5, -10, 0.5, -labelRadius - 10),
					sizeConstraint = UDim2.fromOffset(20, 20),
					zIndex = 6,
				})
			)
		end
		return React.createElement(
			"frame",
			{
				Size = UDim2.fromOffset(diameter, diameter),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
			},
			React.createElement(WheelBurst, {
				flash = launch,
				active = controller.launchNonce > 0 and not reducedMotion,
				accent = Palette.mango,
				budget = antilag.fxBudget,
				launch = true,
				contained = containedEffects,
			}),
			React.createElement(WheelBurst, {
				flash = landing,
				active = controller.impactNonce > 0 and not reducedMotion,
				accent = winnerColor,
				budget = antilag.fxBudget,
				contained = containedEffects,
			}),
			React.createElement(
				"frame",
				{
					Size = UDim2.fromScale(1, 1),
					Position = shake,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = false,
				},
				React.createElement(
					"frame",
					{
						Size = UDim2.fromScale(0.96, 0.96),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = if controller.winner >= 0 then winnerColor else Palette.mango,
						BackgroundTransparency = glow,
						BorderSizePixel = 0,
						ZIndex = 1,
					},
					React.createElement("uicorner", {
						CornerRadius = UDim.new(1, 0),
					}),
					React.createElement("uigradient", {
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.2),
							NumberSequenceKeypoint.new(0.5, 0.75),
							NumberSequenceKeypoint.new(1, 0.2),
						}),
						Rotation = 45,
					})
				),
				React.createElement("viewportframe", {
					ref = spinHost,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Ambient = Color3.fromRGB(200, 194, 206),
					LightColor = Color3.fromRGB(205, 198, 186),
					LightDirection = PRIZE_LIGHT,
					ZIndex = 2,
				}),
				React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = controller.rotation,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 3,
				}, labels),
				React.createElement("viewportframe", {
					ref = staticHost,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Ambient = Color3.fromRGB(200, 194, 206),
					LightColor = Color3.fromRGB(205, 198, 186),
					LightDirection = PRIZE_LIGHT,
					ZIndex = 4,
				})
			)
		)
	end
	local function PrizeWheelMachine(props)
		local kitReady = useKitReady()
		local hasPieces = kitReady and kitFolder() ~= nil and kitFolder():FindFirstChild("Casino_PrizeWedge") ~= nil
		if hasPieces then
			return React.createElement(KitPrizeWheel, props)
		end
		return React.createElement(FlatPrizeWheel, props)
	end
	local function WheelConsole(_param)
		local state = _param.state
		local config = _param.config
		local controller = _param.controller
		local onSpin = _param.onSpin
		local height = _param.height
		local reducedMotion = _param.reducedMotion
		local softMotion = reducedMotion
		reducedMotion = softMotion
		local spinClaimHostRef = _param.spinClaimHostRef
		local compact = _param.compact
		if compact == nil then
			compact = false
		end
		local prize = if controller.winner >= 0 then config.Wheel.Rewards[controller.winner + 1] else nil
		local canSpin = state.Wheel.CanSpin == true
		local _condition = state.Wheel.PityMisses
		if _condition == nil then
			_condition = 0
		end
		local pityMisses = _condition
		local _condition_1 = state.Wheel.PityAfter
		if _condition_1 == nil then
			_condition_1 = config.Wheel.PityAfter
			if _condition_1 == nil then
				_condition_1 = 8
			end
		end
		local pityAfter = _condition_1
		local pityArmed = state.Wheel.PityArmed == true or pityMisses + 1 >= pityAfter
		local pityFill = if pityArmed then 1 else math.clamp(pityMisses / math.max(1, pityAfter), 0, 1)
		local now = useWallClock(not canSpin)
		local cooldown = now:map(function(timestamp)
			return `Ready again in {clockText(math.max(0, state.Wheel.ReadyAt - timestamp))}`
		end)
		local status = if controller.spinning
			then "SPINNING"
			elseif controller.failure ~= nil then "SPIN PAUSED"
			elseif prize ~= nil then "YOU WON"
			elseif canSpin then "READY TO SPIN"
			else "COOLING DOWN"
		local _result
		if controller.failure ~= nil then
			_result = "Connection interrupted"
		else
			local _result_1 = prize
			if _result_1 ~= nil then
				_result_1 = _result_1.Name
			end
			local _condition_2 = _result_1
			if _condition_2 == nil then
				_condition_2 = (
					if controller.spinning
						then "Forging your outcome"
						elseif canSpin then "Your daily draw is ready"
						else "The wheel is recharging"
				)
			end
			_result = _condition_2
		end
		local title = _result
		local _condition_2 = controller.failure
		if _condition_2 == nil then
			local _result_1 = prize
			if _result_1 ~= nil then
				_result_1 = _result_1.ShortLabel
			end
			_condition_2 = _result_1
			if _condition_2 == nil then
				local _result_2
				if controller.spinning then
					_result_2 = (
						if compact then "Your prize is coming up." else "The wheel is slowing down. Watch the pointer."
					)
				else
					local _result_3
					if canSpin then
						local _condition_3 = state.Wheel.FreeSpins
						if _condition_3 == nil then
							_condition_3 = 0
						end
						_result_3 = (
							if _condition_3 > 0
								then `{compactNumber(state.Wheel.FreeSpins)} free spin{if state.Wheel.FreeSpins
										== 1
									then ""
									else "s"} ready.`
								elseif pityArmed then (
									(
										config.ClientPageGuides
										and config.ClientPageGuides.Wheel
										and config.ClientPageGuides.Wheel.PityArmed
									) or "Your next spin has better odds of a rare prize."
								)
								elseif compact then "Tap once to spin."
								else (
									(
										config.ClientPageGuides
										and config.ClientPageGuides.Wheel
										and config.ClientPageGuides.Wheel.Ready
									) or "Give it a spin and see what lands."
								)
						)
					else
						_result_3 = cooldown
					end
					_result_2 = _result_3
				end
				_condition_2 = _result_2
			end
		end
		local detail = _condition_2
		local _result_1
		if controller.failure ~= nil then
			_result_1 = Palette.coral
		else
			local _result_2 = prize
			if _result_2 ~= nil then
				_result_2 = _result_2.Color
			end
			local _condition_3 = _result_2
			if _condition_3 == nil then
				_condition_3 = (if canSpin then Palette.mango else Palette.lineSoft)
			end
			_result_1 = _condition_3
		end
		local accent = _result_1
		local edge = if compact then 10 else 14
		local iconBox = if compact then 58 else 72
		local iconInset = if compact then 7 else 9
		local prizeIcon = if compact then 44 else 54
		local copyX = if compact then 78 else 98
		local copyRight = if compact then 88 else 112
		local statsTop = if compact then 92 else 106
		local statsHeight = if compact then 42 else 52
		local buttonHeight = if compact then 48 else 50
		local buttonBottom = if compact then 10 else 14
		local _exp = React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 14),
		})
		local _exp_1 = React.createElement("uigradient", {
			Color = surfaceGradient(Palette.panel, 0.62),
			Rotation = 90,
		})
		local _exp_2 = React.createElement("uistroke", {
			Color = accent,
			Thickness = 1,
			Transparency = 0.42,
		})
		local _exp_3 = React.createElement(
			"frame",
			{
				Size = UDim2.new(0.46, 0, 0, 3),
				Position = UDim2.fromOffset(edge, 0),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
			},
			React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			React.createElement("uigradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.06),
					NumberSequenceKeypoint.new(1, 1),
				}),
			})
		)
		local _exp_4 = React.createElement(
			"frame",
			{
				Size = UDim2.fromOffset(iconBox, iconBox),
				Position = UDim2.fromOffset(edge, if compact then 12 else 16),
				BackgroundColor3 = darken(accent, 0.76):Lerp(Palette.panelRaised, 0.42),
				BorderSizePixel = 0,
			},
			React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 14),
			}),
			React.createElement("uistroke", {
				Color = accent,
				Thickness = if prize ~= nil then 2 else 1,
				Transparency = if prize ~= nil then 0.08 else 0.46,
			}),
			if prize ~= nil
				then React.createElement(
					"frame",
					{
						Size = UDim2.fromOffset(prizeIcon, prizeIcon),
						Position = UDim2.fromOffset(iconInset, iconInset),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
					},
					React.createElement(WheelPrizeViewport, {
						color = prize.Color,
						shape = prizeShapeFromReward(prize.Reward, prize.Rarity),
						size = prizeIcon,
						spin = false,
					})
				)
				else React.createElement(Icon, {
					kind = "Wheel",
					color = Palette.cream,
					accent = Palette.mango,
					size = if compact then 40 else 48,
					position = UDim2.fromScale(0.5, 0.5),
					anchorPoint = Vector2.new(0.5, 0.5),
					reducedMotion = reducedMotion,
					clipSafe = true,
				})
		)
		local _exp_5 = React.createElement(Badge, {
			value = status,
			accent = accent,
			filled = prize ~= nil or controller.failure ~= nil,
			position = UDim2.fromOffset(copyX, if compact then 12 else 16),
			size = UDim2.new(1, -copyRight, 0, if compact then 22 else 24),
		})
		local _attributes = {
			value = title,
			size = if compact then 15 else 18,
		}
		local _result_2
		if controller.failure ~= nil then
			_result_2 = Palette.coral
		else
			local _result_3 = prize
			if _result_3 ~= nil then
				_result_3 = _result_3.Color
			end
			local _condition_3 = _result_3
			if _condition_3 == nil then
				_condition_3 = Palette.cream
			end
			_result_2 = _condition_3
		end
		_attributes.color = _result_2
		_attributes.weight = Enum.FontWeight.Heavy
		_attributes.fit = true
		_attributes.minSize = if compact then 9 else 11
		_attributes.position = UDim2.fromOffset(copyX, if compact then 38 else 44)
		_attributes.sizeConstraint = UDim2.new(1, -copyRight, 0, if compact then 20 else 24)
		local _exp_6 = React.createElement(Text, _attributes)
		local _exp_7 = React.createElement(Text, {
			value = detail,
			size = if compact then 9 else 11,
			color = Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(copyX, if compact then 59 else 69),
			sizeConstraint = UDim2.new(1, -copyRight, 0, if compact then 28 else 36),
		})
		local _exp_8 = React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 9),
		})
		local _exp_9 = React.createElement("uistroke", {
			Color = Palette.lineSoft,
			Thickness = 1,
			Transparency = 0.64,
		})
		local _attributes_1 = {}
		local _condition_3 = state.Wheel.FreeSpins
		if _condition_3 == nil then
			_condition_3 = 0
		end
		_attributes_1.value = if _condition_3 > 0 then "FREE DRAWS" else "TOTAL DRAWS"
		_attributes_1.size = 12
		_attributes_1.color = Palette.muted
		_attributes_1.weight = Enum.FontWeight.Heavy
		_attributes_1.position = UDim2.fromOffset(10, 5)
		_attributes_1.sizeConstraint = UDim2.new(1, -20, 0, 15)
		local _exp_10 = React.createElement(Text, _attributes_1)
		local _attributes_2 = {}
		local _condition_4 = state.Wheel.FreeSpins
		if _condition_4 == nil then
			_condition_4 = 0
		end
		_attributes_2.value = compactNumber(if _condition_4 > 0 then state.Wheel.FreeSpins else state.Wheel.Spins)
		_attributes_2.size = if compact then 14 else 16
		_attributes_2.color = Palette.cream
		_attributes_2.weight = Enum.FontWeight.Heavy
		_attributes_2.position = UDim2.fromOffset(10, if compact then 21 else 23)
		_attributes_2.sizeConstraint = UDim2.new(1, -20, 0, if compact then 18 else 22)
		return React.createElement(
			"frame",
			{
				Size = UDim2.new(1, 0, 0, height),
				BackgroundColor3 = Palette.ink,
				BorderSizePixel = 0,
				ClipsDescendants = true,
			},
			_exp,
			_exp_1,
			_exp_2,
			_exp_3,
			_exp_4,
			_exp_5,
			_exp_6,
			_exp_7,
			React.createElement(
				"frame",
				{
					Size = UDim2.new(1, -edge * 2, 0, statsHeight),
					Position = UDim2.fromOffset(edge, statsTop),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				},
				React.createElement("frame", {
					Size = UDim2.new(0.34, -5, 1, 0),
					BackgroundColor3 = Palette.panelRaised,
					BorderSizePixel = 0,
				}, _exp_8, _exp_9, _exp_10, React.createElement(Text, _attributes_2)),
				React.createElement(
					"frame",
					{
						Size = UDim2.new(0.66, -5, 1, 0),
						Position = UDim2.new(0.34, 5, 0, 0),
						BackgroundColor3 = Palette.panelRaised,
						BorderSizePixel = 0,
					},
					React.createElement("uicorner", {
						CornerRadius = UDim.new(0, 9),
					}),
					React.createElement("uistroke", {
						Color = if pityArmed then Palette.mango else Palette.lineSoft,
						Thickness = 1,
						Transparency = if pityArmed then 0.28 else 0.64,
					}),
					React.createElement(Text, {
						value = if compact then "RARITY" else "RARITY PRESSURE",
						size = 12,
						color = if pityArmed then Palette.mango else Palette.muted,
						weight = Enum.FontWeight.Heavy,
						position = UDim2.fromOffset(10, 5),
						sizeConstraint = UDim2.new(0.65, -10, 0, 15),
					}),
					React.createElement(Text, {
						value = if pityArmed then "PRIMED" else `{pityMisses} / {pityAfter}`,
						size = 12,
						color = if pityArmed then Palette.mango else Palette.creamSoft,
						weight = Enum.FontWeight.Heavy,
						align = Enum.TextXAlignment.Right,
						position = UDim2.new(0.65, 0, 0, 5),
						sizeConstraint = UDim2.new(0.35, -10, 0, 15),
					}),
					React.createElement(Meter, {
						value = pityFill,
						color = if pityArmed then Palette.mango else Palette.violet,
						reducedMotion = reducedMotion,
						shimmer = pityArmed,
						position = UDim2.fromOffset(10, if compact then 27 else 31),
						size = UDim2.new(1, -20, 0, if compact then 6 else 7),
					})
				)
			),
			React.createElement(
				"frame",
				{
					Name = "WheelSpinClaimActions",
					Size = UDim2.new(1, -edge * 2, 0, buttonHeight),
					Position = UDim2.new(0, edge, 1, -(buttonHeight + buttonBottom)),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = false,
					ref = spinClaimHostRef,
				},
				React.createElement(Button, {
					text = if controller.spinning
						then "SPINNING"
						elseif canSpin then (if pityArmed
							then (if compact then "SPIN Ã‚Â· PITY" else "SPIN Ã‚Â· PITY ARMED")
							elseif compact then "SPIN WHEEL"
							else "SPIN PRIZE WHEEL")
						else "DRAW NOT READY",
					icon = "Wheel",
					onClick = onSpin,
					color = if canSpin and not controller.spinning then Palette.mango else Palette.panelSoft,
					textColor = if canSpin and not controller.spinning then Palette.ink else Palette.muted,
					size = UDim2.fromScale(1, 1),
					reducedMotion = reducedMotion,
					disabled = controller.spinning or not canSpin,
					highlight = canSpin and not controller.spinning,
				})
			)
		)
	end
	local PRIZE_ROW_H = 84
	local function PrizeCatalogRow(_param)
		local reward = _param.reward
		local weightTotal = _param.weightTotal
		local reducedMotion = _param.reducedMotion
		local softMotion = reducedMotion
		local chance = if weightTotal > 0 then (reward.Weight / weightTotal) * 100 else 0
		return React.createElement(
			Panel,
			{
				size = UDim2.new(1, 0, 0, PRIZE_ROW_H - 6),
				accent = reward.Color,
				background = Palette.panel,
				padding = 10,
				reducedMotion = reducedMotion,
				clips = false,
			},
			React.createElement(Text, {
				value = `{_param.index}. {reward.Name or reward.Id}`,
				size = 14,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				fit = true,
				wrap = true,
				sizeConstraint = UDim2.new(1, -110, 0, 38),
			}),
			React.createElement(Text, {
				value = `{reward.Rarity} Ã‚Â· {string.format("%.1f", chance)}%`,
				size = 11,
				color = reward.Color,
				weight = Enum.FontWeight.Bold,
				fit = true,
				position = UDim2.fromOffset(0, 42),
				sizeConstraint = UDim2.new(1, 0, 0, 18),
			}),
			React.createElement(Badge, {
				value = reward.ShortLabel or formatReward(reward.Reward),
				accent = reward.Color,
				filled = true,
				position = UDim2.new(1, -100, 0, 6),
				size = UDim2.fromOffset(100, 24),
			})
		)
	end
	local function WheelView(props)
		local _binding = props
		local state = _binding.state
		local config = _binding.config
		local reducedMotion = _binding.reducedMotion
		local viewport = useViewport()
		local pageWidth, setPageWidth = React.useState(nil)
		local availableWidth = pageWidth or math.max(100, viewport.width - 280)
		local chrome = chromeFor(viewport)
		local antilag = useAntilag()
		local softMotion = reducedMotion
		reducedMotion = softMotion
		local spinClaimHostRef = React.useRef(nil)
		local controller = useWheelController(props)
		React.useEffect(function()
			if state.Wheel.CanSpin ~= true or controller.spinning or not UserInputService.GamepadEnabled then
				return nil
			end
			local host = spinClaimHostRef.current
			if host == nil then
				return nil
			end
			local selectJob = task.defer(function()
				if host.Parent == nil then
					return
				end
				GamepadNavigationService.FocusClaim(host)
			end)
			return function()
				pcall(task.cancel, selectJob)
			end
		end, { state.Wheel.CanSpin, controller.spinning })
		local rewards = config.Wheel.Rewards
		local landscape = chrome.landscape or (viewport.width > viewport.height * 1.35 and viewport.height < 680)
		local shortLandscape = landscape and viewport.width >= 480 and viewport.width < 900 and viewport.height <= 430
		local split = not chrome.contentStack and availableWidth >= 760
		local narrowPortrait = not landscape and viewport.width <= 360
		local widthCap = if split
			then availableWidth * 0.48 - Layout.cardPadding * 2 - 24
			else availableWidth - Layout.cardPadding * 2 - 24
		local heightCap = if shortLandscape then 240 elseif split then 320 else 320
		local wheelDiameter = math.floor(
			if shortLandscape
				then math.clamp(math.min(widthCap, heightCap), 190, 220)
				else math.clamp(
					math.min(widthCap, heightCap),
					if chrome.contentStack then 140 else 180,
					if split then 300 else 300
				)
		)
		wheelDiameter = math.max(100, math.min(wheelDiameter, widthCap))
		local headerH = if shortLandscape then 64 elseif narrowPortrait then 90 else 82
		local consoleH = if shortLandscape then 198 elseif chrome.contentStack then 230 else 232
		local stageH = if split then math.max(wheelDiameter + 24, consoleH) else wheelDiameter + 40 + consoleH
		local panelH = headerH + stageH + Layout.cardPadding * 2
		-- The legend shares the page scroll, so the wheel no longer needs to shrink
		-- to make an artificial nested prize viewport fit above the fold.
		local headerReveal = useStagger(0, softMotion)
		local _result
		if controller.winner >= 0 then
			local _result_1 = rewards[controller.winner + 1]
			if _result_1 ~= nil then
				_result_1 = _result_1.Color
			end
			local _condition = _result_1
			if _condition == nil then
				_condition = Palette.mango
			end
			_result = _condition
		else
			_result = Palette.mango
		end
		local accent = _result
		local headline = "Your daily prize draw"
		local descriptor = if narrowPortrait
			then `{#rewards} prizes / rare-win protection`
			else `{#rewards} prizes  /  better odds after every miss`
		local containedEffects = chrome.portrait
			or shortLandscape
			or viewport.width <= 420
			or (landscape and viewport.height <= 480)
		local weightTotal = 0
		for _, reward in rewards do
			weightTotal += reward.Weight or 0
		end
		-- One page scroll owns the complete legend: no clipped nested prize viewport.
		local prizeRows = {
			layout = React.createElement("uilistlayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		}
		for index, reward in rewards do
			prizeRows[reward.Id] = React.createElement(
				"frame",
				{
					Size = UDim2.new(1, -6, 0, PRIZE_ROW_H - 6),
					BackgroundTransparency = 1,
					LayoutOrder = index,
				},
				React.createElement(PrizeCatalogRow, {
					reward = reward,
					index = index,
					weightTotal = weightTotal,
					reducedMotion = softMotion,
				})
			)
		end
		local prizeList = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, prizeRows)
		return React.createElement(
			"frame",
			{
				Name = "WheelPage",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				[React.Change.AbsoluteSize] = function(host)
					local scale = if workspace:GetAttribute("AstralForgeVRCanvasWidth") then 1 else Layout.chromeScale
					local width = math.floor(host.AbsoluteSize.X / scale)
					if width > 0 then
						setPageWidth(width)
					end
				end,
			},
			React.createElement(PageScaffold, {
				gap = 0,
				tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 40),
				scrollBarColor = accent,
				scrollBarThickness = 4,
				sections = {
					{
						id = "wheel",
						height = panelH,
						element = React.createElement(
							Panel,
							{
								size = UDim2.fromScale(1, 1),
								accent = accent,
								background = Palette.panelRaised,
								padding = Layout.cardPadding,
								reveal = headerReveal,
								reducedMotion = softMotion,
								clips = false,
							},
							React.createElement(Text, {
								value = "PRIZE WHEEL",
								size = if shortLandscape then 9 else 10,
								color = Palette.mango,
								weight = Enum.FontWeight.Heavy,
								fit = false,
								sizeConstraint = UDim2.new(1, 0, 0, if shortLandscape then 14 else 16),
							}),
							React.createElement(Text, {
								value = headline,
								size = if shortLandscape then 16 elseif chrome.contentStack then 18 else 21,
								color = Palette.cream,
								weight = Enum.FontWeight.Heavy,
								fit = false,
								minSize = if narrowPortrait then 10 else 15,
								wrap = narrowPortrait,
								position = UDim2.fromOffset(0, if shortLandscape then 14 else 18),
								sizeConstraint = UDim2.new(
									1,
									0,
									0,
									if narrowPortrait then 36 elseif shortLandscape then 22 else 28
								),
							}),
							React.createElement(Text, {
								value = descriptor,
								size = if narrowPortrait then 9 else 10,
								color = Palette.muted,
								fit = false,
								wrap = narrowPortrait,
								position = UDim2.fromOffset(
									0,
									if narrowPortrait then 57 elseif shortLandscape then 36 else 46
								),
								sizeConstraint = UDim2.new(1, 0, 0, if narrowPortrait then 18 else 16),
							}),
							React.createElement(
								"frame",
								{
									Size = UDim2.fromOffset(wheelDiameter, wheelDiameter),
									Position = if split
										then UDim2.new(0.25, 0, 0, headerH + stageH / 2)
										else UDim2.new(0.5, 0, 0, headerH),
									AnchorPoint = if split then Vector2.new(0.5, 0.5) else Vector2.new(0.5, 0),
									BackgroundTransparency = 1,
									BorderSizePixel = 0,
									ClipsDescendants = true,
								},
								React.createElement(PrizeWheelMachine, {
									rewards = rewards,
									controller = controller,
									diameter = wheelDiameter,
									canSpin = state.Wheel.CanSpin == true,
									reducedMotion = softMotion,
									containedEffects = containedEffects,
								})
							),
							React.createElement(
								"frame",
								{
									Size = if split
										then UDim2.new(0.48, -10, 0, consoleH)
										else UDim2.new(1, 0, 0, consoleH),
									Position = if split
										then UDim2.new(0.52, 10, 0, headerH + (stageH - consoleH) / 2)
										else UDim2.fromOffset(0, headerH + wheelDiameter + 40),
									BackgroundTransparency = 1,
									BorderSizePixel = 0,
								},
								React.createElement(WheelConsole, {
									state = state,
									config = config,
									controller = controller,
									onSpin = controller.spin,
									height = consoleH,
									reducedMotion = softMotion,
									spinClaimHostRef = spinClaimHostRef,
									compact = shortLandscape,
								})
							)
						),
					},
					{
						id = "prizes-label",
						height = 28,
						element = React.createElement(Text, {
							value = "PRIZE TABLE Ã‚Â· MATCH THE SECTOR NUMBER",
							size = 11,
							color = Palette.mango,
							weight = Enum.FontWeight.Heavy,
							sizeConstraint = UDim2.new(1, 0, 0, 20),
						}),
					},
					{
						id = "prizes",
						height = PRIZE_ROW_H * #rewards + 8,
						element = prizeList,
					},
				},
			})
		)
	end
	return {
		WheelView = WheelView,
	}
end

__defs["CrateRevealStage"] = function()
	local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
	local UserInputService = game:GetService("UserInputService")
	local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
	local itemIconKind = require(script.Parent.Parent.ArtKit)("Icon").itemIconKind
	local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
	local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
	local ScaleFromCenter = require(script.Parent.Parent.MotionKit)("motion").ScaleFromCenter
	local _theme = require(script.Parent.Parent.CoreKit)("theme")
	local darken = _theme.darken
	local lighten = _theme.lighten
	local Palette = _theme.Palette
	local TapTarget = _theme.TapTarget
	local _ui = require(script.Parent.Parent.UiCore)("ui")
	local Badge = _ui.Badge
	local Button = _ui.Button
	local IconTile = _ui.IconTile
	local Panel = _ui.Panel
	local Text = _ui.Text

	local RunService = game:GetService("RunService")

	local function easeOutExpo(t)
		return t == 1 and 1 or 1 - math.pow(2, -10 * t)
	end
	local function easeOutBack(t)
		local c1, c3 = 1.70158, 1.70158 + 1
		return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
	end

	local shimmerClock = React.createContext(0)

	local function useShimmerClock()
		return React.useContext(shimmerClock)
	end

	local function ShimmerProvider(props)
		local clock, setClock = React.useBinding(0)
		React.useEffect(function()
			local conn = RunService.RenderStepped:Connect(function(dt)
				setClock((clock:getValue() + dt * 0.72) % 1)
			end)
			return function()
				conn:Disconnect()
			end
		end, {})
		return React.createElement(shimmerClock.Provider, { value = clock }, props.children)
	end

	local function resolveLayout(props)
		local edge = if props.portrait then 10 else 18
		local leftEdge = edge + props.sideSafe
		local rightEdge = edge + props.sideSafe
		local usableWidth = math.max(1, props.viewportWidth - leftEdge - rightEdge)
		if props.shortLandscape then
			local columnGap = 12
			local availableRight = math.max(1, usableWidth - columnGap - 1)
			local rightWidth = math.min(availableRight, math.min(218, math.max(132, math.floor(usableWidth * 0.36))))
			local leftWidth = math.max(1, usableWidth - columnGap - rightWidth)
			local headerTop = props.topInset + 5
			local headerHeight = 52
			local stageTop = headerTop + headerHeight + 8
			local stageBottom = props.viewportHeight - props.bottomSafe - 8
			local stageHeight = math.max(1, math.min(202, stageBottom - stageTop))
			return {
				compactHeight = false,
				headerSize = UDim2.fromOffset(leftWidth, headerHeight),
				headerPosition = UDim2.fromOffset(leftEdge, headerTop),
				headerAnchor = Vector2.zero,
				stageSize = UDim2.fromOffset(leftWidth, stageHeight),
				stagePosition = UDim2.fromOffset(leftEdge, stageTop),
				stageAnchor = Vector2.zero,
				reelWidth = math.max(1, leftWidth - 24),
				reelHeight = math.max(1, stageHeight - 58),
				resultSize = UDim2.fromOffset(rightWidth, 126),
				resultPosition = UDim2.new(1, -rightEdge, 0, props.topInset + 12),
				resultAnchor = Vector2.new(1, 0),
				actionSize = UDim2.fromOffset(rightWidth, TapTarget),
				actionPosition = UDim2.new(1, -rightEdge, 1, -(props.bottomSafe + 8)),
				actionAnchor = Vector2.new(1, 1),
			}
		end
		if props.viewportHeight < 540 then
			local stageWidth = math.min(usableWidth, 390)
			local headerTop = props.topInset + 4
			local headerHeight = 44
			local actionBottom = props.bottomSafe + 8
			local actionTop = props.viewportHeight - actionBottom - TapTarget
			local stageTop = headerTop + headerHeight + 6
			local stageBottom = math.max(stageTop + 1, actionTop - 8)
			local stageHeight = stageBottom - stageTop
			local resultHeight = math.max(1, math.min(100, stageHeight - 12))
			return {
				compactHeight = true,
				headerSize = UDim2.fromOffset(stageWidth, headerHeight),
				headerPosition = UDim2.new(0.5, 0, 0, headerTop),
				headerAnchor = Vector2.new(0.5, 0),
				stageSize = UDim2.fromOffset(stageWidth, stageHeight),
				stagePosition = UDim2.new(0.5, 0, 0, stageTop),
				stageAnchor = Vector2.new(0.5, 0),
				reelWidth = math.max(1, stageWidth - 24),
				reelHeight = math.max(1, stageHeight - 58),
				resultSize = UDim2.fromOffset(math.max(1, stageWidth - 24), resultHeight),
				resultPosition = UDim2.fromOffset(
					math.floor(props.viewportWidth / 2),
					math.floor(stageTop + stageHeight / 2)
				),
				resultAnchor = Vector2.new(0.5, 0.5),
				actionSize = UDim2.fromOffset(stageWidth, TapTarget),
				actionPosition = UDim2.new(0.5, 0, 1, -actionBottom),
				actionAnchor = Vector2.new(0.5, 1),
			}
		end
		local stageWidth = math.min(usableWidth, if props.portrait then 390 else 850)
		local stageHeight = if props.portrait
			then math.clamp(math.floor(props.viewportHeight * 0.37), 204, 232)
			else math.clamp(math.floor(props.viewportHeight * 0.38), 232, 286)
		local headerHeight = if props.portrait then 74 else 82
		local resultHeight = if props.portrait then 88 else 94
		local resultWidth = math.min(if props.portrait then stageWidth else 470, usableWidth)
		local actionWidth = math.min(if props.portrait then stageWidth else 260, usableWidth)
		local actionBottom = props.bottomSafe + 10
		local resultBottom = actionBottom + TapTarget + 10
		local freeTop = props.topInset + headerHeight + 16
		local freeBottom = props.viewportHeight - resultBottom - resultHeight - 10
		local stageCenter = math.floor((freeTop + freeBottom) * 0.5)
		return {
			compactHeight = false,
			headerSize = UDim2.fromOffset(math.min(stageWidth, 620), headerHeight),
			headerPosition = UDim2.new(0.5, 0, 0, props.topInset + 8),
			headerAnchor = Vector2.new(0.5, 0),
			stageSize = UDim2.fromOffset(stageWidth, stageHeight),
			stagePosition = UDim2.fromOffset(math.floor(props.viewportWidth / 2), stageCenter),
			stageAnchor = Vector2.new(0.5, 0.5),
			reelWidth = math.max(1, stageWidth - 24),
			reelHeight = stageHeight - 58,
			resultSize = UDim2.fromOffset(resultWidth, resultHeight),
			resultPosition = UDim2.new(0.5, 0, 1, -resultBottom),
			resultAnchor = Vector2.new(0.5, 1),
			actionSize = UDim2.fromOffset(actionWidth, TapTarget),
			actionPosition = UDim2.new(0.5, 0, 1, -actionBottom),
			actionAnchor = Vector2.new(0.5, 1),
		}
	end

	local function ForgeBackdrop(_param)
		local props = _param.props
		local layout = _param.layout
		local contained = props.shortLandscape or layout.compactHeight or props.viewportHeight < 600
		local burstBase = if contained then 110 else 180
		local burstTravel = if contained then math.min(160, layout.reelWidth * 0.42) else 420
		local center = UDim2.new(
			layout.stagePosition.X.Scale,
			layout.stagePosition.X.Offset + (0.5 - layout.stageAnchor.X) * layout.stageSize.X.Offset,
			layout.stagePosition.Y.Scale,
			layout.stagePosition.Y.Offset + (0.5 - layout.stageAnchor.Y) * layout.stageSize.Y.Offset
		)

		local ringRotation, setRingRotation = React.useBinding(0)
		local ringConn = React.useRef(nil)
		React.useEffect(function()
			local conn = RunService.RenderStepped:Connect(function(dt)
				local speed = if props.phase == "spin" then 38 else 12
				setRingRotation((ringRotation:getValue() + dt * speed) % 360)
			end)
			ringConn.current = conn
			return function()
				conn:Disconnect()
			end
		end, { props.phase })

		local gridLines = {}
		if props.allowAmbient then
			for index = 0, 4 do
				gridLines[`h{index}`] = React.createElement("frame", {
					key = `forge-grid-h-{index}`,
					Size = UDim2.new(0.68, 0, 0, 1),
					Position = UDim2.new(0.5, 0, 0.28 + index * 0.1, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = props.sessionAccent,
					BackgroundTransparency = 0.94,
					BorderSizePixel = 0,
				})
			end
			for index = 0, 6 do
				gridLines[`v{index}`] = React.createElement("frame", {
					key = `forge-grid-v-{index}`,
					Size = UDim2.new(0, 1, 0.54, 0),
					Position = UDim2.new(0.26 + index * 0.08, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = props.sessionAccent,
					BackgroundTransparency = 0.96,
					BorderSizePixel = 0,
				})
			end
		end

		return React.createElement(
			"frame",
			{
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 405,
				Active = false,
			},
			React.createElement("frame", {
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromScale(0, 0.18),
				BackgroundColor3 = Palette.line,
				BackgroundTransparency = 0.78,
				BorderSizePixel = 0,
			}),
			React.createElement("frame", {
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromScale(0, 0.82),
				BackgroundColor3 = Palette.line,
				BackgroundTransparency = 0.84,
				BorderSizePixel = 0,
			}),
			props.allowAmbient
				and React.createElement(
					React.Fragment,
					nil,
					table.unpack((function()
						local items = {}
						for _, v in gridLines do
							table.insert(items, v)
						end
						return items
					end)())
				),
			props.allowAmbient
				and React.createElement(
					"frame",
					{
						Size = props.landFlash:map(function(f)
							local base = if contained then 72 else 130
							return UDim2.fromOffset(base + f * 60, base + f * 60)
						end),
						Position = center,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ZIndex = 406,
						Rotation = ringRotation,
					},
					React.createElement("uistroke", {
						Color = props.sessionAccent,
						Thickness = 1.5,
						Transparency = props.spinEnergy:map(function(e)
							return 1 - e * 0.55 * props.glowScale
						end),
					}),
					React.createElement("uicorner", {
						CornerRadius = UDim.new(0, 6),
					})
				),
			React.createElement(
				"frame",
				{
					Size = props.landFlash:map(function(amount)
						return UDim2.fromOffset(burstBase + amount * burstTravel, burstBase + amount * burstTravel)
					end),
					Position = center,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = props.sessionAccent,
					BackgroundTransparency = props.landFlash:map(function(amount)
						return 1 - amount * (if contained then 0.045 else 0.08)
					end),
					BorderSizePixel = 0,
					Rotation = 45,
					ZIndex = 406,
				},
				React.createElement("uicorner", {
					CornerRadius = UDim.new(1, 0),
				}),
				React.createElement("uistroke", {
					Color = lighten(props.sessionAccent, 0.32),
					Thickness = 2,
					Transparency = props.landFlash:map(function(amount)
						return 1 - amount * (if contained then 0.32 else 0.46)
					end),
				})
			),
			React.createElement("frame", {
				Size = UDim2.new(if contained then 0.58 else 0.82, 0, 0, 2),
				Position = center,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Palette.cream,
				BackgroundTransparency = props.spinEnergy:map(function(amount)
					return 1 - amount * 0.12
				end),
				BorderSizePixel = 0,
				ZIndex = 406,
			})
		)
	end

	local function RevealHeader(_param)
		local props = _param.props
		local layout = _param.layout
		local status = if props.phase == "charge"
			then "GET READY"
			elseif props.phase == "spin" then "ROLLING"
			elseif props.phase == "land" then "YOU GOT"
			elseif props.phase == "done" or props.phase == "exit" then "READY"
			else "OPENING"

		local dotPulse, setDotPulse = React.useBinding(0)
		React.useEffect(function()
			local conn = RunService.RenderStepped:Connect(function(dt)
				setDotPulse((dotPulse:getValue() + dt * 2.8) % 1)
			end)
			return function()
				conn:Disconnect()
			end
		end, {})

		local dotColor = if props.phase == "spin"
			then Palette.cyan
			elseif props.phase == "land" then props.winnerAccent or Palette.mint
			elseif props.phase == "done" then Palette.mint
			else Palette.muted

		local narrowShort = props.shortLandscape and layout.headerSize.X.Offset < 260
		local simplifiedHeader = narrowShort or layout.compactHeight

		return React.createElement(
			"frame",
			{
				Size = layout.headerSize,
				Position = layout.headerPosition,
				AnchorPoint = layout.headerAnchor,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 420,
			},
			not simplifiedHeader
				and React.createElement(Text, {
					value = "RELIC CRATE",
					size = 9,
					color = props.sessionAccent,
					weight = Enum.FontWeight.Heavy,
					align = if props.shortLandscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
					sizeConstraint = UDim2.new(1, if props.shortLandscape then -128 else 0, 0, 14),
					zIndex = 421,
				}),
			React.createElement(Text, {
				value = props.crateName,
				size = if props.shortLandscape then 21 elseif props.portrait then 23 else 27,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				align = if props.shortLandscape and not simplifiedHeader
					then Enum.TextXAlignment.Left
					else Enum.TextXAlignment.Center,
				fit = true,
				minSize = 12,
				position = UDim2.fromOffset(0, if simplifiedHeader then 0 elseif props.shortLandscape then 15 else 16),
				sizeConstraint = UDim2.new(
					1,
					if props.shortLandscape and not simplifiedHeader then -128 else 0,
					0,
					if props.shortLandscape then 28 else 34
				),
				zIndex = 421,
			}),
			React.createElement(
				"frame",
				{
					Size = if simplifiedHeader
						then UDim2.new(1, 0, 0, 15)
						elseif props.shortLandscape then UDim2.fromOffset(128, 36)
						else UDim2.new(1, 0, 0, 14),
					Position = if simplifiedHeader
						then UDim2.fromOffset(0, 27)
						elseif props.shortLandscape then UDim2.new(1, -128, 0, 6)
						else UDim2.fromOffset(0, 53),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 421,
				},
				React.createElement("frame", {
					Size = UDim2.fromOffset(6, 6),
					Position = UDim2.new(if props.shortLandscape and not simplifiedHeader then 0 else 0.5, -48, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = dotColor,
					BackgroundTransparency = dotPulse:map(function(t)
						return 0.1 + math.sin(t * math.pi * 2) * 0.35
					end),
					BorderSizePixel = 0,
					ZIndex = 422,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
				React.createElement(Text, {
					value = `{status}  Ã¢â‚¬Â¢  {props.rollIndex + 1}/{props.rollCount}`,
					size = 9,
					color = Palette.muted,
					weight = Enum.FontWeight.Bold,
					align = if props.shortLandscape and not simplifiedHeader
						then Enum.TextXAlignment.Right
						else Enum.TextXAlignment.Center,
					fit = true,
					minSize = 8,
					sizeConstraint = UDim2.fromScale(1, 1),
					zIndex = 421,
				})
			),
			not props.shortLandscape
				and not layout.compactHeight
				and React.createElement(
					"frame",
					{
						Size = UDim2.fromOffset(math.min(190, props.rollCount * 22), 4),
						Position = UDim2.new(0.5, 0, 1, -2),
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundColor3 = Palette.line,
						BorderSizePixel = 0,
						ZIndex = 421,
					},
					React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }),
					React.createElement("frame", {
						Size = UDim2.new(
							math.clamp((props.rollIndex + 1) / math.max(1, props.rollCount), 0, 1),
							0,
							1,
							0
						),
						BackgroundColor3 = props.sessionAccent,
						BorderSizePixel = 0,
						ZIndex = 422,
					}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
				)
		)
	end

	local function ReelCard(_param)
		local card = _param.card
		local x = _param.x
		local width = _param.width
		local height = _param.height
		local emphasize = _param.emphasize
		local detailed = _param.detailed
		local fitScale = _param.fitScale
		local reducedMotion = _param.reducedMotion
		local winnerScale = _param.winnerScale
		local shimmerPhase = _param.shimmerPhase or 0

		local clock = useShimmerClock()
		local scale = if emphasize
			then winnerScale:map(function(amount)
				return amount * fitScale
			end)
			else 0.94 * fitScale
		local cardZ = if emphasize then 433 else 431

		local shimmerX = React.joinBindings({ clock }):map(function(vals)
			local t = (vals[1] + shimmerPhase) % 1
			local sweep = if t < 0.22 then easeOutExpo(t / 0.22) else if t < 0.35 then 1 - (t - 0.22) / 0.13 else -0.15
			return UDim2.new(sweep, -28, 0, 0)
		end)

		local haloGlow
		if emphasize and not reducedMotion then
			haloGlow = React.createElement(
				"frame",
				{
					Size = UDim2.new(1, 16, 1, 16),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = cardZ - 1,
				},
				React.createElement("uistroke", {
					Color = lighten(card.accent, 0.18),
					Thickness = winnerScale:map(function(amt)
						return 1.5 + amt * 2.5
					end),
					Transparency = winnerScale:map(function(amt)
						return 1 - amt * 0.72
					end),
				}),
				React.createElement("uicorner", { CornerRadius = UDim.new(0, 17) })
			)
		end

		return React.createElement(
			"frame",
			{
				Size = UDim2.fromOffset(width, height),
				Position = UDim2.fromOffset(x, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = cardZ,
			},
			haloGlow,
			React.createElement(
				"frame",
				{
					Size = UDim2.fromScale(1, 1),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = cardZ,
				},
				React.createElement("uiscale", { Scale = scale }),
				React.createElement("frame", {
					Size = UDim2.new(1, -8, 1, -10),
					Position = UDim2.fromOffset(4, 6),
					BackgroundColor3 = Palette.shadow or Color3.fromRGB(0, 0, 0),
					BackgroundTransparency = 0.36,
					BorderSizePixel = 0,
					ZIndex = cardZ,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) })),
				React.createElement(
					"frame",
					{
						Size = UDim2.new(1, -4, 1, -4),
						BackgroundColor3 = Palette.panelRaised,
						BorderSizePixel = 0,
						ZIndex = cardZ + 1,
						ClipsDescendants = true,
					},
					React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
					React.createElement("uistroke", {
						Color = if emphasize then lighten(card.accent, 0.3) else card.accent,
						Thickness = if emphasize then 2 else 1,
						Transparency = if emphasize then 0.04 else 0.42,
					}),
					React.createElement("uigradient", {
						Color = ColorSequence.new(
							lighten(Palette.panelRaised, 0.05),
							darken(Palette.panelRaised, 0.18)
						),
						Rotation = 90,
					}),
					React.createElement("frame", {
						Size = UDim2.new(1, -18, 0, 3),
						Position = UDim2.fromOffset(9, 8),
						BackgroundColor3 = card.accent,
						BackgroundTransparency = if emphasize then 0 else 0.18,
						BorderSizePixel = 0,
						ZIndex = cardZ + 2,
					}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
					not reducedMotion
						and React.createElement(
							"frame",
							{
								Size = UDim2.fromOffset(28, height),
								Position = shimmerX,
								AnchorPoint = Vector2.new(0, 0),
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								Rotation = 12,
								ZIndex = cardZ + 5,
							},
							React.createElement("uigradient", {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Palette.cream),
									ColorSequenceKeypoint.new(0.5, Palette.cream),
									ColorSequenceKeypoint.new(1, Palette.cream),
								}),
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 1),
									NumberSequenceKeypoint.new(0.35, if emphasize then 0.38 else 0.72),
									NumberSequenceKeypoint.new(0.5, if emphasize then 0.22 else 0.58),
									NumberSequenceKeypoint.new(0.65, if emphasize then 0.38 else 0.72),
									NumberSequenceKeypoint.new(1, 1),
								}),
							})
						),
					if detailed
						then React.createElement(
							React.Fragment,
							nil,
							React.createElement(IconTile, {
								kind = itemIconKind(card.definitionId),
								accent = card.accent,
								size = 52,
								radius = 12,
								position = UDim2.new(0.5, 0, 0, 19),
								anchorPoint = Vector2.new(0.5, 0),
								reducedMotion = reducedMotion,
								glow = emphasize,
								filled = true,
								zIndex = cardZ + 3,
							}),
							React.createElement(Badge, {
								value = string.upper(card.rarity),
								accent = card.accent,
								filled = true,
								position = UDim2.new(0.5, -50, 0, 76),
								size = UDim2.fromOffset(100, 20),
								zIndex = cardZ + 4,
							}),
							React.createElement(Text, {
								value = card.name,
								size = 12,
								color = Palette.cream,
								weight = Enum.FontWeight.Heavy,
								align = Enum.TextXAlignment.Center,
								fit = true,
								minSize = 9,
								position = UDim2.fromOffset(8, 99),
								sizeConstraint = UDim2.new(1, -16, 0, 22),
								zIndex = cardZ + 4,
							})
						)
						else React.createElement(
							React.Fragment,
							nil,
							React.createElement(
								"frame",
								{
									Size = UDim2.fromOffset(52, 52),
									Position = UDim2.new(0.5, 0, 0, 24),
									AnchorPoint = Vector2.new(0.5, 0),
									BackgroundColor3 = darken(card.accent, 0.6),
									BorderSizePixel = 0,
									ZIndex = cardZ + 3,
								},
								React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
								React.createElement("uistroke", {
									Color = card.accent,
									Thickness = 1,
									Transparency = 0.42,
								}),
								React.createElement("frame", {
									Size = UDim2.fromOffset(24, 24),
									Position = UDim2.fromScale(0.5, 0.5),
									AnchorPoint = Vector2.new(0.5, 0.5),
									Rotation = 45,
									BackgroundColor3 = card.accent,
									BorderSizePixel = 0,
									ZIndex = cardZ + 4,
								}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 6) })),
								React.createElement("frame", {
									Size = UDim2.fromOffset(8, 8),
									Position = UDim2.fromScale(0.5, 0.5),
									AnchorPoint = Vector2.new(0.5, 0.5),
									BackgroundColor3 = Palette.cream,
									BorderSizePixel = 0,
									ZIndex = cardZ + 5,
								}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
							),
							React.createElement("frame", {
								Size = UDim2.new(1, -34, 0, 3),
								Position = UDim2.new(0.5, 0, 1, -24),
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = card.accent,
								BackgroundTransparency = 0.32,
								BorderSizePixel = 0,
								ZIndex = cardZ + 3,
							}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
						),
					card.tag ~= nil
						and emphasize
						and React.createElement(Badge, {
							value = card.tag,
							accent = if card.tag == "NEW" then Palette.mint else card.accent,
							filled = true,
							position = UDim2.new(1, -54, 0, -8),
							size = UDim2.fromOffset(48, 18),
							zIndex = cardZ + 5,
						})
				)
			)
		)
	end

	local function ForgeReel(_param)
		local props = _param.props
		local layout = _param.layout
		local landed = props.phase == "land" or props.phase == "done" or props.phase == "exit"
		local cardFitScale = math.min(1, math.max(0.01, (layout.reelHeight - 4) / props.cardHeight))

		local pressOffset = React.joinBindings({ props.tickEnergy, props.landFlash, props.chargePulse })
			:map(function(values)
				return math.round(values[1] * 5 + values[2] * 12 + values[3] * 3)
			end)
		local selectorScale = React.joinBindings({ props.tickEnergy, props.landPop, props.landFlash })
			:map(function(values)
				return 1 + values[1] * 0.025 + values[2] * 0.035 + values[3] * 0.02
			end)
		local progressWidth = props.spinProgress:map(function(amount)
			return UDim2.new(math.clamp(amount, 0, 1), 0, 1, 0)
		end)

		local speedBars = {}
		if props.allowAmbient then
			for index = 0, 5 do
				speedBars[index + 1] = React.createElement("frame", {
					key = `rail-speed-{index}`,
					Size = UDim2.fromOffset(52 + index * 12, 2),
					Position = UDim2.new(0.12 + index * 0.15, 0, 0.5, if index % 2 == 0 then -32 else 32),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = if index % 2 == 0 then props.sessionAccent else Palette.cream,
					BackgroundTransparency = props.spinEnergy:map(function(amount)
						return 1 - amount * (0.22 + index * 0.025) * props.glowScale
					end),
					BorderSizePixel = 0,
					ZIndex = 428,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
			end
		end

		local cardElements = {}
		for i, card in props.cards do
			local besideWinner = (props.cards[i] and props.cards[i].winner == true)
				or (props.cards[i + 2] and props.cards[i + 2].winner == true)
			local detailed = not props.economyMode or i <= 4 or card.winner or besideWinner
			cardElements[i] = React.createElement(ReelCard, {
				key = card.key,
				card = card,
				x = i * props.stride,
				width = props.cardWidth,
				height = props.cardHeight,
				emphasize = card.winner and landed,
				detailed = detailed,
				fitScale = cardFitScale,
				reducedMotion = props.reducedMotion,
				winnerScale = props.winnerCardScale,
				shimmerPhase = (i * 0.13) % 1,
			})
		end

		return React.createElement(
			"frame",
			{
				Size = layout.stageSize,
				Position = layout.stagePosition,
				AnchorPoint = layout.stageAnchor,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 425,
				ClipsDescendants = false,
			},
			React.createElement("frame", {
				Size = UDim2.new(1, 6, 1, 8),
				Position = UDim2.fromOffset(-3, 7),
				BackgroundColor3 = Palette.shadow or Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.3,
				BorderSizePixel = 0,
				ZIndex = 424,
			}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 18) })),
			React.createElement(
				"frame",
				{
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Palette.panel,
					BorderSizePixel = 0,
					ZIndex = 425,
					ClipsDescendants = false,
				},
				React.createElement("uicorner", { CornerRadius = UDim.new(0, 18) }),
				React.createElement("uistroke", {
					Color = if landed then props.winnerAccent else props.sessionAccent,
					Thickness = if landed then 2 else 1.25,
					Transparency = if landed then 0.08 else 0.28,
				}),
				React.createElement("uigradient", {
					Color = ColorSequence.new(lighten(Palette.panel, 0.045), darken(Palette.panel, 0.16)),
					Rotation = 90,
				}),
				React.createElement(
					"frame",
					{
						Size = UDim2.new(1, -24, 0, 30),
						Position = UDim2.fromOffset(12, 8),
						BackgroundColor3 = Palette.night,
						BackgroundTransparency = 0.08,
						BorderSizePixel = 0,
						ZIndex = 426,
					},
					React.createElement("uicorner", { CornerRadius = UDim.new(0, 9) }),
					React.createElement(Text, {
						value = "YOUR ROLL",
						size = 9,
						color = Palette.muted,
						weight = Enum.FontWeight.Heavy,
						position = UDim2.fromOffset(10, 0),
						sizeConstraint = UDim2.new(1, -98, 1, 0),
						zIndex = 427,
					}),
					React.createElement(Text, {
						value = if props.phase == "spin" then "ROLLING" elseif landed then "LANDED" else "READY",
						size = 9,
						color = if landed then props.winnerAccent else props.sessionAccent,
						weight = Enum.FontWeight.Heavy,
						align = Enum.TextXAlignment.Right,
						position = UDim2.new(1, -76, 0, 0),
						sizeConstraint = UDim2.fromOffset(66, 30),
						zIndex = 427,
					})
				),
				React.createElement(
					"frame",
					{
						Size = UDim2.fromOffset(layout.reelWidth, layout.reelHeight),
						Position = UDim2.new(0.5, 0, 1, -10),
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundColor3 = Palette.void,
						BackgroundTransparency = 0.05,
						BorderSizePixel = 0,
						ZIndex = 427,
						ClipsDescendants = true,
						Visible = not layout.compactHeight or not landed,
					},
					React.createElement("uicorner", { CornerRadius = UDim.new(0, 12) }),
					React.createElement("uistroke", {
						Color = Palette.line,
						Thickness = 1,
						Transparency = 0.35,
					}),
					React.createElement("frame", {
						Size = UDim2.new(1, -16, 0, 4),
						Position = UDim2.new(0.5, 0, 0.5, 0),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Palette.lineSoft,
						BackgroundTransparency = 0.36,
						BorderSizePixel = 0,
						ZIndex = 428,
					}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
					table.unpack(speedBars),
					React.createElement(
						ShimmerProvider,
						{},
						React.createElement("frame", {
							Size = UDim2.fromOffset(#props.cards * props.stride, props.cardHeight),
							Position = props.reelOffset:map(function(offset)
								return UDim2.fromOffset(
									layout.reelWidth / 2 - props.cardWidth / 2 - offset,
									math.floor((layout.reelHeight - props.cardHeight) / 2)
								)
							end),
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							ZIndex = 429,
						}, table.unpack(cardElements))
					),
					React.createElement(
						"frame",
						{
							Size = UDim2.new(0, math.min(54, layout.reelWidth * 0.16), 1, 0),
							BackgroundColor3 = Palette.void,
							BackgroundTransparency = 0.05,
							BorderSizePixel = 0,
							ZIndex = 438,
						},
						React.createElement("uigradient", {
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0),
								NumberSequenceKeypoint.new(1, 1),
							}),
						})
					),
					React.createElement(
						"frame",
						{
							Size = UDim2.new(0, math.min(54, layout.reelWidth * 0.16), 1, 0),
							Position = UDim2.fromScale(1, 0),
							AnchorPoint = Vector2.new(1, 0),
							BackgroundColor3 = Palette.void,
							BackgroundTransparency = 0.05,
							BorderSizePixel = 0,
							ZIndex = 438,
						},
						React.createElement("uigradient", {
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 1),
								NumberSequenceKeypoint.new(1, 0),
							}),
						})
					),
					React.createElement(
						"frame",
						{
							Size = UDim2.fromOffset(props.cardWidth + 12, props.cardHeight + 8),
							Position = UDim2.fromScale(0.5, 0.5),
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = if landed then props.winnerAccent else props.sessionAccent,
							BackgroundTransparency = if landed then 0.91 else 0.95,
							BorderSizePixel = 0,
							ZIndex = 439,
						},
						React.createElement("uiscale", {
							Scale = selectorScale:map(function(amount)
								return amount * cardFitScale
							end),
						}),
						React.createElement("uicorner", { CornerRadius = UDim.new(0, 14) }),
						React.createElement("uistroke", {
							Color = if landed then props.winnerAccent else props.sessionAccent,
							Thickness = if landed then 2.5 else 1.5,
							Transparency = if landed then 0.04 else 0.18,
						})
					),
					React.createElement("frame", {
						Size = UDim2.new(0, 2, 1, -12),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Palette.cream,
						BackgroundTransparency = props.tickEnergy:map(function(amount)
							return 0.62 - amount * 0.36
						end),
						BorderSizePixel = 0,
						ZIndex = 440,
					})
				),
				React.createElement(
					"frame",
					{
						Size = UDim2.fromOffset(68, 12),
						Position = pressOffset:map(function(value)
							return UDim2.new(0.5, 0, 0, 33 + value)
						end),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Palette.creamSoft,
						BorderSizePixel = 0,
						ZIndex = 445,
					},
					React.createElement("uicorner", { CornerRadius = UDim.new(0, 4) }),
					React.createElement("uigradient", {
						Color = ColorSequence.new(Palette.cream, Palette.lineSoft),
						Rotation = 90,
					}),
					React.createElement("frame", {
						Size = UDim2.fromOffset(28, 9),
						Position = UDim2.fromScale(0.5, 1),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = if landed then props.winnerAccent else props.sessionAccent,
						BorderSizePixel = 0,
						ZIndex = 446,
					}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 3) }))
				),
				React.createElement(
					"frame",
					{
						Size = UDim2.new(1, -24, 0, 3),
						Position = UDim2.new(0.5, 0, 1, -5),
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundColor3 = Palette.line,
						BorderSizePixel = 0,
						ZIndex = 447,
					},
					React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }),
					React.createElement("frame", {
						Size = progressWidth,
						BackgroundColor3 = if landed then props.winnerAccent else props.sessionAccent,
						BorderSizePixel = 0,
						ZIndex = 448,
					}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
				)
			)
		)
	end

	local function LandingBurst(_param)
		local props = _param.props
		local layout = _param.layout
		if props.phase ~= "land" then
			return nil
		end

		local count = math.clamp(math.floor(5 + props.fxBudget * 8), 5, 13)
		local center = UDim2.new(
			layout.stagePosition.X.Scale,
			layout.stagePosition.X.Offset + (0.5 - layout.stageAnchor.X) * layout.stageSize.X.Offset,
			layout.stagePosition.Y.Scale,
			layout.stagePosition.Y.Offset + (0.5 - layout.stageAnchor.Y) * layout.stageSize.Y.Offset
		)

		local sparks = {}
		if not props.reducedMotion and props.allowAmbient then
			for index = 0, 12 do
				if index >= count then
					break
				end
				local angle = (index / count) * math.pi * 2 - math.pi / 2
				local distance = 58 + (index % 4) * 22
				local sizeW = if index % 3 == 0 then 8 else 5
				local sizeH = if index % 2 == 0 then 3 else 5
				local travel = props.landFlash:map(function(amount)
					return 1 - amount
				end)
				sparks[index + 1] = React.createElement("frame", {
					key = `crate-spark-{index}`,
					Size = UDim2.fromOffset(sizeW, sizeH),
					Position = travel:map(function(amount)
						return UDim2.new(
							center.X.Scale,
							center.X.Offset + math.cos(angle) * distance * amount,
							center.Y.Scale,
							center.Y.Offset + math.sin(angle) * distance * amount
						)
					end),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Rotation = index * 37,
					BackgroundColor3 = if index % 3 == 0 then Palette.cream else props.winnerAccent,
					BackgroundTransparency = travel:map(function(amount)
						return math.clamp(amount * 1.2, 0, 1)
					end),
					BorderSizePixel = 0,
					ZIndex = 448,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) }))
			end
		end

		local beams = {}
		if not props.reducedMotion and props.allowAmbient then
			for i = 0, 2 do
				local bx = -60 + i * 60
				beams[i + 1] = React.createElement(
					"frame",
					{
						key = `land-beam-{i}`,
						Size = props.landFlash:map(function(f)
							return UDim2.fromOffset(2 + i, math.round(f * (140 + i * 40)))
						end),
						Position = UDim2.new(center.X.Scale, center.X.Offset + bx, center.Y.Scale, center.Y.Offset),
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundColor3 = if i == 1 then Palette.cream else props.winnerAccent,
						BackgroundTransparency = props.landFlash:map(function(f)
							return 1 - f * (0.55 - i * 0.1)
						end),
						BorderSizePixel = 0,
						ZIndex = 448,
					},
					React.createElement("uigradient", {
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(0.6, 0.3),
							NumberSequenceKeypoint.new(1, 1),
						}),
						Rotation = 90,
					}),
					React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })
				)
			end
		end

		local shockRing = not props.reducedMotion
			and React.createElement(
				"frame",
				{
					Size = props.landFlash:map(function(f)
						local s = easeOutExpo(f) * 160
						return UDim2.fromOffset(s, s)
					end),
					Position = center,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 449,
				},
				React.createElement("uistroke", {
					Color = props.winnerAccent,
					Thickness = 2,
					Transparency = props.landFlash:map(function(f)
						return 0.05 + (1 - f) * 0.85
					end),
				}),
				React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })
			)

		return React.createElement(
			"frame",
			{
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 448,
				Active = false,
			},
			table.unpack(sparks),
			table.unpack(beams),
			shockRing,
			React.createElement(
				"frame",
				{
					Size = props.landFlash:map(function(amount)
						return UDim2.fromOffset(150 + amount * 460, 3 + amount * 3)
					end),
					Position = center,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Palette.cream,
					BackgroundTransparency = props.landFlash:map(function(amount)
						return 1 - amount * 0.82
					end),
					BorderSizePixel = 0,
					ZIndex = 448,
				},
				React.createElement("uigradient", {
					Color = ColorSequence.new(props.winnerAccent, Palette.cream),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.42, 0.05),
						NumberSequenceKeypoint.new(0.58, 0.05),
						NumberSequenceKeypoint.new(1, 1),
					}),
				})
			)
		)
	end

	local function ResultPanel(_param)
		local props = _param.props
		local layout = _param.layout
		local visible = props.phase == "land" or props.phase == "done" or props.phase == "exit"
		local accentLineWidth, setAccentLineWidth = React.useBinding(0)
		React.useEffect(function()
			if not visible then
				return nil
			end
			local start = os.clock()
			local dur = 0.55
			local conn = RunService.RenderStepped:Connect(function()
				local t = math.clamp((os.clock() - start) / dur, 0, 1)
				setAccentLineWidth(easeOutBack(t))
			end)
			return function()
				conn:Disconnect()
			end
		end, { props.winnerName, visible })
		if not visible then
			return nil
		end

		return React.createElement(
			"frame",
			{
				Size = layout.resultSize,
				Position = props.landPop:map(function(amount)
					return UDim2.new(
						layout.resultPosition.X.Scale,
						layout.resultPosition.X.Offset,
						layout.resultPosition.Y.Scale,
						layout.resultPosition.Y.Offset + math.round((1 - amount) * 18)
					)
				end),
				AnchorPoint = layout.resultAnchor,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 450,
			},
			React.createElement(
				Panel,
				{
					size = UDim2.fromScale(1, 1),
					accent = props.winnerAccent,
					background = Palette.panelRaised,
					padding = if props.shortLandscape then 10 else 12,
					highlight = true,
					reducedMotion = props.reducedMotion,
					clips = false,
					zIndex = 450,
				},
				React.createElement(Text, {
					value = `{string.upper(props.winnerRarity)}  Ã¢â‚¬Â¢  ROLL {props.rollIndex + 1}/{props.rollCount}`,
					size = 9,
					color = props.winnerAccent,
					weight = Enum.FontWeight.Heavy,
					fit = true,
					minSize = 7,
					sizeConstraint = UDim2.new(1, if props.shortLandscape then 0 else -118, 0, 14),
					zIndex = 452,
				}),
				React.createElement(Text, {
					value = props.winnerName,
					size = if props.shortLandscape then 16 else 19,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = true,
					minSize = 9,
					position = UDim2.fromOffset(0, 18),
					sizeConstraint = UDim2.new(1, if props.shortLandscape then 0 else -118, 0, 26),
					zIndex = 452,
				}),
				React.createElement("frame", {
					Size = accentLineWidth:map(function(t)
						return UDim2.new(t * (if props.shortLandscape then 0.55 else 0.42), 0, 0, 2)
					end),
					Position = UDim2.fromOffset(0, 44),
					BackgroundColor3 = props.winnerAccent,
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
					ZIndex = 453,
				}, React.createElement("uicorner", { CornerRadius = UDim.new(1, 0) })),
				React.createElement(Text, {
					value = props.resultDetail,
					size = 9,
					color = Palette.creamSoft,
					fit = true,
					minSize = 7,
					wrap = true,
					position = UDim2.fromOffset(0, 47),
					sizeConstraint = UDim2.new(
						1,
						if props.shortLandscape then 0 else -118,
						0,
						if props.shortLandscape then 32 else 24
					),
					zIndex = 452,
				}),
				React.createElement(Badge, {
					value = props.resultTag,
					accent = if props.resultTag == "NEW FIND" then Palette.mint else props.winnerAccent,
					filled = true,
					position = if props.shortLandscape then UDim2.new(0, 0, 1, -27) else UDim2.new(1, -106, 0.5, -14),
					size = if props.shortLandscape then UDim2.new(1, 0, 0, 22) else UDim2.fromOffset(106, 28),
					zIndex = 453,
				})
			)
		)
	end

	local function CrateRevealStage(props)
		local layout = resolveLayout(props)
		local antilag = useAntilag()
		local softMotion = props.reducedMotion == true
		local reducedMotion = softMotion
		local allowAmbient = not reducedMotion and props.allowAmbient ~= false and antilag.allowAmbient
		local actionHostRef = React.useRef(nil)
		React.useEffect(function()
			if not UserInputService.GamepadEnabled then
				return nil
			end
			local host = actionHostRef.current
			if host == nil then
				return nil
			end
			if props.phase ~= "spin" and props.phase ~= "done" then
				GamepadNavigationService.ClearSelection()
				return nil
			end
			local selectJob = task.defer(function()
				if host.Parent == nil then
					return
				end
				GamepadNavigationService.FocusClaim(host)
			end)
			return function()
				pcall(task.cancel, selectJob)
			end
		end, { props.phase })
		local dimmer = props.visualShow:map(function(amount)
			return 1 - math.clamp(amount, 0, 1) * 0.985
		end)
		local accentWash = props.visualShow:map(function(amount)
			return 1 - math.clamp(amount, 0, 1) * 0.08
		end)
		local showingClaim = props.phase == "done" or props.phase == "exit"

		local stageProps = table.clone(props)
		stageProps.reducedMotion = reducedMotion
		stageProps.allowAmbient = allowAmbient

		return React.createElement(
			"frame",
			{
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Active = true,
				ZIndex = 400,
			},
			React.createElement("imagebutton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Palette.void,
				BackgroundTransparency = dimmer,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Selectable = false,
				Active = props.phase == "spin" or props.phase == "done",
				ZIndex = 401,
				Event = {
					Activated = function()
						if props.phase == "spin" then
							Audio:play("crateBrake")
							props.onQuickLand()
						elseif props.phase == "done" then
							Audio:play("crateClaim")
							props.onClaim()
						end
					end,
				},
			}),
			React.createElement(
				"frame",
				{
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = darken(props.sessionAccent, 0.6),
					BackgroundTransparency = accentWash,
					BorderSizePixel = 0,
					ZIndex = 402,
				},
				React.createElement("uigradient", {
					Color = ColorSequence.new(darken(props.sessionAccent, 0.78), Palette.void),
					Rotation = 90,
				})
			),
			React.createElement(
				"frame",
				{
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 404,
					ClipsDescendants = true,
					Visible = props.visualShow:map(function(amount)
						return amount > 0.015
					end),
				},
				React.createElement(
					ScaleFromCenter,
					{
						scale = props.shellScale,
						zIndex = 404,
					},
					React.createElement(ForgeBackdrop, { props = stageProps, layout = layout }),
					React.createElement(RevealHeader, { props = stageProps, layout = layout }),
					React.createElement(ForgeReel, { props = stageProps, layout = layout }),
					React.createElement(LandingBurst, { props = stageProps, layout = layout }),
					React.createElement(ResultPanel, { props = stageProps, layout = layout }),
					props.phase == "spin"
						and React.createElement(
							"frame",
							{
								ref = actionHostRef,
								Name = "CrateSkip",
								Size = layout.actionSize,
								Position = layout.actionPosition,
								AnchorPoint = layout.actionAnchor,
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								ZIndex = 455,
							},
							React.createElement(Button, {
								text = "SKIP TO RESULT",
								icon = "Chevron",
								onClick = props.onQuickLand,
								color = Palette.panelSoft,
								textColor = Palette.creamSoft,
								outline = true,
								size = UDim2.fromScale(1, 1),
								reducedMotion = reducedMotion,
								selectable = true,
							})
						),
					showingClaim
						and React.createElement(
							"frame",
							{
								ref = actionHostRef,
								Name = "CrateClaim",
								Size = layout.actionSize,
								Position = props.claimSlide:map(function(amount)
									return UDim2.new(
										layout.actionPosition.X.Scale,
										layout.actionPosition.X.Offset,
										layout.actionPosition.Y.Scale,
										layout.actionPosition.Y.Offset + math.round((1 - amount) * 24)
									)
								end),
								AnchorPoint = layout.actionAnchor,
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								ClipsDescendants = false,
								ZIndex = 456,
							},
							React.createElement(Button, {
								text = props.claimText,
								icon = "Gift",
								onClick = props.onClaim,
								color = props.sessionAccent,
								textColor = Palette.ink,
								size = UDim2.fromScale(1, 1),
								reducedMotion = reducedMotion,
								highlight = true,
								selectable = true,
								disabled = props.phase == "exit",
							})
						)
				)
			)
		)
	end

	return {
		CrateRevealStage = CrateRevealStage,
	}
end

local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
