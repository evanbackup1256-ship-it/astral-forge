--!strict

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
		error("SharedData: unknown module " .. tostring(name), 2)
	end
	if __loading[name] then
		error("SharedData: cyclic require of member " .. name, 2)
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

__defs["AssetManifest"] = function()
	type Region = { number }

	local Manifest = {}

	Manifest.SoundSheet = {
		Id = 102790009136082,
		Length = 258.574,
		Regions = {
			hover = { 0.15, 0.116 },
			hoverTick = { 0.416, 0.084 },
			tick = { 0.65, 0.049 },
			scroll = { 0.849, 0.056 },
			sliderStep = { 1.055, 0.042 },
			amountChange = { 1.247, 0.0392 },
			filterPick = { 1.4362, 0.056 },
			sanctuaryHover = { 1.6422, 0.112 },
			navHover = { 1.9042, 0.1 },
			click = { 2.1542, 0.146 },
			settings = { 2.4502, 0.14 },
			purchasePress = { 2.7402, 0.14 },
			claimPress = { 3.0302, 0.1396 },
			codeSubmit = { 3.3198, 0.1398 },
			zoneSelect = { 3.6097, 0.14 },
			labRoute = { 3.8997, 0.14 },
			playerlistAction = { 4.1897, 0.14 },
			playerlistSelect = { 4.4797, 0.1377 },
			puzzleTap = { 4.7674, 0.1276 },
			sanctuaryClick = { 5.045, 0.1399 },
			curtainOpen = { 5.3349, 1.182 },
			curtainClose = { 6.6669, 1.142 },
			confirm = { 7.9589, 0.8615 },
			successChime = { 8.9704, 0.7339 },
			equip = { 9.8543, 0.7715 },
			itemLink = { 10.7758, 0.623 },
			tutorialStep = { 11.5488, 0.7051 },
			roleChange = { 12.4039, 0.8496 },
			reactorStabilize = { 13.4035, 0.9596 },
			toggleOn = { 14.5131, 0.16 },
			toggleOff = { 14.8231, 0.16 },
			queueStart = { 15.1331, 0.24 },
			queueStop = { 15.5231, 0.16 },
			open = { 15.8331, 0.7169 },
			modalOpen = { 16.7, 0.722 },
			filterOpen = { 17.572, 0.6477 },
			boostOpen = { 18.3697, 0.7217 },
			offlineOpen = { 19.2414, 0.722 },
			playerlistOpen = { 20.1134, 0.646 },
			story = { 20.9094, 0.722 },
			storyOpen = { 21.7814, 0.722 },
			crate = { 22.6534, 0.722 },
			close = { 23.5254, 0.662 },
			modalDismiss = { 24.3373, 0.592 },
			purchaseExit = { 25.0793, 0.6186 },
			playerlistClose = { 25.8479, 0.662 },
			noticeClose = { 26.6599, 0.6135 },
			itemUnlink = { 27.4234, 0.662 },
			reset = { 28.2354, 0.602 },
			memberRemove = { 28.9874, 0.662 },
			guildLeave = { 29.7994, 0.662 },
			gamePause = { 30.6114, 0.6599 },
			gameExit = { 31.4213, 0.602 },
			page = { 32.1733, 0.372 },
			tabSwitch = { 32.6953, 0.354 },
			preview = { 33.1993, 0.412 },
			storyBeat = { 33.7613, 0.372 },
			storyPage = { 34.2833, 0.372 },
			mailRead = { 34.8053, 0.372 },
			leaderboardSwitch = { 35.3273, 0.354 },
			cardEndTurn = { 35.8312, 0.372 },
			modalPop = { 36.3532, 0.08 },
			sliderCommit = { 36.5832, 0.07 },
			inputClear = { 36.8032, 0.07 },
			chatSend = { 37.0232, 0.455 },
			inputFocus = { 37.6283, 0.02 },
			error = { 37.7983, 0.592 },
			errorBuzz = { 38.5403, 0.71 },
			noticeError = { 39.4002, 0.5821 },
			dangerPress = { 40.1323, 0.4336 },
			locked = { 40.7159, 0.21 },
			requestBlocked = { 41.0759, 0.21 },
			cardBlock = { 41.4359, 0.21 },
			noticeWarning = { 41.7959, 0.7843 },
			systemAlert = { 42.7302, 0.862 },
			requestTimeout = { 43.7422, 0.862 },
			adminArm = { 44.7542, 0.7449 },
			mail = { 45.6492, 1.0813 },
			notification = { 46.8805, 0.8914 },
			noticeInfo = { 47.9219, 0.7937 },
			noticeSuccess = { 48.8656, 0.9066 },
			noticeSpecial = { 49.9223, 1.8273 },
			boostReady = { 51.8996, 0.9263 },
			reactorReady = { 52.976, 0.7375 },
			crewNudge = { 53.8635, 0.612 },
			invite = { 54.6255, 0.5808 },
			chatReceive = { 55.3563, 0.612 },
			gameResume = { 56.1183, 0.722 },
			velocitySlide = { 56.9903, 0.862 },
			travel = { 58.0023, 1.012 },
			purchase = { 59.1643, 0.6257 },
			purchaseResult = { 59.94, 0.5742 },
			vaultDeposit = { 60.6642, 0.6477 },
			vaultBank = { 61.4618, 0.6247 },
			guildDeposit = { 62.2365, 0.6778 },
			collect = { 63.0644, 0.8909 },
			boost = { 64.1053, 0.8283 },
			boostActivate = { 65.0836, 0.8659 },
			offlineCollect = { 66.0995, 0.9968 },
			puzzleClear = { 67.2463, 0.8141 },
			oreCollect = { 68.2103, 0.7881 },
			reward = { 69.1484, 2.1409 },
			codeReward = { 71.4393, 1.6946 },
			tutorialFinish = { 73.2839, 1.8705 },
			domainReward = { 75.3044, 1.9866 },
			wheelLand = { 77.441, 1.5242 },
			unlock = { 79.1152, 1.7267 },
			researchUnlock = { 80.9919, 1.5673 },
			achievementClaim = { 82.7092, 1.7686 },
			seasonClaim = { 84.6278, 1.6384 },
			comboMilestone = { 86.4163, 1.6132 },
			discovery = { 88.1794, 1.6436 },
			zoneUnlock = { 89.973, 1.8092 },
			guildCreate = { 91.9322, 1.5137 },
			echoCapture = { 93.5959, 1.8834 },
			storyReveal = { 95.6293, 1.9675 },
			missionClaim = { 97.7468, 1.1684 },
			dailyClaim = { 99.0652, 1.0257 },
			timedClaim = { 100.2409, 1.1425 },
			mailClaim = { 101.5334, 1.0252 },
			crateClaim = { 102.7085, 1.0375 },
			echoClaim = { 103.8961, 1.0602 },
			guildJoin = { 105.1062, 1.0286 },
			expeditionReturn = { 106.2848, 1.1433 },
			prestige = { 107.5781, 4.0907 },
			rebirthBloom = { 111.8188, 3.9206 },
			crateRare = { 115.8894, 3.8797 },
			salvage = { 119.9191, 0.9537 },
			salvageCrunch = { 121.0229, 0.8393 },
			echoDismantle = { 122.0122, 1.0821 },
			autoForge = { 123.2443, 0.8313 },
			bootStrike = { 124.2256, 0.9657 },
			bootClang = { 125.3413, 0.8437 },
			bootAnvilSplit = { 126.335, 1.1455 },
			wardenStrike = { 127.6305, 0.6598 },
			wardenCrit = { 128.4403, 1.0989 },
			machineInstall = { 129.6892, 0.8055 },
			wheelBrake = { 130.6447, 0.931 },
			crateBrake = { 131.7257, 0.8182 },
			wheel = { 132.6939, 0.812 },
			wheelStart = { 133.6559, 1.1665 },
			crateOpen = { 134.9724, 0.942 },
			expeditionLaunch = { 136.0644, 1.112 },
			bootStart = { 137.3263, 0.962 },
			bootWhoosh = { 138.4383, 1.012 },
			bootFinaleFlip = { 139.6003, 0.862 },
			bootSlamAir = { 140.6123, 1.162 },
			reactor = { 141.9243, 1.2 },
			bootRumble = { 143.2743, 1.4 },
			bootFractureTail = { 144.8243, 1.6 },
			bootGravity = { 146.5743, 1.5 },
			bootAftershock = { 148.2243, 1.3 },
			reactorSurge = { 149.6743, 1.7988 },
			adminExecute = { 151.6232, 1.8074 },
			crateLand = { 153.5806, 1.8215 },
			domainImpact = { 155.5521, 1.7422 },
			bootImpact = { 157.4444, 1.777 },
			bootFinaleBang = { 159.3714, 1.8544 },
			reactorChannel = { 161.3758, 1.6466 },
			rebirthCharge = { 163.1724, 1.862 },
			wheelCharge = { 165.1844, 1.462 },
			crateCharge = { 166.7963, 1.562 },
			domainCharge = { 168.5083, 1.962 },
			cardPower = { 170.6203, 1.3555 },
			bootTension = { 172.1258, 1.712 },
			reactorPulse = { 173.9878, 0.518 },
			domainCrack = { 174.6558, 0.5265 },
			cardEnergy = { 175.3323, 0.5173 },
			bootSpark = { 175.9996, 0.5309 },
			bootFizz = { 176.6805, 0.5377 },
			bootDebris = { 177.3681, 0.5204 },
			domainBind = { 178.0385, 2.6862 },
			boot = { 180.8747, 2.6663 },
			wheelTick = { 183.691, 0.055 },
			wheelSlow = { 183.896, 0.055 },
			crateTick = { 184.101, 0.03 },
			crateNear = { 184.281, 0.03 },
			cardPlay = { 184.461, 0.05 },
			cardDraw = { 184.661, 0.05 },
			bootIgnite = { 184.861, 1.8256 },
			bootReady = { 186.8367, 1.8383 },
			bootSlamCharge = { 188.825, 2.112 },
			oreMine = { 191.087, 0.9218 },
			wardenForming = { 192.1588, 4.612 },
			wardenAwake = { 196.9208, 2.962 },
			wardenSlam = { 200.0328, 3.362 },
			wardenDefeat = { 203.5448, 4.5411 },
			wardenEscape = { 208.2359, 3.212 },
			waystoneTravel = { 211.5979, 2.3711 },
			regionEnter = { 214.119, 3.0588 },
			echoEquip = { 217.3278, 0.8345 },
			echoTune = { 218.3123, 0.056 },
			wardenSlamCharge = { 218.5183, 2.412 },
			navOpenOverview = { 221.0803, 0.2 },
			navHoverOverview = { 221.4303, 0.07 },
			navOpenWorkshop = { 221.6503, 0.2 },
			navHoverWorkshop = { 222.0003, 0.07 },
			navOpenInventory = { 222.2203, 0.2 },
			navHoverInventory = { 222.5703, 0.07 },
			navOpenResearch = { 222.7903, 0.2 },
			navHoverResearch = { 223.1403, 0.07 },
			navOpenShop = { 223.3603, 0.2 },
			navHoverShop = { 223.7103, 0.07 },
			navOpenSettings = { 223.9303, 0.2 },
			navHoverSettings = { 224.2803, 0.07 },
			navOpenWorlds = { 224.5003, 0.1993 },
			navHoverWorlds = { 224.8495, 0.07 },
			navOpenMissions = { 225.0695, 0.2 },
			navHoverMissions = { 225.4195, 0.07 },
			navOpenRewards = { 225.6395, 0.2 },
			navHoverRewards = { 225.9895, 0.07 },
			navOpenBoosts = { 226.2095, 0.2 },
			navHoverBoosts = { 226.5595, 0.07 },
			navOpenStarGrid = { 226.7795, 0.2 },
			navHoverStarGrid = { 227.1295, 0.07 },
			navOpenEchoes = { 227.3495, 0.2 },
			navHoverEchoes = { 227.6995, 0.07 },
			navOpenContinuum = { 227.9195, 0.2 },
			navHoverContinuum = { 228.2695, 0.07 },
			navOpenLab = { 228.4895, 0.2 },
			navHoverLab = { 228.8395, 0.07 },
			navOpenAnomaly = { 229.0595, 0.2 },
			navHoverAnomaly = { 229.4095, 0.07 },
			navOpenWheel = { 229.6295, 0.1997 },
			navHoverWheel = { 229.9792, 0.07 },
			navOpenCommand = { 230.1992, 0.2 },
			navHoverCommand = { 230.5492, 0.07 },
			navOpenStory = { 230.7692, 0.2 },
			navHoverStory = { 231.1192, 0.07 },
			navOpenMail = { 231.3392, 0.2 },
			navHoverMail = { 231.6892, 0.07 },
			navOpenChat = { 231.9092, 0.2 },
			navHoverChat = { 232.2592, 0.07 },
			navOpenCrew = { 232.4792, 0.2 },
			navHoverCrew = { 232.8292, 0.07 },
			navOpenMilestones = { 233.0492, 0.2 },
			navHoverMilestones = { 233.3992, 0.07 },
			navOpenConvergence = { 233.6192, 0.2 },
			navHoverConvergence = { 233.9692, 0.07 },
			navOpenGuild = { 234.1892, 0.2 },
			navHoverGuild = { 234.5392, 0.07 },
			navOpenLeaderboards = { 234.7592, 0.1991 },
			navHoverLeaderboards = { 235.1083, 0.07 },
			navOpenTrade = { 235.3283, 0.2 },
			navHoverTrade = { 235.6783, 0.07 },
			navOpenCredits = { 235.8983, 0.2 },
			navHoverCredits = { 236.2483, 0.07 },
			navOpenAdmin = { 236.4683, 0.2 },
			navHoverAdmin = { 236.8183, 0.07 },
			navOpenForgePath = { 237.0383, 0.2 },
			navHoverForgePath = { 237.3883, 0.07 },
			navOpenFoundry = { 237.6083, 0.2 },
			navHoverFoundry = { 237.9583, 0.07 },
			oreMineEmberite = { 238.1783, 0.32 },
			oreCollectEmberite = { 238.6483, 0.36 },
			oreMineVoidglass = { 239.1583, 0.3063 },
			oreCollectVoidglass = { 239.6146, 0.3525 },
			oreMineStarsteel = { 240.1171, 0.32 },
			oreCollectStarsteel = { 240.5871, 0.36 },
			waystoneHeart = { 241.0971, 0.2174 },
			waystoneEmberreach = { 241.4645, 0.22 },
			waystoneHollows = { 241.8345, 0.22 },
			waystoneSpire = { 242.2045, 0.22 },
			waystoneRiftmaw = { 242.5745, 0.22 },
			sanctuaryRecall = { 242.9445, 0.26 },
			sanctuaryMenu = { 243.3545, 0.09 },
			sanctuarySheetClose = { 243.5945, 0.14 },
			clickHover = { 243.8845, 0.065 },
			confirmHover = { 244.0995, 0.065 },
			settingsHover = { 244.3145, 0.065 },
			purchasePressHover = { 244.5295, 0.065 },
			claimPressHover = { 244.7444, 0.065 },
			codeSubmitHover = { 244.9594, 0.065 },
			zoneSelectHover = { 245.1744, 0.065 },
			labRouteHover = { 245.3894, 0.065 },
			playerlistActionHover = { 245.6044, 0.065 },
			playerlistSelectHover = { 245.8194, 0.065 },
			puzzleTapHover = { 246.0344, 0.065 },
			sanctuaryClickHover = { 246.2494, 0.065 },
			equipHover = { 246.4644, 0.065 },
			dangerPressHover = { 246.6793, 0.065 },
			closeHover = { 246.8943, 0.065 },
			tickHover = { 247.1093, 0.065 },
			openHover = { 247.3243, 0.065 },
			tabSwitchHover = { 247.5393, 0.065 },
			mailHover = { 247.7543, 0.065 },
			storyHover = { 247.9693, 0.065 },
			toggleOnHover = { 248.1843, 0.065 },
			toggleOffHover = { 248.3993, 0.065 },
			lockedHover = { 248.6142, 0.065 },
			errorHover = { 248.8292, 0.065 },
			prestigeHover = { 249.0442, 0.065 },
			domainChargeHover = { 249.2592, 0.065 },
			cardEndTurnHover = { 249.4742, 0.065 },
			cardPowerHover = { 249.6892, 0.065 },
			cardEnergyHover = { 249.9042, 0.065 },
			vaultBankHover = { 250.1192, 0.065 },
			guildCreateHover = { 250.3341, 0.065 },
			guildJoinHover = { 250.5491, 0.065 },
			inviteHover = { 250.7641, 0.065 },
			travelHover = { 250.9791, 0.065 },
			gameResumeHover = { 251.1941, 0.065 },
			gamePauseHover = { 251.4091, 0.065 },
			queueStopHover = { 251.6241, 0.065 },
			queueStartHover = { 251.8391, 0.065 },
			boostHover = { 252.0541, 0.065 },
			reactorPulseHover = { 252.269, 0.065 },
			crateOpenHover = { 252.484, 0.065 },
			wheelStartHover = { 252.699, 0.065 },
			rewardHover = { 252.914, 0.065 },
			rebirthChargeHover = { 253.129, 0.065 },
			missionClaimHover = { 253.344, 0.065 },
			leaderboardSwitchHover = { 253.559, 0.065 },
			adminArmHover = { 253.774, 0.065 },
			memberRemoveHover = { 253.989, 0.065 },
			roleChangeHover = { 254.2039, 0.065 },
			previewHover = { 254.4189, 0.065 },
			resetHover = { 254.6339, 0.065 },
			chatSendHover = { 254.8489, 0.065 },
			boostOpenHover = { 255.0639, 0.065 },
			vaultDepositHover = { 255.2789, 0.065 },
			forgePress = { 255.4939, 0.13 },
			corePress = { 255.7739, 0.13 },
			wavePress = { 256.0539, 0.13 },
			labPress = { 256.3339, 0.13 },
			commandPress = { 256.6139, 0.13 },
			adminPress = { 256.8939, 0.13 },
			creditsPress = { 257.1739, 0.13 },
			chatPress = { 257.4539, 0.13 },
			continuumPress = { 257.7339, 0.13 },
			missionPress = { 258.0139, 0.13 },
			overviewPress = { 258.2939, 0.13 },
		} :: { [string]: Region },
		Loudness = {
			hover = -12.73,
			hoverTick = -17.14,
			tick = -17.38,
			scroll = -16.25,
			sliderStep = -16.65,
			amountChange = -15.88,
			filterPick = -16.23,
			sanctuaryHover = -16.32,
			navHover = -12.53,
			click = -16.62,
			settings = -15.76,
			purchasePress = -16.83,
			claimPress = -16.53,
			codeSubmit = -16.61,
			zoneSelect = -16.32,
			labRoute = -17.83,
			playerlistAction = -16.02,
			playerlistSelect = -17.38,
			puzzleTap = -16.72,
			sanctuaryClick = -17.6,
			curtainOpen = -17.13,
			curtainClose = -17.61,
			confirm = -17.24,
			successChime = -15.79,
			equip = -15.67,
			itemLink = -17.54,
			tutorialStep = -17.42,
			roleChange = -16.59,
			reactorStabilize = -16.69,
			toggleOn = -13.79,
			toggleOff = -13.69,
			queueStart = -16.98,
			queueStop = -15.82,
			open = -15,
			modalOpen = -14.67,
			filterOpen = -14.65,
			boostOpen = -14.89,
			offlineOpen = -14.41,
			playerlistOpen = -14.98,
			story = -14.34,
			storyOpen = -15,
			crate = -14.28,
			close = -16.77,
			modalDismiss = -16.79,
			purchaseExit = -16.72,
			playerlistClose = -16.6,
			noticeClose = -16.34,
			itemUnlink = -16.53,
			reset = -18.13,
			memberRemove = -17.02,
			guildLeave = -16.62,
			gamePause = -16.98,
			gameExit = -18.41,
			page = -16.82,
			tabSwitch = -17.76,
			preview = -16.57,
			storyBeat = -18.44,
			storyPage = -17.56,
			mailRead = -15.06,
			leaderboardSwitch = -18.3,
			cardEndTurn = -17.66,
			modalPop = -11.05,
			sliderCommit = -11,
			inputClear = -13.47,
			chatSend = -17.44,
			inputFocus = -13.68,
			error = -12.23,
			errorBuzz = -11.73,
			noticeError = -11.94,
			dangerPress = -14.23,
			locked = -14.65,
			requestBlocked = -14.28,
			cardBlock = -14.8,
			noticeWarning = -12.03,
			systemAlert = -12.7,
			requestTimeout = -12.79,
			adminArm = -15.89,
			mail = -14.8,
			notification = -16.48,
			noticeInfo = -15.03,
			noticeSuccess = -16.6,
			noticeSpecial = -18.47,
			boostReady = -17.85,
			reactorReady = -17.44,
			crewNudge = -13.72,
			invite = -13.75,
			chatReceive = -12.61,
			gameResume = -14.61,
			velocitySlide = -17.46,
			travel = -18.14,
			purchase = -17.87,
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
			navOpenOverview = -13.23,
			navHoverOverview = -11.27,
			navOpenWorkshop = -15.56,
			navHoverWorkshop = -17.28,
			navOpenInventory = -12.6,
			navHoverInventory = -13.43,
			navOpenResearch = -10.59,
			navHoverResearch = -11.78,
			navOpenShop = -17.2,
			navHoverShop = -13.97,
			navOpenSettings = -15.17,
			navHoverSettings = -13.51,
			navOpenWorlds = -14.44,
			navHoverWorlds = -12.35,
			navOpenMissions = -9.74,
			navHoverMissions = -10.97,
			navOpenRewards = -14.26,
			navHoverRewards = -12.78,
			navOpenBoosts = -13.3,
			navHoverBoosts = -11.22,
			navOpenStarGrid = -15.28,
			navHoverStarGrid = -16.98,
			navOpenEchoes = -12.57,
			navHoverEchoes = -13.39,
			navOpenContinuum = -10.58,
			navHoverContinuum = -11.67,
			navOpenLab = -17.14,
			navHoverLab = -14.09,
			navOpenAnomaly = -15.26,
			navHoverAnomaly = -13.79,
			navOpenWheel = -14.56,
			navHoverWheel = -12.6,
			navOpenCommand = -9.73,
			navHoverCommand = -11.31,
			navOpenStory = -14.34,
			navHoverStory = -12.81,
			navOpenMail = -12.53,
			navHoverMail = -11.24,
			navOpenChat = -15.39,
			navHoverChat = -16.69,
			navOpenCrew = -12.56,
			navHoverCrew = -13.49,
			navOpenMilestones = -10.59,
			navHoverMilestones = -11.52,
			navOpenConvergence = -16.36,
			navHoverConvergence = -14.21,
			navOpenGuild = -15.17,
			navHoverGuild = -12.65,
			navOpenLeaderboards = -14.48,
			navHoverLeaderboards = -12.45,
			navOpenTrade = -9.73,
			navHoverTrade = -11.16,
			navOpenCredits = -14.32,
			navHoverCredits = -12.81,
			navOpenAdmin = -12.52,
			navHoverAdmin = -11.17,
			navOpenForgePath = -15.03,
			navHoverForgePath = -17.07,
			navOpenFoundry = -12.59,
			navHoverFoundry = -13.75,
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
			clickHover = -14.29,
			confirmHover = -16.8,
			settingsHover = -11.55,
			purchasePressHover = -13.49,
			claimPressHover = -9.89,
			codeSubmitHover = -11.36,
			zoneSelectHover = -16.9,
			labRouteHover = -14.43,
			playerlistActionHover = -14.62,
			playerlistSelectHover = -13.42,
			puzzleTapHover = -13.08,
			sanctuaryClickHover = -12.53,
			equipHover = -9.97,
			dangerPressHover = -12.52,
			closeHover = -13.58,
			tickHover = -12.56,
			openHover = -12.33,
			tabSwitchHover = -11.04,
			mailHover = -14.73,
			storyHover = -17.05,
			toggleOnHover = -11.68,
			toggleOffHover = -13.74,
			lockedHover = -9.79,
			errorHover = -11.59,
			prestigeHover = -17.09,
			domainChargeHover = -13.37,
			cardEndTurnHover = -14.76,
			cardPowerHover = -12.51,
			cardEnergyHover = -12.72,
			vaultBankHover = -12.51,
			guildCreateHover = -9.99,
			guildJoinHover = -12.14,
			inviteHover = -12.99,
			travelHover = -12.54,
			gameResumeHover = -12.45,
			gamePauseHover = -11.06,
			queueStopHover = -14.22,
			queueStartHover = -16.84,
			boostHover = -11.6,
			reactorPulseHover = -14,
			crateOpenHover = -9.85,
			wheelStartHover = -11.97,
			rewardHover = -17.08,
			rebirthChargeHover = -13.01,
			missionClaimHover = -14.34,
			leaderboardSwitchHover = -13.7,
			adminArmHover = -13.05,
			memberRemoveHover = -12.59,
			roleChangeHover = -9.95,
			previewHover = -10.88,
			resetHover = -13.65,
			chatSendHover = -12.48,
			boostOpenHover = -12.64,
			vaultDepositHover = -11.2,
			forgePress = -14.78,
			corePress = -17.78,
			wavePress = -12.37,
			labPress = -14.54,
			commandPress = -10.38,
			adminPress = -11.93,
			creditsPress = -17.44,
			chatPress = -14.36,
			continuumPress = -14.31,
			missionPress = -14.23,
			overviewPress = -13.95,
		} :: { [string]: number },
	}

	Manifest.SoundSheetPrevious = {
		Id = 81719045964153,
		Length = 308.235,
		Regions = {
			hover = { 0.3, 0.126 },
			hoverTick = { 0.726, 0.084 },
			tick = { 1.11, 0.049 },
			scroll = { 1.459, 0.056 },
			sliderStep = { 1.815, 0.042 },
			amountChange = { 2.157, 0.0392 },
			filterPick = { 2.4962, 0.056 },
			sanctuaryHover = { 2.8522, 0.112 },
			navHover = { 3.2642, 0.098 },
			click = { 3.6622, 0.1396 },
			settings = { 4.1019, 0.14 },
			purchasePress = { 4.5419, 0.14 },
			claimPress = { 4.9819, 0.1396 },
			codeSubmit = { 5.4215, 0.1398 },
			zoneSelect = { 5.8613, 0.14 },
			labRoute = { 6.3013, 0.14 },
			playerlistAction = { 6.7413, 0.14 },
			playerlistSelect = { 7.1813, 0.1377 },
			puzzleTap = { 7.619, 0.1276 },
			sanctuaryClick = { 8.0467, 0.1399 },
			curtainOpen = { 8.4866, 1.182 },
			curtainClose = { 9.9686, 1.142 },
			confirm = { 11.4106, 0.8615 },
			successChime = { 12.572, 0.7339 },
			equip = { 13.6059, 0.7715 },
			itemLink = { 14.6775, 0.623 },
			tutorialStep = { 15.6005, 0.7051 },
			roleChange = { 16.6056, 0.8496 },
			reactorStabilize = { 17.7552, 0.9596 },
			toggleOn = { 19.0148, 0.16 },
			toggleOff = { 19.4748, 0.16 },
			queueStart = { 19.9348, 0.24 },
			queueStop = { 20.4748, 0.16 },
			open = { 20.9348, 0.7169 },
			modalOpen = { 21.9517, 0.722 },
			filterOpen = { 22.9737, 0.6477 },
			boostOpen = { 23.9214, 0.7217 },
			offlineOpen = { 24.9431, 0.722 },
			playerlistOpen = { 25.9651, 0.646 },
			story = { 26.911, 0.722 },
			storyOpen = { 27.933, 0.722 },
			crate = { 28.955, 0.722 },
			close = { 29.977, 0.662 },
			modalDismiss = { 30.939, 0.592 },
			purchaseExit = { 31.831, 0.6186 },
			playerlistClose = { 32.7495, 0.662 },
			noticeClose = { 33.7115, 0.6135 },
			itemUnlink = { 34.6251, 0.662 },
			reset = { 35.5871, 0.602 },
			memberRemove = { 36.489, 0.662 },
			guildLeave = { 37.451, 0.662 },
			gamePause = { 38.413, 0.6599 },
			gameExit = { 39.3729, 0.602 },
			page = { 40.2749, 0.372 },
			tabSwitch = { 40.9469, 0.322 },
			preview = { 41.5689, 0.412 },
			storyBeat = { 42.2809, 0.372 },
			storyPage = { 42.9529, 0.372 },
			mailRead = { 43.6249, 0.372 },
			leaderboardSwitch = { 44.2969, 0.322 },
			cardEndTurn = { 44.9189, 0.372 },
			modalPop = { 45.5909, 0.08 },
			sliderCommit = { 45.9709, 0.07 },
			inputClear = { 46.3409, 0.07 },
			chatSend = { 46.7109, 0.455 },
			inputFocus = { 47.4659, 0.02 },
			error = { 47.7859, 0.592 },
			errorBuzz = { 48.6779, 0.71 },
			noticeError = { 49.6879, 0.5821 },
			dangerPress = { 50.57, 0.4336 },
			locked = { 51.3036, 0.21 },
			requestBlocked = { 51.8136, 0.21 },
			cardBlock = { 52.3236, 0.21 },
			noticeWarning = { 52.8336, 0.7843 },
			systemAlert = { 53.9179, 0.862 },
			requestTimeout = { 55.0799, 0.862 },
			adminArm = { 56.2419, 0.7449 },
			mail = { 57.2868, 1.0814 },
			notification = { 58.6682, 0.8914 },
			noticeInfo = { 59.8596, 0.7937 },
			noticeSuccess = { 60.9533, 0.9066 },
			noticeSpecial = { 62.16, 1.8273 },
			boostReady = { 64.2873, 0.9263 },
			reactorReady = { 65.5137, 0.7375 },
			crewNudge = { 66.5512, 0.612 },
			invite = { 67.4632, 0.5808 },
			chatReceive = { 68.344, 0.612 },
			gameResume = { 69.256, 0.722 },
			velocitySlide = { 70.278, 0.862 },
			travel = { 71.44, 1.012 },
			purchase = { 72.752, 0.6257 },
			purchaseResult = { 73.6776, 0.5742 },
			vaultDeposit = { 74.5519, 0.6477 },
			vaultBank = { 75.4995, 0.6247 },
			guildDeposit = { 76.4242, 0.6778 },
			collect = { 77.402, 0.8909 },
			boost = { 78.5929, 0.8283 },
			boostActivate = { 79.7213, 0.8659 },
			offlineCollect = { 80.8871, 0.9968 },
			puzzleClear = { 82.1839, 0.8141 },
			oreCollect = { 83.298, 0.7881 },
			reward = { 84.3861, 2.1409 },
			codeReward = { 86.827, 1.6946 },
			tutorialFinish = { 88.8216, 1.8705 },
			domainReward = { 90.9921, 1.9866 },
			wheelLand = { 93.2787, 1.7486 },
			unlock = { 95.3273, 1.7335 },
			researchUnlock = { 97.3608, 1.5673 },
			achievementClaim = { 99.2281, 1.7686 },
			seasonClaim = { 101.2967, 1.6384 },
			comboMilestone = { 103.2351, 1.6132 },
			discovery = { 105.1483, 1.6436 },
			zoneUnlock = { 107.0919, 1.8092 },
			guildCreate = { 109.2011, 1.5137 },
			echoCapture = { 111.0148, 1.8834 },
			storyReveal = { 113.1982, 1.9675 },
			missionClaim = { 115.4657, 1.1684 },
			dailyClaim = { 116.9341, 1.0257 },
			timedClaim = { 118.2598, 1.1425 },
			mailClaim = { 119.7022, 1.0252 },
			crateClaim = { 121.0274, 1.0375 },
			echoClaim = { 122.365, 1.0602 },
			guildJoin = { 123.7251, 1.0286 },
			expeditionReturn = { 125.0537, 1.1433 },
			prestige = { 126.497, 4.0907 },
			rebirthBloom = { 130.8877, 3.9206 },
			crateRare = { 135.1083, 3.8797 },
			salvage = { 139.288, 0.9537 },
			salvageCrunch = { 140.5417, 0.8393 },
			echoDismantle = { 141.6811, 1.0821 },
			autoForge = { 143.0632, 0.8313 },
			bootStrike = { 144.1945, 0.9657 },
			bootClang = { 145.4602, 0.8437 },
			bootAnvilSplit = { 146.6039, 1.1455 },
			wardenStrike = { 148.0494, 0.6598 },
			wardenCrit = { 149.0092, 1.0989 },
			machineInstall = { 150.408, 0.8055 },
			wheelBrake = { 151.5136, 0.8 },
			crateBrake = { 152.6136, 0.8182 },
			wheel = { 153.7318, 0.812 },
			wheelStart = { 154.8438, 0.912 },
			crateOpen = { 156.0558, 0.9368 },
			expeditionLaunch = { 157.2926, 1.112 },
			bootStart = { 158.7046, 0.962 },
			bootWhoosh = { 159.9666, 1.0096 },
			bootFinaleFlip = { 161.2762, 0.8448 },
			bootSlamAir = { 162.421, 1.162 },
			reactor = { 163.883, 1.2 },
			bootRumble = { 165.383, 1.4 },
			bootFractureTail = { 167.083, 1.6 },
			bootGravity = { 168.983, 1.5 },
			bootAftershock = { 170.783, 1.3 },
			reactorSurge = { 172.383, 1.7988 },
			adminExecute = { 174.4819, 1.8074 },
			crateLand = { 176.5892, 1.8216 },
			domainImpact = { 178.7108, 1.7422 },
			bootImpact = { 180.753, 1.777 },
			bootFinaleBang = { 182.83, 1.8544 },
			reactorChannel = { 184.9844, 1.6466 },
			rebirthCharge = { 186.931, 1.862 },
			wheelCharge = { 189.093, 1.462 },
			crateCharge = { 190.855, 1.562 },
			domainCharge = { 192.717, 1.962 },
			cardPower = { 194.979, 1.362 },
			bootTension = { 196.641, 1.7095 },
			reactorPulse = { 198.6505, 0.4933 },
			domainCrack = { 199.4437, 0.5328 },
			cardEnergy = { 200.2766, 0.5035 },
			bootSpark = { 201.0801, 0.5283 },
			bootFizz = { 201.9084, 0.541 },
			bootDebris = { 202.7494, 0.5163 },
			domainBind = { 203.5657, 2.6862 },
			boot = { 206.5519, 2.6663 },
			wheelTick = { 209.5182, 0.03 },
			wheelSlow = { 209.8482, 0.03 },
			crateTick = { 210.1782, 0.03 },
			crateNear = { 210.5082, 0.03 },
			cardPlay = { 210.8382, 0.05 },
			cardDraw = { 211.1882, 0.05 },
			bootIgnite = { 211.5382, 1.8341 },
			bootReady = { 213.6723, 1.8383 },
			bootSlamCharge = { 215.8106, 2.112 },
			oreMine = { 218.2226, 0.9218 },
			wardenForming = { 219.4445, 4.612 },
			wardenAwake = { 224.3565, 2.962 },
			wardenSlam = { 227.6185, 3.362 },
			wardenDefeat = { 231.2805, 4.5411 },
			wardenEscape = { 236.1216, 3.212 },
			waystoneTravel = { 239.6336, 2.3711 },
			regionEnter = { 242.3046, 3.0588 },
			echoEquip = { 245.6634, 0.8345 },
			echoTune = { 246.7979, 0.056 },
			wardenSlamCharge = { 247.1539, 2.412 },
			navOpenOverview = { 249.8659, 0.2 },
			navHoverOverview = { 250.3659, 0.07 },
			navOpenWorkshop = { 250.7359, 0.2 },
			navHoverWorkshop = { 251.2359, 0.07 },
			navOpenInventory = { 251.6059, 0.2 },
			navHoverInventory = { 252.1059, 0.07 },
			navOpenResearch = { 252.4759, 0.2 },
			navHoverResearch = { 252.9759, 0.07 },
			navOpenShop = { 253.3459, 0.2 },
			navHoverShop = { 253.8459, 0.07 },
			navOpenSettings = { 254.2159, 0.2 },
			navHoverSettings = { 254.7159, 0.07 },
			navOpenWorlds = { 255.0859, 0.2 },
			navHoverWorlds = { 255.5859, 0.07 },
			navOpenMissions = { 255.9559, 0.2 },
			navHoverMissions = { 256.4559, 0.07 },
			navOpenRewards = { 256.8259, 0.2 },
			navHoverRewards = { 257.3259, 0.07 },
			navOpenBoosts = { 257.6959, 0.2 },
			navHoverBoosts = { 258.1959, 0.07 },
			navOpenStarGrid = { 258.5659, 0.2 },
			navHoverStarGrid = { 259.0659, 0.07 },
			navOpenEchoes = { 259.4359, 0.2 },
			navHoverEchoes = { 259.9359, 0.07 },
			navOpenContinuum = { 260.3059, 0.2 },
			navHoverContinuum = { 260.8059, 0.07 },
			navOpenLab = { 261.1759, 0.2 },
			navHoverLab = { 261.6759, 0.07 },
			navOpenAnomaly = { 262.0459, 0.2 },
			navHoverAnomaly = { 262.5459, 0.07 },
			navOpenWheel = { 262.9159, 0.2 },
			navHoverWheel = { 263.4159, 0.07 },
			navOpenCommand = { 263.7859, 0.2 },
			navHoverCommand = { 264.2859, 0.07 },
			navOpenStory = { 264.6559, 0.2 },
			navHoverStory = { 265.1559, 0.07 },
			navOpenMail = { 265.5259, 0.2 },
			navHoverMail = { 266.0259, 0.07 },
			navOpenChat = { 266.3959, 0.2 },
			navHoverChat = { 266.8959, 0.07 },
			navOpenCrew = { 267.2659, 0.2 },
			navHoverCrew = { 267.7659, 0.07 },
			navOpenMilestones = { 268.1359, 0.2 },
			navHoverMilestones = { 268.6359, 0.07 },
			navOpenConvergence = { 269.0059, 0.2 },
			navHoverConvergence = { 269.5059, 0.07 },
			navOpenGuild = { 269.8759, 0.2 },
			navHoverGuild = { 270.3759, 0.07 },
			navOpenLeaderboards = { 270.7459, 0.2 },
			navHoverLeaderboards = { 271.2459, 0.07 },
			navOpenTrade = { 271.6159, 0.2 },
			navHoverTrade = { 272.1159, 0.07 },
			navOpenCredits = { 272.4859, 0.2 },
			navHoverCredits = { 272.9859, 0.07 },
			navOpenAdmin = { 273.3559, 0.2 },
			navHoverAdmin = { 273.8559, 0.07 },
			navOpenForgePath = { 274.2259, 0.2 },
			navHoverForgePath = { 274.7259, 0.07 },
			navOpenFoundry = { 275.0959, 0.2 },
			navHoverFoundry = { 275.5959, 0.07 },
			oreMineEmberite = { 275.9659, 0.32 },
			oreCollectEmberite = { 276.5859, 0.36 },
			oreMineVoidglass = { 277.2459, 0.32 },
			oreCollectVoidglass = { 277.8659, 0.36 },
			oreMineStarsteel = { 278.5259, 0.32 },
			oreCollectStarsteel = { 279.1459, 0.36 },
			waystoneHeart = { 279.8059, 0.22 },
			waystoneEmberreach = { 280.3259, 0.22 },
			waystoneHollows = { 280.8459, 0.22 },
			waystoneSpire = { 281.3659, 0.22 },
			waystoneRiftmaw = { 281.8859, 0.22 },
			sanctuaryRecall = { 282.4059, 0.26 },
			sanctuaryMenu = { 282.9659, 0.09 },
			sanctuarySheetClose = { 283.3559, 0.14 },
			clickHover = { 283.7959, 0.065 },
			confirmHover = { 284.1609, 0.065 },
			settingsHover = { 284.5259, 0.065 },
			purchasePressHover = { 284.8909, 0.065 },
			claimPressHover = { 285.2559, 0.065 },
			codeSubmitHover = { 285.6209, 0.065 },
			zoneSelectHover = { 285.9859, 0.065 },
			labRouteHover = { 286.3508, 0.065 },
			playerlistActionHover = { 286.7158, 0.065 },
			playerlistSelectHover = { 287.0808, 0.065 },
			puzzleTapHover = { 287.4458, 0.065 },
			sanctuaryClickHover = { 287.8108, 0.065 },
			equipHover = { 288.1758, 0.065 },
			dangerPressHover = { 288.5408, 0.065 },
			closeHover = { 288.9058, 0.065 },
			tickHover = { 289.2707, 0.065 },
			openHover = { 289.6357, 0.065 },
			tabSwitchHover = { 290.0007, 0.065 },
			mailHover = { 290.3657, 0.065 },
			storyHover = { 290.7307, 0.065 },
			toggleOnHover = { 291.0957, 0.065 },
			toggleOffHover = { 291.4607, 0.065 },
			lockedHover = { 291.8257, 0.065 },
			errorHover = { 292.1907, 0.065 },
			prestigeHover = { 292.5556, 0.065 },
			domainChargeHover = { 292.9206, 0.065 },
			cardEndTurnHover = { 293.2856, 0.065 },
			cardPowerHover = { 293.6506, 0.065 },
			cardEnergyHover = { 294.0156, 0.065 },
			vaultBankHover = { 294.3806, 0.065 },
			guildCreateHover = { 294.7456, 0.065 },
			guildJoinHover = { 295.1106, 0.065 },
			inviteHover = { 295.4756, 0.065 },
			travelHover = { 295.8405, 0.065 },
			gameResumeHover = { 296.2055, 0.065 },
			gamePauseHover = { 296.5705, 0.065 },
			queueStopHover = { 296.9355, 0.065 },
			queueStartHover = { 297.3005, 0.065 },
			boostHover = { 297.6655, 0.065 },
			reactorPulseHover = { 298.0305, 0.065 },
			crateOpenHover = { 298.3955, 0.065 },
			wheelStartHover = { 298.7605, 0.065 },
			rewardHover = { 299.1254, 0.065 },
			rebirthChargeHover = { 299.4904, 0.065 },
			missionClaimHover = { 299.8554, 0.065 },
			leaderboardSwitchHover = { 300.2204, 0.065 },
			adminArmHover = { 300.5854, 0.065 },
			memberRemoveHover = { 300.9504, 0.065 },
			roleChangeHover = { 301.3154, 0.065 },
			previewHover = { 301.6804, 0.065 },
			resetHover = { 302.0454, 0.065 },
			chatSendHover = { 302.4103, 0.065 },
			boostOpenHover = { 302.7753, 0.065 },
			vaultDepositHover = { 303.1403, 0.065 },
			forgePress = { 303.5053, 0.13 },
			corePress = { 303.9353, 0.13 },
			wavePress = { 304.3653, 0.13 },
			labPress = { 304.7953, 0.13 },
			commandPress = { 305.2253, 0.13 },
			adminPress = { 305.6553, 0.13 },
			creditsPress = { 306.0853, 0.13 },
			chatPress = { 306.5153, 0.13 },
			continuumPress = { 306.9453, 0.13 },
			missionPress = { 307.3753, 0.13 },
			overviewPress = { 307.8053, 0.13 },
		} :: { [string]: Region },
		Loudness = {
			hover = -16.9,
			hoverTick = -17.12,
			tick = -17.36,
			scroll = -16.24,
			sliderStep = -16.62,
			amountChange = -15.87,
			filterPick = -16.21,
			sanctuaryHover = -16.33,
			navHover = -16.11,
			click = -16.81,
			settings = -15.76,
			purchasePress = -16.78,
			claimPress = -16.41,
			codeSubmit = -16.41,
			zoneSelect = -16.24,
			labRoute = -17.64,
			playerlistAction = -15.96,
			playerlistSelect = -17.32,
			puzzleTap = -16.66,
			sanctuaryClick = -17.42,
			curtainOpen = -17.11,
			curtainClose = -17.59,
			confirm = -17.22,
			successChime = -15.78,
			equip = -15.68,
			itemLink = -17.52,
			tutorialStep = -17.4,
			roleChange = -16.57,
			reactorStabilize = -16.66,
			toggleOn = -13.76,
			toggleOff = -13.68,
			queueStart = -16.94,
			queueStop = -15.72,
			open = -14.98,
			modalOpen = -14.66,
			filterOpen = -14.63,
			boostOpen = -14.87,
			offlineOpen = -14.39,
			playerlistOpen = -14.96,
			story = -14.32,
			storyOpen = -15,
			crate = -14.27,
			close = -16.74,
			modalDismiss = -16.76,
			purchaseExit = -16.69,
			playerlistClose = -16.57,
			noticeClose = -16.32,
			itemUnlink = -16.51,
			reset = -18.11,
			memberRemove = -16.98,
			guildLeave = -16.6,
			gamePause = -16.94,
			gameExit = -18.39,
			page = -16.8,
			tabSwitch = -18.26,
			preview = -16.68,
			storyBeat = -16.84,
			storyPage = -17.61,
			mailRead = -15.84,
			leaderboardSwitch = -16.95,
			cardEndTurn = -16.35,
			modalPop = -11.05,
			sliderCommit = -10.97,
			inputClear = -13.36,
			chatSend = -17.42,
			inputFocus = -14.98,
			error = -12.26,
			errorBuzz = -11.68,
			noticeError = -11.89,
			dangerPress = -13.89,
			locked = -14.39,
			requestBlocked = -14.3,
			cardBlock = -14.5,
			noticeWarning = -12,
			systemAlert = -12.7,
			requestTimeout = -12.81,
			adminArm = -15.78,
			mail = -14.63,
			notification = -16.44,
			noticeInfo = -15.16,
			noticeSuccess = -16.58,
			noticeSpecial = -18.43,
			boostReady = -17.83,
			reactorReady = -17.41,
			crewNudge = -13.69,
			invite = -13.74,
			chatReceive = -12.58,
			gameResume = -14.59,
			velocitySlide = -17.44,
			travel = -18.12,
			purchase = -17.83,
			purchaseResult = -18.04,
			vaultDeposit = -18.19,
			vaultBank = -18.18,
			guildDeposit = -17.69,
			collect = -16.77,
			boost = -15.06,
			boostActivate = -16.72,
			offlineCollect = -15.42,
			puzzleClear = -15.08,
			oreCollect = -17.5,
			reward = -18.92,
			codeReward = -19.89,
			tutorialFinish = -18.25,
			domainReward = -19,
			wheelLand = -19.29,
			unlock = -19.4,
			researchUnlock = -19.21,
			achievementClaim = -18.6,
			seasonClaim = -19.91,
			comboMilestone = -19.03,
			discovery = -18.64,
			zoneUnlock = -19.31,
			guildCreate = -19.81,
			echoCapture = -19.26,
			storyReveal = -19.95,
			missionClaim = -18.89,
			dailyClaim = -17.59,
			timedClaim = -18.32,
			mailClaim = -18.64,
			crateClaim = -18.74,
			echoClaim = -19.04,
			guildJoin = -19.49,
			expeditionReturn = -18.03,
			prestige = -19.25,
			rebirthBloom = -19.45,
			crateRare = -19.57,
			salvage = -13.92,
			salvageCrunch = -13.48,
			echoDismantle = -13.63,
			autoForge = -13.86,
			bootStrike = -13.84,
			bootClang = -13.74,
			bootAnvilSplit = -13.36,
			wardenStrike = -18.91,
			wardenCrit = -12.84,
			machineInstall = -20.35,
			wheelBrake = -20.29,
			crateBrake = -20.16,
			wheel = -16.77,
			wheelStart = -17.57,
			crateOpen = -17.18,
			expeditionLaunch = -17.26,
			bootStart = -17.44,
			bootWhoosh = -17.22,
			bootFinaleFlip = -16.87,
			bootSlamAir = -17.67,
			reactor = -13.45,
			bootRumble = -13.61,
			bootFractureTail = -12.73,
			bootGravity = -13.8,
			bootAftershock = -13.05,
			reactorSurge = -12.29,
			adminExecute = -12.19,
			crateLand = -12.31,
			domainImpact = -12.39,
			bootImpact = -12.18,
			bootFinaleBang = -12.43,
			reactorChannel = -19.46,
			rebirthCharge = -18.83,
			wheelCharge = -19.72,
			crateCharge = -18.57,
			domainCharge = -19.62,
			cardPower = -18.84,
			bootTension = -19.3,
			reactorPulse = -18.33,
			domainCrack = -18.07,
			cardEnergy = -16.46,
			bootSpark = -16.37,
			bootFizz = -16.91,
			bootDebris = -18.1,
			domainBind = -15.67,
			boot = -16.49,
			wheelTick = -13.69,
			wheelSlow = -13.35,
			crateTick = -13.41,
			crateNear = -13.21,
			cardPlay = -17.74,
			cardDraw = -18.04,
			bootIgnite = -13.09,
			bootReady = -19.89,
			bootSlamCharge = -19.32,
			oreMine = -18.51,
			wardenForming = -17.72,
			wardenAwake = -11.33,
			wardenSlam = -11.55,
			wardenDefeat = -18.75,
			wardenEscape = -15.26,
			waystoneTravel = -18.48,
			regionEnter = -16.13,
			echoEquip = -17.35,
			echoTune = -15.87,
			wardenSlamCharge = -17.89,
			navOpenOverview = -13.12,
			navHoverOverview = -14.33,
			navOpenWorkshop = -15.31,
			navHoverWorkshop = -19.37,
			navOpenInventory = -12.81,
			navHoverInventory = -15.14,
			navOpenResearch = -10.75,
			navHoverResearch = -14.83,
			navOpenShop = -20.6,
			navHoverShop = -17.97,
			navOpenSettings = -15.12,
			navHoverSettings = -16.35,
			navOpenWorlds = -14.91,
			navHoverWorlds = -15.82,
			navOpenMissions = -11.54,
			navHoverMissions = -13.62,
			navOpenRewards = -14.54,
			navHoverRewards = -16.52,
			navOpenBoosts = -13.27,
			navHoverBoosts = -14.83,
			navOpenStarGrid = -15.31,
			navHoverStarGrid = -20.7,
			navOpenEchoes = -12.99,
			navHoverEchoes = -15.39,
			navOpenContinuum = -10.72,
			navHoverContinuum = -15.92,
			navOpenLab = -20.57,
			navHoverLab = -18.7,
			navOpenAnomaly = -15.29,
			navHoverAnomaly = -16.65,
			navOpenWheel = -14.92,
			navHoverWheel = -16.73,
			navOpenCommand = -16.56,
			navHoverCommand = -14.67,
			navOpenStory = -14.35,
			navHoverStory = -16.24,
			navOpenMail = -12.49,
			navHoverMail = -14.68,
			navOpenChat = -15.59,
			navHoverChat = -19.08,
			navOpenCrew = -12.98,
			navHoverCrew = -15.9,
			navOpenMilestones = -10.73,
			navHoverMilestones = -15.41,
			navOpenConvergence = -19.89,
			navHoverConvergence = -18.78,
			navOpenGuild = -15.49,
			navHoverGuild = -18.17,
			navOpenLeaderboards = -14.78,
			navHoverLeaderboards = -17.18,
			navOpenTrade = -12.95,
			navHoverTrade = -13.95,
			navOpenCredits = -14.55,
			navHoverCredits = -16.33,
			navOpenAdmin = -12.46,
			navHoverAdmin = -14.76,
			navOpenForgePath = -15.25,
			navHoverForgePath = -19.44,
			navOpenFoundry = -12.94,
			navHoverFoundry = -15.99,
			oreMineEmberite = -10.52,
			oreCollectEmberite = -12.13,
			oreMineVoidglass = -17.3,
			oreCollectVoidglass = -15.36,
			oreMineStarsteel = -15.32,
			oreCollectStarsteel = -14.33,
			waystoneHeart = -14.75,
			waystoneEmberreach = -13.49,
			waystoneHollows = -17.26,
			waystoneSpire = -14.07,
			waystoneRiftmaw = -13.54,
			sanctuaryRecall = -14.49,
			sanctuaryMenu = -13.79,
			sanctuarySheetClose = -12.24,
			clickHover = -18.4,
			confirmHover = -19.93,
			settingsHover = -17.3,
			purchasePressHover = -16.43,
			claimPressHover = -13.48,
			codeSubmitHover = -16.02,
			zoneSelectHover = -23.58,
			labRouteHover = -17.54,
			playerlistActionHover = -17.47,
			playerlistSelectHover = -16.77,
			puzzleTapHover = -17.59,
			sanctuaryClickHover = -17.81,
			equipHover = -15.05,
			dangerPressHover = -17.03,
			closeHover = -17.46,
			tickHover = -16.2,
			openHover = -15.18,
			tabSwitchHover = -14.33,
			mailHover = -18.05,
			storyHover = -20.24,
			toggleOnHover = -16.61,
			toggleOffHover = -16.93,
			lockedHover = -14.49,
			errorHover = -16.57,
			prestigeHover = -23.23,
			domainChargeHover = -18.17,
			cardEndTurnHover = -16.9,
			cardPowerHover = -16.98,
			cardEnergyHover = -18.12,
			vaultBankHover = -19.02,
			guildCreateHover = -19.63,
			guildJoinHover = -17.7,
			inviteHover = -17.4,
			travelHover = -16.22,
			gameResumeHover = -14.83,
			gamePauseHover = -14.96,
			queueStopHover = -17.93,
			queueStartHover = -21.66,
			boostHover = -16.52,
			reactorPulseHover = -16.05,
			crateOpenHover = -13.36,
			wheelStartHover = -15.56,
			rewardHover = -23.54,
			rebirthChargeHover = -19.38,
			missionClaimHover = -17.23,
			leaderboardSwitchHover = -15.44,
			adminArmHover = -18.36,
			memberRemoveHover = -18.1,
			roleChangeHover = -16.43,
			previewHover = -14.33,
			resetHover = -16.23,
			chatSendHover = -17.17,
			boostOpenHover = -14.28,
			vaultDepositHover = -14.72,
			forgePress = -15.86,
			corePress = -18.24,
			wavePress = -13.58,
			labPress = -14.77,
			commandPress = -11.14,
			adminPress = -13,
			creditsPress = -21.55,
			chatPress = -16.22,
			continuumPress = -15.35,
			missionPress = -14.93,
			overviewPress = -15.49,
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
		Id = 0,
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
		{ Level = 1, Tier = "Beginner", Goal = nil, Unlocks = { "Overview", "Workshop", "Chat", "Settings" } },
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
			Unlocks = { "Milestones", "Casino" },
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
			Unlocks = { "Anomaly", "Command", "Crew", "Trade" },
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
			Unlocks = {},
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
				progress = if type(read) == "number" and read == read then read else 0
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
			local progress = if type(read) == "number" and read == read then read else 0
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

		HideEmptyCategories = false,
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
					{
						Name = "usingINales",
						UserId = 10916707683,
						Role = "Founder",
						Note = "Design, code, worlds and story.",
					},
				},
			},
			{
				Id = "Developers",
				Label = "Developers",
				Description = "Build the game.",
				Accent = "cyan",
				Icon = "Forge",
				Members = {
					{
						Name = "usingINales",
						UserId = 10916707683,
						Role = "Lead developer",
						Note = "Client, server and economy.",
					},
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
			HideEmptyCategories = flag(config.HideEmptyCategories, false),
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
				if
					type(category) ~= "table"
					or type(category.Id) ~= "string"
					or category.Id == ""
					or category.Id == "All"
					or seen[category.Id]
				then
					continue
				end
				seen[category.Id] = true
				local members = {}
				if type(category.Members) == "table" then
					for _, member in category.Members do
						if type(member) ~= "table" or type(member.Name) ~= "string" or member.Name == "" then
							continue
						end
						local userId = if type(member.UserId) == "number" and member.UserId > 0
							then math.floor(member.UserId)
							else nil
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
			table.insert(
				tabs,
				{ id = category.Id, label = category.Label, count = #category.Members, accent = category.Accent }
			)
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
		local textBlock = 22
			+ (if model.ShowUsernames then 16 else 0)
			+ (if model.ShowRoles then 18 else 0)
			+ (if model.ShowNotes then 34 else 0)
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
		{ id = "Other", label = "Other", detail = "Something else. Add details below." },
	})

	PlayerlistModel.SORTS = table.freeze({
		{ id = "Production", label = "Output" },
		{ id = "Rebirths", label = "Rebirths" },
		{ id = "Name", label = "Name" },
	})

	PlayerlistModel.DETAILS_MAX = 400
	PlayerlistModel.SEARCH_MIN_ROWS = 6

	local function num(value: any): number
		if type(value) == "number" and value == value then
			return value
		end
		return 0
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
				DisplayName = if type(entry.DisplayName) == "string" and entry.DisplayName ~= ""
					then entry.DisplayName
					else name,
				IsLocal = entry.IsLocal == true,
				CurrentZone = math.max(1, num(entry.CurrentZone)),
				Zone = math.max(1, num(entry.Zone)),
				Rebirths = num(entry.Rebirths),
				Production = num(entry.Production),
				LifetimeCash = num(entry.LifetimeCash),
				ItemCount = num(entry.ItemCount),
				DomainRank = num(entry.DomainRank),
				PlayTime = num(entry.PlayTime),
				AccountAge = num(entry.AccountAge),
				Premium = entry.Premium == true,
				EquippedItems = if type(entry.EquippedItems) == "table" then entry.EquippedItems else {},
				CurrentPage = if type(entry.CurrentPage) == "string" then entry.CurrentPage else "",
			})
		end
		return rows
	end

	function PlayerlistModel.view(
		rows,
		sortId: string,
		query: string?,
		friendsOnly: boolean?,
		friends: { [number]: boolean }?
	)
		local needle = string.lower((string.gsub(query or "", "^%s*(.-)%s*$", "%1")))
		local out = {}
		for _, row in rows do
			if not row.IsLocal then
				if friendsOnly and not (friends and friends[row.UserId]) then
					continue
				end
				if
					needle ~= ""
					and not string.find(string.lower(row.DisplayName), needle, 1, true)
					and not string.find(string.lower(row.Name), needle, 1, true)
				then
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
			elseif left.Production ~= right.Production then
				return left.Production > right.Production
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
		return trimmed
	end

	return table.freeze(PlayerlistModel)
