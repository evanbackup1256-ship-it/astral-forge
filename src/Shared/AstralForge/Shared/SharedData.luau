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
	Id = 120416738421118,
	Length = 256.484,
	Regions = {
		hover = { 0.15, 0.04 },
		hoverTick = { 0.34, 0.035 },
		tick = { 0.525, 0.03 },
		scroll = { 0.705, 0.025 },
		sliderStep = { 0.88, 0.025 },
		amountChange = { 1.055, 0.03 },
		filterPick = { 1.235, 0.07 },
		sanctuaryHover = { 1.455, 0.045 },
		navHover = { 1.65, 0.04 },
		click = { 1.84, 0.092 },
		settings = { 2.082, 0.092 },
		purchasePress = { 2.3239, 0.18 },
		claimPress = { 2.6539, 0.25 },
		codeSubmit = { 3.0539, 0.1398 },
		zoneSelect = { 3.3438, 0.14 },
		labRoute = { 3.6338, 0.14 },
		playerlistAction = { 3.9238, 0.092 },
		playerlistSelect = { 4.1658, 0.045 },
		puzzleTap = { 4.3608, 0.1276 },
		sanctuaryClick = { 4.6384, 0.092 },
		curtainOpen = { 4.8804, 0.4729 },
		curtainClose = { 5.5033, 0.34 },
		confirm = { 5.9933, 0.3718 },
		successChime = { 6.5151, 0.5101 },
		equip = { 7.1752, 0.7749 },
		itemLink = { 8.1001, 0.623 },
		tutorialStep = { 8.8731, 0.7051 },
		roleChange = { 9.7282, 0.8496 },
		reactorStabilize = { 10.7278, 0.9596 },
		toggleOn = { 11.8374, 0.1 },
		toggleOff = { 12.0874, 0.1 },
		queueStart = { 12.3374, 0.24 },
		queueStop = { 12.7274, 0.16 },
		open = { 13.0374, 0.2738 },
		modalOpen = { 13.4612, 0.3505 },
		filterOpen = { 13.9617, 0.09 },
		boostOpen = { 14.2017, 0.7217 },
		offlineOpen = { 15.0734, 0.722 },
		playerlistOpen = { 15.9454, 0.12 },
		story = { 16.2154, 0.3982 },
		storyOpen = { 16.7637, 0.722 },
		crate = { 17.6356, 0.722 },
		close = { 18.5076, 0.14 },
		modalDismiss = { 18.7976, 0.14 },
		purchaseExit = { 19.0876, 0.12 },
		playerlistClose = { 19.3576, 0.11 },
		noticeClose = { 19.6176, 0.07 },
		itemUnlink = { 19.8376, 0.662 },
		reset = { 20.6496, 0.602 },
		memberRemove = { 21.4016, 0.662 },
		guildLeave = { 22.2136, 0.662 },
		gamePause = { 23.0256, 0.6599 },
		gameExit = { 23.8355, 0.602 },
		page = { 24.5875, 0.12 },
		tabSwitch = { 24.8575, 0.07 },
		preview = { 25.0775, 0.412 },
		storyBeat = { 25.6395, 0.372 },
		storyPage = { 26.1615, 0.24 },
		mailRead = { 26.5515, 0.21 },
		leaderboardSwitch = { 26.9115, 0.07 },
		cardEndTurn = { 27.1315, 0.12 },
		modalPop = { 27.4015, 0.08 },
		sliderCommit = { 27.6315, 0.15 },
		inputClear = { 27.9315, 0.08 },
		chatSend = { 28.1615, 0.08 },
		inputFocus = { 28.3915, 0.08 },
		error = { 28.6215, 0.24 },
		errorBuzz = { 29.0115, 0.32 },
		noticeError = { 29.4815, 0.24 },
		dangerPress = { 29.8715, 0.4336 },
		locked = { 30.4551, 0.125 },
		requestBlocked = { 30.7301, 0.21 },
		cardBlock = { 31.0901, 0.21 },
		noticeWarning = { 31.4501, 0.26 },
		systemAlert = { 31.8601, 0.862 },
		requestTimeout = { 32.8721, 0.862 },
		adminArm = { 33.8841, 0.7449 },
		mail = { 34.779, 0.409 },
		notification = { 35.338, 0.8914 },
		noticeInfo = { 36.3794, 0.2389 },
		noticeSuccess = { 36.7683, 0.379 },
		noticeSpecial = { 37.2973, 0.5519 },
		boostReady = { 37.9993, 0.9331 },
		reactorReady = { 39.0824, 0.7375 },
		crewNudge = { 39.9698, 0.612 },
		invite = { 40.7318, 0.5808 },
		chatReceive = { 41.4627, 0.12 },
		gameResume = { 41.7327, 0.722 },
		velocitySlide = { 42.6047, 0.16 },
		travel = { 42.9147, 1.012 },
		purchase = { 44.0767, 0.6257 },
		purchaseResult = { 44.8523, 0.5742 },
		vaultDeposit = { 45.5766, 0.6477 },
		vaultBank = { 46.3742, 0.6247 },
		guildDeposit = { 47.1489, 0.6778 },
		collect = { 47.9767, 0.8909 },
		boost = { 49.0176, 0.8283 },
		boostActivate = { 49.996, 0.8659 },
		offlineCollect = { 51.0118, 0.9968 },
		puzzleClear = { 52.1586, 0.8141 },
		oreCollect = { 53.1227, 0.7881 },
		reward = { 54.0608, 2.1409 },
		codeReward = { 56.3517, 1.6946 },
		tutorialFinish = { 58.1963, 1.8705 },
		domainReward = { 60.2168, 1.9866 },
		wheelLand = { 62.3534, 1.5242 },
		unlock = { 64.0276, 1.7267 },
		researchUnlock = { 65.9043, 1.5673 },
		achievementClaim = { 67.6216, 1.7686 },
		seasonClaim = { 69.5402, 1.6384 },
		comboMilestone = { 71.3286, 1.6132 },
		discovery = { 73.0918, 1.6436 },
		zoneUnlock = { 74.8854, 1.8092 },
		guildCreate = { 76.8446, 1.5137 },
		echoCapture = { 78.5083, 1.8834 },
		storyReveal = { 80.5417, 1.9675 },
		missionClaim = { 82.6592, 1.1684 },
		dailyClaim = { 83.9776, 1.0257 },
		timedClaim = { 85.1532, 1.1425 },
		mailClaim = { 86.4457, 1.0252 },
		crateClaim = { 87.6209, 1.0375 },
		echoClaim = { 88.8085, 1.0602 },
		guildJoin = { 90.0186, 1.0286 },
		expeditionReturn = { 91.1972, 1.1433 },
		prestige = { 92.4905, 4.0907 },
		rebirthBloom = { 96.7312, 3.9206 },
		crateRare = { 100.8018, 3.8797 },
		salvage = { 104.8315, 0.9537 },
		salvageCrunch = { 105.9352, 0.8393 },
		echoDismantle = { 106.9246, 1.0821 },
		autoForge = { 108.1566, 0.8313 },
		bootStrike = { 109.138, 0.9657 },
		bootClang = { 110.2537, 0.8437 },
		bootAnvilSplit = { 111.2474, 1.1455 },
		wardenStrike = { 112.5429, 0.6598 },
		wardenCrit = { 113.3527, 1.0989 },
		machineInstall = { 114.6015, 0.8055 },
		wheelBrake = { 115.5571, 0.931 },
		crateBrake = { 116.6381, 0.8182 },
		wheel = { 117.6062, 0.812 },
		wheelStart = { 118.5682, 1.1665 },
		crateOpen = { 119.8847, 0.942 },
		expeditionLaunch = { 120.9767, 1.112 },
		bootStart = { 122.2387, 0.962 },
		bootWhoosh = { 123.3507, 1.012 },
		bootFinaleFlip = { 124.5127, 0.862 },
		bootSlamAir = { 125.5247, 1.162 },
		reactor = { 126.8367, 1.2 },
		bootRumble = { 128.1867, 1.4 },
		bootFractureTail = { 129.7367, 1.6 },
		bootGravity = { 131.4867, 1.5 },
		bootAftershock = { 133.1367, 1.3 },
		reactorSurge = { 134.5867, 1.7988 },
		adminExecute = { 136.5356, 1.8074 },
		crateLand = { 138.493, 1.8215 },
		domainImpact = { 140.4645, 1.7422 },
		bootImpact = { 142.3568, 1.777 },
		bootFinaleBang = { 144.2838, 1.8544 },
		reactorChannel = { 146.2881, 1.6466 },
		rebirthCharge = { 148.0847, 1.862 },
		wheelCharge = { 150.0967, 1.462 },
		crateCharge = { 151.7087, 1.562 },
		domainCharge = { 153.4207, 1.962 },
		cardPower = { 155.5327, 1.3555 },
		bootTension = { 157.0382, 1.712 },
		reactorPulse = { 158.9002, 0.518 },
		domainCrack = { 159.5682, 0.5265 },
		cardEnergy = { 160.2447, 0.5173 },
		bootSpark = { 160.912, 0.5309 },
		bootFizz = { 161.5929, 0.5377 },
		bootDebris = { 162.2805, 0.5204 },
		domainBind = { 162.9509, 2.6862 },
		boot = { 165.7871, 2.6663 },
		wheelTick = { 168.6034, 0.055 },
		wheelSlow = { 168.8084, 0.055 },
		crateTick = { 169.0134, 0.03 },
		crateNear = { 169.1934, 0.03 },
		cardPlay = { 169.3734, 0.05 },
		cardDraw = { 169.5734, 0.05 },
		bootIgnite = { 169.7734, 1.8256 },
		bootReady = { 171.749, 1.8383 },
		bootSlamCharge = { 173.7374, 2.112 },
		oreMine = { 175.9994, 0.9218 },
		wardenForming = { 177.0712, 4.612 },
		wardenAwake = { 181.8332, 2.962 },
		wardenSlam = { 184.9452, 3.362 },
		wardenDefeat = { 188.4572, 4.5411 },
		wardenEscape = { 193.1483, 3.212 },
		waystoneTravel = { 196.5103, 2.3711 },
		regionEnter = { 199.0314, 3.0588 },
		echoEquip = { 202.2402, 0.8345 },
		echoTune = { 203.2246, 0.056 },
		wardenSlamCharge = { 203.4307, 2.412 },
		navOpenOverview = { 205.9927, 0.24 },
		navHoverOverview = { 206.3827, 0.04 },
		navOpenWorkshop = { 206.5727, 0.251 },
		navHoverWorkshop = { 206.9736, 0.04 },
		navOpenInventory = { 207.1636, 0.2508 },
		navHoverInventory = { 207.5644, 0.04 },
		navOpenResearch = { 207.7544, 0.2508 },
		navHoverResearch = { 208.1552, 0.04 },
		navOpenShop = { 208.3452, 0.2509 },
		navHoverShop = { 208.746, 0.04 },
		navOpenSettings = { 208.936, 0.2688 },
		navHoverSettings = { 209.3548, 0.04 },
		navOpenWorlds = { 209.5448, 0.2688 },
		navHoverWorlds = { 209.9635, 0.04 },
		navOpenMissions = { 210.1535, 0.2506 },
		navHoverMissions = { 210.5541, 0.04 },
		navOpenRewards = { 210.7441, 0.2574 },
		navHoverRewards = { 211.1515, 0.04 },
		navOpenBoosts = { 211.3415, 0.2564 },
		navHoverBoosts = { 211.7479, 0.04 },
		navOpenStarGrid = { 211.9379, 0.2509 },
		navHoverStarGrid = { 212.3388, 0.04 },
		navOpenEchoes = { 212.5288, 0.251 },
		navHoverEchoes = { 212.9298, 0.04 },
		navOpenContinuum = { 213.1198, 0.251 },
		navHoverContinuum = { 213.5208, 0.04 },
		navOpenLab = { 213.7108, 0.2508 },
		navHoverLab = { 214.1115, 0.04 },
		navOpenAnomaly = { 214.3015, 0.2505 },
		navHoverAnomaly = { 214.702, 0.04 },
		navOpenWheel = { 214.892, 0.2508 },
		navHoverWheel = { 215.2929, 0.04 },
		navOpenCommand = { 215.4829, 0.2688 },
		navHoverCommand = { 215.9016, 0.04 },
		navOpenStory = { 216.0916, 0.2516 },
		navHoverStory = { 216.4932, 0.04 },
		navOpenMail = { 216.6832, 0.2506 },
		navHoverMail = { 217.0838, 0.04 },
		navOpenChat = { 217.2738, 0.2569 },
		navHoverChat = { 217.6807, 0.04 },
		navOpenCrew = { 217.8707, 0.2509 },
		navHoverCrew = { 218.2715, 0.04 },
		navOpenMilestones = { 218.4615, 0.24 },
		navHoverMilestones = { 218.8515, 0.04 },
		navOpenConvergence = { 219.0415, 0.251 },
		navHoverConvergence = { 219.4425, 0.04 },
		navOpenGuild = { 219.6325, 0.2508 },
		navHoverGuild = { 220.0333, 0.04 },
		navOpenLeaderboards = { 220.2233, 0.2508 },
		navHoverLeaderboards = { 220.6241, 0.04 },
		navOpenTrade = { 220.8141, 0.2509 },
		navHoverTrade = { 221.2149, 0.04 },
		navOpenCredits = { 221.4049, 0.2688 },
		navHoverCredits = { 221.8237, 0.04 },
		navOpenAdmin = { 222.0137, 0.2683 },
		navHoverAdmin = { 222.432, 0.04 },
		navOpenForgePath = { 222.622, 0.2506 },
		navHoverForgePath = { 223.0226, 0.04 },
		navOpenFoundry = { 223.2126, 0.2569 },
		navHoverFoundry = { 223.6195, 0.04 },
		oreMineEmberite = { 223.8095, 0.32 },
		oreCollectEmberite = { 224.2795, 0.36 },
		oreMineVoidglass = { 224.7895, 0.3063 },
		oreCollectVoidglass = { 225.2457, 0.3525 },
		oreMineStarsteel = { 225.7482, 0.32 },
		oreCollectStarsteel = { 226.2182, 0.36 },
		waystoneHeart = { 226.7282, 0.2174 },
		waystoneEmberreach = { 227.0956, 0.22 },
		waystoneHollows = { 227.4656, 0.22 },
		waystoneSpire = { 227.8356, 0.22 },
		waystoneRiftmaw = { 228.2056, 0.22 },
		sanctuaryRecall = { 228.5756, 0.26 },
		sanctuaryMenu = { 228.9856, 0.09 },
		sanctuarySheetClose = { 229.2256, 0.14 },
		clickHover = { 229.5156, 0.035 },
		confirmHover = { 229.7006, 0.035 },
		settingsHover = { 229.8856, 0.035 },
		purchasePressHover = { 230.0706, 0.035 },
		claimPressHover = { 230.2556, 0.035 },
		codeSubmitHover = { 230.4406, 0.035 },
		zoneSelectHover = { 230.6256, 0.035 },
		labRouteHover = { 230.8106, 0.035 },
		playerlistActionHover = { 230.9956, 0.035 },
		playerlistSelectHover = { 231.1805, 0.035 },
		puzzleTapHover = { 231.3655, 0.035 },
		sanctuaryClickHover = { 231.5505, 0.035 },
		equipHover = { 231.7355, 0.035 },
		dangerPressHover = { 231.9205, 0.035 },
		closeHover = { 232.1055, 0.035 },
		tickHover = { 232.2905, 0.035 },
		openHover = { 232.4755, 0.035 },
		tabSwitchHover = { 232.6605, 0.035 },
		mailHover = { 232.8454, 0.035 },
		storyHover = { 233.0304, 0.035 },
		toggleOnHover = { 233.2154, 0.035 },
		toggleOffHover = { 233.4004, 0.035 },
		lockedHover = { 233.5854, 0.035 },
		errorHover = { 233.7704, 0.035 },
		prestigeHover = { 233.9554, 0.035 },
		domainChargeHover = { 234.1404, 0.035 },
		cardEndTurnHover = { 234.3254, 0.035 },
		cardPowerHover = { 234.5103, 0.035 },
		cardEnergyHover = { 234.6953, 0.035 },
		vaultBankHover = { 234.8803, 0.035 },
		guildCreateHover = { 235.0653, 0.035 },
		guildJoinHover = { 235.2503, 0.035 },
		inviteHover = { 235.4353, 0.035 },
		travelHover = { 235.6203, 0.035 },
		gameResumeHover = { 235.8053, 0.035 },
		gamePauseHover = { 235.9902, 0.035 },
		queueStopHover = { 236.1752, 0.035 },
		queueStartHover = { 236.3602, 0.035 },
		boostHover = { 236.5452, 0.035 },
		reactorPulseHover = { 236.7302, 0.035 },
		crateOpenHover = { 236.9152, 0.035 },
		wheelStartHover = { 237.1002, 0.035 },
		rewardHover = { 237.2852, 0.035 },
		rebirthChargeHover = { 237.4702, 0.035 },
		missionClaimHover = { 237.6551, 0.035 },
		leaderboardSwitchHover = { 237.8401, 0.035 },
		adminArmHover = { 238.0251, 0.035 },
		memberRemoveHover = { 238.2101, 0.035 },
		roleChangeHover = { 238.3951, 0.035 },
		previewHover = { 238.5801, 0.035 },
		resetHover = { 238.7651, 0.035 },
		chatSendHover = { 238.9501, 0.035 },
		boostOpenHover = { 239.1351, 0.035 },
		vaultDepositHover = { 239.32, 0.035 },
		forgePress = { 239.505, 0.092 },
		corePress = { 239.747, 0.092 },
		wavePress = { 239.989, 0.092 },
		labPress = { 240.231, 0.092 },
		commandPress = { 240.473, 0.092 },
		adminPress = { 240.715, 0.092 },
		creditsPress = { 240.957, 0.092 },
		chatPress = { 241.199, 0.092 },
		continuumPress = { 241.441, 0.092 },
		missionPress = { 241.683, 0.092 },
		overviewPress = { 241.925, 0.092 },
		dropdownOpen = { 242.167, 0.09 },
		dropdownClose = { 242.407, 0.08 },
		copyDone = { 242.637, 0.145 },
		dragGrab = { 242.932, 0.064 },
		dragDrop = { 243.146, 0.106 },
		dragSnap = { 243.402, 0.03 },
		favoriteOn = { 243.582, 0.3155 },
		favoriteOff = { 244.0474, 0.08 },
		ratingStar = { 244.2774, 0.11 },
		searchType = { 244.5374, 0.022 },
		countTick = { 244.7094, 0.02 },
		stepNext = { 244.8794, 0.13 },
		stepBack = { 245.1594, 0.13 },
		reportSubmit = { 245.4394, 0.32 },
		feedbackSubmit = { 245.9094, 0.429 },
		guildAnnounce = { 246.4884, 0.652 },
		badgeEarn = { 247.2904, 0.4201 },
		artifactEquip = { 247.8605, 0.329 },
		artifactUpgrade = { 248.3395, 0.6532 },
		crateSeal = { 249.1427, 0.3432 },
		crateOrbit = { 249.6359, 0.6 },
		crateRarityStep = { 250.3859, 0.14 },
		crateRevealEpic = { 250.6759, 0.6083 },
		crateRevealMythic = { 251.4342, 0.8988 },
		rebirthIgnite = { 252.4831, 1.1149 },
		rebirthShockwave = { 253.748, 0.777 },
		rebirthTierUp = { 254.675, 0.3702 },
		rebirthAscend = { 255.1952, 1.139 },
	} :: { [string]: Region },
	Loudness = {
		hover = -14.25,
		hoverTick = -13.92,
		tick = -12.99,
		scroll = -12.39,
		sliderStep = -12.7,
		amountChange = -13.38,
		filterPick = -15.76,
		sanctuaryHover = -14.55,
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
		puzzleTap = -16.72,
		sanctuaryClick = -15.83,
		curtainOpen = -15.34,
		curtainClose = -15.49,
		confirm = -14.92,
		successChime = -14.94,
		equip = -15.46,
		itemLink = -17.67,
		tutorialStep = -17.42,
		roleChange = -16.54,
		reactorStabilize = -16.63,
		toggleOn = -15.8,
		toggleOff = -15.67,
		queueStart = -16.98,
		queueStop = -15.87,
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
		noticeClose = -14.1,
		itemUnlink = -16.53,
		reset = -18.13,
		memberRemove = -17.02,
		guildLeave = -16.62,
		gamePause = -16.98,
		gameExit = -18.41,
		page = -15.01,
		tabSwitch = -16.05,
		preview = -17.32,
		storyBeat = -16.35,
		storyPage = -17.07,
		mailRead = -16.37,
		leaderboardSwitch = -16.41,
		cardEndTurn = -15.1,
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
		requestBlocked = -14.23,
		cardBlock = -14.43,
		noticeWarning = -15.38,
		systemAlert = -12.7,
		requestTimeout = -12.79,
		adminArm = -15.89,
		mail = -14.82,
		notification = -16.49,
		noticeInfo = -15.84,
		noticeSuccess = -15.39,
		noticeSpecial = -15.25,
		boostReady = -17.76,
		reactorReady = -17.62,
		crewNudge = -13.72,
		invite = -13.75,
		chatReceive = -15.05,
		gameResume = -14.61,
		velocitySlide = -14.9,
		travel = -17.39,
		purchase = -17.84,
		purchaseResult = -18.08,
		vaultDeposit = -18.25,
		vaultBank = -18.23,
		guildDeposit = -17.69,
		collect = -16.79,
		boost = -15.08,
		boostActivate = -16.73,
		offlineCollect = -15.44,
		puzzleClear = -15.11,
		oreCollect = -17.53,
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
		bootStrike = -13.78,
		bootClang = -13.68,
		bootAnvilSplit = -13.3,
		wardenStrike = -18.94,
		wardenCrit = -12.85,
		machineInstall = -20.55,
		wheelBrake = -16.99,
		crateBrake = -20.32,
		wheel = -17.59,
		wheelStart = -19.37,
		crateOpen = -17.51,
		expeditionLaunch = -17.4,
		bootStart = -17.27,
		bootWhoosh = -17.43,
		bootFinaleFlip = -17.12,
		bootSlamAir = -17.68,
		reactor = -15.65,
		bootRumble = -15.62,
		bootFractureTail = -15.41,
		bootGravity = -15.76,
		bootAftershock = -15.86,
		reactorSurge = -12.58,
		adminExecute = -12.65,
		crateLand = -12.53,
		domainImpact = -12.87,
		bootImpact = -12.57,
		bootFinaleBang = -12.89,
		reactorChannel = -18.7,
		rebirthCharge = -18.62,
		wheelCharge = -19.11,
		crateCharge = -18.75,
		domainCharge = -19.45,
		cardPower = -19.24,
		bootTension = -18.63,
		reactorPulse = -15.47,
		domainCrack = -18.63,
		cardEnergy = -16.21,
		bootSpark = -16.19,
		bootFizz = -16.71,
		bootDebris = -19.38,
		domainBind = -16.84,
		boot = -17.51,
		wheelTick = -19.02,
		wheelSlow = -18.73,
		crateTick = -13.58,
		crateNear = -13.41,
		cardPlay = -17.96,
		cardDraw = -16.9,
		bootIgnite = -13.69,
		bootReady = -19.89,
		bootSlamCharge = -19.36,
		oreMine = -18.53,
		wardenForming = -18.14,
		wardenAwake = -11.91,
		wardenSlam = -11.81,
		wardenDefeat = -18.87,
		wardenEscape = -15.51,
		waystoneTravel = -18.62,
		regionEnter = -16.18,
		echoEquip = -17.38,
		echoTune = -15.83,
		wardenSlamCharge = -18.1,
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
		oreMineEmberite = -10.68,
		oreCollectEmberite = -12.15,
		oreMineVoidglass = -17.53,
		oreCollectVoidglass = -15.52,
		oreMineStarsteel = -15.49,
		oreCollectStarsteel = -14.52,
		waystoneHeart = -14.6,
		waystoneEmberreach = -13.67,
		waystoneHollows = -9.73,
		waystoneSpire = -13.92,
		waystoneRiftmaw = -13.91,
		sanctuaryRecall = -14.52,
		sanctuaryMenu = -12.41,
		sanctuarySheetClose = -11.73,
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
		puzzleTapHover = -13.76,
		sanctuaryClickHover = -13.55,
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
		cardEndTurnHover = -13.55,
		cardPowerHover = -13.75,
		cardEnergyHover = -13.82,
		vaultBankHover = -13.5,
		guildCreateHover = -13.76,
		guildJoinHover = -13.55,
		inviteHover = -13.75,
		travelHover = -13.82,
		gameResumeHover = -13.5,
		gamePauseHover = -13.76,
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

Manifest.SoundSheetPrevious = {
	Id = 78085647329544,
	Length = 242.167,
	Regions = {
		hover = { 0.15, 0.04 },
		hoverTick = { 0.34, 0.035 },
		tick = { 0.525, 0.03 },
		scroll = { 0.705, 0.025 },
		sliderStep = { 0.88, 0.025 },
		amountChange = { 1.055, 0.03 },
		filterPick = { 1.235, 0.07 },
		sanctuaryHover = { 1.455, 0.045 },
		navHover = { 1.65, 0.04 },
		click = { 1.84, 0.092 },
		settings = { 2.082, 0.092 },
		purchasePress = { 2.3239, 0.18 },
		claimPress = { 2.6539, 0.25 },
		codeSubmit = { 3.0539, 0.1398 },
		zoneSelect = { 3.3438, 0.14 },
		labRoute = { 3.6338, 0.14 },
		playerlistAction = { 3.9238, 0.092 },
		playerlistSelect = { 4.1658, 0.045 },
		puzzleTap = { 4.3608, 0.1276 },
		sanctuaryClick = { 4.6384, 0.092 },
		curtainOpen = { 4.8804, 0.4729 },
		curtainClose = { 5.5033, 0.34 },
		confirm = { 5.9933, 0.3718 },
		successChime = { 6.5151, 0.5101 },
		equip = { 7.1752, 0.7749 },
		itemLink = { 8.1001, 0.623 },
		tutorialStep = { 8.8731, 0.7051 },
		roleChange = { 9.7282, 0.8496 },
		reactorStabilize = { 10.7278, 0.9596 },
		toggleOn = { 11.8374, 0.1 },
		toggleOff = { 12.0874, 0.1 },
		queueStart = { 12.3374, 0.24 },
		queueStop = { 12.7274, 0.16 },
		open = { 13.0374, 0.2738 },
		modalOpen = { 13.4612, 0.3505 },
		filterOpen = { 13.9617, 0.09 },
		boostOpen = { 14.2017, 0.7217 },
		offlineOpen = { 15.0734, 0.722 },
		playerlistOpen = { 15.9454, 0.12 },
		story = { 16.2154, 0.3982 },
		storyOpen = { 16.7637, 0.722 },
		crate = { 17.6356, 0.722 },
		close = { 18.5076, 0.14 },
		modalDismiss = { 18.7976, 0.14 },
		purchaseExit = { 19.0876, 0.12 },
		playerlistClose = { 19.3576, 0.11 },
		noticeClose = { 19.6176, 0.07 },
		itemUnlink = { 19.8376, 0.662 },
		reset = { 20.6496, 0.602 },
		memberRemove = { 21.4016, 0.662 },
		guildLeave = { 22.2136, 0.662 },
		gamePause = { 23.0256, 0.6599 },
		gameExit = { 23.8355, 0.602 },
		page = { 24.5875, 0.12 },
		tabSwitch = { 24.8575, 0.07 },
		preview = { 25.0775, 0.412 },
		storyBeat = { 25.6395, 0.372 },
		storyPage = { 26.1615, 0.24 },
		mailRead = { 26.5515, 0.21 },
		leaderboardSwitch = { 26.9115, 0.07 },
		cardEndTurn = { 27.1315, 0.12 },
		modalPop = { 27.4015, 0.08 },
		sliderCommit = { 27.6315, 0.15 },
		inputClear = { 27.9315, 0.08 },
		chatSend = { 28.1615, 0.08 },
		inputFocus = { 28.3915, 0.08 },
		error = { 28.6215, 0.24 },
		errorBuzz = { 29.0115, 0.32 },
		noticeError = { 29.4815, 0.24 },
		dangerPress = { 29.8715, 0.4336 },
		locked = { 30.4551, 0.125 },
		requestBlocked = { 30.7301, 0.21 },
		cardBlock = { 31.0901, 0.21 },
		noticeWarning = { 31.4501, 0.26 },
		systemAlert = { 31.8601, 0.862 },
		requestTimeout = { 32.8721, 0.862 },
		adminArm = { 33.8841, 0.7449 },
		mail = { 34.779, 0.409 },
		notification = { 35.338, 0.8914 },
		noticeInfo = { 36.3794, 0.2389 },
		noticeSuccess = { 36.7683, 0.379 },
		noticeSpecial = { 37.2973, 0.5519 },
		boostReady = { 37.9993, 0.9331 },
		reactorReady = { 39.0824, 0.7375 },
		crewNudge = { 39.9698, 0.612 },
		invite = { 40.7318, 0.5808 },
		chatReceive = { 41.4627, 0.12 },
		gameResume = { 41.7327, 0.722 },
		velocitySlide = { 42.6047, 0.16 },
		travel = { 42.9147, 1.012 },
		purchase = { 44.0767, 0.6257 },
		purchaseResult = { 44.8523, 0.5742 },
		vaultDeposit = { 45.5766, 0.6477 },
		vaultBank = { 46.3742, 0.6247 },
		guildDeposit = { 47.1489, 0.6778 },
		collect = { 47.9767, 0.8909 },
		boost = { 49.0176, 0.8283 },
		boostActivate = { 49.996, 0.8659 },
		offlineCollect = { 51.0118, 0.9968 },
		puzzleClear = { 52.1586, 0.8141 },
		oreCollect = { 53.1227, 0.7881 },
		reward = { 54.0608, 2.1409 },
		codeReward = { 56.3517, 1.6946 },
		tutorialFinish = { 58.1963, 1.8705 },
		domainReward = { 60.2168, 1.9866 },
		wheelLand = { 62.3534, 1.5242 },
		unlock = { 64.0276, 1.7267 },
		researchUnlock = { 65.9043, 1.5673 },
		achievementClaim = { 67.6216, 1.7686 },
		seasonClaim = { 69.5402, 1.6384 },
		comboMilestone = { 71.3286, 1.6132 },
		discovery = { 73.0918, 1.6436 },
		zoneUnlock = { 74.8854, 1.8092 },
		guildCreate = { 76.8446, 1.5137 },
		echoCapture = { 78.5083, 1.8834 },
		storyReveal = { 80.5417, 1.9675 },
		missionClaim = { 82.6592, 1.1684 },
		dailyClaim = { 83.9776, 1.0257 },
		timedClaim = { 85.1532, 1.1425 },
		mailClaim = { 86.4457, 1.0252 },
		crateClaim = { 87.6209, 1.0375 },
		echoClaim = { 88.8085, 1.0602 },
		guildJoin = { 90.0186, 1.0286 },
		expeditionReturn = { 91.1972, 1.1433 },
		prestige = { 92.4905, 4.0907 },
		rebirthBloom = { 96.7312, 3.9206 },
		crateRare = { 100.8018, 3.8797 },
		salvage = { 104.8315, 0.9537 },
		salvageCrunch = { 105.9352, 0.8393 },
		echoDismantle = { 106.9246, 1.0821 },
		autoForge = { 108.1566, 0.8313 },
		bootStrike = { 109.138, 0.9657 },
		bootClang = { 110.2537, 0.8437 },
		bootAnvilSplit = { 111.2474, 1.1455 },
		wardenStrike = { 112.5429, 0.6598 },
		wardenCrit = { 113.3527, 1.0989 },
		machineInstall = { 114.6015, 0.8055 },
		wheelBrake = { 115.5571, 0.931 },
		crateBrake = { 116.6381, 0.8182 },
		wheel = { 117.6062, 0.812 },
		wheelStart = { 118.5682, 1.1665 },
		crateOpen = { 119.8847, 0.942 },
		expeditionLaunch = { 120.9767, 1.112 },
		bootStart = { 122.2387, 0.962 },
		bootWhoosh = { 123.3507, 1.012 },
		bootFinaleFlip = { 124.5127, 0.862 },
		bootSlamAir = { 125.5247, 1.162 },
		reactor = { 126.8367, 1.2 },
		bootRumble = { 128.1867, 1.4 },
		bootFractureTail = { 129.7367, 1.6 },
		bootGravity = { 131.4867, 1.5 },
		bootAftershock = { 133.1367, 1.3 },
		reactorSurge = { 134.5867, 1.7988 },
		adminExecute = { 136.5356, 1.8074 },
		crateLand = { 138.493, 1.8215 },
		domainImpact = { 140.4645, 1.7422 },
		bootImpact = { 142.3568, 1.777 },
		bootFinaleBang = { 144.2838, 1.8544 },
		reactorChannel = { 146.2881, 1.6466 },
		rebirthCharge = { 148.0847, 1.862 },
		wheelCharge = { 150.0967, 1.462 },
		crateCharge = { 151.7087, 1.562 },
		domainCharge = { 153.4207, 1.962 },
		cardPower = { 155.5327, 1.3555 },
		bootTension = { 157.0382, 1.712 },
		reactorPulse = { 158.9002, 0.518 },
		domainCrack = { 159.5682, 0.5265 },
		cardEnergy = { 160.2447, 0.5173 },
		bootSpark = { 160.912, 0.5309 },
		bootFizz = { 161.5929, 0.5377 },
		bootDebris = { 162.2805, 0.5204 },
		domainBind = { 162.9509, 2.6862 },
		boot = { 165.7871, 2.6663 },
		wheelTick = { 168.6034, 0.055 },
		wheelSlow = { 168.8084, 0.055 },
		crateTick = { 169.0134, 0.03 },
		crateNear = { 169.1934, 0.03 },
		cardPlay = { 169.3734, 0.05 },
		cardDraw = { 169.5734, 0.05 },
		bootIgnite = { 169.7734, 1.8256 },
		bootReady = { 171.749, 1.8383 },
		bootSlamCharge = { 173.7374, 2.112 },
		oreMine = { 175.9994, 0.9218 },
		wardenForming = { 177.0712, 4.612 },
		wardenAwake = { 181.8332, 2.962 },
		wardenSlam = { 184.9452, 3.362 },
		wardenDefeat = { 188.4572, 4.5411 },
		wardenEscape = { 193.1483, 3.212 },
		waystoneTravel = { 196.5103, 2.3711 },
		regionEnter = { 199.0314, 3.0588 },
		echoEquip = { 202.2402, 0.8345 },
		echoTune = { 203.2246, 0.056 },
		wardenSlamCharge = { 203.4307, 2.412 },
		navOpenOverview = { 205.9927, 0.24 },
		navHoverOverview = { 206.3827, 0.04 },
		navOpenWorkshop = { 206.5727, 0.251 },
		navHoverWorkshop = { 206.9736, 0.04 },
		navOpenInventory = { 207.1636, 0.2508 },
		navHoverInventory = { 207.5644, 0.04 },
		navOpenResearch = { 207.7544, 0.2508 },
		navHoverResearch = { 208.1552, 0.04 },
		navOpenShop = { 208.3452, 0.2509 },
		navHoverShop = { 208.746, 0.04 },
		navOpenSettings = { 208.936, 0.2688 },
		navHoverSettings = { 209.3548, 0.04 },
		navOpenWorlds = { 209.5448, 0.2688 },
		navHoverWorlds = { 209.9635, 0.04 },
		navOpenMissions = { 210.1535, 0.2506 },
		navHoverMissions = { 210.5541, 0.04 },
		navOpenRewards = { 210.7441, 0.2574 },
		navHoverRewards = { 211.1515, 0.04 },
		navOpenBoosts = { 211.3415, 0.2564 },
		navHoverBoosts = { 211.7479, 0.04 },
		navOpenStarGrid = { 211.9379, 0.2509 },
		navHoverStarGrid = { 212.3388, 0.04 },
		navOpenEchoes = { 212.5288, 0.251 },
		navHoverEchoes = { 212.9298, 0.04 },
		navOpenContinuum = { 213.1198, 0.251 },
		navHoverContinuum = { 213.5208, 0.04 },
		navOpenLab = { 213.7108, 0.2508 },
		navHoverLab = { 214.1115, 0.04 },
		navOpenAnomaly = { 214.3015, 0.2505 },
		navHoverAnomaly = { 214.702, 0.04 },
		navOpenWheel = { 214.892, 0.2508 },
		navHoverWheel = { 215.2929, 0.04 },
		navOpenCommand = { 215.4829, 0.2688 },
		navHoverCommand = { 215.9016, 0.04 },
		navOpenStory = { 216.0916, 0.2516 },
		navHoverStory = { 216.4932, 0.04 },
		navOpenMail = { 216.6832, 0.2506 },
		navHoverMail = { 217.0838, 0.04 },
		navOpenChat = { 217.2738, 0.2569 },
		navHoverChat = { 217.6807, 0.04 },
		navOpenCrew = { 217.8707, 0.2509 },
		navHoverCrew = { 218.2715, 0.04 },
		navOpenMilestones = { 218.4615, 0.24 },
		navHoverMilestones = { 218.8515, 0.04 },
		navOpenConvergence = { 219.0415, 0.251 },
		navHoverConvergence = { 219.4425, 0.04 },
		navOpenGuild = { 219.6325, 0.2508 },
		navHoverGuild = { 220.0333, 0.04 },
		navOpenLeaderboards = { 220.2233, 0.2508 },
		navHoverLeaderboards = { 220.6241, 0.04 },
		navOpenTrade = { 220.8141, 0.2509 },
		navHoverTrade = { 221.2149, 0.04 },
		navOpenCredits = { 221.4049, 0.2688 },
		navHoverCredits = { 221.8237, 0.04 },
		navOpenAdmin = { 222.0137, 0.2683 },
		navHoverAdmin = { 222.432, 0.04 },
		navOpenForgePath = { 222.622, 0.2506 },
		navHoverForgePath = { 223.0226, 0.04 },
		navOpenFoundry = { 223.2126, 0.2569 },
		navHoverFoundry = { 223.6195, 0.04 },
		oreMineEmberite = { 223.8095, 0.32 },
		oreCollectEmberite = { 224.2795, 0.36 },
		oreMineVoidglass = { 224.7895, 0.3063 },
		oreCollectVoidglass = { 225.2457, 0.3525 },
		oreMineStarsteel = { 225.7482, 0.32 },
		oreCollectStarsteel = { 226.2182, 0.36 },
		waystoneHeart = { 226.7282, 0.2174 },
		waystoneEmberreach = { 227.0956, 0.22 },
		waystoneHollows = { 227.4656, 0.22 },
		waystoneSpire = { 227.8356, 0.22 },
		waystoneRiftmaw = { 228.2056, 0.22 },
		sanctuaryRecall = { 228.5756, 0.26 },
		sanctuaryMenu = { 228.9856, 0.09 },
		sanctuarySheetClose = { 229.2256, 0.14 },
		clickHover = { 229.5156, 0.035 },
		confirmHover = { 229.7006, 0.035 },
		settingsHover = { 229.8856, 0.035 },
		purchasePressHover = { 230.0706, 0.035 },
		claimPressHover = { 230.2556, 0.035 },
		codeSubmitHover = { 230.4406, 0.035 },
		zoneSelectHover = { 230.6256, 0.035 },
		labRouteHover = { 230.8106, 0.035 },
		playerlistActionHover = { 230.9956, 0.035 },
		playerlistSelectHover = { 231.1805, 0.035 },
		puzzleTapHover = { 231.3655, 0.035 },
		sanctuaryClickHover = { 231.5505, 0.035 },
		equipHover = { 231.7355, 0.035 },
		dangerPressHover = { 231.9205, 0.035 },
		closeHover = { 232.1055, 0.035 },
		tickHover = { 232.2905, 0.035 },
		openHover = { 232.4755, 0.035 },
		tabSwitchHover = { 232.6605, 0.035 },
		mailHover = { 232.8454, 0.035 },
		storyHover = { 233.0304, 0.035 },
		toggleOnHover = { 233.2154, 0.035 },
		toggleOffHover = { 233.4004, 0.035 },
		lockedHover = { 233.5854, 0.035 },
		errorHover = { 233.7704, 0.035 },
		prestigeHover = { 233.9554, 0.035 },
		domainChargeHover = { 234.1404, 0.035 },
		cardEndTurnHover = { 234.3254, 0.035 },
		cardPowerHover = { 234.5103, 0.035 },
		cardEnergyHover = { 234.6953, 0.035 },
		vaultBankHover = { 234.8803, 0.035 },
		guildCreateHover = { 235.0653, 0.035 },
		guildJoinHover = { 235.2503, 0.035 },
		inviteHover = { 235.4353, 0.035 },
		travelHover = { 235.6203, 0.035 },
		gameResumeHover = { 235.8053, 0.035 },
		gamePauseHover = { 235.9902, 0.035 },
		queueStopHover = { 236.1752, 0.035 },
		queueStartHover = { 236.3602, 0.035 },
		boostHover = { 236.5452, 0.035 },
		reactorPulseHover = { 236.7302, 0.035 },
		crateOpenHover = { 236.9152, 0.035 },
		wheelStartHover = { 237.1002, 0.035 },
		rewardHover = { 237.2852, 0.035 },
		rebirthChargeHover = { 237.4702, 0.035 },
		missionClaimHover = { 237.6551, 0.035 },
		leaderboardSwitchHover = { 237.8401, 0.035 },
		adminArmHover = { 238.0251, 0.035 },
		memberRemoveHover = { 238.2101, 0.035 },
		roleChangeHover = { 238.3951, 0.035 },
		previewHover = { 238.5801, 0.035 },
		resetHover = { 238.7651, 0.035 },
		chatSendHover = { 238.9501, 0.035 },
		boostOpenHover = { 239.1351, 0.035 },
		vaultDepositHover = { 239.32, 0.035 },
		forgePress = { 239.505, 0.092 },
		corePress = { 239.747, 0.092 },
		wavePress = { 239.989, 0.092 },
		labPress = { 240.231, 0.092 },
		commandPress = { 240.473, 0.092 },
		adminPress = { 240.715, 0.092 },
		creditsPress = { 240.957, 0.092 },
		chatPress = { 241.199, 0.092 },
		continuumPress = { 241.441, 0.092 },
		missionPress = { 241.683, 0.092 },
		overviewPress = { 241.925, 0.092 },
	} :: { [string]: Region },
	Loudness = {
		hover = -14.25,
		hoverTick = -13.92,
		tick = -12.99,
		scroll = -12.39,
		sliderStep = -12.7,
		amountChange = -13.38,
		filterPick = -15.76,
		sanctuaryHover = -14.55,
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
		puzzleTap = -16.72,
		sanctuaryClick = -15.83,
		curtainOpen = -15.34,
		curtainClose = -15.49,
		confirm = -14.92,
		successChime = -14.94,
		equip = -15.46,
		itemLink = -17.67,
		tutorialStep = -17.42,
		roleChange = -16.54,
		reactorStabilize = -16.63,
		toggleOn = -15.8,
		toggleOff = -15.67,
		queueStart = -16.98,
		queueStop = -15.87,
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
		noticeClose = -14.1,
		itemUnlink = -16.53,
		reset = -18.13,
		memberRemove = -17.02,
		guildLeave = -16.62,
		gamePause = -16.98,
		gameExit = -18.41,
		page = -15.01,
		tabSwitch = -16.05,
		preview = -17.32,
		storyBeat = -16.35,
		storyPage = -17.07,
		mailRead = -16.37,
		leaderboardSwitch = -16.41,
		cardEndTurn = -15.1,
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
		requestBlocked = -14.23,
		cardBlock = -14.43,
		noticeWarning = -15.38,
		systemAlert = -12.7,
		requestTimeout = -12.79,
		adminArm = -15.89,
		mail = -14.82,
		notification = -16.49,
		noticeInfo = -15.84,
		noticeSuccess = -15.39,
		noticeSpecial = -15.25,
		boostReady = -17.76,
		reactorReady = -17.62,
		crewNudge = -13.72,
		invite = -13.75,
		chatReceive = -15.05,
		gameResume = -14.61,
		velocitySlide = -14.9,
		travel = -17.39,
		purchase = -17.84,
		purchaseResult = -18.08,
		vaultDeposit = -18.25,
		vaultBank = -18.23,
		guildDeposit = -17.69,
		collect = -16.79,
		boost = -15.08,
		boostActivate = -16.73,
		offlineCollect = -15.44,
		puzzleClear = -15.11,
		oreCollect = -17.53,
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
		bootStrike = -13.78,
		bootClang = -13.68,
		bootAnvilSplit = -13.3,
		wardenStrike = -18.94,
		wardenCrit = -12.85,
		machineInstall = -20.55,
		wheelBrake = -16.99,
		crateBrake = -20.32,
		wheel = -17.59,
		wheelStart = -19.37,
		crateOpen = -17.51,
		expeditionLaunch = -17.4,
		bootStart = -17.27,
		bootWhoosh = -17.43,
		bootFinaleFlip = -17.12,
		bootSlamAir = -17.68,
		reactor = -15.65,
		bootRumble = -15.62,
		bootFractureTail = -15.41,
		bootGravity = -15.76,
		bootAftershock = -15.86,
		reactorSurge = -12.58,
		adminExecute = -12.65,
		crateLand = -12.53,
		domainImpact = -12.87,
		bootImpact = -12.57,
		bootFinaleBang = -12.89,
		reactorChannel = -18.7,
		rebirthCharge = -18.62,
		wheelCharge = -19.11,
		crateCharge = -18.75,
		domainCharge = -19.45,
		cardPower = -19.24,
		bootTension = -18.63,
		reactorPulse = -15.47,
		domainCrack = -18.63,
		cardEnergy = -16.21,
		bootSpark = -16.19,
		bootFizz = -16.71,
		bootDebris = -19.38,
		domainBind = -16.84,
		boot = -17.51,
		wheelTick = -19.02,
		wheelSlow = -18.73,
		crateTick = -13.58,
		crateNear = -13.41,
		cardPlay = -17.96,
		cardDraw = -16.9,
		bootIgnite = -13.69,
		bootReady = -19.89,
		bootSlamCharge = -19.36,
		oreMine = -18.53,
		wardenForming = -18.14,
		wardenAwake = -11.91,
		wardenSlam = -11.81,
		wardenDefeat = -18.87,
		wardenEscape = -15.51,
		waystoneTravel = -18.62,
		regionEnter = -16.18,
		echoEquip = -17.38,
		echoTune = -15.83,
		wardenSlamCharge = -18.1,
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
		oreMineEmberite = -10.68,
		oreCollectEmberite = -12.15,
		oreMineVoidglass = -17.53,
		oreCollectVoidglass = -15.52,
		oreMineStarsteel = -15.49,
		oreCollectStarsteel = -14.52,
		waystoneHeart = -14.6,
		waystoneEmberreach = -13.67,
		waystoneHollows = -9.73,
		waystoneSpire = -13.92,
		waystoneRiftmaw = -13.91,
		sanctuaryRecall = -14.52,
		sanctuaryMenu = -12.41,
		sanctuarySheetClose = -11.73,
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
		puzzleTapHover = -13.76,
		sanctuaryClickHover = -13.55,
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
		cardEndTurnHover = -13.55,
		cardPowerHover = -13.75,
		cardEnergyHover = -13.82,
		vaultBankHover = -13.5,
		guildCreateHover = -13.76,
		guildJoinHover = -13.55,
		inviteHover = -13.75,
		travelHover = -13.82,
		gameResumeHover = -13.5,
		gamePauseHover = -13.76,
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
