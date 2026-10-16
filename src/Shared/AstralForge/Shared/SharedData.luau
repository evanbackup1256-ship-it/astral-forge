--!strict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

-- Lune guards have no `script`; they resolve siblings by path instead.
local function sibling(name: string): any
	if script ~= nil then
		return require((script.Parent :: any)[name])
	end
	return (require :: any)("./" .. name)
end

local KIT_READY = sibling("PropKit").KitReady

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("SharedData: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("SharedData: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

local function validateMonetizationIds(): { [string]: { string } }
	local config = __load("MonetizationConfig")
	local missing = {
		DevProducts = {},
		GamePasses = {},
	}
	-- Keep runtime purchase gates unchanged while making every placeholder visible at boot.
	for _, entry in config.DevProducts do
		if entry.ProductId <= 0 then
			table.insert(missing.DevProducts, entry.Key)
		end
	end
	for _, entry in config.GamePasses do
		if entry.PassId <= 0 then
			table.insert(missing.GamePasses, entry.Key)
		end
	end
	return missing
end

__defs["AssetManifest"] = function()

type Region = { number }

local Manifest = {}

Manifest.SoundSheet = {
	Id = 89052196079187,
	Length = 195.445,
	Regions = {
		hover = { 0.15, 0.08 },
		hoverTick = { 0.38, 0.08 },
		tick = { 0.61, 0.08 },
		scroll = { 0.84, 0.08 },
		sliderStep = { 1.07, 0.08 },
		amountChange = { 1.3, 0.08 },
		filterPick = { 1.53, 0.11 },
		navHover = { 1.79, 0.08 },
		click = { 2.02, 0.198 },
		settings = { 2.368, 0.198 },
		purchasePress = { 2.716, 0.315 },
		claimPress = { 3.181, 0.315 },
		codeSubmit = { 3.6459, 0.315 },
		zoneSelect = { 4.1109, 0.315 },
		labRoute = { 4.5759, 0.315 },
		playerlistAction = { 5.0409, 0.198 },
		playerlistSelect = { 5.3889, 0.08 },
		confirm = { 5.6189, 0.67 },
		successChime = { 6.4389, 0.7399 },
		equip = { 7.3288, 0.31 },
		itemLink = { 7.7888, 0.3 },
		tutorialStep = { 8.2388, 0.37 },
		roleChange = { 8.7588, 0.315 },
		reactorStabilize = { 9.2238, 1.47 },
		toggleOn = { 10.8438, 0.305 },
		toggleOff = { 11.2988, 0.305 },
		queueStart = { 11.7537, 0.31 },
		queueStop = { 12.2137, 0.31 },
		open = { 12.6737, 0.3817 },
		modalOpen = { 13.2054, 0.6865 },
		filterOpen = { 14.042, 0.2 },
		boostOpen = { 14.3919, 0.4234 },
		offlineOpen = { 14.9653, 0.8099 },
		playerlistOpen = { 15.9252, 0.3821 },
		story = { 16.4573, 1.1893 },
		storyOpen = { 17.7966, 1.4975 },
		crate = { 19.444, 0.4145 },
		close = { 20.0085, 0.3074 },
		modalDismiss = { 20.466, 0.3122 },
		purchaseExit = { 20.9282, 0.3017 },
		playerlistClose = { 21.38, 0.3064 },
		itemUnlink = { 21.8364, 0.25 },
		reset = { 22.2364, 0.26 },
		memberRemove = { 22.6464, 0.32 },
		guildLeave = { 23.1164, 0.39 },
		page = { 23.6564, 0.4047 },
		tabSwitch = { 24.2111, 0.145 },
		preview = { 24.5061, 0.198 },
		storyBeat = { 24.854, 1.2324 },
		storyPage = { 26.2365, 0.24 },
		mailRead = { 26.6265, 0.29 },
		leaderboardSwitch = { 27.0665, 0.145 },
		modalPop = { 27.3615, 0.22 },
		sliderCommit = { 27.7315, 0.25 },
		inputClear = { 28.1315, 0.175 },
		chatSend = { 28.4564, 0.25 },
		inputFocus = { 28.8564, 0.17 },
		error = { 29.1764, 0.38 },
		errorBuzz = { 29.7064, 0.47 },
		noticeError = { 30.3264, 0.38 },
		dangerPress = { 30.8564, 0.27 },
		locked = { 31.2764, 0.225 },
		requestBlocked = { 31.6514, 0.27 },
		noticeWarning = { 32.0714, 0.44 },
		systemAlert = { 32.6614, 0.8 },
		requestTimeout = { 33.6114, 0.54 },
		adminArm = { 34.3014, 0.27 },
		mail = { 34.7214, 0.6975 },
		notification = { 35.5689, 0.5828 },
		noticeInfo = { 36.3016, 0.5731 },
		noticeSuccess = { 37.0248, 0.6065 },
		noticeSpecial = { 37.7813, 0.9345 },
		boostReady = { 38.8658, 0.49 },
		reactorReady = { 39.5058, 0.54 },
		crewNudge = { 40.1958, 0.33 },
		invite = { 40.6758, 0.315 },
		chatReceive = { 41.1408, 0.32 },
		travel = { 41.6108, 0.8191 },
		purchase = { 42.5799, 0.59 },
		purchaseResult = { 43.3199, 0.8568 },
		vaultDeposit = { 44.3268, 0.54 },
		vaultBank = { 45.0168, 0.6 },
		guildDeposit = { 45.7668, 0.54 },
		collect = { 46.4568, 0.61 },
		boost = { 47.2168, 0.7471 },
		boostActivate = { 48.1138, 1.21 },
		offlineCollect = { 49.4738, 1.17 },
		reward = { 50.7937, 0.89 },
		codeReward = { 51.8337, 0.9674 },
		tutorialFinish = { 52.9511, 1.1857 },
		domainReward = { 54.2868, 1.3276 },
		wheelLand = { 55.7643, 1.43 },
		unlock = { 57.3443, 1.12 },
		researchUnlock = { 58.6143, 0.9005 },
		achievementClaim = { 59.6648, 1.1819 },
		seasonClaim = { 60.9967, 1.17 },
		comboMilestone = { 62.3166, 0.41 },
		discovery = { 62.8766, 1.6107 },
		zoneUnlock = { 64.6373, 2.07 },
		guildCreate = { 66.8573, 0.82 },
		echoCapture = { 67.8273, 1.4741 },
		storyReveal = { 69.4514, 1.73 },
		missionClaim = { 71.3313, 0.892 },
		dailyClaim = { 72.3733, 1.12 },
		timedClaim = { 73.6433, 0.9025 },
		mailClaim = { 74.6958, 0.8572 },
		crateClaim = { 75.7031, 0.8772 },
		echoClaim = { 76.7302, 0.9027 },
		guildJoin = { 77.783, 0.72 },
		expeditionReturn = { 78.653, 1.12 },
		prestige = { 79.9229, 2.01 },
		rebirthBloom = { 82.0829, 1.2219 },
		crateRare = { 83.4548, 0.7655 },
		salvage = { 84.3703, 0.36 },
		salvageCrunch = { 84.8803, 0.59 },
		echoDismantle = { 85.6203, 0.59 },
		autoForge = { 86.3603, 0.28 },
		machineInstall = { 86.7903, 0.41 },
		wheelBrake = { 87.3503, 0.4 },
		crateBrake = { 87.9003, 0.35 },
		wheel = { 88.4003, 0.4306 },
		wheelStart = { 88.981, 0.34 },
		crateOpen = { 89.471, 0.34 },
		expeditionLaunch = { 89.961, 0.9839 },
		bootStart = { 91.0948, 3.0499 },
		reactor = { 94.2947, 0.4138 },
		reactorSurge = { 94.8585, 1.1931 },
		adminExecute = { 96.2017, 0.64 },
		crateLand = { 96.9916, 0.43 },
		domainImpact = { 97.5716, 2.49 },
		bootFinaleBang = { 100.2116, 2.79 },
		rebirthCharge = { 103.1516, 0.8 },
		wheelCharge = { 104.1016, 0.4 },
		crateCharge = { 104.6516, 0.5 },
		domainCharge = { 105.3016, 0.7 },
		reactorPulse = { 106.1515, 0.29 },
		domainCrack = { 106.5915, 1.27 },
		domainBind = { 108.0115, 2.12 },
		boot = { 110.2815, 2.4328 },
		wheelTick = { 112.8643, 0.06 },
		wheelSlow = { 113.0743, 0.095 },
		crateTick = { 113.3193, 0.06 },
		crateNear = { 113.5293, 0.27 },
		bootReady = { 113.9493, 1.846 },
		echoEquip = { 115.9453, 0.54 },
		echoTune = { 116.6353, 0.4 },
		navOpenOverview = { 117.1853, 0.4991 },
		navHoverOverview = { 117.8344, 0.08 },
		navOpenWorkshop = { 118.0644, 0.485 },
		navHoverWorkshop = { 118.6994, 0.08 },
		navOpenInventory = { 118.9294, 0.4837 },
		navHoverInventory = { 119.5631, 0.08 },
		navOpenResearch = { 119.7931, 0.4971 },
		navHoverResearch = { 120.4402, 0.08 },
		navOpenShop = { 120.6702, 0.4848 },
		navHoverShop = { 121.305, 0.08 },
		navOpenSettings = { 121.535, 0.4798 },
		navHoverSettings = { 122.1649, 0.08 },
		navOpenWorlds = { 122.3949, 0.5039 },
		navHoverWorlds = { 123.0487, 0.08 },
		navOpenMissions = { 123.2787, 0.5005 },
		navHoverMissions = { 123.9292, 0.08 },
		navOpenRewards = { 124.1592, 0.481 },
		navHoverRewards = { 124.7902, 0.08 },
		navOpenBoosts = { 125.0202, 0.4878 },
		navHoverBoosts = { 125.658, 0.08 },
		navOpenStarGrid = { 125.888, 0.5004 },
		navHoverStarGrid = { 126.5384, 0.08 },
		navOpenEchoes = { 126.7684, 0.4967 },
		navHoverEchoes = { 127.4151, 0.08 },
		navOpenContinuum = { 127.6451, 0.4917 },
		navHoverContinuum = { 128.2869, 0.08 },
		navOpenLab = { 128.5169, 0.5018 },
		navHoverLab = { 129.1687, 0.08 },
		navOpenAnomaly = { 129.3987, 0.475 },
		navHoverAnomaly = { 130.0237, 0.08 },
		navOpenWheel = { 130.2537, 0.4849 },
		navHoverWheel = { 130.8886, 0.08 },
		navOpenCommand = { 131.1186, 0.5141 },
		navHoverCommand = { 131.7827, 0.08 },
		navOpenStory = { 132.0127, 0.4622 },
		navHoverStory = { 132.6249, 0.08 },
		navOpenMail = { 132.8549, 0.5063 },
		navHoverMail = { 133.5112, 0.08 },
		navOpenChat = { 133.7412, 0.4787 },
		navHoverChat = { 134.3699, 0.08 },
		navOpenCrew = { 134.5999, 0.4805 },
		navHoverCrew = { 135.2304, 0.08 },
		navOpenMilestones = { 135.4604, 0.5009 },
		navHoverMilestones = { 136.1113, 0.08 },
		navOpenConvergence = { 136.3413, 0.4818 },
		navHoverConvergence = { 136.9731, 0.08 },
		navOpenGuild = { 137.2031, 0.4814 },
		navHoverGuild = { 137.8346, 0.08 },
		navOpenLeaderboards = { 138.0646, 0.5133 },
		navHoverLeaderboards = { 138.7279, 0.08 },
		navOpenTrade = { 138.9579, 0.5098 },
		navHoverTrade = { 139.6176, 0.08 },
		navOpenCredits = { 139.8476, 0.5025 },
		navHoverCredits = { 140.5002, 0.08 },
		navOpenAdmin = { 140.7302, 0.5027 },
		navHoverAdmin = { 141.3829, 0.08 },
		navOpenForgePath = { 141.6129, 0.4856 },
		navHoverForgePath = { 142.2484, 0.08 },
		navOpenFoundry = { 142.4784, 0.4957 },
		navHoverFoundry = { 143.1242, 0.08 },
		clickHover = { 143.3542, 0.08 },
		confirmHover = { 143.5842, 0.08 },
		settingsHover = { 143.8142, 0.08 },
		purchasePressHover = { 144.0442, 0.08 },
		claimPressHover = { 144.2742, 0.08 },
		codeSubmitHover = { 144.5042, 0.08 },
		zoneSelectHover = { 144.7342, 0.08 },
		labRouteHover = { 144.9642, 0.08 },
		playerlistActionHover = { 145.1942, 0.08 },
		playerlistSelectHover = { 145.4242, 0.08 },
		equipHover = { 145.6542, 0.08 },
		dangerPressHover = { 145.8842, 0.08 },
		closeHover = { 146.1142, 0.08 },
		tickHover = { 146.3442, 0.08 },
		openHover = { 146.5742, 0.08 },
		tabSwitchHover = { 146.8042, 0.08 },
		mailHover = { 147.0342, 0.08 },
		storyHover = { 147.2642, 0.08 },
		toggleOnHover = { 147.4942, 0.08 },
		toggleOffHover = { 147.7242, 0.08 },
		lockedHover = { 147.9542, 0.08 },
		errorHover = { 148.1842, 0.08 },
		prestigeHover = { 148.4142, 0.08 },
		domainChargeHover = { 148.6442, 0.08 },
		vaultBankHover = { 148.8742, 0.08 },
		guildCreateHover = { 149.1042, 0.08 },
		guildJoinHover = { 149.3342, 0.08 },
		inviteHover = { 149.5642, 0.08 },
		travelHover = { 149.7942, 0.08 },
		queueStopHover = { 150.0242, 0.08 },
		queueStartHover = { 150.2542, 0.08 },
		boostHover = { 150.4842, 0.08 },
		reactorPulseHover = { 150.7142, 0.08 },
		crateOpenHover = { 150.9442, 0.08 },
		wheelStartHover = { 151.1742, 0.08 },
		rewardHover = { 151.4042, 0.08 },
		rebirthChargeHover = { 151.6342, 0.08 },
		missionClaimHover = { 151.8642, 0.08 },
		leaderboardSwitchHover = { 152.0942, 0.08 },
		adminArmHover = { 152.3242, 0.08 },
		memberRemoveHover = { 152.5542, 0.08 },
		roleChangeHover = { 152.7842, 0.08 },
		previewHover = { 153.0142, 0.08 },
		resetHover = { 153.2442, 0.08 },
		chatSendHover = { 153.4742, 0.08 },
		boostOpenHover = { 153.7042, 0.08 },
		vaultDepositHover = { 153.9342, 0.08 },
		forgePress = { 154.1642, 0.198 },
		corePress = { 154.5122, 0.198 },
		wavePress = { 154.8601, 0.198 },
		labPress = { 155.2081, 0.198 },
		commandPress = { 155.5561, 0.198 },
		adminPress = { 155.9041, 0.198 },
		creditsPress = { 156.2521, 0.198 },
		chatPress = { 156.6, 0.198 },
		continuumPress = { 156.948, 0.198 },
		missionPress = { 157.296, 0.198 },
		overviewPress = { 157.644, 0.198 },
		dropdownOpen = { 157.992, 0.2 },
		dropdownClose = { 158.342, 0.2 },
		copyDone = { 158.6919, 0.365 },
		dragGrab = { 159.2069, 0.12 },
		dragDrop = { 159.4769, 0.275 },
		dragSnap = { 159.9019, 0.08 },
		favoriteOn = { 160.1319, 0.5141 },
		favoriteOff = { 160.796, 0.26 },
		ratingStar = { 161.206, 0.29 },
		searchType = { 161.646, 0.08 },
		countTick = { 161.876, 0.08 },
		stepNext = { 162.106, 0.31 },
		stepBack = { 162.566, 0.31 },
		reportSubmit = { 163.026, 0.67 },
		feedbackSubmit = { 163.8459, 0.77 },
		guildAnnounce = { 164.7659, 1.8363 },
		badgeEarn = { 166.7523, 0.8683 },
		artifactEquip = { 167.7705, 0.91 },
		artifactUpgrade = { 168.8305, 0.8596 },
		crateSeal = { 169.8401, 0.91 },
		crateOrbit = { 170.9001, 0.6 },
		crateRarityStep = { 171.6501, 0.27 },
		crateRevealEpic = { 172.0701, 1.58 },
		crateRevealMythic = { 173.8001, 2.19 },
		rebirthIgnite = { 176.14, 1.9385 },
		rebirthShockwave = { 178.2286, 2.17 },
		rebirthTierUp = { 180.5485, 0.6979 },
		rebirthAscend = { 181.3965, 2.69 },
		foundryDraw = { 184.2364, 0.6485 },
		foundryDrawRare = { 185.0349, 1.5 },
		foundryExpand = { 186.6849, 2.23 },
		foundryFlow = { 189.0649, 0.12 },
		foundryFuse = { 189.3349, 1.19 },
		foundryIgnite = { 190.6749, 0.39 },
		foundryIgniteMiss = { 191.2149, 0.22 },
		foundryOpen = { 191.5849, 1.0112 },
		foundryPickUp = { 192.7461, 0.12 },
		foundryPlace = { 193.0161, 0.274 },
		foundryRotate = { 193.4401, 0.095 },
		foundrySurge = { 193.6851, 1.61 },
	} :: { [string]: Region },
	Loudness = {
		hover = -14.48,
		hoverTick = -14.71,
		tick = -14.52,
		scroll = -14.5,
		sliderStep = -14.6,
		amountChange = -14.62,
		filterPick = -14.29,
		navHover = -14.49,
		click = -15.39,
		settings = -15.35,
		purchasePress = -15.52,
		claimPress = -15.59,
		codeSubmit = -15.56,
		zoneSelect = -15.48,
		labRoute = -15.53,
		playerlistAction = -15.38,
		playerlistSelect = -14.53,
		confirm = -15.07,
		successChime = -13.23,
		equip = -15.23,
		itemLink = -15.93,
		tutorialStep = -14.4,
		roleChange = -15.52,
		reactorStabilize = -13.25,
		toggleOn = -15.65,
		toggleOff = -16.5,
		queueStart = -16.13,
		queueStop = -16.54,
		open = -15.7,
		modalOpen = -14.46,
		filterOpen = -14.39,
		boostOpen = -16.88,
		offlineOpen = -14.24,
		playerlistOpen = -15.1,
		story = -17.48,
		storyOpen = -16.58,
		crate = -16.29,
		close = -15.21,
		modalDismiss = -15.63,
		purchaseExit = -14.83,
		playerlistClose = -15.37,
		itemUnlink = -16.69,
		reset = -15.6,
		memberRemove = -15.7,
		guildLeave = -15.57,
		page = -15.59,
		tabSwitch = -15.96,
		preview = -15.38,
		storyBeat = -15.98,
		storyPage = -15.75,
		mailRead = -15.75,
		leaderboardSwitch = -15.98,
		modalPop = -15.13,
		sliderCommit = -14.48,
		inputClear = -14.31,
		chatSend = -15.29,
		inputFocus = -14.76,
		error = -14.94,
		errorBuzz = -14.33,
		noticeError = -14.87,
		dangerPress = -15.61,
		locked = -15.55,
		requestBlocked = -14.84,
		noticeWarning = -14.23,
		systemAlert = -13.11,
		requestTimeout = -14.28,
		adminArm = -14.4,
		mail = -14.6,
		notification = -14.39,
		noticeInfo = -13.95,
		noticeSuccess = -14.65,
		noticeSpecial = -12.47,
		boostReady = -14.34,
		reactorReady = -14.65,
		crewNudge = -13.87,
		invite = -15.5,
		chatReceive = -15.33,
		travel = -14.7,
		purchase = -14.7,
		purchaseResult = -12.87,
		vaultDeposit = -16.26,
		vaultBank = -14.89,
		guildDeposit = -16.21,
		collect = -15.31,
		boost = -16.52,
		boostActivate = -13.76,
		offlineCollect = -11.69,
		reward = -12.97,
		codeReward = -12.41,
		tutorialFinish = -12.12,
		domainReward = -12.33,
		wheelLand = -13.06,
		unlock = -14.11,
		researchUnlock = -13.75,
		achievementClaim = -12.21,
		seasonClaim = -11.87,
		comboMilestone = -14.52,
		discovery = -13.4,
		zoneUnlock = -14.95,
		guildCreate = -14.2,
		echoCapture = -17.71,
		storyReveal = -14.77,
		missionClaim = -13.08,
		dailyClaim = -11.29,
		timedClaim = -12.63,
		mailClaim = -13.33,
		crateClaim = -13.29,
		echoClaim = -13.51,
		guildJoin = -14.03,
		expeditionReturn = -11.95,
		prestige = -13.88,
		rebirthBloom = -13.36,
		crateRare = -13.06,
		salvage = -16.44,
		salvageCrunch = -18.95,
		echoDismantle = -16,
		autoForge = -16.37,
		machineInstall = -13.75,
		wheelBrake = -16.7,
		crateBrake = -17.13,
		wheel = -15.75,
		wheelStart = -15.01,
		crateOpen = -14.76,
		expeditionLaunch = -17.55,
		bootStart = -18.32,
		reactor = -15.62,
		reactorSurge = -14.33,
		adminExecute = -15.13,
		crateLand = -16.15,
		domainImpact = -14.26,
		bootFinaleBang = -14.98,
		rebirthCharge = -12.58,
		wheelCharge = -12.74,
		crateCharge = -12.65,
		domainCharge = -12.65,
		reactorPulse = -15.68,
		domainCrack = -19.18,
		domainBind = -18.05,
		boot = -17.86,
		wheelTick = -16.42,
		wheelSlow = -16.45,
		crateTick = -16.45,
		crateNear = -14.4,
		bootReady = -14.19,
		echoEquip = -16.31,
		echoTune = -14.51,
		navOpenOverview = -14.18,
		navHoverOverview = -14.72,
		navOpenWorkshop = -14.4,
		navHoverWorkshop = -14.61,
		navOpenInventory = -14.21,
		navHoverInventory = -14.34,
		navOpenResearch = -13.63,
		navHoverResearch = -14.58,
		navOpenShop = -15.28,
		navHoverShop = -14.55,
		navOpenSettings = -15.01,
		navHoverSettings = -14.57,
		navOpenWorlds = -14.39,
		navHoverWorlds = -14.52,
		navOpenMissions = -15.01,
		navHoverMissions = -14.71,
		navOpenRewards = -14.2,
		navHoverRewards = -14.56,
		navOpenBoosts = -15.19,
		navHoverBoosts = -14.3,
		navOpenStarGrid = -13.68,
		navHoverStarGrid = -14.61,
		navOpenEchoes = -14.93,
		navHoverEchoes = -14.55,
		navOpenContinuum = -14.69,
		navHoverContinuum = -14.61,
		navOpenLab = -14.45,
		navHoverLab = -14.44,
		navOpenAnomaly = -15.15,
		navHoverAnomaly = -14.64,
		navOpenWheel = -14.71,
		navHoverWheel = -14.63,
		navOpenCommand = -13.99,
		navHoverCommand = -14.32,
		navOpenStory = -15.36,
		navHoverStory = -14.57,
		navOpenMail = -14.74,
		navHoverMail = -14.49,
		navOpenChat = -14.14,
		navHoverChat = -14.6,
		navOpenCrew = -15.1,
		navHoverCrew = -14.46,
		navOpenMilestones = -14.75,
		navHoverMilestones = -14.65,
		navOpenConvergence = -14.29,
		navHoverConvergence = -14.62,
		navOpenGuild = -15.56,
		navHoverGuild = -14.38,
		navOpenLeaderboards = -14.09,
		navHoverLeaderboards = -14.58,
		navOpenTrade = -14,
		navHoverTrade = -14.5,
		navOpenCredits = -14,
		navHoverCredits = -14.58,
		navOpenAdmin = -14.93,
		navHoverAdmin = -14.49,
		navOpenForgePath = -13.81,
		navHoverForgePath = -14.54,
		navOpenFoundry = -14.12,
		navHoverFoundry = -14.61,
		clickHover = -14.46,
		confirmHover = -14.37,
		settingsHover = -14.45,
		purchasePressHover = -14.61,
		claimPressHover = -14.54,
		codeSubmitHover = -14.47,
		zoneSelectHover = -14.69,
		labRouteHover = -14.58,
		playerlistActionHover = -14.71,
		playerlistSelectHover = -14.57,
		equipHover = -14.7,
		dangerPressHover = -14.61,
		closeHover = -14.69,
		tickHover = -14.54,
		openHover = -14.5,
		tabSwitchHover = -14.51,
		mailHover = -14.48,
		storyHover = -14.57,
		toggleOnHover = -14.58,
		toggleOffHover = -14.34,
		lockedHover = -14.58,
		errorHover = -14.28,
		prestigeHover = -14.52,
		domainChargeHover = -14.55,
		vaultBankHover = -14.53,
		guildCreateHover = -14.62,
		guildJoinHover = -14.67,
		inviteHover = -14.62,
		travelHover = -14.61,
		queueStopHover = -14.59,
		queueStartHover = -14.55,
		boostHover = -14.56,
		reactorPulseHover = -14.44,
		crateOpenHover = -14.6,
		wheelStartHover = -14.66,
		rewardHover = -14.32,
		rebirthChargeHover = -14.39,
		missionClaimHover = -14.56,
		leaderboardSwitchHover = -14.5,
		adminArmHover = -14.58,
		memberRemoveHover = -14.42,
		roleChangeHover = -14.29,
		previewHover = -14.56,
		resetHover = -14.34,
		chatSendHover = -14.58,
		boostOpenHover = -14.3,
		vaultDepositHover = -14.6,
		forgePress = -15.3,
		corePress = -15.32,
		wavePress = -15.38,
		labPress = -15.27,
		commandPress = -15.3,
		adminPress = -15.32,
		creditsPress = -15.36,
		chatPress = -15.23,
		continuumPress = -15.3,
		missionPress = -15.31,
		overviewPress = -15.34,
		dropdownOpen = -14.57,
		dropdownClose = -14.37,
		copyDone = -15.36,
		dragGrab = -17.04,
		dragDrop = -15.97,
		dragSnap = -14.46,
		favoriteOn = -13.96,
		favoriteOff = -15.3,
		ratingStar = -15.16,
		searchType = -14.46,
		countTick = -14.59,
		stepNext = -15.02,
		stepBack = -15.19,
		reportSubmit = -15.88,
		feedbackSubmit = -14.18,
		guildAnnounce = -13.83,
		badgeEarn = -13.81,
		artifactEquip = -16.29,
		artifactUpgrade = -14.09,
		crateSeal = -15.57,
		crateOrbit = -12.67,
		crateRarityStep = -14.8,
		crateRevealEpic = -13.32,
		crateRevealMythic = -12.32,
		rebirthIgnite = -17.72,
		rebirthShockwave = -15.68,
		rebirthTierUp = -12.57,
		rebirthAscend = -12.55,
		foundryDraw = -14.97,
		foundryDrawRare = -13.23,
		foundryExpand = -13.25,
		foundryFlow = -15.03,
		foundryFuse = -13.61,
		foundryIgnite = -16.55,
		foundryIgniteMiss = -16.96,
		foundryOpen = -16.62,
		foundryPickUp = -16.77,
		foundryPlace = -16.03,
		foundryRotate = -16.6,
		foundrySurge = -14.16,
	} :: { [string]: number },
}

Manifest.SoundSheetPrevious = {
	Id = 90949921399160,
	Length = 183.503,
	Regions = {
		hover = { 0.15, 0.04 },
		hoverTick = { 0.34, 0.035 },
		tick = { 0.525, 0.03 },
		scroll = { 0.705, 0.025 },
		sliderStep = { 0.88, 0.025 },
		amountChange = { 1.055, 0.03 },
		filterPick = { 1.235, 0.07 },
		navHover = { 1.455, 0.04 },
		click = { 1.645, 0.092 },
		settings = { 1.887, 0.092 },
		purchasePress = { 2.129, 0.18 },
		claimPress = { 2.459, 0.25 },
		codeSubmit = { 2.859, 0.1398 },
		zoneSelect = { 3.1488, 0.14 },
		labRoute = { 3.4388, 0.14 },
		playerlistAction = { 3.7288, 0.092 },
		playerlistSelect = { 3.9708, 0.045 },
		confirm = { 4.1658, 0.3718 },
		successChime = { 4.6876, 0.5101 },
		equip = { 5.3477, 0.7715 },
		itemLink = { 6.2692, 0.623 },
		tutorialStep = { 7.0422, 0.7051 },
		roleChange = { 7.8973, 0.8496 },
		reactorStabilize = { 8.897, 0.9596 },
		toggleOn = { 10.0066, 0.1 },
		toggleOff = { 10.2566, 0.1 },
		queueStart = { 10.5066, 0.24 },
		queueStop = { 10.8966, 0.16 },
		open = { 11.2066, 0.2738 },
		modalOpen = { 11.6303, 0.3505 },
		filterOpen = { 12.1309, 0.09 },
		boostOpen = { 12.3709, 0.7217 },
		offlineOpen = { 13.2426, 0.722 },
		playerlistOpen = { 14.1146, 0.12 },
		story = { 14.3846, 0.3982 },
		storyOpen = { 14.9328, 0.722 },
		crate = { 15.8048, 0.722 },
		close = { 16.6768, 0.14 },
		modalDismiss = { 16.9668, 0.14 },
		purchaseExit = { 17.2568, 0.12 },
		playerlistClose = { 17.5268, 0.11 },
		itemUnlink = { 17.7868, 0.662 },
		reset = { 18.5988, 0.602 },
		memberRemove = { 19.3508, 0.662 },
		guildLeave = { 20.1628, 0.662 },
		page = { 20.9748, 0.12 },
		tabSwitch = { 21.2448, 0.07 },
		preview = { 21.4648, 0.412 },
		storyBeat = { 22.0268, 0.372 },
		storyPage = { 22.5488, 0.24 },
		mailRead = { 22.9388, 0.21 },
		leaderboardSwitch = { 23.2988, 0.07 },
		modalPop = { 23.5188, 0.08 },
		sliderCommit = { 23.7488, 0.15 },
		inputClear = { 24.0488, 0.08 },
		chatSend = { 24.2788, 0.08 },
		inputFocus = { 24.5088, 0.08 },
		error = { 24.7388, 0.24 },
		errorBuzz = { 25.1288, 0.32 },
		noticeError = { 25.5988, 0.24 },
		dangerPress = { 25.9888, 0.4336 },
		locked = { 26.5724, 0.125 },
		requestBlocked = { 26.8473, 0.21 },
		noticeWarning = { 27.2073, 0.26 },
		systemAlert = { 27.6173, 0.862 },
		requestTimeout = { 28.6293, 0.862 },
		adminArm = { 29.6413, 0.7449 },
		mail = { 30.5363, 0.409 },
		notification = { 31.0953, 0.8914 },
		noticeInfo = { 32.1367, 0.2389 },
		noticeSuccess = { 32.5256, 0.379 },
		noticeSpecial = { 33.0546, 0.5519 },
		boostReady = { 33.7565, 0.9331 },
		reactorReady = { 34.8396, 0.7375 },
		crewNudge = { 35.7271, 0.612 },
		invite = { 36.4891, 0.5808 },
		chatReceive = { 37.22, 0.12 },
		travel = { 37.49, 1.012 },
		purchase = { 38.652, 0.6257 },
		purchaseResult = { 39.4276, 0.5742 },
		vaultDeposit = { 40.1518, 0.6477 },
		vaultBank = { 40.9495, 0.6247 },
		guildDeposit = { 41.7242, 0.6778 },
		collect = { 42.552, 0.8909 },
		boost = { 43.5929, 0.8283 },
		boostActivate = { 44.5713, 0.8659 },
		offlineCollect = { 45.5871, 0.9968 },
		reward = { 46.7339, 2.1409 },
		codeReward = { 49.0248, 1.6946 },
		tutorialFinish = { 50.8695, 1.8705 },
		domainReward = { 52.8899, 1.9866 },
		wheelLand = { 55.0266, 1.5242 },
		unlock = { 56.7007, 1.7267 },
		researchUnlock = { 58.5774, 1.5673 },
		achievementClaim = { 60.2947, 1.7686 },
		seasonClaim = { 62.2133, 1.6384 },
		comboMilestone = { 64.0018, 1.6132 },
		discovery = { 65.7649, 1.6436 },
		zoneUnlock = { 67.5585, 1.8092 },
		guildCreate = { 69.5177, 1.5137 },
		echoCapture = { 71.1814, 1.8834 },
		storyReveal = { 73.2148, 1.9675 },
		missionClaim = { 75.3323, 1.1684 },
		dailyClaim = { 76.6507, 1.0257 },
		timedClaim = { 77.8264, 1.1425 },
		mailClaim = { 79.1189, 1.0252 },
		crateClaim = { 80.2941, 1.0375 },
		echoClaim = { 81.4816, 1.0602 },
		guildJoin = { 82.6917, 1.0286 },
		expeditionReturn = { 83.8703, 1.1433 },
		prestige = { 85.1637, 4.0907 },
		rebirthBloom = { 89.4043, 3.9206 },
		crateRare = { 93.4749, 3.8797 },
		salvage = { 97.5046, 0.9537 },
		salvageCrunch = { 98.6084, 0.8393 },
		echoDismantle = { 99.5977, 1.0821 },
		autoForge = { 100.8298, 0.8313 },
		machineInstall = { 101.8111, 0.8055 },
		wheelBrake = { 102.7666, 0.9522 },
		crateBrake = { 103.8688, 0.8182 },
		wheel = { 104.837, 0.812 },
		wheelStart = { 105.799, 1.186 },
		crateOpen = { 107.135, 0.942 },
		expeditionLaunch = { 108.227, 1.112 },
		bootStart = { 109.489, 0.962 },
		reactor = { 110.601, 1.2 },
		reactorSurge = { 111.951, 1.7989 },
		adminExecute = { 113.8999, 1.8074 },
		crateLand = { 115.8573, 1.7221 },
		domainImpact = { 117.7294, 1.7422 },
		bootFinaleBang = { 119.6216, 1.8545 },
		rebirthCharge = { 121.6261, 1.862 },
		wheelCharge = { 123.6381, 1.462 },
		crateCharge = { 125.2501, 1.562 },
		domainCharge = { 126.9621, 1.962 },
		reactorPulse = { 129.0741, 0.5062 },
		domainCrack = { 129.7303, 0.5275 },
		domainBind = { 130.4078, 2.6901 },
		boot = { 133.2478, 2.6663 },
		wheelTick = { 136.0642, 0.055 },
		wheelSlow = { 136.2692, 0.055 },
		crateTick = { 136.4742, 0.03 },
		crateNear = { 136.6542, 0.03 },
		bootReady = { 136.8342, 1.8383 },
		echoEquip = { 138.8225, 0.8345 },
		echoTune = { 139.807, 0.056 },
		navOpenOverview = { 140.013, 0.24 },
		navHoverOverview = { 140.403, 0.04 },
		navOpenWorkshop = { 140.593, 0.251 },
		navHoverWorkshop = { 140.994, 0.04 },
		navOpenInventory = { 141.184, 0.2508 },
		navHoverInventory = { 141.5847, 0.04 },
		navOpenResearch = { 141.7747, 0.2508 },
		navHoverResearch = { 142.1755, 0.04 },
		navOpenShop = { 142.3655, 0.2509 },
		navHoverShop = { 142.7664, 0.04 },
		navOpenSettings = { 142.9564, 0.2688 },
		navHoverSettings = { 143.3751, 0.04 },
		navOpenWorlds = { 143.5651, 0.2688 },
		navHoverWorlds = { 143.9839, 0.04 },
		navOpenMissions = { 144.1739, 0.2506 },
		navHoverMissions = { 144.5745, 0.04 },
		navOpenRewards = { 144.7645, 0.2574 },
		navHoverRewards = { 145.1719, 0.04 },
		navOpenBoosts = { 145.3619, 0.2564 },
		navHoverBoosts = { 145.7683, 0.04 },
		navOpenStarGrid = { 145.9583, 0.2509 },
		navHoverStarGrid = { 146.3591, 0.04 },
		navOpenEchoes = { 146.5491, 0.251 },
		navHoverEchoes = { 146.9501, 0.04 },
		navOpenContinuum = { 147.1401, 0.251 },
		navHoverContinuum = { 147.5411, 0.04 },
		navOpenLab = { 147.7311, 0.2508 },
		navHoverLab = { 148.1319, 0.04 },
		navOpenAnomaly = { 148.3219, 0.2505 },
		navHoverAnomaly = { 148.7224, 0.04 },
		navOpenWheel = { 148.9124, 0.2508 },
		navHoverWheel = { 149.3132, 0.04 },
		navOpenCommand = { 149.5032, 0.2688 },
		navHoverCommand = { 149.922, 0.04 },
		navOpenStory = { 150.112, 0.2516 },
		navHoverStory = { 150.5135, 0.04 },
		navOpenMail = { 150.7035, 0.2506 },
		navHoverMail = { 151.1041, 0.04 },
		navOpenChat = { 151.2941, 0.2569 },
		navHoverChat = { 151.701, 0.04 },
		navOpenCrew = { 151.891, 0.2509 },
		navHoverCrew = { 152.2919, 0.04 },
		navOpenMilestones = { 152.4819, 0.24 },
		navHoverMilestones = { 152.8719, 0.04 },
		navOpenConvergence = { 153.0619, 0.251 },
		navHoverConvergence = { 153.4629, 0.04 },
		navOpenGuild = { 153.6529, 0.2508 },
		navHoverGuild = { 154.0536, 0.04 },
		navOpenLeaderboards = { 154.2436, 0.2508 },
		navHoverLeaderboards = { 154.6444, 0.04 },
		navOpenTrade = { 154.8344, 0.2509 },
		navHoverTrade = { 155.2353, 0.04 },
		navOpenCredits = { 155.4253, 0.2688 },
		navHoverCredits = { 155.844, 0.04 },
		navOpenAdmin = { 156.034, 0.2683 },
		navHoverAdmin = { 156.4523, 0.04 },
		navOpenForgePath = { 156.6423, 0.2506 },
		navHoverForgePath = { 157.0429, 0.04 },
		navOpenFoundry = { 157.2329, 0.2569 },
		navHoverFoundry = { 157.6398, 0.04 },
		clickHover = { 157.8298, 0.035 },
		confirmHover = { 158.0148, 0.035 },
		settingsHover = { 158.1998, 0.035 },
		purchasePressHover = { 158.3848, 0.035 },
		claimPressHover = { 158.5698, 0.035 },
		codeSubmitHover = { 158.7548, 0.035 },
		zoneSelectHover = { 158.9398, 0.035 },
		labRouteHover = { 159.1247, 0.035 },
		playerlistActionHover = { 159.3097, 0.035 },
		playerlistSelectHover = { 159.4947, 0.035 },
		equipHover = { 159.6797, 0.035 },
		dangerPressHover = { 159.8647, 0.035 },
		closeHover = { 160.0497, 0.035 },
		tickHover = { 160.2347, 0.035 },
		openHover = { 160.4197, 0.035 },
		tabSwitchHover = { 160.6046, 0.035 },
		mailHover = { 160.7896, 0.035 },
		storyHover = { 160.9746, 0.035 },
		toggleOnHover = { 161.1596, 0.035 },
		toggleOffHover = { 161.3446, 0.035 },
		lockedHover = { 161.5296, 0.035 },
		errorHover = { 161.7146, 0.035 },
		prestigeHover = { 161.8996, 0.035 },
		domainChargeHover = { 162.0846, 0.035 },
		vaultBankHover = { 162.2695, 0.035 },
		guildCreateHover = { 162.4545, 0.035 },
		guildJoinHover = { 162.6395, 0.035 },
		inviteHover = { 162.8245, 0.035 },
		travelHover = { 163.0095, 0.035 },
		queueStopHover = { 163.1945, 0.035 },
		queueStartHover = { 163.3795, 0.035 },
		boostHover = { 163.5645, 0.035 },
		reactorPulseHover = { 163.7495, 0.035 },
		crateOpenHover = { 163.9344, 0.035 },
		wheelStartHover = { 164.1194, 0.035 },
		rewardHover = { 164.3044, 0.035 },
		rebirthChargeHover = { 164.4894, 0.035 },
		missionClaimHover = { 164.6744, 0.035 },
		leaderboardSwitchHover = { 164.8594, 0.035 },
		adminArmHover = { 165.0444, 0.035 },
		memberRemoveHover = { 165.2294, 0.035 },
		roleChangeHover = { 165.4144, 0.035 },
		previewHover = { 165.5993, 0.035 },
		resetHover = { 165.7843, 0.035 },
		chatSendHover = { 165.9693, 0.035 },
		boostOpenHover = { 166.1543, 0.035 },
		vaultDepositHover = { 166.3393, 0.035 },
		forgePress = { 166.5243, 0.092 },
		corePress = { 166.7663, 0.092 },
		wavePress = { 167.0083, 0.092 },
		labPress = { 167.2503, 0.092 },
		commandPress = { 167.4923, 0.092 },
		adminPress = { 167.7343, 0.092 },
		creditsPress = { 167.9763, 0.092 },
		chatPress = { 168.2183, 0.092 },
		continuumPress = { 168.4602, 0.092 },
		missionPress = { 168.7022, 0.092 },
		overviewPress = { 168.9442, 0.092 },
		dropdownOpen = { 169.1862, 0.09 },
		dropdownClose = { 169.4262, 0.08 },
		copyDone = { 169.6562, 0.145 },
		dragGrab = { 169.9512, 0.064 },
		dragDrop = { 170.1652, 0.106 },
		dragSnap = { 170.4212, 0.03 },
		favoriteOn = { 170.6012, 0.3155 },
		favoriteOff = { 171.0667, 0.08 },
		ratingStar = { 171.2967, 0.11 },
		searchType = { 171.5567, 0.022 },
		countTick = { 171.7287, 0.02 },
		stepNext = { 171.8987, 0.13 },
		stepBack = { 172.1787, 0.13 },
		reportSubmit = { 172.4587, 0.32 },
		feedbackSubmit = { 172.9287, 0.429 },
		guildAnnounce = { 173.5077, 0.652 },
		badgeEarn = { 174.3096, 0.4201 },
		artifactEquip = { 174.8798, 0.329 },
		artifactUpgrade = { 175.3588, 0.6532 },
		crateSeal = { 176.162, 0.3432 },
		crateOrbit = { 176.6552, 0.6 },
		crateRarityStep = { 177.4052, 0.14 },
		crateRevealEpic = { 177.6952, 0.6083 },
		crateRevealMythic = { 178.4535, 0.8988 },
		rebirthIgnite = { 179.5023, 1.1149 },
		rebirthShockwave = { 180.7672, 0.777 },
		rebirthTierUp = { 181.6943, 0.3702 },
		rebirthAscend = { 182.2144, 1.139 },
	} :: { [string]: Region },
	Loudness = {
		hover = -14.25,
		hoverTick = -13.92,
		tick = -12.99,
		scroll = -12.39,
		sliderStep = -12.7,
		amountChange = -13.38,
		filterPick = -15.76,
		navHover = -14.32,
		click = -16.82,
		settings = -16.82,
		purchasePress = -17.82,
		claimPress = -17.59,
		codeSubmit = -16.61,
		zoneSelect = -16.32,
		labRoute = -17.83,
		playerlistAction = -16.68,
		playerlistSelect = -14.49,
		confirm = -14.92,
		successChime = -14.94,
		equip = -15.64,
		itemLink = -17.56,
		tutorialStep = -17.42,
		roleChange = -16.61,
		reactorStabilize = -16.66,
		toggleOn = -15.8,
		toggleOff = -15.67,
		queueStart = -16.98,
		queueStop = -15.79,
		open = -14.74,
		modalOpen = -15.27,
		filterOpen = -13.98,
		boostOpen = -14.89,
		offlineOpen = -14.41,
		playerlistOpen = -14.82,
		story = -15.55,
		storyOpen = -15,
		crate = -14.28,
		close = -15.06,
		modalDismiss = -15.21,
		purchaseExit = -15.28,
		playerlistClose = -15.07,
		itemUnlink = -16.53,
		reset = -18.13,
		memberRemove = -17.02,
		guildLeave = -16.62,
		page = -15.01,
		tabSwitch = -16.05,
		preview = -17.46,
		storyBeat = -17.28,
		storyPage = -17.06,
		mailRead = -16.36,
		leaderboardSwitch = -16.3,
		modalPop = -14.88,
		sliderCommit = -14.8,
		inputClear = -14.23,
		chatSend = -14.02,
		inputFocus = -14.23,
		error = -15.87,
		errorBuzz = -15.21,
		noticeError = -15.93,
		dangerPress = -14.23,
		locked = -16.81,
		requestBlocked = -14.29,
		noticeWarning = -15.38,
		systemAlert = -12.7,
		requestTimeout = -12.79,
		adminArm = -15.89,
		mail = -14.82,
		notification = -16.52,
		noticeInfo = -15.84,
		noticeSuccess = -15.39,
		noticeSpecial = -15.25,
		boostReady = -17.76,
		reactorReady = -17.43,
		crewNudge = -13.72,
		invite = -13.75,
		chatReceive = -15.05,
		travel = -17.08,
		purchase = -17.94,
		purchaseResult = -18.08,
		vaultDeposit = -18.25,
		vaultBank = -18.23,
		guildDeposit = -17.69,
		collect = -16.79,
		boost = -15.08,
		boostActivate = -16.73,
		offlineCollect = -15.44,
		reward = -18.96,
		codeReward = -19.91,
		tutorialFinish = -18.29,
		domainReward = -19.01,
		wheelLand = -20.33,
		unlock = -19.44,
		researchUnlock = -19.25,
		achievementClaim = -18.63,
		seasonClaim = -19.92,
		comboMilestone = -19.06,
		discovery = -18.66,
		zoneUnlock = -19.33,
		guildCreate = -19.87,
		echoCapture = -19.31,
		storyReveal = -20,
		missionClaim = -18.91,
		dailyClaim = -17.61,
		timedClaim = -18.33,
		mailClaim = -18.66,
		crateClaim = -18.75,
		echoClaim = -19.05,
		guildJoin = -19.52,
		expeditionReturn = -18.05,
		prestige = -19.41,
		rebirthBloom = -19.63,
		crateRare = -19.74,
		salvage = -13.83,
		salvageCrunch = -13.39,
		echoDismantle = -13.49,
		autoForge = -13.78,
		machineInstall = -20.55,
		wheelBrake = -17.16,
		crateBrake = -20.33,
		wheel = -17.59,
		wheelStart = -21.06,
		crateOpen = -17.21,
		expeditionLaunch = -17.65,
		bootStart = -16.81,
		reactor = -15.87,
		reactorSurge = -12.66,
		adminExecute = -12.63,
		crateLand = -12.53,
		domainImpact = -12.89,
		bootFinaleBang = -13,
		rebirthCharge = -19.2,
		wheelCharge = -18.79,
		crateCharge = -18.93,
		domainCharge = -19.62,
		reactorPulse = -16.14,
		domainCrack = -18.55,
		domainBind = -16.54,
		boot = -17.51,
		wheelTick = -19.02,
		wheelSlow = -18.73,
		crateTick = -13.58,
		crateNear = -13.41,
		bootReady = -19.88,
		echoEquip = -17.38,
		echoTune = -15.83,
		navOpenOverview = -15.02,
		navHoverOverview = -14.31,
		navOpenWorkshop = -14.74,
		navHoverWorkshop = -14.19,
		navOpenInventory = -14.71,
		navHoverInventory = -14.35,
		navOpenResearch = -15.02,
		navHoverResearch = -14.31,
		navOpenShop = -14.52,
		navHoverShop = -14.19,
		navOpenSettings = -14.96,
		navHoverSettings = -14.35,
		navOpenWorlds = -15.25,
		navHoverWorlds = -14.31,
		navOpenMissions = -15.09,
		navHoverMissions = -14.19,
		navOpenRewards = -14.58,
		navHoverRewards = -14.35,
		navOpenBoosts = -14.84,
		navHoverBoosts = -14.31,
		navOpenStarGrid = -15.13,
		navHoverStarGrid = -14.19,
		navOpenEchoes = -14.57,
		navHoverEchoes = -14.35,
		navOpenContinuum = -15.08,
		navHoverContinuum = -14.31,
		navOpenLab = -15.06,
		navHoverLab = -14.19,
		navOpenAnomaly = -15.07,
		navHoverAnomaly = -14.35,
		navOpenWheel = -14.71,
		navHoverWheel = -14.31,
		navOpenCommand = -14.84,
		navHoverCommand = -14.19,
		navOpenStory = -15.13,
		navHoverStory = -14.35,
		navOpenMail = -14.67,
		navHoverMail = -14.31,
		navOpenChat = -14.98,
		navHoverChat = -14.19,
		navOpenCrew = -15.17,
		navHoverCrew = -14.35,
		navOpenMilestones = -14.93,
		navHoverMilestones = -14.31,
		navOpenConvergence = -14.67,
		navHoverConvergence = -14.19,
		navOpenGuild = -14.61,
		navHoverGuild = -14.35,
		navOpenLeaderboards = -15,
		navHoverLeaderboards = -14.31,
		navOpenTrade = -14.71,
		navHoverTrade = -14.19,
		navOpenCredits = -14.89,
		navHoverCredits = -14.35,
		navOpenAdmin = -15.31,
		navHoverAdmin = -14.31,
		navOpenForgePath = -15.18,
		navHoverForgePath = -14.19,
		navOpenFoundry = -14.74,
		navHoverFoundry = -14.35,
		clickHover = -13.76,
		confirmHover = -13.55,
		settingsHover = -13.75,
		purchasePressHover = -13.82,
		claimPressHover = -13.5,
		codeSubmitHover = -13.76,
		zoneSelectHover = -13.55,
		labRouteHover = -13.75,
		playerlistActionHover = -13.82,
		playerlistSelectHover = -13.5,
		equipHover = -13.75,
		dangerPressHover = -13.82,
		closeHover = -13.5,
		tickHover = -13.76,
		openHover = -13.55,
		tabSwitchHover = -13.75,
		mailHover = -13.82,
		storyHover = -13.5,
		toggleOnHover = -13.76,
		toggleOffHover = -13.55,
		lockedHover = -13.75,
		errorHover = -13.82,
		prestigeHover = -13.5,
		domainChargeHover = -13.76,
		vaultBankHover = -13.5,
		guildCreateHover = -13.76,
		guildJoinHover = -13.55,
		inviteHover = -13.75,
		travelHover = -13.82,
		queueStopHover = -13.55,
		queueStartHover = -13.75,
		boostHover = -13.82,
		reactorPulseHover = -13.5,
		crateOpenHover = -13.76,
		wheelStartHover = -13.55,
		rewardHover = -13.75,
		rebirthChargeHover = -13.82,
		missionClaimHover = -13.5,
		leaderboardSwitchHover = -13.76,
		adminArmHover = -13.55,
		memberRemoveHover = -13.75,
		roleChangeHover = -13.82,
		previewHover = -13.5,
		resetHover = -13.76,
		chatSendHover = -13.55,
		boostOpenHover = -13.75,
		vaultDepositHover = -13.82,
		forgePress = -15.83,
		corePress = -16.92,
		wavePress = -16.52,
		labPress = -16.19,
		commandPress = -16.68,
		adminPress = -16.61,
		creditsPress = -16.82,
		chatPress = -16.65,
		continuumPress = -15.83,
		missionPress = -16.92,
		overviewPress = -16.52,
		dropdownOpen = -13.89,
		dropdownClose = -15.45,
		copyDone = -16.13,
		dragGrab = -14.78,
		dragDrop = -15.98,
		dragSnap = -13.38,
		favoriteOn = -14.94,
		favoriteOff = -14.24,
		ratingStar = -16.61,
		searchType = -12.06,
		countTick = -12.27,
		stepNext = -14.29,
		stepBack = -14.44,
		reportSubmit = -18.58,
		feedbackSubmit = -17.01,
		guildAnnounce = -16.61,
		badgeEarn = -15.66,
		artifactEquip = -16.19,
		artifactUpgrade = -15.96,
		crateSeal = -17.52,
		crateOrbit = -12.28,
		crateRarityStep = -14.13,
		crateRevealEpic = -16.02,
		crateRevealMythic = -15.71,
		rebirthIgnite = -20.55,
		rebirthShockwave = -18.18,
		rebirthTierUp = -15.02,
		rebirthAscend = -15.62,
	} :: { [string]: number },
}

Manifest.Ambience = {
	Id = 134085646747854,
	Length = 81.8,
	Regions = {
		amb_heart = { 0.3, 16 },
		amb_ember = { 16.6, 16 },
		amb_hollows = { 32.9, 16 },
		amb_spire = { 49.2, 16 },
		amb_riftmaw = { 65.5, 16 },
	} :: { [string]: Region },
	Loudness = {
		amb_heart = -19.01,
		amb_ember = -20.04,
		amb_hollows = -24.2,
		amb_spire = -23.8,
		amb_riftmaw = -21.06,
	} :: { [string]: number },
}

Manifest.Kit = {
	Id = 95516912278016,
	PlaceholderId = 0,
	KitReady = true,
	Sizes = {
		Crystal = Vector3.new(0.9201, 3.05, 1.0186),
		CrystalShard = Vector3.new(0.7224, 2.45, 0.8424),
		RockA = Vector3.new(2.258, 1.201, 2.4613),
		RockB = Vector3.new(2.5634, 1.3845, 1.8375),
		RockC = Vector3.new(2.0783, 1.547, 2.4256),
		BasaltCluster = Vector3.new(3.0476, 4.0478, 3.0936),
		VoidSpire = Vector3.new(2.5449, 6.6929, 1.5524),
		Obelisk = Vector3.new(1.24, 7.5, 1.24),
		Plinth = Vector3.new(6.0976, 1.35, 6.0976),
		Lantern = Vector3.new(1.1031, 7.1, 1.1031),
		ArenaPillar = Vector3.new(3.8803, 25, 3.8803),
		Star = Vector3.new(2, 2, 2),
		WardenCore = Vector3.new(2, 2, 2),
		WardenPlate = Vector3.new(3.1361, 4.0898, 1.0098),
		WardenBlade = Vector3.new(1.4441, 4.966, 0.8328),
		Halo = Vector3.new(2.14, 0.1212, 2.14),
		BridgeDeck = Vector3.new(1, 1, 1),
	} :: { [string]: Vector3 },
}

return Manifest
end

__defs["OreConfig"] = function()

type Rgb = { number }

type OreType = {
	Id: string,
	Name: string,
	Region: string,
	Color: Rgb,
	Glow: Rgb,
	YieldMin: number,
	YieldMax: number,
}

type OreUpgrade = {
	Id: string,
	Name: string,
	Description: string,
	Effect: string,
	PerLevel: number,
	MaxLevel: number,
	Cost: { [string]: number },
	Scale: number,
}

local OreConfig = {}

OreConfig.Ore = {
	RegrowSeconds = 90,
	HoldSeconds = 1.1,
	PromptDistance = 12,
	ServerReach = 18,
	Types = {
		{
			Id = "Emberite",
			Name = "Emberite",
			Region = "Emberreach",
			Color = { 255, 128, 64 },
			Glow = { 255, 196, 120 },
			YieldMin = 3,
			YieldMax = 5,
		},
		{
			Id = "Voidglass",
			Name = "Voidglass",
			Region = "Hollows",
			Color = { 150, 104, 255 },
			Glow = { 206, 172, 255 },
			YieldMin = 2,
			YieldMax = 4,
		},
		{
			Id = "Starsteel",
			Name = "Starsteel",
			Region = "Spire",
			Color = { 140, 220, 255 },
			Glow = { 226, 248, 255 },
			YieldMin = 1,
			YieldMax = 2,
		},
	} :: { OreType },
	Upgrades = {
		{
			Id = "TemperedCores",
			Name = "Tempered Cores",
			Description = "Machines produce 3% more per level.",
			Effect = "Production",
			PerLevel = 0.03,
			MaxLevel = 30,
			Cost = { Emberite = 6 },
			Scale = 1.24,
		},
		{
			Id = "DeepVault",
			Name = "Deep Vault",
			Description = "The vault holds 4% more per level.",
			Effect = "Capacity",
			PerLevel = 0.04,
			MaxLevel = 25,
			Cost = { Voidglass = 5 },
			Scale = 1.26,
		},
		{
			Id = "ResonantStrike",
			Name = "Resonant Strike",
			Description = "Overcharge taps hit 5% harder per level.",
			Effect = "Tap",
			PerLevel = 0.05,
			MaxLevel = 25,
			Cost = { Emberite = 3, Voidglass = 3 },
			Scale = 1.27,
		},
		{
			Id = "StarsteelEdge",
			Name = "Starsteel Edge",
			Description = "Strikes on the Rift Warden land 8% harder per level.",
			Effect = "BossDamage",
			PerLevel = 0.08,
			MaxLevel = 15,
			Cost = { Starsteel = 3 },
			Scale = 1.32,
		},
		{
			Id = "ProspectorsEye",
			Name = "Prospector's Eye",
			Description = "Every outcrop gives 6% more ore per level.",
			Effect = "OreYield",
			PerLevel = 0.06,
			MaxLevel = 10,
			Cost = { Starsteel = 2, Emberite = 8 },
			Scale = 1.4,
		},
	} :: { OreUpgrade },
}

return table.freeze(OreConfig)
end

__defs["ForgeLevels"] = function()

type Goal = {
	Kind: string,
	Target: number,
	Text: string,
}

type LevelDef = {
	Level: number,
	Tier: string,
	Goal: Goal?,
	Unlocks: { string },
}

type NextStep = {
	Level: number,
	Tier: string,
	Text: string,
	Kind: string,
	Progress: number,
	Target: number,
	Unlocks: { string },
}

type Snapshot = {
	Level: number,
	Tier: string,
	Max: number,
	Next: NextStep?,
}

local ForgeLevels = {}

ForgeLevels.LIFETIME_KINDS = table.freeze({
	LifetimeCash = true,
	MachinesBought = true,
	Rebirths = true,
	Domain = true,
})

local TIERS = { "Beginner", "Apprentice", "Journeyman", "Expert", "Master", "Legend" }

local TIER_BLURBS: { [string]: string } = {
	Beginner = "Learn the basics: collect flux, buy machines, research.",
	Apprentice = "Grow your forge and open new ways to earn.",
	Journeyman = "Build up to your first rebirth.",
	Expert = "Rebirth again to grow stronger every run.",
	Master = "Expand your domain and bend reality.",
	Legend = "The very top of the forge.",
}

local LADDER: { LevelDef } = {
	{ Level = 1, Tier = "Beginner", Goal = nil, Unlocks = { "Overview", "Workshop", "Chat", "Settings", "Trade" } },
	{
		Level = 2,
		Tier = "Beginner",
		Goal = { Kind = "LifetimeCash", Target = 100, Text = "Earn 100 flux in total" },
		Unlocks = { "Research" },
	},
	{
		Level = 3,
		Tier = "Beginner",
		Goal = { Kind = "LifetimeCash", Target = 250, Text = "Earn 250 flux in total" },
		Unlocks = { "Mail", "Wheel", "Inventory" },
	},
	{
		Level = 4,
		Tier = "Beginner",
		Goal = { Kind = "LifetimeCash", Target = 500, Text = "Earn 500 flux in total" },
		Unlocks = { "Rewards", "Boosts" },
	},
	{
		Level = 5,
		Tier = "Apprentice",
		Goal = { Kind = "MachinesBought", Target = 5, Text = "Buy 5 machine levels" },
		Unlocks = { "Story", "ForgePath" },
	},
	{
		Level = 6,
		Tier = "Apprentice",
		Goal = { Kind = "LifetimeCash", Target = 1_000, Text = "Earn 1K flux in total" },
		Unlocks = { "Missions", "Leaderboards", "Guild" },
	},
	{
		Level = 7,
		Tier = "Apprentice",
		Goal = { Kind = "LifetimeCash", Target = 2_500, Text = "Earn 2.5K flux in total" },
		Unlocks = { "Worlds", "Shop" },
	},
	{
		Level = 8,
		Tier = "Apprentice",
		Goal = { Kind = "LifetimeCash", Target = 5_000, Text = "Earn 5K flux in total" },
		Unlocks = { "StarGrid", "Credits" },
	},
	{
		Level = 9,
		Tier = "Journeyman",
		Goal = { Kind = "MachinesBought", Target = 15, Text = "Buy 15 machine levels" },
		Unlocks = { "Milestones" },
	},
	{
		Level = 10,
		Tier = "Journeyman",
		Goal = { Kind = "LifetimeCash", Target = 75_000, Text = "Earn 75K flux in total" },
		Unlocks = { "Rebirth", "Bazaar" },
	},
	{
		Level = 11,
		Tier = "Journeyman",
		Goal = { Kind = "Rebirths", Target = 1, Text = "Complete your first rebirth" },
		Unlocks = { "Anomaly", "Command", "Crew" },
	},
	{
		Level = 12,
		Tier = "Expert",
		Goal = { Kind = "Rebirths", Target = 2, Text = "Complete 2 rebirths" },
		Unlocks = { "Lab" },
	},
	{
		Level = 13,
		Tier = "Expert",
		Goal = { Kind = "Rebirths", Target = 3, Text = "Complete 3 rebirths" },
		Unlocks = { "Echoes", "Convergence" },
	},
	{
		Level = 14,
		Tier = "Expert",
		Goal = { Kind = "Rebirths", Target = 5, Text = "Complete 5 rebirths" },
		Unlocks = { "Continuum" },
	},
	{
		Level = 15,
		Tier = "Master",
		Goal = { Kind = "Rebirths", Target = 10, Text = "Complete 10 rebirths" },
		Unlocks = { "Domain" },
	},
	{
		Level = 16,
		Tier = "Master",
		Goal = { Kind = "Domain", Target = 1, Text = "Expand your domain" },
		Unlocks = {},
	},
	{
		Level = 17,
		Tier = "Master",
		Goal = { Kind = "Domain", Target = 3, Text = "Reach domain rank 3" },
		Unlocks = {},
	},
	{
		Level = 18,
		Tier = "Legend",
		Goal = { Kind = "Domain", Target = 10, Text = "Reach domain rank 10" },
		Unlocks = { "Ascension" },
	},
}

for _, def in LADDER do
	table.freeze(def.Unlocks)
	if def.Goal ~= nil then
		table.freeze(def.Goal)
	end
	table.freeze(def)
end
table.freeze(LADDER)
table.freeze(TIERS)
table.freeze(TIER_BLURBS)

function ForgeLevels.ladder(): { LevelDef }
	return LADDER
end

function ForgeLevels.count(): number
	return #LADDER
end

function ForgeLevels.get(level: number): LevelDef?
	return LADDER[level]
end

function ForgeLevels.tiers(): { string }
	return TIERS
end

function ForgeLevels.tierBlurb(tier: string): string
	return TIER_BLURBS[tier] or ""
end

function ForgeLevels.tierBlurbs(): { [string]: string }
	return TIER_BLURBS
end

function ForgeLevels.requirementText(level: number): string
	local def = LADDER[level]
	if def == nil then
		return `Reach Level {level}`
	end
	return `Reach Level {level} ({def.Tier})`
end

-- The milestone that opens a feature (nil for features open from the start). Unlocks are no
-- longer shown as levels: each feature names the one goal that opens it.
function ForgeLevels.goalFor(featureId: string): Goal?
	for _, def in LADDER do
		for _, id in def.Unlocks do
			if id == featureId then
				return def.Goal
			end
		end
	end
	return nil
end

function ForgeLevels.unlockLevels(): { [string]: number }
	local result = {}
	for _, def in LADDER do
		for _, featureId in def.Unlocks do
			result[featureId] = def.Level
		end
	end
	return result
end

function ForgeLevels.levelFor(progressOf: (string) -> number): number
	local cache: { [string]: number } = {}
	local level = 1
	for _, def in LADDER do
		local goal = def.Goal
		if goal == nil then
			continue
		end
		local progress = cache[goal.Kind]
		if progress == nil then
			local read = progressOf(goal.Kind)
			progress = if type(read) == "number" and read == read then math.max(0, read) else 0
			cache[goal.Kind] = progress
		end
		if (progress :: number) >= goal.Target then
			level = def.Level
		end
	end
	return level
end

function ForgeLevels.snapshot(progressOf: (string) -> number): Snapshot
	local level = ForgeLevels.levelFor(progressOf)
	local current = LADDER[level]
	local nextDef = LADDER[level + 1]
	local nextStep: NextStep? = nil
	if nextDef ~= nil and nextDef.Goal ~= nil then
		local goal = nextDef.Goal
		local read = progressOf(goal.Kind)
		local progress = if type(read) == "number" and read == read then math.max(0, read) else 0
		nextStep = {
			Level = nextDef.Level,
			Tier = nextDef.Tier,
			Text = goal.Text,
			Kind = goal.Kind,
			Progress = math.clamp(progress, 0, goal.Target),
			Target = goal.Target,
			Unlocks = table.clone(nextDef.Unlocks),
		}
	end
	return {
		Level = level,
		Tier = current.Tier,
		Max = #LADDER,
		Next = nextStep,
	}
end

return table.freeze(ForgeLevels)
end

__defs["CreditsConfig"] = function()

local CreditsConfig = {
	Title = "ASTRAL FORGE",
	Eyebrow = "CREDITS",
	Tagline = "The people who built, run and test the forge.",
	ShowVersion = true,
	Accent = "violet",

	CategoryTabs = true,
	DefaultCategory = "All",
	ShowCategoryCounts = true,
	SearchBar = true,
	SearchMinMembers = 6,

	CardStyle = "Card",
	ShowAvatars = true,
	AvatarShape = "Rounded",
	AvatarSize = 64,
	ShowUsernames = true,
	ShowRoles = true,
	ShowNotes = true,
	FetchNames = true,
	MaxColumns = 3,
	CardMinWidth = 220,
	CardHoverLift = true,

	HideEmptyCategories = true, -- no tabs or sections for roles nobody holds yet
	DefaultEmptyText = "To be announced.",

	EntranceStagger = true,
	StaggerStep = 0.035,

	Categories = {
		{
			Id = "Owner",
			Label = "Owner",
			Description = "Runs the forge.",
			Accent = "mango",
			Icon = "Admin",
			Members = {
				{ Name = "usingINales", UserId = 10916707683, Role = "Founder", Note = "Design, code, worlds and story." },
			},
		},
		{
			Id = "Developers",
			Label = "Developers",
			Description = "Build the game.",
			Accent = "cyan",
			Icon = "Forge",
			Members = {
				{ Name = "usingINales", UserId = 10916707683, Role = "Lead developer", Note = "Client, server and economy." },
			},
		},
		{
			Id = "Moderators",
			Label = "Moderators",
			Description = "Keep servers friendly.",
			Accent = "mint",
			Icon = "Check",
			Members = {},
		},
		{
			Id = "Testers",
			Label = "Testers",
			Description = "Break things before you do.",
			Accent = "pink",
			Icon = "Guide",
			Members = {},
		},
		{
			Id = "Thanks",
			Label = "Special Thanks",
			Description = "",
			Accent = "violet",
			Icon = "Gift",
			Members = {
				{ Name = "You", Role = "Player", Note = "Thanks for playing." },
			},
		},
	},

	Acknowledgements = {
		"Interface icons by Flaticon / Freepik Company",
	},
	Footer = "Thanks for playing.",
}

return CreditsConfig
end

__defs["CreditsModel"] = function()

local CreditsModel = {}

local CARD_STYLES = { Card = true, Compact = true }
local AVATAR_SHAPES = { Rounded = true, Circle = true }

local function text(value: any, fallback: string): string
	if type(value) == "string" then
		return value
	end
	return fallback
end

local function flag(value: any, fallback: boolean): boolean
	if type(value) == "boolean" then
		return value
	end
	return fallback
end

local function number(value: any, fallback: number, low: number, high: number): number
	if type(value) ~= "number" or value ~= value then
		return fallback
	end
	return math.clamp(value, low, high)
end

function CreditsModel.normalize(raw: any)
	local config = if type(raw) == "table" then raw else {}
	local model = {
		Title = text(config.Title, "ASTRAL FORGE"),
		Eyebrow = text(config.Eyebrow, "CREDITS"),
		Tagline = text(config.Tagline, ""),
		ShowVersion = flag(config.ShowVersion, true),
		Accent = text(config.Accent, "violet"),
		CategoryTabs = flag(config.CategoryTabs, true),
		DefaultCategory = text(config.DefaultCategory, "All"),
		ShowCategoryCounts = flag(config.ShowCategoryCounts, true),
		SearchBar = flag(config.SearchBar, true),
		SearchMinMembers = math.floor(number(config.SearchMinMembers, 6, 0, 1000)),
		CardStyle = if CARD_STYLES[config.CardStyle] then config.CardStyle else "Card",
		ShowAvatars = flag(config.ShowAvatars, true),
		AvatarShape = if AVATAR_SHAPES[config.AvatarShape] then config.AvatarShape else "Rounded",
		AvatarSize = math.floor(number(config.AvatarSize, 64, 40, 96)),
		ShowUsernames = flag(config.ShowUsernames, true),
		ShowRoles = flag(config.ShowRoles, true),
		ShowNotes = flag(config.ShowNotes, true),
		FetchNames = flag(config.FetchNames, true),
		MaxColumns = math.floor(number(config.MaxColumns, 3, 1, 4)),
		CardMinWidth = math.floor(number(config.CardMinWidth, 220, 140, 480)),
		CardHoverLift = flag(config.CardHoverLift, true),
		HideEmptyCategories = flag(config.HideEmptyCategories, true),
		DefaultEmptyText = text(config.DefaultEmptyText, "To be announced."),
		EntranceStagger = flag(config.EntranceStagger, true),
		StaggerStep = number(config.StaggerStep, 0.035, 0, 0.1),
		Acknowledgements = {},
		Footer = text(config.Footer, ""),
		Categories = {},
	}
	if type(config.Acknowledgements) == "table" then
		for _, line in config.Acknowledgements do
			if type(line) == "string" and line ~= "" then
				table.insert(model.Acknowledgements, line)
			end
		end
	end
	local seen = {}
	if type(config.Categories) == "table" then
		for _, category in config.Categories do
			if type(category) ~= "table" or type(category.Id) ~= "string" or category.Id == "" or category.Id == "All" or seen[category.Id] then
				continue
			end
			seen[category.Id] = true
			local members = {}
			if type(category.Members) == "table" then
				for _, member in category.Members do
					if type(member) ~= "table" or type(member.Name) ~= "string" or member.Name == "" then
						continue
					end
					local userId = if type(member.UserId) == "number" and member.UserId > 0 then math.floor(member.UserId) else nil
					table.insert(members, {
						Name = member.Name,
						DisplayName = text(member.DisplayName, member.Name),
						UserId = userId,
						Role = text(member.Role, ""),
						Note = text(member.Note, ""),
					})
				end
			end
			table.insert(model.Categories, {
				Id = category.Id,
				Label = text(category.Label, category.Id),
				Description = text(category.Description, ""),
				Accent = text(category.Accent, model.Accent),
				Icon = text(category.Icon, "Credits"),
				EmptyText = text(category.EmptyText, model.DefaultEmptyText),
				Members = members,
			})
		end
	end
	if model.DefaultCategory ~= "All" and not seen[model.DefaultCategory] then
		model.DefaultCategory = "All"
	end
	return model
end

function CreditsModel.memberCount(model): number
	local total = 0
	for _, category in model.Categories do
		total += #category.Members
	end
	return total
end

local function matches(member, needle: string): boolean
	if needle == "" then
		return true
	end
	for _, field in { member.Name, member.DisplayName, member.Role, member.Note } do
		if string.find(string.lower(field), needle, 1, true) then
			return true
		end
	end
	return false
end

function CreditsModel.visible(model, tab: string, query: string?)
	local needle = string.lower((string.gsub(query or "", "^%s*(.-)%s*$", "%1")))
	local out = {}
	for _, category in model.Categories do
		if tab ~= "All" and category.Id ~= tab then
			continue
		end
		local members = {}
		for _, member in category.Members do
			if matches(member, needle) then
				table.insert(members, member)
			end
		end
		if #members == 0 and (needle ~= "" or model.HideEmptyCategories) then
			continue
		end
		table.insert(out, { category = category, members = members })
	end
	return out
end

function CreditsModel.tabs(model)
	local tabs = { { id = "All", label = "All", count = CreditsModel.memberCount(model) } }
	for _, category in model.Categories do
		if #category.Members == 0 and model.HideEmptyCategories then
			continue
		end
		table.insert(tabs, { id = category.Id, label = category.Label, count = #category.Members, accent = category.Accent })
	end
	return tabs
end

function CreditsModel.columns(model, width: number, gap: number): number
	if model.CardStyle == "Compact" then
		return 1
	end
	local fit = math.floor((width + gap) / (model.CardMinWidth + gap))
	return math.clamp(fit, 1, model.MaxColumns)
end

function CreditsModel.cardHeight(model): number
	if model.CardStyle == "Compact" then
		return math.max(44, if model.ShowAvatars then math.min(model.AvatarSize, 48) + 12 else 44)
	end
	local textBlock = 22 + (if model.ShowUsernames then 16 else 0) + (if model.ShowRoles then 18 else 0) + (if model.ShowNotes then 34 else 0)
	local avatar = if model.ShowAvatars then model.AvatarSize else 0
	return math.max(avatar, textBlock) + 24
end

function CreditsModel.showSearch(model): boolean
	return model.SearchBar and CreditsModel.memberCount(model) >= model.SearchMinMembers
end

return table.freeze(CreditsModel)
end

__defs["PlayerlistModel"] = function()

local PlayerlistModel = {}

PlayerlistModel.REASONS = table.freeze({
	{ id = "Exploiting", label = "Exploiting", detail = "Cheats, scripts or abusing glitches." },
	{ id = "Scamming", label = "Scamming", detail = "Tricked someone in a trade or promised something fake." },
	{ id = "Harassment", label = "Harassment", detail = "Targeting, bullying or threatening someone." },
	{ id = "Trolling", label = "Trolling", detail = "Ruining the game for others on purpose." },
	{ id = "Spam", label = "Spam", detail = "Flooding chat or invites." },
	{ id = "Inappropriate", label = "Inappropriate", detail = "Offensive name, avatar or messages." },
	{ id = "Impersonating", label = "Impersonating", detail = "Pretending to be staff, a creator or another player." },
	{ id = "Botting", label = "Botting", detail = "Looks automated: macros, AFK farms or alt swarms." },
	{ id = "Other", label = "Other", detail = "Something else. Add details below." },
})

PlayerlistModel.SEVERITIES = table.freeze({
	{ id = "Minor", label = "Minor" },
	{ id = "Serious", label = "Serious" },
	{ id = "Urgent", label = "Urgent" },
})

PlayerlistModel.WHENS = table.freeze({
	{ id = "Now", label = "Just now" },
	{ id = "Earlier", label = "Earlier" },
	{ id = "Repeated", label = "Keeps happening" },
})

PlayerlistModel.WHERES = table.freeze({
	{ id = "World", label = "In world" },
	{ id = "Chat", label = "Chat" },
	{ id = "Trade", label = "Trade" },
	{ id = "Guild", label = "Guild" },
})

PlayerlistModel.SORTS = table.freeze({
	{ id = "Production", label = "Output" },
	{ id = "Rebirths", label = "Rebirths" },
	{ id = "Name", label = "Name" },
})

PlayerlistModel.DETAILS_MAX = 400
PlayerlistModel.SEARCH_MIN_ROWS = 6

-- Output comparisons go through OmegaMath when it is loadable (in game); plain numbers otherwise.
local omega: any = nil
local function omegaMath()
	if omega == nil then
		local ok, loaded = pcall(function() return require(script.Parent:WaitForChild("OmegaMath", 5)) end)
		omega = if ok and type(loaded) == "table" then loaded else false
	end
	return omega or nil
end
local function productionGreater(a: any, b: any): boolean
	local math_ = omegaMath()
	if math_ and math_.Gt then
		local ok, result = pcall(math_.Gt, a, b)
		if ok then return result == true end
	end
	return (tonumber(a) or 0) > (tonumber(b) or 0)
end
local function productionEqual(a: any, b: any): boolean
	return not productionGreater(a, b) and not productionGreater(b, a)
end
local function num(value: any): number
	if type(value) == "number" and value == value then
		return value
	end
	return 0
end

function PlayerlistModel.artifact(raw: any)
	if type(raw) ~= "table" or type(raw.Id) ~= "string" or raw.Id == "" then
		return nil
	end
	return {
		Id = raw.Id,
		Name = if type(raw.Name) == "string" and raw.Name ~= "" then raw.Name else raw.Id,
		Element = if type(raw.Element) == "string" then raw.Element else "",
		Rarity = if type(raw.Rarity) == "string" then raw.Rarity else "COMMON",
		Level = math.max(1, math.floor(num(raw.Level))),
		Color = if typeof(raw.Color) == "Color3" then raw.Color else nil,
		Effect = if type(raw.Effect) == "string" then raw.Effect else nil,
	}
end

-- live attributes win over the polled record: they replicate the moment someone equips
function PlayerlistModel.artifactOf(player: any, fallback: any)
	if player == nil then
		return fallback
	end
	local id = player:GetAttribute("EquippedArtifact")
	if type(id) ~= "string" or id == "" then
		return nil
	end
	return PlayerlistModel.artifact({
		Id = id,
		Name = player:GetAttribute("EquippedArtifactName"),
		Element = player:GetAttribute("EquippedArtifactElement"),
		Rarity = player:GetAttribute("EquippedArtifactRarity"),
		Level = player:GetAttribute("EquippedArtifactLevel"),
		Color = player:GetAttribute("EquippedArtifactColor"),
		Effect = player:GetAttribute("EquippedArtifactEffect"),
	})
end

function PlayerlistModel.clean(raw: any, skipUserId: number?)
	local rows = {}
	local seen = {}
	if type(raw) ~= "table" then
		return rows
	end
	for _, entry in raw do
		if type(entry) ~= "table" then
			continue
		end
		local userId = tonumber(entry.UserId)
		if userId == nil or userId ~= userId or userId <= 0 then
			continue
		end
		userId = math.floor(userId)
		if seen[userId] or userId == skipUserId then
			continue
		end
		seen[userId] = true
		local name = if type(entry.Name) == "string" and entry.Name ~= "" then entry.Name else tostring(userId)
		table.insert(rows, {
			UserId = userId,
			Name = name,
			DisplayName = if type(entry.DisplayName) == "string" and entry.DisplayName ~= "" then entry.DisplayName else name,
			IsLocal = entry.IsLocal == true,
			CurrentZone = math.max(1, num(entry.CurrentZone)),
			Zone = math.max(1, num(entry.Zone)),
			Rebirths = num(entry.Rebirths),
			-- big-number output (Googol and up) arrives as an encoded value; keep it for formatting and sorting
			Production = if type(entry.Production) == "number" and entry.Production == entry.Production then entry.Production elseif type(entry.Production) == "string" and (string.match(entry.Production, "^%-?%d+%.?%d*e%-?%d+$") or entry.Production == "inf") then entry.Production else 0,
			LifetimeCash = num(entry.LifetimeCash),
			ItemCount = num(entry.ItemCount),
			DomainRank = num(entry.DomainRank),
			PlayTime = num(entry.PlayTime),
			AccountAge = num(entry.AccountAge),
			Premium = entry.Premium == true,
			EquippedItems = if type(entry.EquippedItems) == "table" then entry.EquippedItems else {},
			Artifact = PlayerlistModel.artifact(entry.Artifact),
			CurrentPage = if type(entry.CurrentPage) == "string" then entry.CurrentPage else "",
		})
	end
	return rows
end

function PlayerlistModel.view(rows, sortId: string, query: string?, friendsOnly: boolean?, friends: { [number]: boolean }?)
	local needle = string.lower((string.gsub(query or "", "^%s*(.-)%s*$", "%1")))
	local out = {}
	for _, row in rows do
		if not row.IsLocal then
			if friendsOnly and not (friends and friends[row.UserId]) then
				continue
			end
			if needle ~= "" and not string.find(string.lower(row.DisplayName), needle, 1, true) and not string.find(string.lower(row.Name), needle, 1, true) then
				continue
			end
		end
		table.insert(out, row)
	end
	table.sort(out, function(left, right)
		if left.IsLocal ~= right.IsLocal then
			return left.IsLocal
		end
		if sortId == "Name" then
			local a, b = string.lower(left.DisplayName), string.lower(right.DisplayName)
			if a ~= b then
				return a < b
			end
		elseif sortId == "Rebirths" then
			if left.Rebirths ~= right.Rebirths then
				return left.Rebirths > right.Rebirths
			end
		elseif not productionEqual(left.Production, right.Production) then
			return productionGreater(left.Production, right.Production)
		end
		return left.UserId < right.UserId
	end)
	return out
end

function PlayerlistModel.playTime(seconds: number): string
	local total = math.max(0, math.floor(num(seconds)))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	end
	if minutes > 0 then
		return string.format("%dm", minutes)
	end
	return "<1m"
end

function PlayerlistModel.accountAge(days: number): string
	local value = math.max(0, math.floor(num(days)))
	if value >= 365 then
		return string.format("%dy", value // 365)
	end
	if value >= 30 then
		return string.format("%dmo", value // 30)
	end
	return string.format("%dd", value)
end

function PlayerlistModel.details(text: string?): string
	local trimmed = (string.gsub(text or "", "^%s*(.-)%s*$", "%1"))
	if #trimmed > PlayerlistModel.DETAILS_MAX then
		trimmed = string.sub(trimmed, 1, PlayerlistModel.DETAILS_MAX)
	end
	local _, brokenAt = utf8.len(trimmed)
	if brokenAt then
		trimmed = string.sub(trimmed, 1, brokenAt - 1)
	end
	return trimmed
end

return table.freeze(PlayerlistModel)
end

__defs["TutorialScript"] = function()

local TutorialScript = {}

TutorialScript.PET_NAME = "Bolt"
TutorialScript.EXPERIENCE_NAME = "GETTING STARTED"

TutorialScript.STEPS = table.freeze({
	{
		id = "hello",
		title = "Welcome to Astral Forge",
		say = "Hi, I'm Bolt! I'll show you around the forge. Click me any time for a hint.",
		body = "This guide points at exactly what to click. You can go back, skip or replay it from Settings.",
		goal = "Say hi to Bolt",
		startPage = "Overview",
		page = "Overview",
		watch = "continue",
	},
	{
		id = "vault",
		title = "This is your vault",
		say = "Machines pour Flux into this vault, even while you're away.",
		body = "Stored Flux isn't money yet. Collect it to turn it into cash you can spend.",
		goal = "Find the vault",
		target = "OverviewVaultClaimActions",
		startPage = "Overview",
		page = "Overview",
		watch = "continue",
	},
	{
		id = "collect",
		title = "Collect your Flux",
		say = "Collect the vault to turn its Flux into cash.",
		body = "A full vault stops filling, so collect often.",
		goal = "Collect the vault",
		target = "OverviewVaultClaimActions",
		page = "Overview",
		watch = "collect",
		auto = true,
		cta = "collect",
		ctaLabel = "Collect stored Flux",
		controls = "Keyboard: E  ·  Xbox: Y",
	},
	{
		id = "toWorkshop",
		title = "Machines live in the Workshop",
		say = "Now open the Workshop. That's where you buy machines.",
		body = "Every page is in the menu. Workshop is the one you'll use most.",
		goal = "Open the Workshop",
		target = "Nav_Workshop",
		page = "Workshop",
		watch = "page:Workshop",
		auto = true,
		cta = "workshop",
		ctaLabel = "Open Workshop",
	},
	{
		id = "buy",
		title = "Buy your first machine",
		say = "Buy a machine here. Every machine adds Flux each second.",
		body = "Each level adds Flux per second. Grey means you need more cash: collect the vault first.",
		goal = "Buy a machine",
		target = "WorkshopBuyClaim",
		startPage = "Workshop",
		page = "Workshop",
		watch = "buy",
		auto = true,
	},
	{
		id = "amount",
		title = "Buy many levels at once",
		say = "Pick x5 or Max to buy several levels at once.",
		body = "x1 buys one level, x5 buys five, Max buys everything you can afford.",
		goal = "Pick x5 or Max",
		target = "AmountToggleTarget",
		page = "Workshop",
		watch = "amount",
		auto = true,
		controls = "Xbox: LT / RT",
	},
	{
		id = "level",
		title = "Your forge level",
		say = "This bar is your level. Each new level opens another part of the forge.",
		body = "Open the bar any time to see every level and what it unlocks.",
		goal = "Look at the level bar",
		target = { "LevelBarTarget", "MobileHeader" },
		page = "Workshop",
		watch = "continue",
	},
	{
		id = "toResearch",
		title = "Research lasts forever",
		say = "Open Research. Its bonuses stay even after you rebirth.",
		body = "Research opens properly at level 2, but you can take a look now.",
		goal = "Open Research",
		target = "Nav_Research",
		page = "Research",
		watch = "page:Research",
		auto = true,
		cta = "research",
		ctaLabel = "Open Research",
	},
	{
		id = "research",
		title = "Buy the lit bonuses",
		say = "When a bonus lights up, you can afford it. Buy them in order.",
		body = "Research is the best long-term use of your cash.",
		goal = "Read the research page",
		target = "ResearchBuyClaimActions",
		page = "Research",
		watch = "continue",
	},
	{
		id = "menu",
		title = "Everything is in the menu",
		say = "Every page is in the menu, grouped into sections. On a phone, it's the Menu tab.",
		body = "Home, Daily, Progress, Games & Deals, Social and System. New pages appear as you level up.",
		goal = "Look over the menu",
		target = { "RailNavClaim", "Nav_Menu" },
		page = "Research",
		watch = "continue",
	},
	{
		id = "rebirth",
		title = "Rebirth makes every run faster",
		say = "Later, Rebirth trades your machines for Cores. Your research stays.",
		body = "The Overview shows how many Cores a rebirth pays before you confirm.",
		goal = "Learn about rebirth",
		target = { "Nav_Overview", "Nav_Menu" },
		startPage = "Overview",
		page = "Overview",
		watch = "continue",
	},
	{
		id = "finish",
		title = "You're ready",
		say = "That's the tour. You can replay it from Settings, under Guide.",
		body = "Collect, buy machines, research, rebirth. Finishing pays a small Flux bonus.",
		goal = "Finish the guide",
		target = { "Nav_Settings", "Nav_Menu" },
		page = "Overview",
		watch = "finish",
	},
})

TutorialScript.QUIPS = table.freeze({
	idle = { "Stuck? Follow my finger.", "The highlighted box is the next step.", "Careful, I'm ticklish.", "I run on Flux. Mostly." },
	done = { "Nice. On to the next bit.", "You're a natural.", "That's it. Keep going." },
	dizzy = { "Whoa. The forge is spinning.", "Okay, okay, no more spins.", "Hang on. Which way is up?" },
	pet = { "Heh. That's nice.", "My circuits are humming.", "You're my favourite forger." },
	wake = { "Huh? I'm awake. Totally awake.", "Oh. Where were we?" },
	missing = { "That control is still loading. I'll keep looking.", "I lost the target for a second. You can keep moving.", "Nothing to click yet. I'll point it out when it appears." },
})

local function num(value: any, fallback: number): number
	if type(value) == "number" and value == value then
		return value
	end
	return fallback
end

function TutorialScript.goalMet(step, live, collected: boolean?): boolean
	if step == nil then
		return false
	end
	local watch = step.watch
	live = if type(live) == "table" then live else {}
	if watch == "continue" or watch == "finish" then
		return true
	elseif watch == "collect" then
		return collected == true or (type(live.vaultFlux) == "number" and live.vaultFlux <= 0.01)
	elseif watch == "buy" then
		return num(live.ownedMachines, 0) > 0
	elseif watch == "amount" then
		return num(live.buyAmount, 1) ~= 1
	elseif type(watch) == "string" and string.sub(watch, 1, 5) == "page:" then
		return live.page == string.sub(watch, 6)
	end
	return false
end

function TutorialScript.needsAction(step): boolean
	return step ~= nil and step.watch ~= "continue" and step.watch ~= "finish"
end

function TutorialScript.petPose(rect, screenW: number, screenH: number, petSize: number, dock)
	local margin = 14
	local half = petSize / 2
	local function clampPoint(x, y)
		return math.clamp(x, half + 6, math.max(half + 6, screenW - half - 6)), math.clamp(y, half + 6, math.max(half + 6, screenH - half - 6))
	end
	local dockH = if dock ~= nil then num(dock.h, 0) else 0
	local function onDock(x, y): boolean
		if dock == nil or dockH <= 0 then
			return false
		end
		local pad = 8
		return x + half > dock.x - pad and x - half < dock.x + dock.w + pad and y + half > dock.y - pad and y - half < dock.y + dockH + pad
	end
	if rect == nil then
		local dockTop = if dock ~= nil then dock.y else screenH * 0.7
		local dockX = if dock ~= nil then dock.x + dock.w - half - 10 else screenW / 2
		local below = dock ~= nil and dockH > 0 and dockTop + dockH / 2 < screenH / 2
		local x, y = clampPoint(dockX, if below then dockTop + dockH + half + 10 else dockTop - half - 10)
		return x, y, if below then -90 else 90, "dock"
	end
	local cx, cy = rect.x + rect.w / 2, rect.y + rect.h / 2
	local room = petSize + margin * 2
	local candidates: { { any } } = {
		{ "right", screenW - (rect.x + rect.w) >= room, rect.x + rect.w + margin + half, cy },
		{ "left", rect.x >= room, rect.x - margin - half, cy },
		{ "below", screenH - (rect.y + rect.h) >= room, cx, rect.y + rect.h + margin + half },
		{ "above", rect.y >= room, cx, rect.y - margin - half },
	}
	local side, x, y
	for _, candidate in candidates do
		if candidate[2] then
			local px, py = clampPoint(candidate[3], candidate[4])
			if not onDock(px, py) then
				side, x, y = candidate[1], px, py
				break
			end
		end
	end
	if side == nil then
		for _, candidate in candidates do
			if candidate[2] then
				side, x, y = candidate[1], candidate[3], candidate[4]
				break
			end
		end
	end
	if side == nil then
		side, x, y = "above", cx, rect.y - margin - half
	end
	x, y = clampPoint(x, y)
	local px = math.clamp(x, rect.x, rect.x + rect.w)
	local py = math.clamp(y, rect.y, rect.y + rect.h)
	local angle = math.deg(math.atan2(py - y, px - x))
	if px == x and py == y then
		angle = 90
	end
	return x, y, angle, side
end

function TutorialScript.dockPlacement(rect, screenH: number, cardH: number, topInset: number, bottomInset: number)
	local gap = 12
	local bottomY = screenH - math.max(gap, bottomInset) - cardH
	local topY = math.max(gap, topInset + 8)
	if rect == nil then
		return bottomY, "bottom"
	end
	local function overlap(y: number): number
		return math.max(0, math.min(y + cardH + gap, rect.y + rect.h) - math.max(y - gap, rect.y))
	end
	local atBottom = overlap(bottomY)
	if atBottom > 0 and overlap(topY) < atBottom then
		return topY, "top"
	end
	return bottomY, "bottom"
end

function TutorialScript.progress(index: number, count: number, met: boolean): number
	local total = math.max(1, count)
	return math.clamp((index - (if met then 0 else 0.5)) / total, 0, 1)
end

return TutorialScript
end

__defs["LevelRewards"] = function()

local LevelRewards = {}

local TIER_INDEX = { Beginner = 1, Apprentice = 2, Journeyman = 3, Expert = 4, Master = 5, Legend = 6 }

LevelRewards.MASTERY_PER_LEVEL = 0.02
LevelRewards.SURGE_CAP_SECONDS = 1800
LevelRewards.SURGE_MAX_MULTIPLIER = 1.6
LevelRewards.HALFWAY_SHARE = 0.5

type Reward = {
	FluxSeconds: number,
	MinFlux: number,
	Stardust: number,
	SurgeMultiplier: number,
	SurgeSeconds: number,
}

function LevelRewards.forLevel(level: number, tier: string?): Reward
	local tierIndex = TIER_INDEX[tier or ""] or 1
	level = math.max(1, math.floor(level))
	return {
		FluxSeconds = 90 + level * 30,
		MinFlux = 60 * level,
		Stardust = level * 4 + tierIndex * 8,
		SurgeMultiplier = math.min(LevelRewards.SURGE_MAX_MULTIPLIER, 1.2 + tierIndex * 0.05),
		SurgeSeconds = math.min(900, 240 + level * 30),
	}
end

function LevelRewards.halfway(nextLevel: number): { FluxSeconds: number, MinFlux: number }
	nextLevel = math.max(2, math.floor(nextLevel))
	return { FluxSeconds = 30 + nextLevel * 10, MinFlux = 25 * nextLevel }
end

function LevelRewards.mastery(level: number): number
	return math.max(0, math.floor(level) - 1) * LevelRewards.MASTERY_PER_LEVEL
end

function LevelRewards.mergeSurge(current, now: number, multiplier: number, seconds: number)
	local active = type(current) == "table" and type(current.EndsAt) == "number" and current.EndsAt > now
	local baseEnd = if active then current.EndsAt else now
	local baseMultiplier = if active and type(current.Multiplier) == "number" then current.Multiplier else 1
	return {
		Multiplier = math.min(LevelRewards.SURGE_MAX_MULTIPLIER, math.max(baseMultiplier, multiplier)),
		EndsAt = math.min(now + LevelRewards.SURGE_CAP_SECONDS, baseEnd + math.max(0, seconds)),
	}
end

function LevelRewards.surgeMultiplier(surge, now: number): number
	if type(surge) ~= "table" or type(surge.EndsAt) ~= "number" or surge.EndsAt <= now then
		return 1
	end
	local multiplier = tonumber(surge.Multiplier) or 1
	return math.clamp(multiplier, 1, LevelRewards.SURGE_MAX_MULTIPLIER)
end

function LevelRewards.owed(rewarded: number, level: number): ({ number }, number)
	if type(rewarded) ~= "number" or rewarded < 0 then
		return {}, level
	end
	local owed = {}
	for value = math.floor(rewarded) + 1, math.floor(level) do
		table.insert(owed, value)
	end
	return owed, math.max(math.floor(rewarded), math.floor(level))
end

function LevelRewards.halfwayDue(paidFor: number, nextLevel: number?, progress: number, target: number): boolean
	if nextLevel == nil or target <= 0 or type(paidFor) ~= "number" or paidFor < 0 then
		return false
	end
	return paidFor < nextLevel and progress / target >= LevelRewards.HALFWAY_SHARE
end

function LevelRewards.eta(kind: string, remaining: number, ratePerSecond: number): number?
	if kind ~= "LifetimeCash" or ratePerSecond <= 0 or remaining <= 0 then
		return nil
	end
	return remaining / ratePerSecond
end

function LevelRewards.etaText(seconds: number?): string
	if seconds == nil or seconds ~= seconds then
		return ""
	end
	local total = math.max(0, math.floor(seconds))
	if total < 60 then
		return `{math.max(1, total)}s`
	elseif total < 3600 then
		return `{total // 60}m`
	elseif total < 86400 then
		local minutes = (total % 3600) // 60
		return if minutes > 0 then `{total // 3600}h {minutes}m` else `{total // 3600}h`
	end
	return `{total // 86400}d`
end

return table.freeze(LevelRewards)
end

__defs["ServerEvents"] = function()

local ServerEvents = {}

ServerEvents.REST_SECONDS = 8 * 60
ServerEvents.WARNING_SECONDS = 60
ServerEvents.LIVE_SECONDS = 5 * 60
ServerEvents.RESULTS_SECONDS = 20
ServerEvents.FIRST_REST_SECONDS = 3 * 60

ServerEvents.EVENTS = table.freeze({
	MeteorShower = table.freeze({
		Id = "MeteorShower",
		Name = "Meteor Shower",
		Blurb = "Meteors are hitting the forge. Everyone's output is boosted!",
		How = "Just keep earning: every machine produces more while it lasts.",
		Icon = "Boost",
		Accent = "mango",
		Multiplier = 1.5,
	}),
	CommunityForge = table.freeze({
		Id = "CommunityForge",
		Name = "Community Forge",
		Blurb = "The whole server works on one giant order. Collect your vault to help!",
		How = "Every vault collect adds points. Fill the bar together to pay everyone who helped.",
		Icon = "Crew",
		Accent = "cyan",
		PointsPerPlayer = 900,
		MinGoal = 900,
		MaxPointsPerCollect = 600,
		RewardFluxSeconds = 300,
		RewardStardust = 30,
		TopBonusStardust = { 40, 25, 15 },
	}),
	StardustRain = table.freeze({
		Id = "StardustRain",
		Name = "Stardust Rain",
		Blurb = "Stardust is falling. Every vault collect drops some!",
		How = "Collect your vault as often as you can while it rains.",
		Icon = "Dust",
		Accent = "violet",
		MaxDustPerCollect = 25,
	}),
})
ServerEvents.ORDER = table.freeze({ "MeteorShower", "CommunityForge", "StardustRain" })

function ServerEvents.pick(lastId: string?, roll: number): string
	local choices = {}
	for _, id in ServerEvents.ORDER do
		if id ~= lastId then
			table.insert(choices, id)
		end
	end
	local index = math.clamp(math.floor(roll * #choices) + 1, 1, #choices)
	return choices[index]
end

function ServerEvents.advance(state, now: number, roll: number)
	if state == nil or state.Phase == nil then
		return { Phase = "Rest", Id = nil, PhaseEndsAt = now + ServerEvents.FIRST_REST_SECONDS, LastId = nil }, true
	end
	if now < state.PhaseEndsAt then
		return state, false
	end
	if state.Phase == "Rest" then
		local id = ServerEvents.pick(state.LastId, roll)
		return { Phase = "Warning", Id = id, PhaseEndsAt = now + ServerEvents.WARNING_SECONDS, LastId = state.LastId }, true
	elseif state.Phase == "Warning" then
		return { Phase = "Live", Id = state.Id, PhaseEndsAt = now + ServerEvents.LIVE_SECONDS, LastId = state.LastId }, true
	elseif state.Phase == "Live" then
		return { Phase = "Results", Id = state.Id, PhaseEndsAt = now + ServerEvents.RESULTS_SECONDS, LastId = state.Id }, true
	end
	return { Phase = "Rest", Id = nil, PhaseEndsAt = now + ServerEvents.REST_SECONDS, LastId = state.LastId }, true
end

function ServerEvents.productionMultiplier(state): number
	if state ~= nil and state.Phase == "Live" and state.Id == "MeteorShower" then
		return ServerEvents.EVENTS.MeteorShower.Multiplier
	end
	return 1
end

function ServerEvents.communityGoal(players: number): number
	local def = ServerEvents.EVENTS.CommunityForge
	return math.max(def.MinGoal, math.max(1, math.floor(players)) * def.PointsPerPlayer)
end

function ServerEvents.collectPoints(collected: number, perSecond: number): number
	if collected <= 0 then
		return 0
	end
	local seconds = if perSecond > 0 then collected / perSecond else 1
	return math.clamp(math.floor(seconds), 1, ServerEvents.EVENTS.CommunityForge.MaxPointsPerCollect)
end

function ServerEvents.rainDust(collected: number, perSecond: number): number
	if collected <= 0 then
		return 0
	end
	local seconds = if perSecond > 0 then collected / perSecond else 1
	return math.clamp(math.floor(math.sqrt(seconds)), 1, ServerEvents.EVENTS.StardustRain.MaxDustPerCollect)
end

function ServerEvents.ranking(points: { [number]: number })
	local list = {}
	for userId, value in points do
		if value > 0 then
			table.insert(list, { UserId = userId, Points = value })
		end
	end
	table.sort(list, function(a, b)
		if a.Points ~= b.Points then
			return a.Points > b.Points
		end
		return a.UserId < b.UserId
	end)
	return list
end

function ServerEvents.communityStardust(rank: number): number
	local def = ServerEvents.EVENTS.CommunityForge
	return def.RewardStardust + (def.TopBonusStardust[rank] or 0)
end

function ServerEvents.secondsLeft(state, now: number): number
	if state == nil or state.PhaseEndsAt == nil then
		return 0
	end
	return math.max(0, state.PhaseEndsAt - now)
end

return table.freeze(ServerEvents)
end

__defs["LiveOpsConfig"] = function()

local WEEK = 7 * 24 * 60 * 60
local EPOCH = 1_767_225_600

local Config = {
	ManifestVersion = 1,
	Season = { Id = "DEEP_SPACE_01", Name = "DEEP SPACE COMMAND" },
	Convergence = {
		Name = "FORGE CONVERGENCE",
		CycleSeconds = WEEK,
		Epoch = EPOCH,
		GlobalPhases = {
			{ Target = 500, Name = "IGNITION", ProductionMultiplier = 1.02 },
			{ Target = 2_500, Name = "TEMPERED", ProductionMultiplier = 1.05 },
			{ Target = 10_000, Name = "RESONANT", ProductionMultiplier = 1.10 },
			{ Target = 40_000, Name = "CELESTIAL", ProductionMultiplier = 1.18 },
		},
		PersonalTiers = {
			{ Required = 20, Reward = { Cash = 5_000, Stardust = 15 } },
			{ Required = 75, Reward = { Cash = 25_000, Stardust = 35, Cores = 1 } },
			{ Required = 200, Reward = { Cash = 100_000, Stardust = 75, Signals = 20 } },
			{ Required = 500, Reward = { Cash = 500_000, Stardust = 150, Cores = 3, Boost = "Hyperdrive" } },
		},
		ContributionByAction = {
			CollectVault = 1, BuyMachine = 2, BuyResearch = 3, BuyGridUpgrade = 4,
			PulseAnomaly = 1, StabilizeAnomaly = 8, ClaimLabOrder = 7,
			Rebirth = 25, DomainExpansion = 100,
		},
	},
}

function Config.CurrentConvergence(now: number?)
	local timestamp = math.max(EPOCH, math.floor(now or os.time()))
	local cycle = math.floor((timestamp - EPOCH) / WEEK)
	local startsAt = EPOCH + cycle * WEEK
	return {
		EventId = "CONVERGENCE_" .. tostring(cycle),
		Name = Config.Convergence.Name,
		StartsAt = startsAt,
		EndsAt = startsAt + WEEK,
	}
end

return table.freeze(Config)
end

__defs["MonetizationConfig"] = function()

type RewardTable = {
	Cash: number?,
	CashMinutes: number?,
	Stardust: number?,
	Cores: number?,
	Boost: string?,
	Signals: number?,
	CommandXP: number?,
	StreakShield: number?,
	Keys: { [string]: number }?,
}

type DevProductDef = {
	Key: string,
	ProductId: number,
	Name: string,
	Description: string,
	Category: string,
	Icon: string,
	Accent: { number },
	PriceLabel: string,
	StudioPrice: number,
	Reward: RewardTable,
}

type GamePassDef = {
	Key: string,
	PassId: number,
	Name: string,
	Description: string,
	Category: string,
	Icon: string,
	Accent: { number },
	PriceLabel: string,
	StudioPrice: number,
	ProductionBonus: number?,
	CapacityBonus: number?,
}

local MonetizationConfig = {
	DevProducts = {
		{
			Key = "StardustParcel",
			ProductId = 3716811152,
			Name = "Stardust Pack",
			Description = "80 stardust for grid upgrades.",
			Category = "Packs",
			Icon = "Dust",
			Accent = { 93, 247, 180 },
			PriceLabel = "R$",
			StudioPrice = 49,
			Reward = { Stardust = 80 },
		},
		{
			Key = "FluxCrate",
			ProductId = 3716811274,
			Name = "Flux Drop",
			Description = "120k flux you can spend right now.",
			Category = "Packs",
			Icon = "Flux",
			Accent = { 72, 190, 255 },
			PriceLabel = "R$",
			StudioPrice = 99,
			Reward = { Cash = 120_000 },
		},
		{
			Key = "RelayBooster",
			ProductId = 3716811317,
			Name = "Overdrive Charge",
			Description = "One Overdrive boost for the Rewards tab.",
			Category = "Boosts",
			Icon = "Forge",
			Accent = { 255, 83, 111 },
			PriceLabel = "R$",
			StudioPrice = 75,
			Reward = { Boost = "Overdrive" },
		},
		{
			Key = "CoreCluster",
			ProductId = 3716811360,
			Name = "Core Bundle",
			Description = "3 permanent cores. No rebirth needed.",
			Category = "Packs",
			Icon = "Core",
			Accent = { 161, 126, 255 },
			PriceLabel = "R$",
			StudioPrice = 199,
			Reward = { Cores = 3 },
		},
	} :: { DevProductDef },

	GamePasses = {
		{
			Key = "VIP",
			PassId = 2005587679,
			Name = "VIP",
			Description = "+12% production forever.",
			Category = "Passes",
			Icon = "StarGrid",
			Accent = { 255, 191, 78 },
			PriceLabel = "R$",
			StudioPrice = 399,
			ProductionBonus = 0.12,
		},
		{
			Key = "DoubleProduction",
			PassId = 2006769725,
			Name = "Overclock",
			Description = "+25% line output forever.",
			Category = "Passes",
			Icon = "Research",
			Accent = { 102, 177, 255 },
			PriceLabel = "R$",
			StudioPrice = 499,
			ProductionBonus = 0.25,
		},
		{
			Key = "DoubleCapacity",
			PassId = 2005557744,
			Name = "Bigger Vault",
			Description = "+35% vault size forever.",
			Category = "Passes",
			Icon = "Vault",
			Accent = { 72, 190, 255 },
			PriceLabel = "R$",
			StudioPrice = 349,
			CapacityBonus = 0.35,
		},
		{
			Key = "AutoSalvage",
			PassId = 2006703685,
			Name = "Relic Recycler",
			Description = "Automatically salvage selected crate rarities. First discoveries stay protected by default.",
			Category = "Passes",
			Icon = "Inventory",
			Accent = { 255, 88, 156 },
			PriceLabel = "R$",
			StudioPrice = 299,
		},
	} :: { GamePassDef },
}

function MonetizationConfig.FindDevProductByProductId(productId: number): DevProductDef?
	if productId <= 0 then
		return nil
	end
	for _, entry in MonetizationConfig.DevProducts do
		if entry.ProductId == productId then
			return entry
		end
	end
	return nil
end

function MonetizationConfig.FindDevProductByKey(key: string): DevProductDef?
	for _, entry in MonetizationConfig.DevProducts do
		if entry.Key == key then
			return entry
		end
	end
	return nil
end

function MonetizationConfig.FindPassByPassId(passId: number): GamePassDef?
	if passId <= 0 then
		return nil
	end
	for _, entry in MonetizationConfig.GamePasses do
		if entry.PassId == passId then
			return entry
		end
	end
	return nil
end

function MonetizationConfig.FindPassByKey(key: string): GamePassDef?
	for _, entry in MonetizationConfig.GamePasses do
		if entry.Key == key then
			return entry
		end
	end
	return nil
end

function MonetizationConfig.PassBonuses(owned: { [string]: boolean }): (number, number)
	local production = 0
	local capacity = 0
	for _, entry in MonetizationConfig.GamePasses do
		if owned[entry.Key] == true then
			production += entry.ProductionBonus or 0
			capacity += entry.CapacityBonus or 0
		end
	end
	return production, capacity
end

return table.freeze(MonetizationConfig)
end

__defs["CapacityProjection"] = function()

local CapacityProjection = {}

type SteadyParts = {
	EfficiencyLevel: number,
	ZoneMultiplier: number,
	PermanentMultiplier: any,
	Additives: { number },
	SocialMultiplier: number,
	MasteryMultiplier: number,
	ContinuumProduction: any,
}

function CapacityProjection.SteadyMultiplier(omegaMath, parts: SteadyParts): any
	local multiplier = omegaMath.Mul(1 + parts.EfficiencyLevel * 0.15, parts.ZoneMultiplier)
	multiplier = omegaMath.Mul(multiplier, parts.PermanentMultiplier)
	for _, additive in parts.Additives do
		multiplier = omegaMath.Mul(multiplier, 1 + additive)
	end
	multiplier = omegaMath.Mul(multiplier, math.max(1, parts.SocialMultiplier))
	multiplier = omegaMath.Mul(multiplier, parts.MasteryMultiplier)
	multiplier = omegaMath.Mul(multiplier, parts.ContinuumProduction)
	return multiplier
end

function CapacityProjection.SteadyProduction(omegaMath, rawProduction: any, parts: SteadyParts): any
	return omegaMath.Mul(rawProduction, CapacityProjection.SteadyMultiplier(omegaMath, parts))
end

type CapacitySecondsParts = {
	BaseSeconds: number,
	SecondsPerLevel: number,
	StorageLevel: number,
	Additives: { number },
	DomainRank: number,
	CapacityPerRank: number,
	BoostCapacityMultiplier: number,
	MaxSeconds: number,
	DomainTreeCapacity: number,
}

function CapacityProjection.Seconds(parts: CapacitySecondsParts): number
	local seconds = parts.BaseSeconds * (parts.SecondsPerLevel ^ parts.StorageLevel)
	for _, additive in parts.Additives do
		seconds *= 1 + additive
	end
	seconds *= 1 + parts.DomainRank * parts.CapacityPerRank
	seconds *= parts.BoostCapacityMultiplier
	seconds = math.clamp(seconds, 1, parts.MaxSeconds)
	seconds *= 1 + parts.DomainTreeCapacity
	return seconds
end

function CapacityProjection.Vault(
	omegaMath,
	baseCapacity: number,
	steadyProduction: any,
	seconds: number,
	continuumCapacity: any
): any
	return omegaMath.Floor(omegaMath.Max(
		baseCapacity,
		omegaMath.Mul(omegaMath.Mul(steadyProduction, seconds), continuumCapacity)
	))
end

function CapacityProjection.CapacitySeconds(omegaMath, capacity: any, steadyProduction: any, lte: (any, any) -> boolean): number
	if lte(steadyProduction, 0) then
		return 0
	end
	return omegaMath.ToNumber(omegaMath.Div(capacity, steadyProduction))
end

return table.freeze(CapacityProjection)
end

__defs["ZoneUnlock"] = function()

local ZoneUnlock = {}

type ZoneLike = {
	Id: number,
	Name: string,
	RequiredRebirths: number,
	CoreCost: number,
	Cost: any,
}

type UnlockFlags = {
	Unlocked: boolean,
	RebirthOk: boolean,
	CoresOk: boolean,
	CashOk: boolean,
	CanUnlock: boolean,
	IsNext: boolean,
}

function ZoneUnlock.Flags(
	unlockedZone: number,
	rebirths: number,
	cores: number,
	cash: any,
	zone: ZoneLike,
	gteCash: (any, any) -> boolean
): UnlockFlags
	local haveZone = math.max(0, math.floor(tonumber(unlockedZone) or 0))
	local haveRebirths = math.max(0, math.floor(tonumber(rebirths) or 0))
	local haveCores = math.max(0, tonumber(cores) or 0)
	local unlocked = haveZone >= zone.Id
	local rebirthOk = haveRebirths >= (zone.RequiredRebirths or 0)
	local coresOk = haveCores >= (zone.CoreCost or 0)
	local cashOk = gteCash(cash, zone.Cost)
	local isNext = zone.Id == haveZone + 1
	return {
		Unlocked = unlocked,
		RebirthOk = rebirthOk,
		CoresOk = coresOk,
		CashOk = cashOk,
		IsNext = isNext,
		CanUnlock = not unlocked and isNext and rebirthOk and coresOk and cashOk,
	}
end

function ZoneUnlock.Evaluate(
	unlockedZone: number,
	rebirths: number,
	cores: number,
	cash: any,
	zoneId: number,
	zone: ZoneLike,
	cashLt: (any, any) -> boolean
): (string, string?)
	local haveZone = math.max(0, math.floor(tonumber(unlockedZone) or 0))
	local target = math.floor(tonumber(zoneId) or 0)
	if target <= haveZone then
		return "Travel", nil
	end
	if target ~= haveZone + 1 then
		return "Error", "Worlds must be unlocked in order."
	end
	local haveRebirths = math.max(0, math.floor(tonumber(rebirths) or 0))
	if haveRebirths < (zone.RequiredRebirths or 0) then
		return "Error", string.format("Requires %d rebirths.", zone.RequiredRebirths or 0)
	end
	local haveCores = math.max(0, tonumber(cores) or 0)
	if haveCores < (zone.CoreCost or 0) then
		return "Error", string.format("Requires %d astral cores.", zone.CoreCost or 0)
	end
	if cashLt(cash, zone.Cost) then
		return "Error", "NEED_MORE_FLUX"
	end
	return "Unlock", nil
end

return table.freeze(ZoneUnlock)
end

__defs["SettingsSchema"] = function()

type Choice = { label: string, value: number }
export type Entry = {
	key: string,
	section: string,
	label: string,
	help: string,
	kind: "toggle" | "slider" | "choice",
	default: number,
	choices: { Choice }?,
	advanced: boolean?,
	touchOnly: boolean?,
}

local Schema = {}

Schema.SECTIONS = table.freeze({
	{ id = "sound", label = "Sound", icon = "Wave", accent = "mint", blurb = "Volume for music, effects and alerts." },
	{ id = "display", label = "Graphics", icon = "Boost", accent = "pink", blurb = "Effects, glow and how lively the menus move." },
	{ id = "interface", label = "Interface", icon = "Settings", accent = "cyan", blurb = "What the screen shows and how it is laid out." },
	{ id = "accessibility", label = "Accessibility", icon = "Guide", accent = "mango", blurb = "Text size, contrast and color-safe signals." },
	{ id = "social", label = "Social", icon = "Chat", accent = "violet", blurb = "Who can reach you, and how chat looks." },
	{ id = "mobile", label = "Phone", icon = "Menu", accent = "blue", blurb = "Sizes and layout for touch screens.", touchOnly = true },
})

local SIZE4 = { { label = "S", value = 0.25 }, { label = "M", value = 0.5 }, { label = "L", value = 0.75 }, { label = "XL", value = 1 } }
local THREE = function(a: string, b: string, c: string, va: number, vb: number, vc: number): { Choice }
	return { { label = a, value = va }, { label = b, value = vb }, { label = c, value = vc } }
end
local function toggle(key, section, label, help, default, advanced)
	return { key = key, section = section, label = label, help = help, kind = "toggle", default = default, advanced = advanced }
end
local function slider(key, section, label, help, default, advanced)
	return { key = key, section = section, label = label, help = help, kind = "slider", default = default, advanced = advanced }
end
local function choice(key, section, label, help, default, choices, advanced)
	return { key = key, section = section, label = label, help = help, kind = "choice", default = default, choices = choices, advanced = advanced }
end

Schema.ENTRIES = table.freeze({
	slider("SoundVolume", "sound", "Master volume", "Everything at once.", 0.75),
	slider("MusicVolume", "sound", "Music", "The soundtrack.", 1),
	slider("SfxVolume", "sound", "Sound effects", "Buttons, rewards, machines.", 1),
	toggle("PageMusic", "sound", "Background music", "Play the soundtrack at all.", 1),
	toggle("NotificationSounds", "sound", "Alert sounds", "Mail, unlocks and other pings.", 1),
	toggle("HoverSounds", "sound", "Hover sounds", "A soft tick when you point at a button.", 1),
	slider("UiVolume", "sound", "Menu clicks", "Taps and page turns.", 0.6, true),
	slider("GameplayVolume", "sound", "Gameplay sounds", "Machines, reactor, arcade.", 1, true),
	slider("RewardVolume", "sound", "Reward sounds", "Claims, crates, the wheel.", 1, true),
	slider("AmbientVolume", "sound", "Ambience", "The quiet forge noise under the music.", 0.75, true),
	slider("SoundVariation", "sound", "Pitch variation", "Small changes so repeated clicks don't sound identical.", 0.7, true),
	slider("EffectsIntensity", "display", "Effects", "Sparks, pops and flashes.", 1),
	slider("MotionIntensity", "display", "Animation", "How lively menus feel. Lower is calmer, never choppy.", 1),
	toggle("ConfettiEnabled", "display", "Celebrations", "Confetti and bursts on big wins.", 1),
	toggle("ScreenFlashes", "display", "Screen flashes", "A brief flash on big moments.", 0.8),
	toggle("BackgroundStars", "display", "Background stars", "The starfield behind the pages.", 1),
	toggle("ButtonShimmers", "display", "Button shine", "A light sweep across hovered buttons.", 1),
	slider("GlowIntensity", "display", "Glow", "Light around rewards and live things.", 0.75, true),
	slider("ParticleDensity", "display", "Particles", "How many sparks and bits fly.", 0.75, true),
	slider("ShimmerIntensity", "display", "Shine strength", "How bright the button sweep is.", 0.8, true),
	slider("BackgroundDetail", "display", "Background detail", "Depth and glow behind the menus.", 0.8, true),
	toggle("AmbientGlow", "display", "Ambient light", "Soft colored light behind the interface.", 1, true),
	toggle("PanelHover", "display", "Card lift", "Cards rise a little when you point at them.", 1, true),
	toggle("PanelEntrances", "display", "Card entrances", "New cards ease in instead of appearing.", 1, true),
	toggle("AnimatedTitles", "display", "Moving titles", "Titles keep a slow drift.", 1, true),
	toggle("IconAnimations", "display", "Moving icons", "Large icons turn and orbit.", 1, true),
	toggle("NumberAnimations", "display", "Rolling numbers", "Counters roll when they change.", 1, true),
	toggle("OfflineRewardEffects", "display", "Welcome-back glow", "Effects when you return to offline earnings.", 1, true),
	slider("ViewportSpeed", "display", "3D spin speed", "How fast 3D icons turn.", 0.65, true),
	slider("ReactorMotion", "display", "Reactor motion", "How busy the reactor looks.", 0.8, true),
	toggle("ShowFps", "interface", "FPS", "Frame rate in the top bar.", 1),
	toggle("ShowPing", "interface", "Ping", "Connection delay in the top bar.", 1),
	toggle("ShowResourceLabels", "interface", "Currency labels", "FLUX, CORES and DUST above the numbers.", 1),
	toggle("ShowNextGoal", "interface", "Level bar", "Your Forge Level and next goal under page titles.", 1),
	toggle("CompactTopBar", "interface", "Compact top bar", "A shorter header with more room below.", 0),
	choice("UiDensity", "interface", "Spacing", "Room between things on the page.", 0.55, THREE("Tight", "Normal", "Roomy", 0.2, 0.55, 0.9)),
	choice("ToastDensity", "interface", "Alerts on screen", "How many notifications stack up.", 0.55, THREE("Few", "Some", "Many", 0.2, 0.55, 0.9)),
	choice("NotificationDuration", "interface", "Alert time", "How long notifications stay.", 0.55, THREE("Short", "Normal", "Long", 0.25, 0.55, 0.9)),
	choice("PerformanceBias", "interface", "Priority", "Favor looks or frame rate when the game is busy.", 0.5, THREE("Looks", "Balanced", "Speed", 0, 0.5, 1)),
	choice("ScrollSpeed", "interface", "Scroll speed", "How far one wheel notch moves a list.", 0.65, THREE("Slow", "Normal", "Fast", 0.35, 0.65, 0.95), true),
	slider("ScrollMomentum", "interface", "Scroll glide", "How long a list keeps moving after you let go.", 0.75, true),
	choice("DesktopTextScale", "accessibility", "Text size", "Bigger or smaller text. Buttons stay where they are.", 0.5, SIZE4),
	toggle("HighContrast", "accessibility", "High contrast", "Stronger text and edges.", 0),
	toggle("ColorblindMode", "accessibility", "Color-safe signals", "Blue and gold instead of green and red.", 0),
	toggle("BoldText", "accessibility", "Bolder text", "Heavier descriptions.", 0),
	toggle("ReducedTransparency", "accessibility", "Solid panels", "Less see-through backgrounds.", 0),
	toggle("LargeTouchTargets", "accessibility", "Large buttons", "Bigger tap targets on touch screens.", 1),
	slider("HapticIntensity", "accessibility", "Vibration", "How hard the phone buzzes on taps.", 0.65),
	-- Social: the "who can reach you" choices are enforced by the server, not just hidden in the UI
	toggle("ChatShowGlobal", "social", "Global chat", "Show messages from every server in the All tab.", 1),
	toggle("ChatSounds", "social", "Chat sounds", "A soft sound when a message arrives.", 1),
	choice("ChatTextSize", "social", "Chat text size", "Message text in the chat page.", 0.5, THREE("Small", "Normal", "Large", 0.2, 0.5, 0.85)),
	toggle("WhispersFriendsOnly", "social", "Whispers from friends only", "Only Roblox friends can start a private chat with you.", 0),
	choice("CrewInvitePolicy", "social", "Crew invites", "Who can invite you to a crew.", 0, THREE("Anyone", "Friends", "Nobody", 0, 0.5, 1)),
	choice("TradeInvitePolicy", "social", "Trade invites", "Who can invite you to trade.", 0, THREE("Anyone", "Friends", "Nobody", 0, 0.5, 1)),
	choice("MobileTextScale", "mobile", "Text size", "Text size on phones.", 0.5, SIZE4),
	choice("MobileQuickReverse", "mobile", "Main thumb", "Which side the overcharge button sits on.", 0, { { label = "Right", value = 0 }, { label = "Left", value = 1 } }),
	toggle("MobileQuickVisible", "mobile", "Quick buttons", "Vault and overcharge above the menu.", 1),
	toggle("MobileDockVisible", "mobile", "Bottom menu", "Show the menu bar. The drawer still works.", 1),
	toggle("MobileToastVisible", "mobile", "Alerts", "Floating notifications.", 1),
	toggle("MobileCompactHeaders", "mobile", "Short headers", "Smaller page titles for more room.", 1),
	toggle("MobileAutoHideDock", "mobile", "Hide menu while typing", "Also hides it in the arcade.", 1),
	toggle("MobileLandscapeCompact", "mobile", "Compact sideways", "Fewer headers when the phone is turned.", 1),
	toggle("MobileKeyboardCompact", "mobile", "Compact with keyboard", "Shrink the chrome while typing.", 1),
	slider("MobileQuickScale", "mobile", "Quick button size", "Vault and overcharge buttons.", 0.5, true),
	slider("MobileDockScale", "mobile", "Menu size", "The bottom menu.", 0.5, true),
	slider("MobileToastScale", "mobile", "Alert size", "Notification cards.", 0.5, true),
	slider("MobileQuickOpacity", "mobile", "Quick button opacity", "How solid the floating buttons are.", 0.9, true),
	slider("MobileDockOpacity", "mobile", "Menu opacity", "How solid the bottom menu is.", 0.88, true),
	slider("MobileToastOpacity", "mobile", "Alert opacity", "How solid notifications are.", 0.9, true),
	slider("MobileButtonSpacing", "mobile", "Button spacing", "Room between thumb buttons.", 0.5, true),
})

Schema.HIDDEN_KEYS = table.freeze({
	RippleIntensity = 0.5,
	ButtonRipples = 1,
	MobileHudScale = 0.5,
	MobileHudOpacity = 0.85,
	MobilePreviewAck = 0,
	MobileQuickX = 0.5,
	MobileQuickY = 0.7,
	MobileDockX = 0.5,
	MobileDockY = 0.92,
	MobileToastX = 0.84,
	MobileToastY = 0.27,
})

local byKey: { [string]: Entry } = {}
for _, entry in Schema.ENTRIES do
	assert(byKey[entry.key] == nil, "duplicate setting " .. entry.key)
	byKey[entry.key] = entry :: any
end

function Schema.entry(key: string): Entry?
	return byKey[key]
end

function Schema.accepts(key: any): boolean
	return type(key) == "string" and (byKey[key] ~= nil or Schema.HIDDEN_KEYS[key] ~= nil)
end

function Schema.normalize(key: string, value: number): number
	local v = if value == value then math.clamp(value, 0, 1) else 0
	local entry = byKey[key]
	if entry == nil then
		return v
	end
	if entry.kind == "toggle" then
		return if v >= 0.5 then 1 else 0
	elseif entry.kind == "choice" and entry.choices ~= nil then
		local best, gap = entry.choices[1].value, math.huge
		for _, option in entry.choices do
			local d = math.abs(option.value - v)
			if d < gap then
				best, gap = option.value, d
			end
		end
		return best
	end
	return v
end

function Schema.value(settings: any, key: string): number
	local raw = if type(settings) == "table" then settings[key] else nil
	if type(raw) == "number" and raw == raw then
		return math.clamp(raw, 0, 1)
	end
	local entry = byKey[key]
	if entry ~= nil then
		return entry.default
	end
	return Schema.HIDDEN_KEYS[key] or 1
end

function Schema.inSection(section: string): { Entry }
	local list = {}
	for _, entry in Schema.ENTRIES do
		if entry.section == section then
			table.insert(list, entry)
		end
	end
	return list
end

function Schema.sectionDefaults(section: string): { [string]: number }
	local values = {}
	for _, entry in Schema.ENTRIES do
		if entry.section == section then
			values[entry.key] = entry.default
		end
	end
	return values
end

Schema.PRESETS = table.freeze({
	{
		id = "low",
		label = "Low",
		notice = "Low graphics: fewer effects, calmer motion.",
		values = { EffectsIntensity = 0.25, MotionIntensity = 0.3, ParticleDensity = 0.15, GlowIntensity = 0.25, ShimmerIntensity = 0.2, ButtonShimmers = 0, ConfettiEnabled = 0, ScreenFlashes = 0, BackgroundDetail = 0.3, AnimatedTitles = 0, IconAnimations = 0, PerformanceBias = 1 },
	},
	{
		id = "balanced",
		label = "Balanced",
		notice = "Balanced graphics.",
		values = { EffectsIntensity = 0.7, MotionIntensity = 0.7, ParticleDensity = 0.6, GlowIntensity = 0.6, ShimmerIntensity = 0.7, ButtonShimmers = 1, ConfettiEnabled = 1, ScreenFlashes = 1, BackgroundDetail = 0.7, AnimatedTitles = 1, IconAnimations = 1, PerformanceBias = 0.5 },
	},
	{
		id = "high",
		label = "High",
		notice = "High graphics: every effect at full.",
		values = { EffectsIntensity = 1, MotionIntensity = 1, ParticleDensity = 1, GlowIntensity = 1, ShimmerIntensity = 1, ButtonShimmers = 1, ConfettiEnabled = 1, ScreenFlashes = 1, BackgroundDetail = 1, AnimatedTitles = 1, IconAnimations = 1, PerformanceBias = 0 },
	},
})

function Schema.matchingPreset(settings: any): string?
	for _, preset in Schema.PRESETS do
		local same = true
		for key, value in preset.values do
			if math.abs(Schema.value(settings, key) - value) > 0.03 then
				same = false
				break
			end
		end
		if same then
			return preset.id
		end
	end
	return nil
end

return table.freeze(Schema)
end

__defs["RelicSystem"] = function()

local RelicSystem = {}

RelicSystem.ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Astral" }

local function stars(instance: any): number
	local n = if type(instance) == "table" then tonumber(instance.Stars) else nil
	if type(n) ~= "number" or n ~= n then
		return 0
	end
	return math.max(0, math.floor(n))
end
RelicSystem.stars = stars

function RelicSystem.starMultiplier(items: any, count: any): number
	local maxStars = (type(items) == "table" and items.MaxStars) or 5
	local bonus = (type(items) == "table" and items.StarBonus) or 0.25
	local n = tonumber(count)
	if type(n) ~= "number" or n ~= n then
		return 1
	end
	return 1 + bonus * math.clamp(math.floor(n), 0, maxStars)
end

local function level(instance: any): number
	return if type(instance) == "table" and type(instance.Level) == "number" then instance.Level else 1
end

function RelicSystem.fusionPair(inventory: any, equipped: any, definitionId: string, maxStars: number?): (string?, string?, string?)
	if type(inventory) ~= "table" then
		return nil, nil, "You have no relics."
	end
	local cap = maxStars or 5
	local socketed = {}
	if type(equipped) == "table" then
		for _, uid in equipped do
			socketed[uid] = true
		end
	end
	local copies = {}
	for uid, instance in inventory do
		if type(instance) == "table" and instance.DefinitionId == definitionId then
			table.insert(copies, uid)
		end
	end
	if #copies < 2 then
		return nil, nil, "You need two copies of this relic to fuse them."
	end
	table.sort(copies, function(a, b)
		local ia, ib = inventory[a], inventory[b]
		if (socketed[a] == true) ~= (socketed[b] == true) then
			return socketed[a] == true
		end
		if stars(ia) ~= stars(ib) then
			return stars(ia) > stars(ib)
		end
		if level(ia) ~= level(ib) then
			return level(ia) > level(ib)
		end
		return a < b
	end)
	local target = copies[1]
	if stars(inventory[target]) >= cap then
		return nil, nil, "That relic already has every star."
	end
	for index = #copies, 2, -1 do
		local uid = copies[index]
		local instance = inventory[uid]
		if not socketed[uid] and instance.Locked ~= true then
			return target, uid, nil
		end
	end
	return nil, nil, "Every spare copy is socketed or locked."
end

function RelicSystem.fuse(target: any, fodder: any, maxStars: number?): (number, number)
	local cap = maxStars or 5
	local nextStars = math.min(cap, stars(target) + 1 + stars(fodder))
	return nextStars, math.max(level(target), level(fodder))
end

function RelicSystem.codex(discovered: any, items: any): ({ [string]: { found: number, total: number } }, number)
	local definitions = if type(items) == "table" then items.Definitions else nil
	local bonuses = if type(items) == "table" then items.CodexBonus else nil
	local progress = {}
	for _, rarity in RelicSystem.ORDER do
		progress[rarity] = { found = 0, total = 0 }
	end
	if type(definitions) ~= "table" then
		return progress, 0
	end
	for _, definition in definitions do
		local row = progress[definition.Rarity]
		if row == nil then
			row = { found = 0, total = 0 }
			progress[definition.Rarity] = row
		end
		row.total += 1
		if type(discovered) == "table" and discovered[definition.Id] == true then
			row.found += 1
		end
	end
	local bonus = 0
	for rarity, row in progress do
		if row.total > 0 and row.found == row.total and type(bonuses) == "table" then
			bonus += tonumber(bonuses[rarity]) or 0
		end
	end
	return progress, bonus
end

function RelicSystem.odds(weights: any): { { rarity: string, chance: number } }
	local total = 0
	for _, weight in (if type(weights) == "table" then weights else {}) do
		total += math.max(0, tonumber(weight) or 0)
	end
	local list = {}
	for _, rarity in RelicSystem.ORDER do
		local weight = if type(weights) == "table" then tonumber(weights[rarity]) or 0 else 0
		if weight > 0 and total > 0 then
			table.insert(list, { rarity = rarity, chance = weight / total })
		end
	end
	return list
end

function RelicSystem.chanceText(chance: number): string
	if chance <= 0 then
		return "-"
	end
	if chance < 0.001 then
		local oneIn = math.floor(1 / chance + 0.5)
		local text = tostring(oneIn)
		local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
		return "1 in " .. string.gsub(formatted, "^,", "")
	end
	if chance < 0.01 then
		return string.format("%.2f%%", chance * 100)
	end
	return string.format("%.1f%%", chance * 100)
end

return table.freeze(RelicSystem)
end

__defs["ShopCatalog"] = function()

local ShopCatalog = {}

ShopCatalog.SLOTS = 6
ShopCatalog.DEAL_DISCOUNT = 0.35
ShopCatalog.DAY_SECONDS = 86400

ShopCatalog.SKINS = table.freeze({
	{ Id = "Classic", Name = "Forge Iron", Tier = "Common", Blurb = "Riveted iron, warm from the forge.", Accent = { 255, 184, 52 }, Glow = { 255, 140, 60 }, Vfx = "embers", Default = true },
	{ Id = "Crystal", Name = "Crystal Prism", Tier = "Rare", Blurb = "Cut quartz panels that split the light.", Accent = { 120, 220, 255 }, Glow = { 200, 245, 255 }, Vfx = "shards", Price = { Currency = "Stardust", Amount = 400 } },
	{ Id = "Frost", Name = "Frost Rune", Tier = "Rare", Blurb = "A rune-locked chest that breathes cold.", Accent = { 170, 225, 255 }, Glow = { 230, 250, 255 }, Vfx = "frost", Price = { Currency = "Stardust", Amount = 450 } },
	{ Id = "Molten", Name = "Molten Core", Tier = "Epic", Blurb = "Cracked basalt over a river of fire.", Accent = { 255, 110, 60 }, Glow = { 255, 190, 90 }, Vfx = "magma", Price = { Currency = "Stardust", Amount = 900 } },
	{ Id = "Nebula", Name = "Nebula Glass", Tier = "Epic", Blurb = "Smoked glass with a small galaxy inside.", Accent = { 178, 134, 255 }, Glow = { 250, 140, 220 }, Vfx = "nebula", Price = { Currency = "Cores", Amount = 12 } },
	{ Id = "Void", Name = "Void Reliquary", Tier = "Legendary", Blurb = "Black stone. The lid opens inward.", Accent = { 130, 90, 220 }, Glow = { 190, 120, 255 }, Vfx = "void", Price = { Currency = "Cores", Amount = 30 } },
	{ Id = "Gilded", Name = "Gilded Starlight", Tier = "Legendary", Blurb = "Gold leaf and a lid of falling stars.", Accent = { 255, 214, 120 }, Glow = { 255, 246, 214 }, Vfx = "stars", Price = { Currency = "Cores", Amount = 40 } },
	{ Id = "Celestial", Name = "Celestial Ark", Tier = "Mythic", Blurb = "Only ever seen in the Daily Shop.", Accent = { 120, 240, 255 }, Glow = { 255, 236, 170 }, Vfx = "prism", Price = { Currency = "Cores", Amount = 90 }, DailyOnly = true },
})

local crateExpansion: any = nil
if script ~= nil then
	crateExpansion = require((script.Parent :: any).CrateExpansion)
else
	-- Lune: a full-file require resolves the sibling; a member slice loaded alone cannot require.
	local ok, loaded = pcall(function()
		return (require :: any)("./CrateExpansion")
	end)
	crateExpansion = if ok then loaded else nil
end
if crateExpansion ~= nil then
	ShopCatalog.SKINS = crateExpansion.extendSkins(ShopCatalog.SKINS)
end

local skinById = {}
for _, skin in ShopCatalog.SKINS do
	skinById[skin.Id] = skin
end
function ShopCatalog.skin(id: any): any
	return if type(id) == "string" then skinById[id] else nil
end
ShopCatalog.DEFAULT_SKIN = "Classic"

ShopCatalog.POOL = table.freeze({
	{ Id = "ForgeKeys", Name = "3 Forge Keys", Kind = "Key", CrateId = "ForgeCrate", Amount = 3, Currency = "Stardust", Price = 20, Stock = 2, Weight = 10 },
	{ Id = "CrystalKeys", Name = "2 Crystal Keys", Kind = "Key", CrateId = "CrystalCrate", Amount = 2, Currency = "Stardust", Price = 60, Stock = 2, Weight = 8 },
	{ Id = "NebulaKey", Name = "Nebula Key", Kind = "Key", CrateId = "NebulaCrate", Amount = 1, Currency = "Stardust", Price = 62, Stock = 2, Weight = 7 },
	{ Id = "OrbitKeys", Name = "2 Orbit Keys", Kind = "Key", CrateId = "OrbitCrate", Amount = 2, Currency = "Stardust", Price = 95, Stock = 1, Weight = 6 },
	{ Id = "AetherKey", Name = "Aether Key", Kind = "Key", CrateId = "AetherCrate", Amount = 1, Currency = "Stardust", Price = 52, Stock = 2, Weight = 6 },
	{ Id = "HorizonKey", Name = "Horizon Key", Kind = "Key", CrateId = "HorizonCrate", Amount = 1, Currency = "Stardust", Price = 80, Stock = 1, Weight = 5 },
	{ Id = "SingularityKey", Name = "Singularity Key", Kind = "Key", CrateId = "SingularityCrate", Amount = 1, Currency = "Cores", Price = 3, Stock = 1, Weight = 3 },
	{ Id = "EchoKey", Name = "Echo Key", Kind = "Key", CrateId = "EchoCrate", Amount = 1, Currency = "Cores", Price = 4, Stock = 1, Weight = 3 },
	{ Id = "DriftKey", Name = "Drift Key", Kind = "Key", CrateId = "DriftCrate", Amount = 1, Currency = "Cores", Price = 3, Stock = 1, Weight = 3 },
	{ Id = "EssenceJar", Name = "Essence Jar", Kind = "Essence", Amount = 150, Currency = "Stardust", Price = 40, Stock = 3, Weight = 8 },
	{ Id = "EssenceCask", Name = "Essence Cask", Kind = "Essence", Amount = 600, Currency = "Cores", Price = 3, Stock = 1, Weight = 4 },
	{ Id = "FluxHour", Name = "An Hour of Flux", Kind = "Flux", Minutes = 60, Currency = "Stardust", Price = 30, Stock = 2, Weight = 7 },
	{ Id = "FluxDay", Name = "A Shift of Flux", Kind = "Flux", Minutes = 480, Currency = "Cores", Price = 4, Stock = 1, Weight = 3 },
	{ Id = "Overdrive", Name = "Overdrive Boost", Kind = "Boost", BoostId = "Overdrive", Amount = 1, Currency = "Stardust", Price = 45, Stock = 2, Weight = 5 },
	{ Id = "Hyperdrive", Name = "Hyperdrive Boost", Kind = "Boost", BoostId = "Hyperdrive", Amount = 1, Currency = "Stardust", Price = 70, Stock = 1, Weight = 4 },
	{ Id = "SteadyBurn", Name = "Steady Burn Boost", Kind = "Boost", BoostId = "SteadyBurn", Amount = 1, Currency = "Stardust", Price = 55, Stock = 1, Weight = 4 },
	{ Id = "DomainSurge", Name = "Domain Surge Boost", Kind = "Boost", BoostId = "DomainSurge", Amount = 1, Currency = "Cores", Price = 5, Stock = 1, Weight = 2 },
	{ Id = "EpicCache", Name = "Epic Relic Cache", Kind = "Cache", Rarity = "Epic", Currency = "Stardust", Price = 180, Stock = 1, Weight = 4 },
	{ Id = "LegendaryCache", Name = "Legendary Relic Cache", Kind = "Cache", Rarity = "Legendary", Currency = "Cores", Price = 8, Stock = 1, Weight = 2 },
	{ Id = "MythicCache", Name = "Mythic Relic Cache", Kind = "Cache", Rarity = "Mythic", Currency = "Cores", Price = 25, Stock = 1, Weight = 0.6 },
	{ Id = "SkinCrystal", Kind = "Skin", SkinId = "Crystal", Stock = 1, Weight = 1.2 },
	{ Id = "SkinFrost", Kind = "Skin", SkinId = "Frost", Stock = 1, Weight = 1.2 },
	{ Id = "SkinMolten", Kind = "Skin", SkinId = "Molten", Stock = 1, Weight = 0.9 },
	{ Id = "SkinNebula", Kind = "Skin", SkinId = "Nebula", Stock = 1, Weight = 0.9 },
	{ Id = "SkinVoid", Kind = "Skin", SkinId = "Void", Stock = 1, Weight = 0.5 },
	{ Id = "SkinGilded", Kind = "Skin", SkinId = "Gilded", Stock = 1, Weight = 0.5 },
	{ Id = "SkinCelestial", Kind = "Skin", SkinId = "Celestial", Stock = 1, Weight = 0.25 },
})

local function generator(seed: number)
	local state = math.floor(seed) % 4294967296
	if state == 0 then
		state = 2463534242
	end
	return function(): number
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return state / 4294967296
	end
end

function ShopCatalog.day(now: number): number
	return math.floor(now / ShopCatalog.DAY_SECONDS)
end

function ShopCatalog.secondsLeft(now: number): number
	return ShopCatalog.DAY_SECONDS - (now % ShopCatalog.DAY_SECONDS)
end

local function basePrice(entry: any): (string, number)
	if entry.Kind == "Skin" then
		local skin = skinById[entry.SkinId]
		return skin.Price.Currency, skin.Price.Amount
	end
	return entry.Currency, entry.Price
end

function ShopCatalog.roll(userId: number, day: number, ownedSkins: any?): { any }
	local random = generator(((math.abs(math.floor(userId)) % 1000003) * 7919 + math.floor(day) * 104729) % 4294967296)
	for _ = 1, 4 do
		random()
	end
	local remaining = {}
	for _, entry in ShopCatalog.POOL do
		local owned = entry.Kind == "Skin" and type(ownedSkins) == "table" and ownedSkins[entry.SkinId] == true
		if not owned then
			table.insert(remaining, entry)
		end
	end
	local offers = {}
	while #offers < ShopCatalog.SLOTS and #remaining > 0 do
		local total = 0
		for _, entry in remaining do
			total += entry.Weight
		end
		local pick = random() * total
		local chosen = #remaining
		for index, entry in remaining do
			pick -= entry.Weight
			if pick <= 0 then
				chosen = index
				break
			end
		end
		local entry = table.remove(remaining, chosen)
		local slot = #offers + 1
		local currency, price = basePrice(entry)
		local deal = slot == 1
		if deal then
			price = math.max(1, math.floor(price * (1 - ShopCatalog.DEAL_DISCOUNT) + 0.5))
		end
		local offer = table.clone(entry)
		offer.Slot = slot
		offer.Currency = currency
		offer.Price = price
		offer.Deal = deal
		offer.Name = entry.Name or (entry.Kind == "Skin" and (skinById[entry.SkinId].Name .. " Skin")) or entry.Id
		table.insert(offers, offer)
	end
	return offers
end

function ShopCatalog.remaining(offer: any, bought: any): number
	local used = if type(bought) == "table" then tonumber(bought[tostring(offer.Slot)]) or 0 else 0
	return math.max(0, (offer.Stock or 1) - math.max(0, math.floor(used)))
end

return table.freeze(ShopCatalog)
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
		elseif name == "ValidateMonetizationIds" then
			return validateMonetizationIds
		end
		return __load(name)
	end,
})
