--!strict
--[=[
	SharedData: merged module suite.
	Members (10): AssetKit, AssetManifest, Vfx, SanctuaryConfig, SanctuaryLayout, ForgeLevels, LiveOpsConfig, MonetizationConfig, CapacityProjection, ZoneUnlock.

	Each member keeps its original source inside its own closure (so every member
	still has its own local-register budget) and is evaluated lazily, exactly once,
	on first access.  Use `require(<this module>)("<Member>")` (or index the returned
	table with the member name) to get a member's exports.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

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

-- ======================================================================
-- Module: AssetKit   (merged from AssetKit.luau, 203 lines)
-- ======================================================================
__defs["AssetKit"] = function()
-- The model kit (tools/assetgen/meshes.py -> AstralForgeKit.glb) at runtime.
--
-- Where the kit comes from, first match wins:
--   1. ServerStorage.AstralForgeKit   -- imported by hand in Studio
--   2. the uploaded model, Manifest.Kit.Id, loaded with InsertService
-- The server publishes one copy of every MeshPart to
-- ReplicatedStorage.AstralForgeKit, so clients (the Warden's body) clone the
-- same templates. With no kit at all, make() returns nil and every caller
-- falls back to its part-built shape, so the game looks as it did before.
--
--   AssetKit.load(8)                        -- server: at most 8 s; client: waits for the publish
--   AssetKit.make("Crystal", size) -> MeshPart?
--   AssetKit.sized("Obelisk", 1.4) -> Vector3  (native proportions, scaled)

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = if RunService:IsServer() then game:GetService("ServerStorage") else nil

local Manifest = __load("AssetManifest")

local AssetKit = {}

local PUBLISHED = "AstralForgeKit"

local templates: { [string]: MeshPart? } = {}
local state = "idle" -- idle | loading | ready | missing
local waiters: { thread } = {}

-- Importers sometimes decorate names ("Crystal.001", "Crystal_Mesh"); match
-- the longest kit name the instance's name starts with.
local function kitName(name: string): string?
	local best: string? = nil
	for key in Manifest.Kit.Sizes do
		if name == key then
			return key
		end
		if string.sub(name, 1, #key) == key and not string.match(string.sub(name, #key + 1, #key + 1), "%w") then
			if best == nil or #key > #best then
				best = key
			end
		end
	end
	return best
end

local function collect(root: Instance)
	for _, item in root:GetDescendants() do
		if item:IsA("MeshPart") then
			local key = kitName(item.Name)
			if key ~= nil and templates[key] == nil then
				templates[key] = item
			end
		end
	end
end

local function finish(ready: boolean)
	state = if ready then "ready" else "missing"
	local list = waiters
	waiters = {}
	for _, thread in list do
		task.spawn(thread)
	end
end

local function publish()
	if ReplicatedStorage:FindFirstChild(PUBLISHED) ~= nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = PUBLISHED
	for key, template in templates do
		if template == nil then
			continue
		end
		local copy = template:Clone()
		copy.Name = key
		copy.Anchored = true
		copy.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

local function loadServer()
	local source: Instance? = if ServerStorage ~= nil then ServerStorage:FindFirstChild(PUBLISHED) else nil
	if source == nil and Manifest.Kit.Id > 0 then
		local ok, result = pcall(function()
			return InsertService:LoadAsset(Manifest.Kit.Id)
		end)
		if ok and typeof(result) == "Instance" then
			source = result
		else
			warn(`[AssetKit] couldn't load kit {Manifest.Kit.Id}: {result}. The game owner must own the asset.`)
		end
	end
	if source ~= nil then
		collect(source)
	end
	if next(templates) ~= nil then
		publish()
	end
	finish(next(templates) ~= nil)
end

local function loadClient()
	local folder = ReplicatedStorage:WaitForChild(PUBLISHED, 12)
	if folder ~= nil then
		collect(folder)
		for _, item in folder:GetChildren() do
			if item:IsA("MeshPart") and templates[item.Name] == nil then
				templates[item.Name] = item
			end
		end
	end
	finish(next(templates) ~= nil)
end

-- Load the kit, waiting at most `timeout` seconds. Safe to call many times.
function AssetKit.load(timeout: number?): boolean
	if state == "ready" or state == "missing" then
		return state == "ready"
	end
	-- Nothing uploaded and nothing imported: skip the wait entirely.
	if RunService:IsServer() and Manifest.Kit.Id == 0 and (ServerStorage == nil or ServerStorage:FindFirstChild(PUBLISHED) == nil) then
		finish(false)
		return false
	end
	if RunService:IsClient() and Manifest.Kit.Id == 0 and ReplicatedStorage:FindFirstChild(PUBLISHED) == nil then
		finish(false)
		return false
	end
	if state == "idle" then
		state = "loading"
		task.spawn(if RunService:IsServer() then loadServer else loadClient)
	end
	if state == "loading" then
		local me = coroutine.running()
		table.insert(waiters, me)
		local deadline = task.delay(timeout or 8, function()
			local index = table.find(waiters, me)
			if index ~= nil then
				table.remove(waiters, index)
				task.spawn(me)
			end
		end)
		coroutine.yield()
		pcall(task.cancel, deadline)
	end
	return state == "ready"
end

function AssetKit.ready(): boolean
	return state == "ready"
end

function AssetKit.has(name: string): boolean
	return templates[name] ~= nil
end

-- Native proportions of a model, scaled.
function AssetKit.sized(name: string, scale: number): Vector3
	local native: Vector3? = Manifest.Kit.Sizes[name]
	return if native ~= nil then native * scale else Vector3.one * scale
end

-- A fresh, anchored MeshPart of `name` at `size`, or nil if the kit isn't loaded.
function AssetKit.make(name: string, size: Vector3, cframe: CFrame?, color: Color3?, material: Enum.Material?, collide: boolean?): MeshPart?
	local template: MeshPart? = templates[name]
	if template == nil then
		return nil
	end
	local part = template:Clone()
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CanCollide = collide == true
	part.CanQuery = collide == true
	part.CanTouch = false
	if cframe ~= nil then
		part.CFrame = cframe
	end
	if color ~= nil then
		part.Color = color
	end
	if material ~= nil then
		part.Material = material
	end
	-- Imported meshes can carry a texture or surface appearance; the kit is
	-- coloured by material, so drop both.
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	pcall(function()
		part.TextureID = ""
	end)
	return part
end

return AssetKit
end

-- ======================================================================
-- Module: AssetManifest   (merged from AssetManifest.luau, 731 lines)
-- ======================================================================
__defs["AssetManifest"] = function()
-- GENERATED by tools/assetgen/build.py -- do not edit by hand.
-- Regions, lengths and sizes come from the generated files; the ids come
-- from assets/asset_ids.json (filled in by tools/assetgen/upload.py). An id
-- of 0 means that file hasn't been uploaded yet, and the game falls back to
-- its built-in sounds and part-built models.

type Region = { number } -- { start seconds, length seconds }

local Manifest = {}

Manifest.SoundSheet = {
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
	-- Loudness of each entry (dB RMS while sounding), for level matching.
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
	-- Loudness of each entry (dB RMS while sounding), for level matching.
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
	-- Native size of each model (studs, as generated). The game sets
	-- MeshPart.Size itself; these keep proportions when it scales one axis.
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

-- ======================================================================
-- Module: Vfx   (merged from Vfx.luau, 311 lines)
-- ======================================================================
__defs["Vfx"] = function()
-- Visual effects built on the particle textures every Roblox client ships
-- with (rbxasset://textures/particles/...). Nothing here needs an upload, so
-- the effects look the same in Studio, on desktop, on phones and on console.
--
-- Presets are tuned for the sanctuary's palette and kept cheap: low rates,
-- short lifetimes, and bursts that emit once and clean themselves up.
--
--   Vfx.attach(part, "Embers", { Color = ... })   -- a continuous emitter
--   Vfx.burst(position, "Shatter", { Color = ... }) -- a one-off, auto-cleaned
--   Vfx.beam(a0, a1, "Tether", { Color = ... })    -- a textured beam
--
-- Used by the server (ambient scenery emitters, replicated) and the client
-- (moment-to-moment effects, never replicated).

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Vfx = {}

local TEX = "rbxasset://textures/particles/"
Vfx.Textures = table.freeze({
	Sparkle = TEX .. "sparkles_main.dds",
	Fire = TEX .. "fire_main.dds",
	FireSparks = TEX .. "fire_sparks_main.dds",
	Smoke = TEX .. "smoke_main.dds",
	Glow = TEX .. "forcefield_glow_main.dds",
	Vortex = TEX .. "forcefield_vortex_main.dds",
	Core = TEX .. "explosion01_core_main.dds",
	Implosion = TEX .. "explosion01_implosion_main.dds",
	Shockwave = TEX .. "explosion01_shockwave_main.dds",
	BlastSmoke = TEX .. "explosion01_smoke_main.dds",
})

type Spec = { [string]: any }

local function seq(...: number): NumberSequence
	local values = { ... }
	local points = {}
	for i = 1, #values, 2 do
		table.insert(points, NumberSequenceKeypoint.new(values[i], values[i + 1]))
	end
	return NumberSequence.new(points)
end

local function colors(a: Color3, b: Color3?): ColorSequence
	return if b == nil then ColorSequence.new(a) else ColorSequence.new(a, b)
end

-- Presets. Color/Color2 are filled in per use; everything else is a
-- ParticleEmitter property.
local PRESETS: { [string]: Spec } = {
	-- Ambient, continuous.
	Embers = {
		Texture = Vfx.Textures.FireSparks,
		Size = seq(0, 0.35, 1, 0),
		Transparency = seq(0, 0.1, 0.7, 0.4, 1, 1),
		Lifetime = NumberRange.new(2, 3.6),
		Rate = 5,
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(22, 22),
		Acceleration = Vector3.new(0, 1.2, 0),
		RotSpeed = NumberRange.new(-60, 60),
		LightEmission = 1,
	},
	Flame = {
		Texture = Vfx.Textures.Fire,
		Size = seq(0, 1.6, 0.5, 1.2, 1, 0.2),
		Transparency = seq(0, 1, 0.12, 0.25, 0.7, 0.55, 1, 1),
		Lifetime = NumberRange.new(0.7, 1.2),
		Rate = 14,
		Speed = NumberRange.new(2.5, 4.5),
		SpreadAngle = Vector2.new(12, 12),
		Rotation = NumberRange.new(-180, 180),
		RotSpeed = NumberRange.new(-40, 40),
		LightEmission = 0.85,
		LightInfluence = 0,
	},
	Smoke = {
		Texture = Vfx.Textures.Smoke,
		Size = seq(0, 1.5, 1, 5),
		Transparency = seq(0, 1, 0.2, 0.72, 1, 1),
		Lifetime = NumberRange.new(3.5, 5.5),
		Rate = 2.5,
		Speed = NumberRange.new(1.5, 3),
		SpreadAngle = Vector2.new(18, 18),
		Rotation = NumberRange.new(-180, 180),
		RotSpeed = NumberRange.new(-12, 12),
		Acceleration = Vector3.new(0.6, 0.8, 0),
		LightInfluence = 0.6,
	},
	Motes = {
		Texture = Vfx.Textures.Sparkle,
		Size = seq(0, 0, 0.3, 0.32, 1, 0),
		Transparency = seq(0, 0.2, 1, 1),
		Lifetime = NumberRange.new(4, 7),
		Rate = 3,
		Speed = NumberRange.new(0.4, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.25, 0),
		RotSpeed = NumberRange.new(-30, 30),
		LightEmission = 1,
		LightInfluence = 0,
	},
	Halo = {
		-- A soft glow that sits on the part: one long-lived particle at a time.
		Texture = Vfx.Textures.Glow,
		Size = seq(0, 3.2, 0.5, 3.6, 1, 3.2),
		Transparency = seq(0, 1, 0.25, 0.62, 0.75, 0.62, 1, 1),
		Lifetime = NumberRange.new(2.4, 2.4),
		Rate = 1.1,
		Speed = NumberRange.new(0, 0),
		LockedToPart = true,
		LightEmission = 1,
		LightInfluence = 0,
		ZOffset = -0.5,
	},
	Swirl = {
		Texture = Vfx.Textures.Vortex,
		Size = seq(0, 6, 1, 7),
		Transparency = seq(0, 1, 0.3, 0.55, 0.7, 0.55, 1, 1),
		Lifetime = NumberRange.new(2.5, 2.5),
		Rate = 1.2,
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(40, 40),
		LockedToPart = true,
		LightEmission = 1,
		LightInfluence = 0,
	},
	Rising = {
		-- Sparks drifting up a column (waystones, the Warden forming).
		Texture = Vfx.Textures.Sparkle,
		Size = seq(0, 0.45, 1, 0),
		Transparency = seq(0, 0.1, 1, 1),
		Lifetime = NumberRange.new(1.4, 2.4),
		Rate = 10,
		Speed = NumberRange.new(3, 7),
		SpreadAngle = Vector2.new(8, 8),
		LightEmission = 1,
		LightInfluence = 0,
	},

	-- One-off bursts (Emit counts come from the burst call).
	Shatter = {
		Texture = Vfx.Textures.Sparkle,
		Size = seq(0, 0.55, 1, 0),
		Transparency = seq(0, 0, 1, 1),
		Lifetime = NumberRange.new(0.5, 1.1),
		Speed = NumberRange.new(10, 22),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -24, 0),
		Drag = 2.5,
		RotSpeed = NumberRange.new(-200, 200),
		LightEmission = 1,
		LightInfluence = 0,
	},
	Flash = {
		Texture = Vfx.Textures.Core,
		Size = seq(0, 2, 0.3, 6, 1, 7),
		Transparency = seq(0, 0, 0.4, 0.4, 1, 1),
		Lifetime = NumberRange.new(0.35, 0.45),
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		LightEmission = 1,
		LightInfluence = 0,
	},
	Implode = {
		Texture = Vfx.Textures.Implosion,
		Size = seq(0, 10, 1, 0.5),
		Transparency = seq(0, 1, 0.3, 0.3, 1, 1),
		Lifetime = NumberRange.new(0.9, 0.9),
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		LightEmission = 1,
		LightInfluence = 0,
	},
	Shockwave = {
		-- Lies flat on the ground: the plane is perpendicular to its (upward) velocity.
		Texture = Vfx.Textures.Shockwave,
		Size = seq(0, 2, 1, 30),
		Transparency = seq(0, 0.1, 0.6, 0.5, 1, 1),
		Lifetime = NumberRange.new(0.6, 0.6),
		Speed = NumberRange.new(0.01, 0.01),
		EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Rotation = NumberRange.new(0, 360),
		LightEmission = 1,
		LightInfluence = 0,
	},
	Dust = {
		Texture = Vfx.Textures.BlastSmoke,
		Size = seq(0, 3, 1, 9),
		Transparency = seq(0, 0.4, 1, 1),
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(8, 16),
		SpreadAngle = Vector2.new(80, 10),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 3,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-30, 30),
		LightInfluence = 0.7,
	},
	Spark = {
		Texture = Vfx.Textures.FireSparks,
		Size = seq(0, 0.4, 1, 0),
		Transparency = seq(0, 0, 1, 1),
		Lifetime = NumberRange.new(0.25, 0.5),
		Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(70, 70),
		Drag = 4,
		LightEmission = 1,
		LightInfluence = 0,
	},
}

Vfx.PRESETS = PRESETS

local function apply(emitter: ParticleEmitter, spec: Spec, overrides: Spec?)
	for key, value in spec do
		(emitter :: any)[key] = value
	end
	if overrides ~= nil then
		for key, value in overrides do
			if key == "Color" or key == "Color2" then
				continue
			end
			(emitter :: any)[key] = value
		end
		local color = overrides.Color
		if typeof(color) == "Color3" then
			emitter.Color = colors(color, overrides.Color2)
		elseif typeof(color) == "ColorSequence" then
			emitter.Color = color
		end
	end
end

-- A continuous emitter on a part or attachment.
function Vfx.attach(parent: Instance, preset: string, overrides: Spec?): ParticleEmitter
	local spec = PRESETS[preset]
	assert(spec ~= nil, "unknown vfx preset " .. preset)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Vfx" .. preset
	apply(emitter, spec, overrides)
	emitter.Parent = parent
	return emitter
end

-- A one-off burst at a world position, cleaned up after its longest particle.
function Vfx.burst(position: Vector3, preset: string, count: number, overrides: Spec?, parent: Instance?): ParticleEmitter
	local holder = Instance.new("Part")
	holder.Name = "VfxBurst"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	holder.Parent = parent or Workspace
	local emitter = Vfx.attach(holder, preset, overrides)
	emitter.Rate = 0
	emitter:Emit(math.max(1, math.floor(count)))
	Debris:AddItem(holder, emitter.Lifetime.Max + 0.5)
	return emitter
end

-- A textured beam between two attachments.
function Vfx.beam(a0: Attachment, a1: Attachment, preset: string, overrides: Spec?): Beam
	local beam = Instance.new("Beam")
	beam.Name = "Vfx" .. preset
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 16
	if preset == "Tether" then
		beam.Texture = Vfx.Textures.Sparkle
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 4
		beam.TextureSpeed = 1.6
		beam.Width0, beam.Width1 = 1.2, 0.4
		beam.Transparency = seq(0, 0.35, 0.5, 0.1, 1, 0.5)
		beam.CurveSize0, beam.CurveSize1 = 4, -4
	elseif preset == "Column" then
		beam.Texture = Vfx.Textures.Glow
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.Width0, beam.Width1 = 5, 1.5
		beam.Transparency = seq(0, 0.3, 1, 1)
	else
		error("unknown beam preset " .. preset)
	end
	if overrides ~= nil then
		local color = overrides.Color
		if typeof(color) == "Color3" then
			beam.Color = colors(color, overrides.Color2)
		end
		for key, value in overrides do
			if key ~= "Color" and key ~= "Color2" then
				(beam :: any)[key] = value
			end
		end
	end
	beam.Parent = a0
	return beam
end

return Vfx
end

-- ======================================================================
-- Module: SanctuaryConfig   (merged from SanctuaryConfig.luau, 166 lines)
-- ======================================================================
__defs["SanctuaryConfig"] = function()
-- Tuning for the two sanctuary features: ore outcrops and the Rift Warden.
--
-- Pure data (colours are plain RGB triples, not Color3) so the same numbers
-- are shared by the server services, the client and the Lune tests
-- (scripts/verify_sanctuary_world.luau). GameConfig exposes it as
-- GameConfig.Ore and GameConfig.RiftBoss.

type Rgb = { number }

type OreType = {
	Id: string,
	Name: string,
	-- Where it grows (SanctuaryLayout region id).
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
	-- What it improves: Production / Capacity / Tap / BossDamage / OreYield.
	Effect: string,
	PerLevel: number,
	MaxLevel: number,
	-- Ore cost of the first level, by ore id; each level multiplies by Scale.
	Cost: { [string]: number },
	Scale: number,
}

local SanctuaryConfig = {}

SanctuaryConfig.Ore = {
	-- Seconds before a node a player mined grows back for that player.
	RegrowSeconds = 90,
	-- How long the mining prompt is held.
	HoldSeconds = 1.1,
	-- Mining reach: prompt distance, and the server's own check (with slack).
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

SanctuaryConfig.RiftBoss = {
	Name = "The Rift Warden",
	Kind = "Warden",
	Title = "Keeper of the Riftmaw",
	-- Where it fights (a SanctuaryLayout id) and how players are told to find it.
	Island = "Riftmaw",
	Approach = "Open the rift and head south to fight it.",
	-- Which audio cue plays for each beat. Every boss names its own so the fights sound
	-- different; Music is the looping bed layered over the region's while it fights
	-- (Bed is a sanctuary ambience region; set Id to an uploaded track to use that instead).
	Cues = {
		Forming = "wardenForming",
		Awake = "wardenAwake",
		Charge = "wardenSlamCharge",
		Land = "wardenSlam",
		Phase = "wardenAwake",
		Defeat = "wardenDefeat",
		Escape = "wardenEscape",
	},
	Music = { Bed = "amb_riftmaw", Id = 0, Pitch = 0.88, Level = 0.5 },
	-- Colours the client dresses the boss, its telegraphs and its cinematic in.
	Theme = {
		Primary = { 128, 92, 255 },
		Hot = { 214, 196, 255 },
		Alert = { 255, 84, 120 },
	},
	-- Health fractions at which the boss changes phase (phase 1 above the first). Every
	-- phase after the first speeds it up (PhaseDelayScale) and unlocks harder attacks.
	Phases = { 0.66, 0.33 },
	-- Multiplier on the wait between attacks, per phase (the last entry holds).
	PhaseDelayScale = { 1, 0.8, 0.62 },
	-- Weighted attack list. MinPhase gates an attack until the boss has reached it.
	-- Params override what the attack reads; Slam/TwinSlam use the Slam* fields below.
	Attacks = {
		{ Kind = "Slam", Weight = 1 },
		{ Kind = "TwinSlam", Weight = 0.8, MinPhase = 2 },
	},	-- Quiet time between appearances, and the first appearance after a server starts.
	IntervalSeconds = 540,
	FirstDelaySeconds = 150,
	-- The Warden takes shape in the Riftmaw before it can be struck.
	FormingSeconds = 40,
	-- How long it stays before slipping back into the rift.
	ActiveSeconds = 150,
	-- How long the defeat / escape moment plays before it goes quiet.
	OutroSeconds = 6,
	-- Health: a base plus a share per fighter in the sanctuary when it wakes.
	BaseHealth = 900,
	HealthPerFighter = 700,
	-- Strikes.
	StrikeCooldown = 0.28,
	StrikeRange = 64,
	BaseDamage = 12,
	DamagePerLevel = 2.5,
	CritChance = 0.12,
	CritMultiplier = 2,
	-- Slams: a telegraphed ring on the arena floor that staggers anyone inside.
	SlamIntervalMin = 6,
	SlamIntervalMax = 9,
	SlamTelegraphSeconds = 1.7,
	SlamRadius = 24,
	DazeSeconds = 2.2,
	-- Fewer strikes than this and a fighter was only passing through.
	MinStrikesForReward = 3,
	-- Reward = Base + Share x (the fighter's share of all damage dealt).
	Rewards = {
		Stardust = { Base = 40, Share = 360 },
		Starsteel = { Base = 2, Share = 6 },
		Emberite = { Base = 4, Share = 8 },
		Voidglass = { Base = 3, Share = 7 },
	},
}

-- The roster rotates: each appearance is the next boss in this list. Every boss after the
-- Warden inherits its timings, strikes and rewards and changes only what makes it
-- different; `Attacks` is replaced wholesale (never merged) so a boss owns its moveset.
local function bossFrom(base, overrides)
	local boss = table.clone(base)
	for key, value in overrides do
		boss[key] = value
	end
	return boss
end

-- The Hollow Choir (Voidglass Hollows): a conductor of glass. Its attack is a ripple of
-- shockwave rings; the safe ground is the gaps between them, so the fight is about
-- reading the rhythm and stepping between beats, not about outrunning one big circle.
local HollowChoir = bossFrom(SanctuaryConfig.RiftBoss, {
	Name = "The Hollow Choir",
	Kind = "Choir",
	Title = "Seven voices, one silence",
	Island = "ChoirIsle",
	Approach = "Cross the Riftmaw's western bridge to the Hall of the Hollow Choir.",
	Cues = {
		Forming = "echoCapture",
		Awake = "discovery",
		Charge = "echoTune",
		Land = "oreCollect",
		Phase = "successChime",
		Defeat = "rebirthBloom",
		Escape = "reactorStabilize",
	},
	Music = { Bed = "amb_hollows", Id = 0, Pitch = 1.3, Level = 0.46, Effect = "Reverb" },
	Theme = {
		Primary = { 86, 200, 255 },
		Hot = { 214, 244, 255 },
		Alert = { 120, 255, 236 },
	},
	BaseHealth = 1000,
	HealthPerFighter = 760,
	SlamIntervalMin = 5,
	SlamIntervalMax = 8,
	Attacks = {
		-- Three beats out from the centre; the gaps between rings are safe.
		{ Kind = "Rings", Weight = 1, Params = { Count = 3, FirstRadius = 16, Gap = 20, Width = 5.5, StepSeconds = 0.6, TelegraphSeconds = 2 } },
		-- Phase 2: a longer, tighter phrase.
		{ Kind = "Rings", Weight = 1, MinPhase = 2, Params = { Count = 4, FirstRadius = 14, Gap = 15, Width = 5, StepSeconds = 0.5, TelegraphSeconds = 2 } },
		-- Phase 3 adds the old slam on top of the rhythm.
		{ Kind = "Slam", Weight = 0.7, MinPhase = 3 },
	},
})

-- The Cinder Regent (Emberreach): a crown of fire. Its attack is a slow rotating beam; the
-- answer is to keep moving around it. It slams and twin-slams as it is worn down.
local CinderRegent = bossFrom(SanctuaryConfig.RiftBoss, {
	Name = "The Cinder Regent",
	Kind = "Regent",
	Title = "The last crown of Emberreach",
	Island = "RegentIsle",
	Approach = "Cross the Riftmaw's eastern bridge to the Cinderthrone.",
	Cues = {
		Forming = "domainCharge",
		Awake = "domainImpact",
		Charge = "bootSlamCharge",
		Land = "bootImpact",
		Phase = "domainCrack",
		Defeat = "prestige",
		Escape = "bootAftershock",
	},
	Music = { Bed = "amb_ember", Id = 0, Pitch = 0.72, Level = 0.56, Effect = "Distortion" },
	Theme = {
		Primary = { 255, 132, 48 },
		Hot = { 255, 226, 170 },
		Alert = { 255, 70, 40 },
	},
	BaseHealth = 1200,
	HealthPerFighter = 900,
	ActiveSeconds = 165,
	SlamIntervalMin = 6,
	SlamIntervalMax = 9,
	Attacks = {
		{ Kind = "Sweep", Weight = 1, Params = { Seconds = 5.2, Speed = 0.85, HalfWidth = 0.17, Range = 84, TelegraphSeconds = 1.6 } },
		{ Kind = "Slam", Weight = 0.6 },
		{ Kind = "TwinSlam", Weight = 0.7, MinPhase = 2 },
		-- Phase 3: a faster beam, the other way round.
		{ Kind = "Sweep", Weight = 1, MinPhase = 3, Params = { Seconds = 4.4, Speed = 1.25, HalfWidth = 0.2, Range = 84, TelegraphSeconds = 1.2 } },
	},
})

SanctuaryConfig.RiftBosses = table.freeze({ SanctuaryConfig.RiftBoss, HollowChoir, CinderRegent })

return SanctuaryConfig
end

-- ======================================================================
-- Module: SanctuaryLayout   (merged from SanctuaryLayout.luau, 319 lines)
-- ======================================================================
__defs["SanctuaryLayout"] = function()
-- The shape of the sanctuary: a hub of floating stone around the forge altar,
-- four island regions reached by long sky bridges, waystones to travel between
-- them, ore outcrop sites and the Riftmaw arena.
--
--                    Starsteel Spire (N, high)
--                            |
--   Voidglass Hollows (W) -- Forge Heart -- Emberreach (E)
--                            |
--                    The Riftmaw (S, arena)
--
-- Pure data + math on plain {X, Y, Z} tables (no Vector3), relative to ORIGIN,
-- so the world builder (WorldService), the ore and boss services, the client
-- and the Lune tests (scripts/verify_sanctuary_world.luau) all read one map.

type Point = { X: number, Y: number, Z: number }

type Region = {
	Id: string,
	Name: string,
	Center: Point,
	-- Radius of the walkable plateau; its top surface is at Center.Y.
	Radius: number,
	-- Terrain materials for the plateau top and the rock beneath.
	Top: string,
	Under: string,
	-- Ore that grows here (nil for the hub and the arena).
	Ore: string?,
	OreSites: number,
}

type Bridge = {
	Region: string,
	From: Point,
	To: Point,
	Control: Point,
	Width: number,
}

type Waystone = { Id: string, Name: string, Region: string, Position: Point }
type OreSite = { Id: string, Region: string, Ore: string, Position: Point }

local Layout = {}

Layout.ORIGIN = table.freeze({ X = 1680, Y = 248, Z = -220 })

-- The hub is the original hand-built forge deck. A terrain ring widens it; its
-- surface sits a little below the deck parts so they stand on top of it.
Layout.HUB_RADIUS = 62
Layout.HUB_TOP = -1.5
-- Everything walkable lies within this horizontal radius of the origin.
Layout.WORLD_RADIUS = 560
-- A character this far below the origin has fallen off the world.
Layout.KILL_DEPTH = 230

local REGIONS: { Region } = {
	{
		Id = "Heart",
		Name = "Forge Heart",
		Center = { X = 0, Y = -1.5, Z = 0 },
		Radius = 62,
		Top = "Slate",
		Under = "Basalt",
		Ore = nil,
		OreSites = 0,
	},
	{
		Id = "Emberreach",
		Name = "Emberreach",
		Center = { X = 312, Y = 10, Z = -72 },
		Radius = 112,
		Top = "Basalt",
		Under = "Rock",
		Ore = "Emberite",
		OreSites = 12,
	},
	{
		Id = "Hollows",
		Name = "Voidglass Hollows",
		Center = { X = -312, Y = -2, Z = -48 },
		Radius = 112,
		Top = "Glacier",
		Under = "Rock",
		Ore = "Voidglass",
		OreSites = 12,
	},
	{
		Id = "Spire",
		Name = "Starsteel Spire",
		Center = { X = 0, Y = 58, Z = -362 },
		Radius = 66,
		Top = "Limestone",
		Under = "Rock",
		Ore = "Starsteel",
		OreSites = 7,
	},
	{
		Id = "Riftmaw",
		Name = "The Riftmaw",
		Center = { X = 0, Y = -8, Z = 362 },
		Radius = 98,
		Top = "Asphalt",
		Under = "Rock",
		Ore = nil,
		OreSites = 0,
	},
}
for _, region in REGIONS do
	table.freeze(region.Center)
	table.freeze(region)
end
table.freeze(REGIONS)

-- Boss islands: one arena of their own for each boss after the Warden, off the Riftmaw's
-- flanks and joined to it by a bridge. They are deliberately not in REGIONS: they have no
-- ore, no hub bridge and no waystone (the Riftmaw's is the way in), so every rule that
-- walks the five regions stays as it was.
local ISLES: { Region } = {
	{
		Id = "ChoirIsle",
		Name = "Hall of the Hollow Choir",
		Center = { X = -300, Y = -14, Z = 330 },
		Radius = 84,
		Top = "Glacier",
		Under = "Rock",
		Ore = nil,
		OreSites = 0,
	},
	{
		Id = "RegentIsle",
		Name = "The Cinderthrone",
		Center = { X = 300, Y = 6, Z = 330 },
		Radius = 84,
		Top = "Basalt",
		Under = "Rock",
		Ore = nil,
		OreSites = 0,
	},
}
for _, isle in ISLES do
	table.freeze(isle.Center)
	table.freeze(isle)
end
table.freeze(ISLES)

local BY_ID: { [string]: Region } = {}
for _, region in REGIONS do
	BY_ID[region.Id] = region
end
for _, isle in ISLES do
	BY_ID[isle.Id] = isle
end

local function point(x: number, y: number, z: number): Point
	return { X = x, Y = y, Z = z }
end

local function horizontal(a: Point, b: Point): number
	local dx, dz = b.X - a.X, b.Z - a.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Unit direction on the ground plane from a to b.
local function heading(a: Point, b: Point): (number, number)
	local length = horizontal(a, b)
	if length < 1e-6 then
		return 0, -1
	end
	return (b.X - a.X) / length, (b.Z - a.Z) / length
end

function Layout.regions(): { Region }
	return REGIONS
end

function Layout.region(id: string): Region?
	return BY_ID[id]
end

function Layout.isles(): { Region }
	return ISLES
end

-- Where an isle's bridge meets its plateau, and the direction it arrives from (pointing
-- from the isle toward the Riftmaw).
function Layout.isleLanding(isle: Region): (Point, number, number)
	local maw = BY_ID.Riftmaw
	local dx, dz = heading(isle.Center, maw.Center)
	local rim = isle.Radius - 4
	return point(isle.Center.X + dx * rim, isle.Center.Y, isle.Center.Z + dz * rim), dx, dz
end

-- The bridge from the Riftmaw's rim to each boss island.
function Layout.isleBridges(): { Bridge }
	local maw = BY_ID.Riftmaw
	local result: { Bridge } = {}
	for index, isle in ISLES do
		local dx, dz = heading(maw.Center, isle.Center)
		local from = point(maw.Center.X + dx * (maw.Radius - 6), maw.Center.Y, maw.Center.Z + dz * (maw.Radius - 6))
		local to = Layout.isleLanding(isle)
		local span = horizontal(from, to)
		local side = if index % 2 == 0 then 1 else -1
		local px, pz = -dz, dx
		table.insert(result, {
			Region = isle.Id,
			From = from,
			To = to,
			Control = point((from.X + to.X) / 2 + px * span * 0.1 * side, (from.Y + to.Y) / 2, (from.Z + to.Z) / 2 + pz * span * 0.1 * side),
			Width = 14,
		})
	end
	return result
end

function Layout.distance(a: Point, b: Point): number
	return horizontal(a, b)
end

-- Where the bridge from the hub meets a region's plateau, and the direction it
-- arrives from (pointing from the region toward the hub).
function Layout.landing(region: Region): (Point, number, number)
	local hub = REGIONS[1].Center
	local dx, dz = heading(region.Center, hub)
	local rim = region.Radius - 4
	return point(region.Center.X + dx * rim, region.Center.Y, region.Center.Z + dz * rim), dx, dz
end

-- The sky bridges: one from the hub rim to each outer region, bowed gently to
-- one side so the walk reads as a path rather than a ruler line.
function Layout.bridges(): { Bridge }
	local hub = REGIONS[1]
	local result: { Bridge } = {}
	for index, region in REGIONS do
		if region.Id == hub.Id then
			continue
		end
		local dx, dz = heading(hub.Center, region.Center)
		local from = point(hub.Center.X + dx * (Layout.HUB_RADIUS - 6), Layout.HUB_TOP, hub.Center.Z + dz * (Layout.HUB_RADIUS - 6))
		local to = Layout.landing(region)
		local span = horizontal(from, to)
		local side = if index % 2 == 0 then 1 else -1
		-- Perpendicular on the ground plane.
		local px, pz = -dz, dx
		local control = point(
			(from.X + to.X) / 2 + px * span * 0.1 * side,
			(from.Y + to.Y) / 2,
			(from.Z + to.Z) / 2 + pz * span * 0.1 * side
		)
		table.insert(result, {
			Region = region.Id,
			From = from,
			To = to,
			Control = control,
			Width = if region.Id == "Riftmaw" then 16 else 12,
		})
	end
	return result
end

-- Points along a bridge's curve, roughly `spacing` studs apart, ends included.
function Layout.bridgePoints(bridge: Bridge, spacing: number): { Point }
	local span = horizontal(bridge.From, bridge.To) + math.abs(bridge.To.Y - bridge.From.Y)
	local steps = math.max(2, math.ceil(span / math.max(4, spacing)))
	local points: { Point } = {}
	for step = 0, steps do
		local t = step / steps
		local u = 1 - t
		table.insert(
			points,
			point(
				u * u * bridge.From.X + 2 * u * t * bridge.Control.X + t * t * bridge.To.X,
				u * u * bridge.From.Y + 2 * u * t * bridge.Control.Y + t * t * bridge.To.Y,
				u * u * bridge.From.Z + 2 * u * t * bridge.Control.Z + t * t * bridge.To.Z
			)
		)
	end
	return points
end

-- One waystone per region, just inside the bridge landing and off to its side
-- so it never blocks the path. The hub's stands beside the spawn causeway.
function Layout.waystones(): { Waystone }
	local result: { Waystone } = {
		{ Id = "Heart", Name = "Forge Heart", Region = "Heart", Position = point(24, Layout.HUB_TOP, 24) },
	}
	for _, region in REGIONS do
		if region.Id == "Heart" then
			continue
		end
		local landing, dx, dz = Layout.landing(region)
		local px, pz = -dz, dx
		table.insert(result, {
			Id = region.Id,
			Name = region.Name,
			Region = region.Id,
			Position = point(landing.X - dx * 20 + px * 16, region.Center.Y, landing.Z - dz * 20 + pz * 16),
		})
	end
	return result
end

-- Ore outcrops: an inner and an outer ring on each ore region's plateau, with
-- a clear corridor left where the bridge lands and around the waystone.
function Layout.oreSites(): { OreSite }
	local result: { OreSite } = {}
	for _, region in REGIONS do
		local ore = region.Ore
		if ore == nil or region.OreSites <= 0 then
			continue
		end
		local _, dx, dz = Layout.landing(region)
		local landingAngle = math.atan2(dz, dx)
		local inner = math.floor(region.OreSites * 0.4 + 0.5)
		local rings = {
			{ count = inner, radius = region.Radius * 0.42, offset = 0.35 },
			{ count = region.OreSites - inner, radius = region.Radius * 0.74, offset = 0 },
		}
		local index = 0
		for _, ring in rings do
			-- Spread the ring's sites over the arc that avoids the landing corridor.
			local clear = math.rad(34)
			local arc = 2 * math.pi - clear * 2
			for k = 1, ring.count do
				local angle = landingAngle + clear + arc * ((k - 1 + 0.5 + ring.offset * 0.5) / ring.count)
				index += 1
				table.insert(result, {
					Id = `{region.Id}-{index}`,
					Region = region.Id,
					Ore = ore,
					Position = point(
						region.Center.X + math.cos(angle) * ring.radius,
						region.Center.Y,
						region.Center.Z + math.sin(angle) * ring.radius
					),
				})
			end
		end
	end
	return result
end

-- The Riftmaw arena: where the Rift Warden hovers and where strikes count.
function Layout.arena(id: string?): { Center: Point, Radius: number, Hover: Point, PillarRadius: number }
	local maw = BY_ID[id or "Riftmaw"] or BY_ID.Riftmaw
	return {
		Center = maw.Center,
		Radius = maw.Radius - 10,
		Hover = point(maw.Center.X, maw.Center.Y + 26, maw.Center.Z),
		PillarRadius = maw.Radius - 12,
	}
end

-- The region a point stands in, or nil out on a bridge.
function Layout.regionAt(p: Point): Region?
	for _, region in REGIONS do
		if horizontal(p, region.Center) <= region.Radius + 6 then
			return region
		end
	end
	for _, isle in ISLES do
		if horizontal(p, isle.Center) <= isle.Radius + 6 then
			return isle
		end
	end
	return nil
end

function Layout.nearestWaystone(p: Point): Waystone
	local best: Waystone? = nil
	local bestDistance = math.huge
	for _, stone in Layout.waystones() do
		local d = horizontal(p, stone.Position)
		if d < bestDistance then
			best, bestDistance = stone, d
		end
	end
	return best :: Waystone
end

function Layout.waystone(id: string): Waystone?
	for _, stone in Layout.waystones() do
		if stone.Id == id then
			return stone
		end
	end
	return nil
end

-- Inside the walkable world (and not fallen through it)?
function Layout.inBounds(p: Point): boolean
	return horizontal(p, point(0, 0, 0)) <= Layout.WORLD_RADIUS and p.Y > -Layout.KILL_DEPTH
end

return Layout
end

-- ======================================================================
-- Module: ForgeLevels   (merged from ForgeLevels.luau, 296 lines)
-- ======================================================================
__defs["ForgeLevels"] = function()
-- Forge Levels: the game's single progression ladder.
--
-- Before this, each of ~30 features had its own unlock rule measured in one of
-- six unrelated things (lifetime flux, machine levels, play time, rebirths,
-- domain rank, or "always"), so there was no single answer to "how far along
-- am I, and what do I do next?". Two of those rules even measured machines,
-- which reset on rebirth, so Story and Milestones re-locked every run.
--
-- Now there is one ladder. Every level has exactly one plain-language goal, and
-- every feature opens at a level. Goals only use lifetime numbers that never go
-- down, so nothing ever re-locks. A player's level is the HIGHEST level whose
-- goal they meet, which means progress made before this ladder existed (or
-- before a counter was added) can never strand a veteran on a low level.
--
-- Pure data + logic: no Roblox instances, so the ladder is unit tested under
-- Lune (scripts/verify_forge_levels.luau). GameConfig derives every feature's
-- unlock rule from this ladder; ProgressionGate supplies the progress numbers.

type Goal = {
	-- A ProgressionGate progress kind. Only kinds that never decrease belong
	-- here (see LIFETIME_KINDS).
	Kind: string,
	Target: number,
	-- What the player does, as they would say it.
	Text: string,
}

type LevelDef = {
	Level: number,
	Tier: string,
	-- Nil only for level 1, where everyone starts.
	Goal: Goal?,
	-- Feature ids (GameConfig.Unlocks keys) this level opens, in display order.
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

-- Progress kinds whose values only ever grow. Machine levels and the current
-- world reset on rebirth, and play time rewards idling over playing, so none
-- of those may be a level goal.
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
		Unlocks = { "Mail", "Wheel", "Inventory", "Foundry" },
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
		Unlocks = { "Rebirth" },
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
		-- 10 rebirths is exactly what the first domain expansion costs
		-- (GameConfig.Domain.BaseRequiredRebirths), so Domain opens the moment
		-- the player can actually use it.
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

-- "Reach Level 6 (Apprentice)" -- the requirement shown for a locked feature.
function ForgeLevels.requirementText(level: number): string
	local def = LADDER[level]
	if def == nil then
		return `Reach Level {level}`
	end
	return `Reach Level {level} ({def.Tier})`
end

-- Feature id -> the level that opens it.
function ForgeLevels.unlockLevels(): { [string]: number }
	local result = {}
	for _, def in LADDER do
		for _, featureId in def.Unlocks do
			result[featureId] = def.Level
		end
	end
	return result
end

-- The player's level for a progress lookup: the highest level whose goal is
-- met. Level 1 needs nothing. Each kind is read once, however many levels use it.
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

-- Everything the client needs to draw the level bar, from the same lookup.
-- `Next.Progress` is always below `Next.Target`: if the next goal were met,
-- the player would already be on that level.
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
			-- Clamped so a huge lifetime number never has to travel to the client.
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

-- ======================================================================
-- Module: LiveOpsConfig   (merged from LiveOpsConfig.luau, 46 lines)
-- ======================================================================
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

-- ======================================================================
-- Module: MonetizationConfig   (merged from MonetizationConfig.luau, 200 lines)
-- ======================================================================
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

-- ======================================================================
-- Module: CapacityProjection   (merged from CapacityProjection.luau, 89 lines)
-- ======================================================================
__defs["CapacityProjection"] = function()
-- Pure steady-production + vault-capacity projection. No Roblox services —
-- Economy and Lune verify scripts share this so capacity/steady math can be
-- tested without Studio. Effect totals and zone/permanent multipliers are
-- injected by the caller; temporary boost/surge stay out of Steady.

local CapacityProjection = {}

type SteadyParts = {
	EfficiencyLevel: number,
	ZoneMultiplier: number,
	PermanentMultiplier: any,
	-- Additive effect fractions (each applied as 1+x), in Economy order:
	-- Grid, Echo, Artifact, Item, Anomaly, Lab, Pass, Guild.
	Additives: { number },
	SocialMultiplier: number,
	MasteryMultiplier: number,
	-- Continuum production scale is already a multiplier (not 1+x).
	ContinuumProduction: any,
}

-- Permanent/steady multiplier only — excludes ActiveBoost and Anomaly Surge.
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
	-- Additive capacity fractions (1+x each), Economy order:
	-- Grid, Echo, Artifact, Item, Anomaly, Lab, Pass, Guild, ForgePath.
	Additives: { number },
	DomainRank: number,
	CapacityPerRank: number,
	BoostCapacityMultiplier: number,
	MaxSeconds: number,
	DomainTreeCapacity: number,
}

-- Vault fill-time in seconds. DomainTreeCapacity is applied AFTER the max clamp
-- (matches Economy.Capacity — do not reorder).
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

-- Vault size from steady output × seconds × continuum capacity scale.
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

-- Display helper: capacity / steady → effective seconds (0 when idle).
function CapacityProjection.CapacitySeconds(omegaMath, capacity: any, steadyProduction: any, lte: (any, any) -> boolean): number
	if lte(steadyProduction, 0) then
		return 0
	end
	return omegaMath.ToNumber(omegaMath.Div(capacity, steadyProduction))
end

return table.freeze(CapacityProjection)
end

-- ======================================================================
-- Module: ZoneUnlock   (merged from ZoneUnlock.luau, 85 lines)
-- ======================================================================
__defs["ZoneUnlock"] = function()
-- Pure zone travel / unlock gate checks. No Roblox services — ServerServices
-- and Lune verify scripts share this so world-order / rebirth / core / flux
-- gates can be tested without Studio. Cash comparison is injected (Economy.Lt).

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

-- Boolean flags matching Overview world-row readiness (PageRouter / WorldRow).
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

-- Server unlock/travel decision. Returns kind + optional error message.
-- kind: "Travel" | "Unlock" | "Error"
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

-- ======================================================================
-- Suite entry point
-- ======================================================================
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		return __load(name)
	end,
})