end

__defs["TutorialScript"] = function()
	local TutorialScript = {}

	TutorialScript.PET_NAME = "Bolt"

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
			say = "Click the glowing Collect button!",
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
			say = "Now click Workshop. That's where you buy machines.",
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
			say = "Buy a machine here. More machines, more Flux every second!",
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
			say = "Tap x5 or Max to buy lots of levels in one click.",
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
			body = "Click the bar any time to see every level and what it unlocks.",
			goal = "Look at the level bar",
			target = { "LevelBarTarget", "MobileHeader" },
			page = "Workshop",
			watch = "continue",
		},
		{
			id = "toResearch",
			title = "Research lasts forever",
			say = "Click Research. Its bonuses stay even after you rebirth.",
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
			say = "Later on, Rebirth trades your machines for Cores. Your research stays!",
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
			say = "That's the tour! Replay me from Settings, then Guide. Now go build something huge!",
			body = "Collect, buy machines, research, rebirth. Finishing pays a small Flux bonus.",
			goal = "Finish the guide",
			target = { "Nav_Settings", "Nav_Menu" },
			page = "Overview",
			watch = "finish",
		},
	})

	TutorialScript.QUIPS = table.freeze({
		idle = {
			"Need a hint? Follow my finger!",
			"The glowing box is the thing to click.",
			"Beep boop. That tickles!",
			"I run on Flux. Mostly.",
		},
		done = { "Nice! On to the next bit.", "You're a natural!", "Woo! Keep going!" },
		dizzy = { "Whoa... the forge is spinning!", "Okay, okay, no more spins!", "Everything is sparkly now." },
		pet = { "Hehe, that's nice!", "Bzzzt! Happy sparks!", "You're my favourite forger." },
		wake = { "Huh? I'm awake! Totally awake.", "Zzz... oh! Where were we?" },
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
			return collected == true
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
			return math.clamp(x, half + 6, math.max(half + 6, screenW - half - 6)),
				math.clamp(y, half + 6, math.max(half + 6, screenH - half - 6))
		end
		local dockH = if dock ~= nil then num(dock.h, 0) else 0
		local function onDock(x, y): boolean
			if dock == nil or dockH <= 0 then
				return false
			end
			local pad = 8
			return x + half > dock.x - pad
				and x - half < dock.x + dock.w + pad
				and y + half > dock.y - pad
				and y - half < dock.y + dockH + pad
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
			return {
				Phase = "Warning",
				Id = id,
				PhaseEndsAt = now + ServerEvents.WARNING_SECONDS,
				LastId = state.LastId,
			},
				true
		elseif state.Phase == "Warning" then
			return {
				Phase = "Live",
				Id = state.Id,
				PhaseEndsAt = now + ServerEvents.LIVE_SECONDS,
				LastId = state.LastId,
			},
				true
		elseif state.Phase == "Live" then
			return {
				Phase = "Results",
				Id = state.Id,
				PhaseEndsAt = now + ServerEvents.RESULTS_SECONDS,
				LastId = state.Id,
			},
				true
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
				CollectVault = 1,
				BuyMachine = 2,
				BuyResearch = 3,
				BuyGridUpgrade = 4,
				PulseAnomaly = 1,
				StabilizeAnomaly = 8,
				ClaimLabOrder = 7,
				Rebirth = 25,
				DomainExpansion = 100,
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
		Donation: boolean?,
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
				ProductId = 0,
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
				ProductId = 0,
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
				ProductId = 0,
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
				ProductId = 0,
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
				PassId = 0,
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
				PassId = 0,
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
				PassId = 0,
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
				PassId = 0,
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

	require(script.Parent.CommerceCatalog).Extend(MonetizationConfig, require(script.Parent.CommerceIds))

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
		return omegaMath.Floor(
			omegaMath.Max(baseCapacity, omegaMath.Mul(omegaMath.Mul(steadyProduction, seconds), continuumCapacity))
		)
	end

	function CapacityProjection.CapacitySeconds(
		omegaMath,
		capacity: any,
		steadyProduction: any,
		lte: (any, any) -> boolean
	): number
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
		{
			id = "sound",
			label = "Sound",
			icon = "Wave",
			accent = "mint",
			blurb = "Volume for music, effects and alerts.",
		},
		{
			id = "display",
			label = "Graphics",
			icon = "Boost",
			accent = "pink",
			blurb = "Effects, glow and how lively the menus move.",
		},
		{
			id = "interface",
			label = "Interface",
			icon = "Settings",
			accent = "cyan",
			blurb = "What the screen shows and how it is laid out.",
		},
		{
			id = "accessibility",
			label = "Accessibility",
			icon = "Guide",
			accent = "mango",
			blurb = "Text size, contrast and color-safe signals.",
		},
		{
			id = "mobile",
			label = "Phone",
			icon = "Menu",
			accent = "blue",
			blurb = "Sizes and layout for touch screens.",
			touchOnly = true,
		},
	})

	local SIZE4 = {
		{ label = "S", value = 0.25 },
		{ label = "M", value = 0.5 },
		{ label = "L", value = 0.75 },
		{ label = "XL", value = 1 },
	}
	local THREE = function(a: string, b: string, c: string, va: number, vb: number, vc: number): { Choice }
		return { { label = a, value = va }, { label = b, value = vb }, { label = c, value = vc } }
	end
	local function toggle(key, section, label, help, default, advanced)
		return {
			key = key,
			section = section,
			label = label,
			help = help,
			kind = "toggle",
			default = default,
			advanced = advanced,
		}
	end
	local function slider(key, section, label, help, default, advanced)
		return {
			key = key,
			section = section,
			label = label,
			help = help,
			kind = "slider",
			default = default,
			advanced = advanced,
		}
	end
	local function choice(key, section, label, help, default, choices, advanced)
		return {
			key = key,
			section = section,
			label = label,
			help = help,
			kind = "choice",
			default = default,
			choices = choices,
			advanced = advanced,
		}
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
		slider(
			"SoundVariation",
			"sound",
			"Pitch variation",
			"Small changes so repeated clicks don't sound identical.",
			0.7,
			true
		),
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
		toggle(
			"OfflineRewardEffects",
			"display",
			"Welcome-back glow",
			"Effects when you return to offline earnings.",
			1,
			true
		),
		slider("ViewportSpeed", "display", "3D spin speed", "How fast 3D icons turn.", 0.65, true),
		slider("ReactorMotion", "display", "Reactor motion", "How busy the reactor looks.", 0.8, true),
		toggle("ShowFps", "interface", "FPS", "Frame rate in the top bar.", 1),
		toggle("ShowPing", "interface", "Ping", "Connection delay in the top bar.", 1),
		toggle("ShowResourceLabels", "interface", "Currency labels", "FLUX, CORES and DUST above the numbers.", 1),
		toggle("ShowNextGoal", "interface", "Level bar", "Your Forge Level and next goal under page titles.", 1),
		toggle("CompactTopBar", "interface", "Compact top bar", "A shorter header with more room below.", 0),
		choice(
			"UiDensity",
			"interface",
			"Spacing",
			"Room between things on the page.",
			0.55,
			THREE("Tight", "Normal", "Roomy", 0.2, 0.55, 0.9)
		),
		choice(
			"ToastDensity",
			"interface",
			"Alerts on screen",
			"How many notifications stack up.",
			0.55,
			THREE("Few", "Some", "Many", 0.2, 0.55, 0.9)
		),
		choice(
			"NotificationDuration",
			"interface",
			"Alert time",
			"How long notifications stay.",
			0.55,
			THREE("Short", "Normal", "Long", 0.25, 0.55, 0.9)
		),
		choice(
			"PerformanceBias",
			"interface",
			"Priority",
			"Favor looks or frame rate when the game is busy.",
			0.5,
			THREE("Looks", "Balanced", "Speed", 0, 0.5, 1)
		),
		choice(
			"ScrollSpeed",
			"interface",
			"Scroll speed",
			"How far one wheel notch moves a list.",
			0.65,
			THREE("Slow", "Normal", "Fast", 0.35, 0.65, 0.95),
			true
		),
		slider(
			"ScrollMomentum",
			"interface",
			"Scroll glide",
			"How long a list keeps moving after you let go.",
			0.75,
			true
		),
		choice(
			"DesktopTextScale",
			"accessibility",
			"Text size",
			"Bigger or smaller text. Buttons stay where they are.",
			0.5,
			SIZE4
		),
		toggle("HighContrast", "accessibility", "High contrast", "Stronger text and edges.", 0),
		toggle("ColorblindMode", "accessibility", "Color-safe signals", "Blue and gold instead of green and red.", 0),
		toggle("BoldText", "accessibility", "Bolder text", "Heavier descriptions.", 0),
		toggle("ReducedTransparency", "accessibility", "Solid panels", "Less see-through backgrounds.", 0),
		toggle("LargeTouchTargets", "accessibility", "Large buttons", "Bigger tap targets on touch screens.", 1),
		slider("HapticIntensity", "accessibility", "Vibration", "How hard the phone buzzes on taps.", 0.65),
		choice("MobileTextScale", "mobile", "Text size", "Text size on phones.", 0.5, SIZE4),
		choice(
			"MobileQuickReverse",
			"mobile",
			"Main thumb",
			"Which side the overcharge button sits on.",
			0,
			{ { label = "Right", value = 0 }, { label = "Left", value = 1 } }
		),
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
		slider(
			"MobileQuickOpacity",
			"mobile",
			"Quick button opacity",
			"How solid the floating buttons are.",
			0.9,
			true
		),
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
			values = {
				EffectsIntensity = 0.25,
				MotionIntensity = 0.3,
				ParticleDensity = 0.15,
				GlowIntensity = 0.25,
				ShimmerIntensity = 0.2,
				ButtonShimmers = 0,
				ConfettiEnabled = 0,
				ScreenFlashes = 0,
				BackgroundDetail = 0.3,
				AnimatedTitles = 0,
				IconAnimations = 0,
				PerformanceBias = 1,
			},
		},
		{
			id = "balanced",
			label = "Balanced",
			notice = "Balanced graphics.",
			values = {
				EffectsIntensity = 0.7,
				MotionIntensity = 0.7,
				ParticleDensity = 0.6,
				GlowIntensity = 0.6,
				ShimmerIntensity = 0.7,
				ButtonShimmers = 1,
				ConfettiEnabled = 1,
				ScreenFlashes = 1,
				BackgroundDetail = 0.7,
				AnimatedTitles = 1,
				IconAnimations = 1,
				PerformanceBias = 0.5,
			},
		},
		{
			id = "high",
			label = "High",
			notice = "High graphics: every effect at full.",
			values = {
				EffectsIntensity = 1,
				MotionIntensity = 1,
				ParticleDensity = 1,
				GlowIntensity = 1,
				ShimmerIntensity = 1,
				ButtonShimmers = 1,
				ConfettiEnabled = 1,
				ScreenFlashes = 1,
				BackgroundDetail = 1,
				AnimatedTitles = 1,
				IconAnimations = 1,
				PerformanceBias = 0,
			},
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

	function RelicSystem.fusionPair(
		inventory: any,
		equipped: any,
		definitionId: string,
		maxStars: number?
	): (string?, string?, string?)
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
		{
			Id = "Classic",
			Name = "Forge Iron",
			Tier = "Common",
			Blurb = "Riveted iron, warm from the forge.",
			Accent = { 255, 184, 52 },
			Glow = { 255, 140, 60 },
			Vfx = "embers",
			Default = true,
		},
		{
			Id = "Crystal",
			Name = "Crystal Prism",
			Tier = "Rare",
			Blurb = "Cut quartz panels that split the light.",
			Accent = { 120, 220, 255 },
			Glow = { 200, 245, 255 },
			Vfx = "shards",
			Price = { Currency = "Stardust", Amount = 400 },
		},
		{
			Id = "Frost",
			Name = "Frost Rune",
			Tier = "Rare",
			Blurb = "A rune-locked chest that breathes cold.",
			Accent = { 170, 225, 255 },
			Glow = { 230, 250, 255 },
			Vfx = "frost",
			Price = { Currency = "Stardust", Amount = 450 },
		},
		{
			Id = "Molten",
			Name = "Molten Core",
			Tier = "Epic",
			Blurb = "Cracked basalt over a river of fire.",
			Accent = { 255, 110, 60 },
			Glow = { 255, 190, 90 },
			Vfx = "magma",
			Price = { Currency = "Stardust", Amount = 900 },
		},
		{
			Id = "Nebula",
			Name = "Nebula Glass",
			Tier = "Epic",
			Blurb = "Smoked glass with a small galaxy inside.",
			Accent = { 178, 134, 255 },
			Glow = { 250, 140, 220 },
			Vfx = "nebula",
			Price = { Currency = "Cores", Amount = 12 },
		},
		{
			Id = "Void",
			Name = "Void Reliquary",
			Tier = "Legendary",
			Blurb = "Black stone. The lid opens inward.",
			Accent = { 130, 90, 220 },
			Glow = { 190, 120, 255 },
			Vfx = "void",
			Price = { Currency = "Cores", Amount = 30 },
		},
		{
			Id = "Gilded",
			Name = "Gilded Starlight",
			Tier = "Legendary",
			Blurb = "Gold leaf and a lid of falling stars.",
			Accent = { 255, 214, 120 },
			Glow = { 255, 246, 214 },
			Vfx = "stars",
			Price = { Currency = "Cores", Amount = 40 },
		},
		{
			Id = "Celestial",
			Name = "Celestial Ark",
			Tier = "Mythic",
			Blurb = "Only ever seen in the Daily Shop.",
			Accent = { 120, 240, 255 },
			Glow = { 255, 236, 170 },
			Vfx = "prism",
			Price = { Currency = "Cores", Amount = 90 },
			DailyOnly = true,
		},
	})

	local skinById = {}
	for _, skin in ShopCatalog.SKINS do
		skinById[skin.Id] = skin
	end
	function ShopCatalog.skin(id: any): any
		return if type(id) == "string" then skinById[id] else nil
	end
	ShopCatalog.DEFAULT_SKIN = "Classic"

	ShopCatalog.POOL = table.freeze({
		{
			Id = "ForgeKeys",
			Name = "3 Forge Keys",
			Kind = "Key",
			CrateId = "ForgeCrate",
			Amount = 3,
			Currency = "Stardust",
			Price = 20,
			Stock = 2,
			Weight = 10,
		},
		{
			Id = "CrystalKeys",
			Name = "2 Crystal Keys",
			Kind = "Key",
			CrateId = "CrystalCrate",
			Amount = 2,
			Currency = "Stardust",
			Price = 60,
			Stock = 2,
			Weight = 8,
		},
		{
			Id = "NebulaKey",
			Name = "Nebula Key",
			Kind = "Key",
			CrateId = "NebulaCrate",
			Amount = 1,
			Currency = "Stardust",
			Price = 62,
			Stock = 2,
			Weight = 7,
		},
		{
			Id = "OrbitKeys",
			Name = "2 Orbit Keys",
			Kind = "Key",
			CrateId = "OrbitCrate",
			Amount = 2,
			Currency = "Stardust",
			Price = 95,
			Stock = 1,
			Weight = 6,
		},
		{
			Id = "AetherKey",
			Name = "Aether Key",
			Kind = "Key",
			CrateId = "AetherCrate",
			Amount = 1,
			Currency = "Stardust",
			Price = 52,
			Stock = 2,
			Weight = 6,
		},
		{
			Id = "HorizonKey",
			Name = "Horizon Key",
			Kind = "Key",
			CrateId = "HorizonCrate",
			Amount = 1,
			Currency = "Stardust",
			Price = 80,
			Stock = 1,
			Weight = 5,
		},
		{
			Id = "SingularityKey",
			Name = "Singularity Key",
			Kind = "Key",
			CrateId = "SingularityCrate",
			Amount = 1,
			Currency = "Cores",
			Price = 3,
			Stock = 1,
			Weight = 3,
		},
		{
			Id = "EchoKey",
			Name = "Echo Key",
			Kind = "Key",
			CrateId = "EchoCrate",
			Amount = 1,
			Currency = "Cores",
			Price = 4,
			Stock = 1,
			Weight = 3,
		},
		{
			Id = "DriftKey",
			Name = "Drift Key",
			Kind = "Key",
			CrateId = "DriftCrate",
			Amount = 1,
			Currency = "Cores",
			Price = 3,
			Stock = 1,
			Weight = 3,
		},
		{
			Id = "EssenceJar",
			Name = "Essence Jar",
			Kind = "Essence",
			Amount = 150,
			Currency = "Stardust",
			Price = 40,
			Stock = 3,
			Weight = 8,
		},
		{
			Id = "EssenceCask",
			Name = "Essence Cask",
			Kind = "Essence",
			Amount = 600,
			Currency = "Cores",
			Price = 3,
			Stock = 1,
			Weight = 4,
		},
		{
			Id = "FluxHour",
			Name = "An Hour of Flux",
			Kind = "Flux",
			Minutes = 60,
			Currency = "Stardust",
			Price = 30,
			Stock = 2,
			Weight = 7,
		},
		{
			Id = "FluxDay",
			Name = "A Shift of Flux",
			Kind = "Flux",
			Minutes = 480,
			Currency = "Cores",
			Price = 4,
			Stock = 1,
			Weight = 3,
		},
		{
			Id = "Overdrive",
			Name = "Overdrive Boost",
			Kind = "Boost",
			BoostId = "Overdrive",
			Amount = 1,
			Currency = "Stardust",
			Price = 45,
			Stock = 2,
			Weight = 5,
		},
		{
			Id = "Hyperdrive",
			Name = "Hyperdrive Boost",
			Kind = "Boost",
			BoostId = "Hyperdrive",
			Amount = 1,
			Currency = "Stardust",
			Price = 70,
			Stock = 1,
			Weight = 4,
		},
		{
			Id = "SteadyBurn",
			Name = "Steady Burn Boost",
			Kind = "Boost",
			BoostId = "SteadyBurn",
			Amount = 1,
			Currency = "Stardust",
			Price = 55,
			Stock = 1,
			Weight = 4,
		},
		{
			Id = "DomainSurge",
			Name = "Domain Surge Boost",
			Kind = "Boost",
			BoostId = "DomainSurge",
			Amount = 1,
			Currency = "Cores",
			Price = 5,
			Stock = 1,
			Weight = 2,
		},
		{
			Id = "EpicCache",
			Name = "Epic Relic Cache",
			Kind = "Cache",
			Rarity = "Epic",
			Currency = "Stardust",
			Price = 180,
			Stock = 1,
			Weight = 4,
		},
		{
			Id = "LegendaryCache",
			Name = "Legendary Relic Cache",
			Kind = "Cache",
			Rarity = "Legendary",
			Currency = "Cores",
			Price = 8,
			Stock = 1,
			Weight = 2,
		},
		{
			Id = "MythicCache",
			Name = "Mythic Relic Cache",
			Kind = "Cache",
			Rarity = "Mythic",
			Currency = "Cores",
			Price = 25,
			Stock = 1,
			Weight = 0.6,
		},
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
		local random =
			generator(((math.abs(math.floor(userId)) % 1000003) * 7919 + math.floor(day) * 104729) % 4294967296)
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
		end
		return __load(name)
	end,
})
