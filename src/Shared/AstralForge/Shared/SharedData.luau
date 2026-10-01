--!strict
--[=[
	SharedData: merged module suite.
	Members (11): AssetKit, AssetManifest, Vfx, SanctuaryConfig, SanctuaryLayout, ForgeLevels, LiveOpsConfig, MonetizationConfig, CapacityProjection, ZoneUnlock, ProcAnim.

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
		-- Four beams of the seal fan out from it, telegraphed as thin lines, then fire.
		{ Kind = "Lances", Weight = 1, Params = { Count = 4, HalfWidth = 0.075, Range = 92, TelegraphSeconds = 1.8 } },
		{ Kind = "TwinSlam", Weight = 0.8, MinPhase = 2 },
		-- A well opens under a fighter and drags everyone toward it; the core then detonates.
		{ Kind = "GravityWell", Weight = 0.9, MinPhase = 2, Params = { Radius = 30, Core = 15, PullSeconds = 3, Strength = 34, TelegraphSeconds = 0.8 } },
		-- Rifts tear open under the fighters one after another.
		{ Kind = "Volley", Weight = 0.9, MinPhase = 2, Params = { Count = 5, StepSeconds = 0.4, Scatter = 8, RadiusScale = 0.6, TelegraphSeconds = 1.6, Element = "Void" } },
		-- Void wisps circle the arena and blow up unless cut down.
		{ Kind = "Summon", Weight = 0.8, MinPhase = 2, Params = { Count = 4, Health = 70, FuseSeconds = 9, Orbit = 34, OrbitSpeed = 0.5, BlastRadius = 11, TelegraphSeconds = 1.4, Element = "Void" } },
		-- Signature: a fault races out from the boss toward a fighter, then a cage of rifts closes.
		{ Kind = "Fissure", Weight = 0.9, Params = { Count = 6, FirstDistance = 14, Gap = 11, StepSeconds = 0.14, RadiusScale = 0.5, TelegraphSeconds = 1.6, Element = "Void" } },
		{ Kind = "Cage", Weight = 0.9, MinPhase = 3, Params = { Count = 7, Distance = 15, RadiusScale = 0.55, TelegraphSeconds = 2, Element = "Void" } },
		-- Phase 3: eight beams at once.
		{ Kind = "Lances", Weight = 1, MinPhase = 3, Params = { Count = 8, HalfWidth = 0.06, Range = 92, TelegraphSeconds = 1.7 } },
	},
	Dialogue = {
		Forming = { "[whisper]The seal... is [wave]thinning[/].[/]", "Something that was never meant to wake [glitch]is waking[/]." },
		Awake = { "[slow]Who opens[/] [big]the Riftmaw?[/]", "I have kept this door [beat] since before your stars had [hot]names[/].", "[shake]Turn back.[/] [beat] Or be [glitch]unmade[/]." },
		Phase2 = { "You fight like the rift itself. [beat] [hot]Without end.[/]", "Then I shall stop being [slow]gentle[/]." },
		Phase3 = { "[big][shake]ENOUGH.[/][/]", "The door [hot]STAYS SHUT[/]. [beat] Even if I must close it [glitch]with you inside[/]." },
		Defeat = { "[whisper]The seal... was never [wave]mine[/] to keep.[/]", "[slow]Go on, then.[/] [beat] See what waits [hot]behind it[/]." },
		Escape = { "The door closes. [beat] [wave]Remember what you could not finish.[/]" },
		Enrage = { "[shake]You are taking too long.[/] [beat] The door [hot]hungers[/].", "[glitch]ENOUGH GAMES.[/]" },
		Break = { "[big]Impossible![/]", "The seal... [shake]cracks[/]?" },
		Hit = { "Stay [hot]down[/].", "[shake]Do not rise.[/]", "Your light is [wave]small[/].", "Fall. [beat] [slow]Again.[/]", "[glitch]Pathetic.[/]" },
		Attack = {
			Slam = { "[big]KNEEL.[/]", "Fall.", "The floor [hot]remembers[/] weight." },
			TwinSlam = { "Two fall as [hot]one[/].", "[shake]Both of you.[/]" },
			GravityWell = { "Come [slow]closer[/].", "The rift will [hot]have you[/].", "[wave]Everything falls inward.[/]" },
			Lances = { "The seal's own edge. [beat] Cross it and be [hot]cut[/].", "[glitch]Lines of the door.[/]" },
			Volley = { "The door opens [hot]where you stand[/].", "[shake]Fall through.[/]", "[wave]Rifts, rifts, rifts.[/]" },
			Summon = { "Rise, [hot]keepers of the door[/].", "Let the dark have [glitch]hands[/].", "[whisper]Come, little shadows.[/]" },
			Fissure = { "The floor remembers the [hot]door[/].", "[big]Split.[/]", "[slow]Follow the crack...[/]" },
			Cage = { "Stay. [beat] The seal will [hot]close round you[/].", "[wave]No way out but through me.[/]" },
		},
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
		-- Every voice but the safe ones sings at once: stand in a pocket of calm.
		{ Kind = "Dissonance", Weight = 1, Params = { Zones = 3, ZoneRadius = 13, TelegraphSeconds = 2.8 } },
		-- One note struck three times in the same place, each wider than the last.
		{ Kind = "EchoSlam", Weight = 0.8, MinPhase = 2, Params = { Hits = 3, StepSeconds = 0.7, Growth = 1.22, TelegraphSeconds = 1.5 } },
		-- Shards of ice fall in a run of small, fast blows.
		{ Kind = "Volley", Weight = 0.9, Params = { Count = 5, StepSeconds = 0.3, Scatter = 6, RadiusScale = 0.6, TelegraphSeconds = 1.5, Element = "Frost" } },
		-- Frozen echoes drift round the hall; shatter them before they ring.
		{ Kind = "Summon", Weight = 0.8, MinPhase = 2, Params = { Count = 5, Health = 60, FuseSeconds = 8, Orbit = 30, OrbitSpeed = 0.6, BlastRadius = 10, TelegraphSeconds = 1.4, Element = "Frost" } },
		-- Signature: a chord of blows blooming outward from the conductor.
		{ Kind = "Starburst", Weight = 0.9, MinPhase = 2, Params = { Rings = 2, Points = 4, FirstDistance = 20, Gap = 22, StepSeconds = 0.5, RadiusScale = 0.5, TelegraphSeconds = 1.8, Element = "Frost" } },
		-- Phase 3: fewer pockets, a shorter warning, and the old slam on top.
		{ Kind = "Dissonance", Weight = 1, MinPhase = 3, Params = { Zones = 2, ZoneRadius = 11, TelegraphSeconds = 2.2 } },
		{ Kind = "Slam", Weight = 0.7, MinPhase = 3 },
	},
	Dialogue = {
		Forming = { "[wave]A note, held too long, begins to [hot]crack[/].[/]", "[whisper]Listen...[/] the hall is [pulse]humming[/]." },
		Awake = { "[wave]Seven voices woke.[/] [beat] One of them is singing [hot]for you[/].", "Listen. [beat] Between every note, there is a place to [hot]stand[/].", "Find it. [beat] Or we shall sing you [shake]quiet[/]." },
		Phase2 = { "[big]Louder.[/] The hall has not heard a true [hot]chord[/] in an age.", "[wave]More voices... more... [/][pulse]more[/]." },
		Phase3 = { "[shake]All voices -- together --[/] [big]NOW.[/]", "[glitch]Let the whole hall shatter with us![/]" },
		Defeat = { "[slow]The hall... falls [wave]silent[/].[/]", "It is so [whisper]quiet[/]. [beat] [hot]Thank you.[/]" },
		Escape = { "[wave]The song goes on without you.[/]" },
		Enrage = { "[wave]The hall grows [hot]impatient[/].[/]", "[shake]FASTER. LOUDER.[/]" },
		Break = { "[glitch]Out of... time...[/]", "[big]A false note![/]" },
		Hit = { "[glitch]Out of tune.[/]", "[hot]Flat.[/]", "That one [wave]rang false[/].", "[shake]Sour.[/] Sour!", "Again, [slow]but listen this time[/]." },
		Attack = {
			Rings = { "[hot]Hear[/] the rhythm.", "Step between the [pulse]beats[/].", "[wave]One... two... three...[/]" },
			Dissonance = { "Find the [hot]harmony[/].", "Only the [slow]still[/] notes are safe.", "[glitch]All discord, all at once.[/]" },
			EchoSlam = { "[wave]Echo... echo... [/][hot]echo[/].", "Struck [pulse]three times[/]. Hear it grow?" },
			Slam = { "A [shake]sour[/] note.", "[big]Fortissimo.[/]" },
			Volley = { "[hot]Shatter.[/]", "[wave]Glass rain.[/]", "[glitch]Every note, a blade.[/]" },
			Starburst = { "A chord, in [hot]every direction[/].", "[big]Bloom.[/]" },
			Summon = { "My echoes -- [hot]sing for me[/].", "[whisper]Cold little voices... wake.[/]", "[wave]Join the chorus.[/]" },
		},
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
		-- Fire rains on several fighters in quick succession.
		{ Kind = "Volley", Weight = 1, Params = { Count = 4, StepSeconds = 0.32, Scatter = 7, RadiusScale = 0.72, TelegraphSeconds = 1.5 } },
		{ Kind = "Slam", Weight = 0.5 },
		{ Kind = "TwinSlam", Weight = 0.6, MinPhase = 2 },
		-- A wall of flame crosses the arena with one gap to slip through.
		{ Kind = "Wall", Weight = 0.9, MinPhase = 2, Params = { Speed = 24, Half = 3, Range = 84, GapHalf = 9, TelegraphSeconds = 2.2 } },
		-- Signature: a river of lava splits the floor toward a fighter, and a ring of fire cages them.
		{ Kind = "Fissure", Weight = 0.9, Params = { Count = 7, FirstDistance = 12, Gap = 10, StepSeconds = 0.12, RadiusScale = 0.5, TelegraphSeconds = 1.6, Element = "Fire" } },
		{ Kind = "Cage", Weight = 0.8, MinPhase = 3, Params = { Count = 8, Distance = 16, RadiusScale = 0.55, TelegraphSeconds = 2, Element = "Fire" } },
		-- Fire from the sky across the whole arena.
		{ Kind = "Meteors", Weight = 1, MinPhase = 2, Params = { Count = 7, StepSeconds = 0.35, RadiusScale = 0.7, TelegraphSeconds = 1.9, Element = "Fire" } },
		-- Ember spirits circle the throne and burst if left alone.
		{ Kind = "Summon", Weight = 0.8, MinPhase = 2, Params = { Count = 4, Health = 90, FuseSeconds = 9, Orbit = 36, OrbitSpeed = 0.55, BlastRadius = 12, TelegraphSeconds = 1.4, Element = "Fire" } },
		{ Kind = "Meteors", Weight = 1, MinPhase = 3, Params = { Count = 11, StepSeconds = 0.28, RadiusScale = 0.7, TelegraphSeconds = 1.7, Element = "Fire" } },
		-- Phase 3: a faster beam, the other way round.
		{ Kind = "Sweep", Weight = 1, MinPhase = 3, Params = { Seconds = 4.4, Speed = 1.25, HalfWidth = 0.2, Range = 84, TelegraphSeconds = 1.2 } },
		{ Kind = "Volley", Weight = 1, MinPhase = 3, Params = { Count = 7, StepSeconds = 0.26, Scatter = 6, RadiusScale = 0.72, TelegraphSeconds = 1.3 } },
	},
	Dialogue = {
		Forming = { "The embers remember their [hot]king[/].", "[wave]Heat rises... [/][shake]as it should.[/]" },
		Awake = { "[big]KNEEL[/] before the last crown of [hot]Emberreach[/].", "You trespass on my throne [beat] and expect [slow]mercy?[/]", "Let the fire decide [beat] [shake]how long you last.[/]" },
		Phase2 = { "You [shake]dare[/] make me bleed? [beat] [hot]Fine.[/]", "[slow]Bow to the flame.[/]" },
		Phase3 = { "[big][shake]BURN.[/][/] Burn it all -- the throne, the sky, [hot]you[/]!", "[glitch]If I fall, the world falls with me![/]" },
		Defeat = { "A king... does not... [slow]fall[/] to...", "[whisper]The crown is yours.[/] [beat] It was always [hot]heavy[/]." },
		Escape = { "I retreat to my [hot]embers[/]. [beat] Not to you." },
		Enrage = { "[big]MY PATIENCE BURNS.[/]", "[shake]The crown demands [hot]ash[/]![/]" },
		Break = { "[shake]You... [hot]DARE[/]?[/]", "[big]Insolent embers![/]" },
		Hit = { "[hot]Ash.[/]", "[shake]Crawl.[/]", "You burn [slow]so brightly[/]. How briefly.", "[big]INSOLENT.[/]", "Is that all the [hot]fire[/] you carry?" },
		Attack = {
			Sweep = { "Run in circles, [hot]little ember[/].", "[wave]The beam turns... and turns...[/]" },
			Volley = { "[big]Rain, fire![/]", "Every one of you is a [hot]target[/]." },
			Slam = { "[shake]Crushed.[/]", "[big]Beneath my heel.[/]" },
			TwinSlam = { "Two! [beat] [hot]Two at once![/]", "[shake]Neither escapes.[/]" },
			Wall = { "The wall advances. Find the [hot]gap[/] -- or [shake]burn[/].", "[slow]Walk through fire, if you can.[/]" },
			Meteors = { "The sky is [hot]mine[/] to throw!", "Let the heavens burn [slow]with me[/].", "[big]FALL, STARS.[/]" },
			Summon = { "Rise, my [hot]cinders[/]!", "Guard the [shake]throne[/]!", "[wave]Ember spirits, attend me.[/]" },
			Fissure = { "The earth [hot]splits[/] for its king.", "[slow]A river of fire... for you.[/]" },
			Cage = { "A crown of flame -- [hot]for you[/].", "[shake]Kneel inside it.[/]" },
		},
	},
})

-- The Stormbound Seraph (Tempest Aerie): a wing of lightning. Its fights are fast and loud:
-- forked volleys, a fault of thunder down the floor, and the sky itself called down.
local StormSeraph = bossFrom(SanctuaryConfig.RiftBoss, {
	Name = "The Stormbound Seraph",
	Kind = "Seraph",
	Title = "Wings of the last tempest",
	Island = "StormIsle",
	Approach = "Take the Riftmaw's south-western bridge to the Tempest Aerie.",
	Cues = {
		Forming = "reactorStabilize",
		Awake = "domainImpact",
		Charge = "echoTune",
		Land = "bootImpact",
		Phase = "domainCrack",
		Defeat = "rebirthBloom",
		Escape = "wardenEscape",
	},
	Music = { Bed = "amb_spire", Id = 0, Pitch = 1.12, Level = 0.52, Effect = "Distortion" },
	Theme = {
		Primary = { 96, 168, 255 },
		Hot = { 232, 244, 255 },
		Alert = { 255, 232, 96 },
	},
	BaseHealth = 1100,
	HealthPerFighter = 820,
	SlamIntervalMin = 4.5,
	SlamIntervalMax = 7.5,
	PhaseDelayScale = { 1, 0.78, 0.58 },
	Attacks = {
		{ Kind = "Volley", Weight = 1, Params = { Count = 6, StepSeconds = 0.25, Scatter = 6, RadiusScale = 0.6, TelegraphSeconds = 1.4, Element = "Storm" } },
		{ Kind = "Lances", Weight = 1, Params = { Count = 4, HalfWidth = 0.07, Range = 92, TelegraphSeconds = 1.7 } },
		-- Signature: thunder runs down the floor toward a fighter in a line of blows.
		{ Kind = "Fissure", Weight = 1, Params = { Count = 7, FirstDistance = 12, Gap = 9, StepSeconds = 0.1, RadiusScale = 0.5, TelegraphSeconds = 1.5, Element = "Storm" } },
		{ Kind = "Starburst", Weight = 0.9, MinPhase = 2, Params = { Rings = 2, Points = 4, FirstDistance = 18, Gap = 20, StepSeconds = 0.5, RadiusScale = 0.5, TelegraphSeconds = 1.7, Element = "Storm" } },
		{ Kind = "Summon", Weight = 0.8, MinPhase = 2, Params = { Count = 5, Health = 70, FuseSeconds = 8, Orbit = 32, OrbitSpeed = 0.9, BlastRadius = 10, TelegraphSeconds = 1.4, Element = "Storm" } },
		{ Kind = "Meteors", Weight = 1, MinPhase = 3, Params = { Count = 10, StepSeconds = 0.26, RadiusScale = 0.6, TelegraphSeconds = 1.7, Element = "Storm" } },
		{ Kind = "Cage", Weight = 0.9, MinPhase = 3, Params = { Count = 7, Distance = 14, RadiusScale = 0.5, TelegraphSeconds = 1.9, Element = "Storm" } },
		{ Kind = "Lances", Weight = 1, MinPhase = 3, Params = { Count = 8, HalfWidth = 0.055, Range = 92, TelegraphSeconds = 1.6 } },
	},
	Dialogue = {
		Forming = { "The air tastes of [hot]iron[/]. [beat] Something is [pulse]gathering[/].", "[whisper]Do you hear the wires of the sky?[/]" },
		Awake = { "I am the storm that was [hot]promised[/].", "Every wire of the sky [wave]answers me[/].", "[slow]Stand still.[/] [beat] It will be over before the [big]thunder[/]." },
		Phase2 = { "You are [hot]quick[/]. [beat] Good. [beat] I am [shake]quicker[/].", "[wave]The clouds are gathering their courage.[/]" },
		Phase3 = { "[big]THE WHOLE SKY --[/] [shake]COME DOWN![/]", "[glitch]Let every cloud break at once![/]" },
		Defeat = { "The clouds... are [wave]parting[/].", "[slow]Let the quiet have the sky.[/]" },
		Escape = { "The storm moves on. [beat] [hot]So will its thunder.[/]" },
		Enrage = { "[shake]The storm [hot]breaks[/] its leash![/]", "[big]NO MORE WAITING.[/]" },
		Break = { "[glitch]Grounded...?[/]", "[shake]Impossible![/]" },
		Hit = { "[hot]Too slow.[/]", "[shake]Feel that?[/]", "You are a spark. I am the [big]STORM[/].", "[glitch]Static.[/]", "Flinch. [beat] [slow]Go on.[/]" },
		Attack = {
			Volley = { "[hot]Lightning[/] finds you.", "[shake]Strike, strike, strike![/]", "[glitch]Fork and flash.[/]" },
			Lances = { "Arcs of the sky -- [big]cut![/]", "[hot]Rails of lightning.[/]" },
			Fissure = { "Thunder [hot]runs[/] to you.", "[slow]Follow the light to its end.[/]", "[big]CRACK.[/]" },
			Starburst = { "[big]Burst, storm.[/]", "[wave]In all directions.[/]" },
			Summon = { "Little sparks, [hot]take wing[/].", "[shake]Fly, my storm-children.[/]", "[wave]Come, come, come.[/]" },
			Meteors = { "Let the sky fall in [hot]bolts[/].", "Every cloud is a [shake]hammer[/].", "[big]RAIN.[/]" },
			Cage = { "A cage of [hot]thunder[/].", "[glitch]There is nowhere to run.[/]" },
		},
	},
})

-- The Rimeheart (Frozen Reliquary): an ancient glacier that learned to hate. It cages, it
-- freezes the floor in bands, and buries the arena in hail.
local Rimeheart = bossFrom(SanctuaryConfig.RiftBoss, {
	Name = "The Rimeheart",
	Kind = "Rime",
	Title = "The glacier that remembers",
	Island = "RimeIsle",
	Approach = "Take the Riftmaw's southern bridge to the Frozen Reliquary.",
	Cues = {
		Forming = "echoCapture",
		Awake = "wardenAwake",
		Charge = "wardenSlamCharge",
		Land = "oreCollect",
		Phase = "successChime",
		Defeat = "rebirthBloom",
		Escape = "reactorStabilize",
	},
	Music = { Bed = "amb_hollows", Id = 0, Pitch = 0.82, Level = 0.5, Effect = "Reverb" },
	Theme = {
		Primary = { 150, 222, 255 },
		Hot = { 240, 252, 255 },
		Alert = { 80, 170, 255 },
	},
	BaseHealth = 1350,
	HealthPerFighter = 960,
	ActiveSeconds = 170,
	SlamIntervalMin = 6,
	SlamIntervalMax = 9,
	Attacks = {
		-- Signature: ice closes round a fighter in a ring; only the heart of it is safe.
		{ Kind = "Cage", Weight = 1.2, Params = { Count = 7, Distance = 15, RadiusScale = 0.55, TelegraphSeconds = 2, Element = "Frost" } },
		{ Kind = "Rings", Weight = 1, Params = { Count = 3, FirstRadius = 14, Gap = 14, Width = 5, StepSeconds = 0.6, TelegraphSeconds = 2 } },
		{ Kind = "Volley", Weight = 0.9, Params = { Count = 5, StepSeconds = 0.3, Scatter = 7, RadiusScale = 0.6, TelegraphSeconds = 1.5, Element = "Frost" } },
		{ Kind = "Dissonance", Weight = 0.9, MinPhase = 2, Params = { Zones = 3, ZoneRadius = 12, TelegraphSeconds = 2.8 } },
		{ Kind = "Starburst", Weight = 0.9, MinPhase = 2, Params = { Rings = 2, Points = 4, FirstDistance = 16, Gap = 18, StepSeconds = 0.55, RadiusScale = 0.5, TelegraphSeconds = 1.8, Element = "Frost" } },
		{ Kind = "Summon", Weight = 0.8, MinPhase = 2, Params = { Count = 5, Health = 100, FuseSeconds = 9, Orbit = 30, OrbitSpeed = 0.45, BlastRadius = 12, TelegraphSeconds = 1.4, Element = "Frost" } },
		{ Kind = "Meteors", Weight = 1, MinPhase = 3, Params = { Count = 9, StepSeconds = 0.3, RadiusScale = 0.65, TelegraphSeconds = 1.9, Element = "Frost" } },
		{ Kind = "GravityWell", Weight = 0.8, MinPhase = 3, Params = { Radius = 28, Core = 14, PullSeconds = 3, Strength = 30, TelegraphSeconds = 0.8 } },
	},
	Dialogue = {
		Forming = { "[wave]Ice creaks.[/] [beat] Something very [slow]old[/] is turning over.", "[whisper]Snow falls upward here.[/]" },
		Awake = { "I have waited under the snow for [hot]ten thousand winters[/].", "You are [wave]warm[/]. [beat] Warm things do not last here.", "[slow]Sleep.[/] [beat] I will [hot]keep[/] you." },
		Phase2 = { "The cold is [hot]patient[/]. [beat] [shake]I am not.[/]", "[wave]Frost on your breath... on your blade...[/]" },
		Phase3 = { "[big]FREEZE.[/] [shake]FREEZE.[/] [glitch]EVERYTHING FREEZE.[/]", "[slow]Let the world forget the sun.[/]" },
		Defeat = { "I am... [wave]cracking[/].", "[whisper]Spring... was so far away.[/]" },
		Escape = { "I sink back into the ice. [beat] It will [hot]keep[/]." },
		Enrage = { "[slow]The frost... [hot]hardens[/].[/]", "[shake]WINTER WILL NOT WAIT.[/]" },
		Break = { "[wave]A crack... in the ice...[/]", "[big]No![/]" },
		Hit = { "[hot]Brittle.[/]", "[wave]Numb yet?[/]", "Your heat is [slow]leaving you[/].", "[shake]Slower.[/] You are slowing.", "[whisper]So tired...[/]" },
		Attack = {
			Cage = { "Be [slow]still[/]. Be [hot]kept[/].", "[wave]Walls of winter.[/]", "[big]CLOSE.[/]" },
			Rings = { "The frost spreads in [hot]rings[/].", "[wave]Ripples of cold.[/]" },
			Volley = { "[hot]Icicles.[/] One for each of you.", "[shake]Needles of winter.[/]" },
			Dissonance = { "Only the pockets of [hot]warmth[/] survive.", "[slow]Find the last fire.[/]" },
			Starburst = { "Frost, [hot]bloom[/].", "[wave]A snowflake, grown huge.[/]" },
			Summon = { "My frozen children -- [hot]wake[/].", "[whisper]Cold little guardians.[/]", "[wave]Rise from the snow.[/]" },
			Meteors = { "[big]Hail.[/]", "The sky is full of [shake]knives[/].", "[slow]It all comes down.[/]" },
			GravityWell = { "Come into the [hot]cold[/].", "[wave]Everything drifts to winter.[/]", "[slow]Settle... settle...[/]" },
		},
	},
})

-- The Umbral Knight (Gloaming Keep): a swordsman of pure shadow. Precise and fast: long
-- cutting lines, a hunter's sweep, cages of void, and a wall that leaves a single gap.
local UmbralKnight = bossFrom(SanctuaryConfig.RiftBoss, {
	Name = "The Umbral Knight",
	Kind = "Knight",
	Title = "Sworn to the dark between stars",
	Island = "GloamIsle",
	Approach = "Take the Riftmaw's far southern bridge to the Gloaming Keep.",
	Cues = {
		Forming = "wardenForming",
		Awake = "domainImpact",
		Charge = "bootSlamCharge",
		Land = "wardenSlam",
		Phase = "wardenAwake",
		Defeat = "prestige",
		Escape = "wardenEscape",
	},
	Music = { Bed = "amb_riftmaw", Id = 0, Pitch = 0.66, Level = 0.56, Effect = "Distortion" },
	Theme = {
		Primary = { 122, 82, 196 },
		Hot = { 196, 168, 255 },
		Alert = { 255, 60, 140 },
	},
	BaseHealth = 1500,
	HealthPerFighter = 1050,
	ActiveSeconds = 175,
	SlamIntervalMin = 4.5,
	SlamIntervalMax = 7,
	PhaseDelayScale = { 1, 0.75, 0.55 },
	Attacks = {
		-- Signature: a blade of void races from the knight to a fighter.
		{ Kind = "Fissure", Weight = 1.2, Params = { Count = 7, FirstDistance = 12, Gap = 9, StepSeconds = 0.09, RadiusScale = 0.5, TelegraphSeconds = 1.4, Element = "Void" } },
		{ Kind = "TwinSlam", Weight = 0.9, Params = { Element = "Void" } },
		{ Kind = "Sweep", Weight = 1, Params = { Seconds = 4.8, Speed = 0.95, HalfWidth = 0.16, Range = 84, TelegraphSeconds = 1.5 } },
		{ Kind = "Summon", Weight = 0.8, MinPhase = 2, Params = { Count = 4, Health = 110, FuseSeconds = 8, Orbit = 30, OrbitSpeed = 0.75, BlastRadius = 11, TelegraphSeconds = 1.3, Element = "Void" } },
		{ Kind = "Cage", Weight = 1, MinPhase = 2, Params = { Count = 8, Distance = 14, RadiusScale = 0.5, TelegraphSeconds = 1.9, Element = "Void" } },
		{ Kind = "Wall", Weight = 0.9, MinPhase = 2, Params = { Speed = 26, Half = 3, Range = 70, GapHalf = 8, TelegraphSeconds = 2 } },
		{ Kind = "Starburst", Weight = 0.9, MinPhase = 3, Params = { Rings = 2, Points = 5, FirstDistance = 16, Gap = 20, StepSeconds = 0.45, RadiusScale = 0.5, TelegraphSeconds = 1.6, Element = "Void" } },
		{ Kind = "Lances", Weight = 1, MinPhase = 3, Params = { Count = 6, HalfWidth = 0.06, Range = 92, TelegraphSeconds = 1.5 } },
		{ Kind = "Meteors", Weight = 0.9, MinPhase = 3, Params = { Count = 9, StepSeconds = 0.3, RadiusScale = 0.6, TelegraphSeconds = 1.7, Element = "Void" } },
	},
	Dialogue = {
		Forming = { "[wave]Armour assembles itself out of nothing.[/]", "[whisper]A blade, drawn from the dark.[/]" },
		Awake = { "I swore an oath to the [hot]space between stars[/].", "No crown. [beat] No name. [beat] [slow]Only the blade.[/]", "[big]Draw.[/] [beat] Let us see what you are [hot]made of[/]." },
		Phase2 = { "You have earned my [hot]full attention[/].", "[whisper]Few ever did.[/]" },
		Phase3 = { "[shake]NO MORE HONOUR.[/] [beat] [big]ONLY THE DARK.[/]", "[glitch]I will be nothing -- and nothing cannot be cut![/]" },
		Defeat = { "A good... [slow]duel[/].", "The oath is ended. [beat] [hot]The dark is yours.[/]" },
		Escape = { "We will finish this [hot]another night[/]." },
		Enrage = { "[hot]No more games.[/]", "[shake]I tire of this duel.[/]" },
		Break = { "[shake]A clean cut...[/]", "[hot]Well struck.[/]" },
		Hit = { "[hot]Unguarded.[/]", "[slow]Again.[/]", "[shake]Your stance is weak.[/]", "Sloppy. [beat] [hot]Try harder.[/]", "[wave]Is that your best?[/]" },
		Attack = {
			Fissure = { "[hot]One cut.[/]", "The blade [slow]reaches[/].", "[big]FOLLOW.[/]" },
			TwinSlam = { "[hot]Twice.[/]", "[shake]Two strokes.[/]" },
			Sweep = { "[wave]Turn with me.[/]", "[slow]The whole arc.[/]" },
			Summon = { "Shades, [hot]to arms[/].", "[whisper]Shadows... attend.[/]", "[wave]Rise, my lost companions.[/]" },
			Cage = { "No [hot]retreat[/].", "[slow]Enclosed.[/]", "[glitch]The circle closes.[/]" },
			Wall = { "A wall of night -- find the [hot]gap[/].", "[shake]Walk through the dark.[/]" },
			Starburst = { "From the heart, [hot]outward[/].", "[big]Bloom, void.[/]" },
			Lances = { "[hot]Lines[/] of the void.", "[glitch]Cut. Cut. Cut.[/]" },
			Meteors = { "The dark [hot]rains[/] down.", "[slow]Let it fall.[/]", "[big]ALL OF IT.[/]" },
		},
	},
})
-- Boss effect sounds by name (cast_<Element>, hit_<Element>, wisp_*, impact) -> uploaded audio id.
-- BOSS-SFX-BEGIN (rewritten by tools/assetgen/upload_boss_sfx.py)
SanctuaryConfig.BossSfx = {
	["cast_Fire"] = 133922670576399,
	["cast_Frost"] = 72187971131986,
	["cast_Storm"] = 92138127701089,
	["cast_Void"] = 106692366896440,
	["hit_Fire"] = 88917316640445,
	["hit_Frost"] = 123582349928047,
	["hit_Storm"] = 116862191440594,
	["hit_Void"] = 116315495398978,
	["impact"] = 88257269102737,
	["wisp_blast"] = 140620443596331,
	["wisp_down"] = 80813482090323,
	["wisp_spawn"] = 76279580661681,
}
-- BOSS-SFX-END

-- Which body each boss wears: the generated textured models (default) or the procedural Blender bodies.
-- Set to "blender" for every boss, or { Knight = "blender", ... } for some.
SanctuaryConfig.BossBodyStyle = "generated"

-- Boss bodies built, rigged, textured and animated in Blender (tools/bossbuild): skeleton, piece placement and clips.
-- BOSS-BODIES-BEGIN (moved to BossBodies.luau; see tools/bossbuild/export_bodies.py)
SanctuaryConfig.BossBodies = false
-- BOSS-BODIES-END

-- The uploaded body models, one per boss: kind -> model id.
-- BOSS-BODYKIT-BEGIN (rewritten by tools/bossbuild/upload_bodies.py)
SanctuaryConfig.BossBodyKit = {
	Choir = 128966943239551,
	Knight = 79529741206058,
	Regent = 126822760222185,
	Rime = 79017711263030,
	Seraph = 99989330053898,
	Warden = 116830667212689,
}
-- BOSS-BODYKIT-END

-- The bosses' body animation, authored in Blender (tools/assetgen/blender_bossrig.py): per clip, per bone, pitch/yaw/roll at 15 fps.
-- BOSS-CLIPS-BEGIN (rewritten by tools/assetgen/blender_bossrig.py)
SanctuaryConfig.BossClips = {
	default = {
		idle = { fps = 15, length = 3, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.01, 0, 0.03, 0.01, 0, 0.03, 0.01, 0, 0.02, 0.01, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, -0.01, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.01, 0, -0.03, -0.01, 0, -0.03, -0.01, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.01, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0 },
			armL = { -0.08, 0, 0.14, -0.07, 0, 0.15, -0.06, 0, 0.15, -0.05, 0, 0.15, -0.04, 0, 0.16, -0.03, 0, 0.16, -0.02, 0, 0.17, -0.02, 0, 0.17, -0.01, 0, 0.17, -0.01, 0, 0.18, -0.01, 0, 0.18, -0.01, 0, 0.18, -0.02, 0, 0.18, -0.02, 0, 0.18, -0.03, 0, 0.18, -0.04, 0, 0.18, -0.05, 0, 0.18, -0.06, 0, 0.17, -0.07, 0, 0.17, -0.08, 0, 0.17, -0.09, 0, 0.16, -0.11, 0, 0.16, -0.12, 0, 0.15, -0.13, 0, 0.15, -0.13, 0, 0.15, -0.14, 0, 0.14, -0.15, 0, 0.13, -0.15, 0, 0.13, -0.15, 0, 0.13, -0.15, 0, 0.12, -0.15, 0, 0.12, -0.14, 0, 0.11, -0.14, 0, 0.11, -0.13, 0, 0.11, -0.12, 0, 0.1, -0.11, 0, 0.1, -0.1, 0, 0.1, -0.09, 0, 0.1, -0.07, 0, 0.1, -0.06, 0, 0.1, -0.05, 0, 0.1, -0.04, 0, 0.1, -0.03, 0, 0.11, -0.02, 0, 0.11, -0.02, 0, 0.11, -0.01, 0, 0.12 },
			armR = { -0.02, 0, 0.17, -0.02, 0, 0.18, -0.03, 0, 0.18, -0.04, 0, 0.18, -0.05, 0, 0.18, -0.06, 0, 0.18, -0.07, 0, 0.18, -0.08, 0, 0.18, -0.09, 0, 0.18, -0.11, 0, 0.17, -0.12, 0, 0.17, -0.13, 0, 0.17, -0.13, 0, 0.16, -0.14, 0, 0.16, -0.15, 0, 0.15, -0.15, 0, 0.15, -0.15, 0, 0.15, -0.15, 0, 0.14, -0.15, 0, 0.14, -0.14, 0, 0.13, -0.14, 0, 0.13, -0.13, 0, 0.12, -0.12, 0, 0.12, -0.11, 0, 0.11, -0.1, 0, 0.11, -0.09, 0, 0.11, -0.07, 0, 0.1, -0.06, 0, 0.1, -0.05, 0, 0.1, -0.04, 0, 0.1, -0.03, 0, 0.1, -0.02, 0, 0.1, -0.02, 0, 0.1, -0.01, 0, 0.1, -0.01, 0, 0.11, -0.01, 0, 0.11, -0.01, 0, 0.11, -0.01, 0, 0.12, -0.02, 0, 0.12, -0.03, 0, 0.13, -0.03, 0, 0.13, -0.04, 0, 0.13, -0.05, 0, 0.14, -0.06, 0, 0.14, -0.08, 0, 0.15, -0.09, 0, 0.15 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.06, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.06, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13, 0, 0, 0.05, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.03, 0, 0, 0.03, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.25, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.21, 0, 0, 0.13, 0, 0, 0.06, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13, 0, 0, 0.05, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.03, 0, 0, 0.03, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.25, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.21, 0, 0, 0.13, 0, 0, 0.06, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04, 0.11, 0, -0.05, 0.13, 0, -0.05, 0.14, 0, -0.05, 0.15, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.15, 0, -0.03, 0.14, 0, -0.02, 0.13, 0, -0.01, 0.11, 0, -0.01, 0.1, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.05, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0 },
		} },
		forming = { fps = 15, length = 3, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.01, 0, 0.03, 0.01, 0, 0.03, 0.01, 0, 0.02, 0.01, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, -0.01, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.01, 0, -0.03, -0.01, 0, -0.03, -0.01, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03 },
			head = { 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0 },
			armL = { -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25 },
			armR = { -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.06, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.06, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04 },
			wingL = { 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5 },
			wingR = { 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04, 0.11, 0, -0.05, 0.13, 0, -0.05, 0.14, 0, -0.05, 0.15, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.15, 0, -0.03, 0.14, 0, -0.02, 0.13, 0, -0.01, 0.11, 0, -0.01, 0.1, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.05, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0 },
		} },
		slam = { fps = 15, length = 1.8, hit = 1.1, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.07, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.15, 0, 0, -0.18, 0, 0, -0.21, 0, 0, -0.24, 0, 0, -0.26, 0, 0, -0.28, 0, 0, -0.3, 0, 0, -0.31, 0, 0, -0.32, 0, 0, -0.05, 0, 0, 0.28, 0, 0, 0.42, 0, 0, 0.45, 0, 0, 0.43, 0, 0, 0.37, 0, 0, 0.29, 0, 0, 0.19, 0, 0, 0.1, 0, 0, 0.03, 0, 0, 0, 0, 0 },
			head = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.04, 0, 0, -0.05, 0, 0, -0.08, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.16, 0, 0, -0.19, 0, 0, -0.2, 0, 0, -0.22, 0, 0, -0.23, 0, 0, -0.24, 0, 0, -0.25, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.14, 0, 0, 0.12, 0, 0, 0.1, 0, 0, 0.06, 0, 0, 0.03, 0, 0, 0.01, 0, 0, 0, 0, 0 },
			armL = { 0, 0, 0.1, -0.02, 0, 0.1, -0.1, 0, 0.1, -0.2, 0, 0.1, -0.35, 0, 0.1, -0.52, 0, 0.1, -0.71, 0, 0.1, -0.91, 0, 0.1, -1.12, 0, 0.1, -1.33, 0, 0.1, -1.54, 0, 0.1, -1.74, 0, 0.1, -1.92, 0, 0.1, -2.08, 0, 0.1, -2.2, 0, 0.1, -2.3, 0, 0.1, -2.34, 0, 0.1, -1.41, 0, 0.1, -0.23, 0, 0.1, 0.25, 0, 0.1, 0.35, 0, 0.1, 0.34, 0, 0.1, 0.28, 0, 0.1, 0.19, 0, 0.1, 0.1, 0, 0.1, 0.01, 0, 0.1, -0.05, 0, 0.1, -0.08, 0, 0.1 },
			armR = { 0, 0, 0, -0.01, 0, 0, -0.03, 0, 0.01, -0.06, 0, 0.03, -0.1, 0, 0.05, -0.15, 0, 0.08, -0.21, 0, 0.11, -0.27, 0, 0.14, -0.33, 0, 0.17, -0.4, 0, 0.2, -0.46, 0, 0.23, -0.52, 0, 0.26, -0.57, 0, 0.29, -0.62, 0, 0.31, -0.66, 0, 0.33, -0.68, 0, 0.34, -0.7, 0, 0.35, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.29, -0.3, 0, 0.27, -0.3, 0, 0.24, -0.3, 0, 0.21, -0.3, 0, 0.17, -0.3, 0, 0.15, -0.3, 0, 0.14 },
			legL = { 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.05, 0.03, 0, 0.05, 0.05, 0, 0.05, 0.06, 0, 0.05, 0.07, 0, 0.05, 0.09, 0, 0.05, 0.1, 0, 0.05, 0.11, 0, 0.05, 0.12, 0, 0.05, 0.13, 0, 0.05, 0.14, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04 },
			legR = { 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.05, 0.03, 0, 0.05, 0.05, 0, 0.05, 0.06, 0, 0.05, 0.07, 0, 0.05, 0.09, 0, 0.05, 0.1, 0, 0.05, 0.11, 0, 0.05, 0.12, 0, 0.05, 0.13, 0, 0.05, 0.14, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.15, 0, 0, 0.17, 0, 0, 0.2, 0, 0, 0.23, 0, 0, 0.26, 0, 0, 0.29, 0, 0, 0.32, 0, 0, 0.35, 0, 0, 0.38, 0, 0, 0.41, 0, 0, 0.43, 0, 0, 0.45, 0, 0, 0.46, 0, 0, 0.47, 0, 0, 0.27, 0, 0, -0.01, 0, 0, -0.13, 0, 0, -0.15, 0, 0, -0.14, 0, 0, -0.1, 0, 0, -0.05, 0, 0, 0.01, 0, 0, 0.06, 0, 0, 0.1, 0, 0, 0.12 },
			wingR = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.15, 0, 0, 0.17, 0, 0, 0.2, 0, 0, 0.23, 0, 0, 0.26, 0, 0, 0.29, 0, 0, 0.32, 0, 0, 0.35, 0, 0, 0.38, 0, 0, 0.41, 0, 0, 0.43, 0, 0, 0.45, 0, 0, 0.46, 0, 0, 0.47, 0, 0, 0.27, 0, 0, -0.01, 0, 0, -0.13, 0, 0, -0.15, 0, 0, -0.14, 0, 0, -0.1, 0, 0, -0.05, 0, 0, 0.01, 0, 0, 0.06, 0, 0, 0.1, 0, 0, 0.12 },
			cloth = { -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, 0.44, 0, 0, 0.41, 0, 0, 0.39, 0, 0, 0.36, 0, 0, 0.33, 0, 0, 0.31, 0, 0, 0.28, 0, 0, 0.26, 0, 0, 0.23, 0, 0, 0.2, 0, 0, 0.18, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06 },
		} },
		thrust = { fps = 15, length = 1.6, hit = 0.9, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.15, 0, 0, 0.16, 0, 0, 0.32, 0, 0, 0.35, 0, 0, 0.33, 0, 0, 0.27, 0, 0, 0.19, 0, 0, 0.11, 0, 0, 0.04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0 },
			armL = { -0.15, 0, 0, -0.15, 0, 0.02, -0.15, 0, 0.07, -0.15, 0, 0.15, -0.15, 0, 0.24, -0.15, 0, 0.36, -0.15, 0, 0.48, -0.15, 0, 0.61, -0.15, 0, 0.73, -0.15, 0, 0.85, -0.15, 0, 0.96, -0.15, 0, 1.05, -0.15, 0, 1.11, -0.15, 0, 1.15, -0.79, 0, 0.68, -1.43, 0, 0.21, -1.55, 0, 0.12, -1.48, 0, 0.12, -1.23, 0, 0.12, -0.89, 0, 0.13, -0.53, 0, 0.13, -0.23, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14 },
			armR = { -0.15, 0, 0, -0.15, 0, 0.02, -0.15, 0, 0.07, -0.15, 0, 0.15, -0.15, 0, 0.24, -0.15, 0, 0.36, -0.15, 0, 0.48, -0.15, 0, 0.61, -0.15, 0, 0.73, -0.15, 0, 0.85, -0.15, 0, 0.96, -0.15, 0, 1.05, -0.15, 0, 1.11, -0.15, 0, 1.15, -0.79, 0, 0.68, -1.43, 0, 0.21, -1.55, 0, 0.12, -1.48, 0, 0.12, -1.23, 0, 0.12, -0.89, 0, 0.13, -0.53, 0, 0.13, -0.23, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02 },
		} },
		pull = { fps = 15, length = 1.2, hit = 0, loop = true, bones = {
			torso = { 0.18, 0, 0, 0.2, 0, 0, 0.22, 0, 0, 0.23, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.23, 0, 0, 0.22, 0, 0, 0.2, 0, 0, 0.18, 0, 0, 0.16, 0, 0, 0.14, 0, 0, 0.13, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.14, 0, 0, 0.16, 0, 0, 0.18, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0 },
			armL = { -1.25, 0, 0.2, -1.34, 0, 0.17, -1.41, 0, 0.14, -1.47, 0, 0.11, -1.5, 0, 0.1, -1.5, 0, 0.1, -1.47, 0, 0.11, -1.41, 0, 0.14, -1.34, 0, 0.17, -1.25, 0, 0.2, -1.16, 0, 0.23, -1.09, 0, 0.26, -1.03, 0, 0.29, -1, 0, 0.3, -1, 0, 0.3, -1.03, 0, 0.29, -1.09, 0, 0.26, -1.16, 0, 0.23, -1.25, 0, 0.2 },
			armR = { -1.25, 0, 0.2, -1.16, 0, 0.23, -1.09, 0, 0.26, -1.03, 0, 0.29, -1, 0, 0.3, -1, 0, 0.3, -1.03, 0, 0.29, -1.09, 0, 0.26, -1.16, 0, 0.23, -1.25, 0, 0.2, -1.34, 0, 0.17, -1.41, 0, 0.14, -1.47, 0, 0.11, -1.5, 0, 0.1, -1.5, 0, 0.1, -1.47, 0, 0.11, -1.41, 0, 0.14, -1.34, 0, 0.17, -1.25, 0, 0.2 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06 },
		} },
		sweep = { fps = 15, length = 2, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.02, 0, 0, -0.02, 0, 0 },
			armL = { -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05 },
			armR = { -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3 },
			wingR = { 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09 },
		} },
		floor = { fps = 15, length = 1, hit = 0, loop = true, bones = {
			torso = { 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0 },
			armL = { 0.35, 0, 0.35, 0.4, 0, 0.35, 0.44, 0, 0.35, 0.45, 0, 0.35, 0.43, 0, 0.35, 0.39, 0, 0.35, 0.34, 0, 0.35, 0.29, 0, 0.35, 0.26, 0, 0.35, 0.25, 0, 0.35, 0.28, 0, 0.35, 0.32, 0, 0.35, 0.37, 0, 0.35, 0.42, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35 },
			armR = { 0.43, 0, 0.35, 0.45, 0, 0.35, 0.44, 0, 0.35, 0.4, 0, 0.35, 0.35, 0, 0.35, 0.3, 0, 0.35, 0.26, 0, 0.35, 0.25, 0, 0.35, 0.27, 0, 0.35, 0.31, 0, 0.35, 0.37, 0, 0.35, 0.41, 0, 0.35, 0.44, 0, 0.35, 0.45, 0, 0.35, 0.42, 0, 0.35, 0.38, 0, 0.35 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09 },
		} },
		roar = { fps = 15, length = 1.8, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, -0.1, 0, 0, -0.17, 0, 0, -0.22, 0, 0, -0.25, 0, 0, -0.27, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0 },
			head = { 0, 0, 0, -0.17, 0, 0, -0.3, 0, 0, -0.39, 0, 0, -0.45, 0, 0, -0.48, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0 },
			armL = { 0, 0, 0, -0.12, 0, 0.45, -0.21, 0, 0.79, -0.27, 0, 1.02, -0.31, 0, 1.17, -0.34, 0, 1.25, -0.35, 0, 1.29, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3 },
			armR = { 0, 0, 0, -0.12, 0, 0.45, -0.21, 0, 0.79, -0.27, 0, 1.02, -0.31, 0, 1.17, -0.34, 0, 1.25, -0.35, 0, 1.29, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.34, 0, 0, 0.49, 0, 0, 0.55, 0, 0, 0.6, 0, 0, 0.68, 0, 0, 0.74, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73 },
			wingR = { 0, 0, 0.12, 0, 0, 0.34, 0, 0, 0.49, 0, 0, 0.55, 0, 0, 0.6, 0, 0, 0.68, 0, 0, 0.74, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73 },
			cloth = { 0.1, 0, 0, 0.01, 0, 0, -0.05, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06 },
		} },
		summon = { fps = 15, length = 2, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, -0.04, 0, 0, -0.07, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.13, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			head = { 0, 0, 0, -0.08, 0, 0, -0.14, 0, 0, -0.19, 0, 0, -0.23, 0, 0, -0.26, 0, 0, -0.28, 0, 0, -0.29, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0 },
			armL = { 0, 0, 0, -0.46, 0, 0.13, -0.86, 0, 0.23, -1.22, 0, 0.32, -1.54, 0, 0.38, -1.78, 0, 0.43, -1.92, 0, 0.46, -1.96, 0, 0.48, -1.94, 0, 0.49, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5, -1.94, 0, 0.5, -1.92, 0, 0.5, -1.95, 0, 0.5, -2.02, 0, 0.5, -2.07, 0, 0.5, -2.08, 0, 0.5, -2.03, 0, 0.5, -1.97, 0, 0.5, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5 },
			armR = { 0, 0, 0, -0.46, 0, 0.13, -0.86, 0, 0.23, -1.22, 0, 0.32, -1.54, 0, 0.38, -1.78, 0, 0.43, -1.92, 0, 0.46, -1.96, 0, 0.48, -1.94, 0, 0.49, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5, -1.94, 0, 0.5, -1.92, 0, 0.5, -1.95, 0, 0.5, -2.02, 0, 0.5, -2.07, 0, 0.5, -2.08, 0, 0.5, -2.03, 0, 0.5, -1.97, 0, 0.5, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.22, 0, 0, 0.31, 0, 0, 0.37, 0, 0, 0.43, 0, 0, 0.46, 0, 0, 0.49, 0, 0, 0.51, 0, 0, 0.51, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52 },
			wingR = { 0, 0, 0.12, 0, 0, 0.22, 0, 0, 0.31, 0, 0, 0.37, 0, 0, 0.43, 0, 0, 0.46, 0, 0, 0.49, 0, 0, 0.51, 0, 0, 0.51, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09 },
		} },
		hit = { fps = 15, length = 0.5, hit = 0, loop = false, bones = {
			torso = { -0.35, 0, 0.1, -0.26, 0, 0.08, -0.19, 0, 0.05, -0.13, 0, 0.04, -0.08, 0, 0.02, -0.04, 0, 0.01, -0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
			head = { -0.3, 0, 0, -0.23, 0, 0, -0.16, 0, 0, -0.11, 0, 0, -0.07, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
			armL = { -0.2, 0, 0.4, -0.15, 0, 0.3, -0.11, 0, 0.22, -0.07, 0, 0.14, -0.04, 0, 0.09, -0.02, 0, 0.04, -0.01, 0, 0.02, 0, 0, 0, 0, 0, 0 },
			armR = { -0.2, 0, 0.4, -0.15, 0, 0.3, -0.11, 0, 0.22, -0.07, 0, 0.14, -0.04, 0, 0.09, -0.02, 0, 0.04, -0.01, 0, 0.02, 0, 0, 0, 0, 0, 0 },
			cloth = { 0.3, 0, 0, 0.23, 0, 0, 0.16, 0, 0, 0.11, 0, 0, 0.07, 0, 0, 0.03, 0, 0, 0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
		} },
		death = { fps = 15, length = 2.4, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0.01, 0.05, 0, 0.01, 0.07, 0, 0.02, 0.1, 0, 0.03, 0.13, 0, 0.04, 0.17, 0, 0.05, 0.21, 0, 0.06, 0.24, 0, 0.08, 0.28, 0, 0.09, 0.32, 0, 0.1, 0.37, 0, 0.11, 0.41, 0, 0.12, 0.44, 0, 0.14, 0.48, 0, 0.15, 0.52, 0, 0.16, 0.55, 0, 0.17, 0.58, 0, 0.18, 0.6, 0, 0.19, 0.62, 0, 0.19, 0.64, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.03, 0, 0.01, 0.05, 0, 0.02, 0.08, 0, 0.03, 0.11, 0, 0.05, 0.14, 0, 0.06, 0.18, 0, 0.08, 0.22, 0, 0.09, 0.26, 0, 0.11, 0.31, 0, 0.13, 0.35, 0, 0.15, 0.39, 0, 0.17, 0.44, 0, 0.19, 0.48, 0, 0.21, 0.52, 0, 0.22, 0.56, 0, 0.24, 0.59, 0, 0.25, 0.62, 0, 0.27, 0.65, 0, 0.28, 0.67, 0, 0.29, 0.69, 0, 0.29, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3 },
			armL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.03, 0, 0.02, 0.04, 0, 0.03, 0.05, 0, 0.04, 0.06, 0, 0.05, 0.07, 0, 0.06, 0.08, 0, 0.06, 0.09, 0, 0.07, 0.1, 0, 0.08, 0.11, 0, 0.09, 0.12, 0, 0.1, 0.13, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			armR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.03, 0, 0.02, 0.04, 0, 0.03, 0.05, 0, 0.04, 0.06, 0, 0.05, 0.07, 0, 0.06, 0.08, 0, 0.06, 0.09, 0, 0.07, 0.1, 0, 0.08, 0.11, 0, 0.09, 0.12, 0, 0.1, 0.13, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			legL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.06, 0.04, 0, 0.07, 0.06, 0, 0.07, 0.08, 0, 0.08, 0.1, 0, 0.09, 0.13, 0, 0.09, 0.16, 0, 0.09, 0.19, 0, 0.1, 0.22, 0, 0.1, 0.25, 0, 0.1, 0.28, 0, 0.1, 0.31, 0, 0.1, 0.34, 0, 0.1, 0.37, 0, 0.1, 0.4, 0, 0.1, 0.42, 0, 0.1, 0.44, 0, 0.1, 0.46, 0, 0.1, 0.48, 0, 0.1, 0.49, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1 },
			legR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.06, 0.04, 0, 0.07, 0.06, 0, 0.07, 0.08, 0, 0.08, 0.1, 0, 0.09, 0.13, 0, 0.09, 0.16, 0, 0.09, 0.19, 0, 0.1, 0.22, 0, 0.1, 0.25, 0, 0.1, 0.28, 0, 0.1, 0.31, 0, 0.1, 0.34, 0, 0.1, 0.37, 0, 0.1, 0.4, 0, 0.1, 0.42, 0, 0.1, 0.44, 0, 0.1, 0.46, 0, 0.1, 0.48, 0, 0.1, 0.49, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1 },
			wingL = { 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.05, 0, 0, -0.09, 0, 0, -0.13, 0, 0, -0.18, 0, 0, -0.23, 0, 0, -0.29, 0, 0, -0.35, 0, 0, -0.42, 0, 0, -0.48, 0, 0, -0.55, 0, 0, -0.61, 0, 0, -0.67, 0, 0, -0.72, 0, 0, -0.77, 0, 0, -0.81, 0, 0, -0.85, 0, 0, -0.88, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			wingR = { 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.05, 0, 0, -0.09, 0, 0, -0.13, 0, 0, -0.18, 0, 0, -0.23, 0, 0, -0.29, 0, 0, -0.35, 0, 0, -0.42, 0, 0, -0.48, 0, 0, -0.55, 0, 0, -0.61, 0, 0, -0.67, 0, 0, -0.72, 0, 0, -0.77, 0, 0, -0.81, 0, 0, -0.85, 0, 0, -0.88, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			cloth = { 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.06, 0, 0, 0.08, 0, 0, 0.1, 0, 0, 0.12, 0, 0, 0.14, 0, 0, 0.16, 0, 0, 0.18, 0, 0, 0.2, 0, 0, 0.22, 0, 0, 0.24, 0, 0, 0.26, 0, 0, 0.27, 0, 0, 0.28, 0, 0, 0.29, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0 },
		} },
	},
	Knight = {
		idle = { fps = 15, length = 3, hit = 0, loop = true, bones = {
			torso = { 0.04, 0, 0, 0.04, 0.01, 0, 0.05, 0.02, 0.01, 0.05, 0.03, 0.01, 0.05, 0.04, 0.01, 0.06, 0.05, 0.02, 0.06, 0.06, 0.02, 0.06, 0.07, 0.02, 0.06, 0.08, 0.02, 0.06, 0.08, 0.03, 0.06, 0.09, 0.03, 0.06, 0.1, 0.03, 0.06, 0.1, 0.03, 0.06, 0.11, 0.03, 0.06, 0.11, 0.03, 0.06, 0.12, 0.03, 0.06, 0.12, 0.03, 0.06, 0.12, 0.03, 0.05, 0.12, 0.03, 0.05, 0.12, 0.03, 0.05, 0.12, 0.02, 0.05, 0.12, 0.02, 0.04, 0.11, 0.02, 0.04, 0.11, 0.02, 0.03, 0.1, 0.01, 0.03, 0.1, 0.01, 0.03, 0.09, 0.01, 0.03, 0.08, 0, 0.02, 0.08, 0, 0.02, 0.07, 0, 0.02, 0.06, -0.01, 0.02, 0.05, -0.01, 0.02, 0.04, -0.01, 0.02, 0.03, -0.02, 0.02, 0.02, -0.02, 0.02, 0.01, -0.02, 0.02, 0, -0.02, 0.02, -0.01, -0.03, 0.02, -0.02, -0.03, 0.02, -0.03, -0.03, 0.02, -0.04, -0.03, 0.03, -0.05, -0.03, 0.03, -0.06, -0.03, 0.03, -0.07, -0.03, 0.04, -0.08, -0.03, 0.04, -0.08, -0.03 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.01, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0 },
			armL = { -0.55, 0, 0.35, -0.54, 0, 0.35, -0.53, 0, 0.35, -0.52, 0, 0.35, -0.52, 0, 0.35, -0.51, 0, 0.35, -0.51, 0, 0.35, -0.5, 0, 0.35, -0.5, 0, 0.35, -0.5, 0, 0.35, -0.5, 0, 0.35, -0.5, 0, 0.35, -0.51, 0, 0.35, -0.51, 0, 0.35, -0.52, 0, 0.35, -0.52, 0, 0.35, -0.53, 0, 0.35, -0.54, 0, 0.35, -0.55, 0, 0.35, -0.56, 0, 0.35, -0.57, 0, 0.35, -0.57, 0, 0.35, -0.58, 0, 0.35, -0.59, 0, 0.35, -0.59, 0, 0.35, -0.6, 0, 0.35, -0.6, 0, 0.35, -0.6, 0, 0.35, -0.6, 0, 0.35, -0.6, 0, 0.35, -0.59, 0, 0.35, -0.59, 0, 0.35, -0.58, 0, 0.35, -0.57, 0, 0.35, -0.57, 0, 0.35, -0.56, 0, 0.35, -0.55, 0, 0.35, -0.54, 0, 0.35, -0.53, 0, 0.35, -0.52, 0, 0.35, -0.52, 0, 0.35, -0.51, 0, 0.35, -0.51, 0, 0.35, -0.5, 0, 0.35, -0.5, 0, 0.35, -0.5, 0, 0.35 },
			armR = { -0.75, 0, 0.1, -0.74, 0, 0.1, -0.74, 0, 0.1, -0.74, 0, 0.1, -0.74, 0, 0.1, -0.74, 0, 0.1, -0.75, 0, 0.1, -0.75, 0, 0.1, -0.76, 0, 0.1, -0.77, 0, 0.1, -0.78, 0, 0.1, -0.79, 0, 0.1, -0.8, 0, 0.1, -0.81, 0, 0.1, -0.82, 0, 0.1, -0.83, 0, 0.1, -0.84, 0, 0.1, -0.84, 0, 0.1, -0.85, 0, 0.1, -0.86, 0, 0.1, -0.86, 0, 0.1, -0.86, 0, 0.1, -0.86, 0, 0.1, -0.86, 0, 0.1, -0.85, 0, 0.1, -0.85, 0, 0.1, -0.84, 0, 0.1, -0.83, 0, 0.1, -0.82, 0, 0.1, -0.81, 0, 0.1, -0.8, 0, 0.1, -0.79, 0, 0.1, -0.78, 0, 0.1, -0.77, 0, 0.1, -0.76, 0, 0.1, -0.76, 0, 0.1, -0.75, 0, 0.1, -0.74, 0, 0.1, -0.74, 0, 0.1, -0.74, 0, 0.1, -0.74, 0, 0.1, -0.74, 0, 0.1, -0.75, 0, 0.1, -0.75, 0, 0.1, -0.76, 0, 0.1, -0.77, 0, 0.1 },
			legL = { -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12, -0.18, 0, 0.12 },
			legR = { 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13, 0, 0, 0.05, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.03, 0, 0, 0.03, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.25, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.21, 0, 0, 0.13, 0, 0, 0.06, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13, 0, 0, 0.05, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.03, 0, 0, 0.03, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.25, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.21, 0, 0, 0.13, 0, 0, 0.06, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04, 0.11, 0, -0.05, 0.13, 0, -0.05, 0.14, 0, -0.05, 0.15, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.15, 0, -0.03, 0.14, 0, -0.02, 0.13, 0, -0.01, 0.11, 0, -0.01, 0.1, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.05, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0 },
		} },
		forming = { fps = 15, length = 3, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.01, 0, 0.03, 0.01, 0, 0.03, 0.01, 0, 0.02, 0.01, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, -0.01, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.01, 0, -0.03, -0.01, 0, -0.03, -0.01, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03 },
			head = { 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0 },
			armL = { -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25 },
			armR = { -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.06, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.06, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04 },
			wingL = { 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5 },
			wingR = { 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04, 0.11, 0, -0.05, 0.13, 0, -0.05, 0.14, 0, -0.05, 0.15, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.15, 0, -0.03, 0.14, 0, -0.02, 0.13, 0, -0.01, 0.11, 0, -0.01, 0.1, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.05, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0 },
		} },
		slam = { fps = 15, length = 1.8, hit = 1.1, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.07, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.15, 0, 0, -0.18, 0, 0, -0.21, 0, 0, -0.24, 0, 0, -0.26, 0, 0, -0.28, 0, 0, -0.3, 0, 0, -0.31, 0, 0, -0.32, 0, 0, -0.05, 0, 0, 0.28, 0, 0, 0.42, 0, 0, 0.45, 0, 0, 0.43, 0, 0, 0.37, 0, 0, 0.29, 0, 0, 0.19, 0, 0, 0.1, 0, 0, 0.03, 0, 0, 0, 0, 0 },
			head = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.04, 0, 0, -0.05, 0, 0, -0.08, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.16, 0, 0, -0.19, 0, 0, -0.2, 0, 0, -0.22, 0, 0, -0.23, 0, 0, -0.24, 0, 0, -0.25, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.14, 0, 0, 0.12, 0, 0, 0.1, 0, 0, 0.06, 0, 0, 0.03, 0, 0, 0.01, 0, 0, 0, 0, 0 },
			armL = { 0, 0, 0.1, -0.02, 0, 0.1, -0.1, 0, 0.1, -0.2, 0, 0.1, -0.35, 0, 0.1, -0.52, 0, 0.1, -0.71, 0, 0.1, -0.91, 0, 0.1, -1.12, 0, 0.1, -1.33, 0, 0.1, -1.54, 0, 0.1, -1.74, 0, 0.1, -1.92, 0, 0.1, -2.08, 0, 0.1, -2.2, 0, 0.1, -2.3, 0, 0.1, -2.34, 0, 0.1, -1.41, 0, 0.1, -0.23, 0, 0.1, 0.25, 0, 0.1, 0.35, 0, 0.1, 0.34, 0, 0.1, 0.28, 0, 0.1, 0.19, 0, 0.1, 0.1, 0, 0.1, 0.01, 0, 0.1, -0.05, 0, 0.1, -0.08, 0, 0.1 },
			armR = { 0, 0, 0.12, -0.02, 0, 0.12, -0.1, 0, 0.12, -0.2, 0, 0.12, -0.35, 0, 0.12, -0.52, 0, 0.12, -0.71, 0, 0.12, -0.91, 0, 0.12, -1.12, 0, 0.12, -1.33, 0, 0.12, -1.54, 0, 0.12, -1.74, 0, 0.12, -1.92, 0, 0.12, -2.08, 0, 0.12, -2.2, 0, 0.12, -2.3, 0, 0.12, -2.34, 0, 0.12, -1.41, 0, 0.12, -0.23, 0, 0.12, 0.25, 0, 0.12, 0.35, 0, 0.12, 0.34, 0, 0.12, 0.28, 0, 0.12, 0.19, 0, 0.12, 0.1, 0, 0.12, 0.01, 0, 0.12, -0.05, 0, 0.12, -0.08, 0, 0.12 },
			legL = { 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.05, 0.03, 0, 0.05, 0.04, 0, 0.05, 0.05, 0, 0.05, 0.06, 0, 0.05, 0.07, 0, 0.05, 0.07, 0, 0.05, 0.08, 0, 0.05, 0.09, 0, 0.05, 0.09, 0, 0.05, 0.1, 0, 0.05, 0.1, 0, 0.05, -0.19, 0, 0.1, -0.43, 0, 0.1, -0.53, 0, 0.1, -0.55, 0, 0.1, -0.55, 0, 0.1, -0.55, 0, 0.1, -0.55, 0, 0.1, -0.55, 0, 0.1, -0.55, 0, 0.1, -0.55, 0, 0.1, -0.55, 0, 0.1 },
			legR = { 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.05, 0.03, 0, 0.05, 0.05, 0, 0.05, 0.06, 0, 0.05, 0.07, 0, 0.05, 0.09, 0, 0.05, 0.1, 0, 0.05, 0.11, 0, 0.05, 0.12, 0, 0.05, 0.13, 0, 0.05, 0.14, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.12, 0, 0.1, 0.27, 0, 0.1, 0.34, 0, 0.1, 0.35, 0, 0.1, 0.35, 0, 0.1, 0.35, 0, 0.1, 0.35, 0, 0.1, 0.35, 0, 0.1, 0.35, 0, 0.1, 0.35, 0, 0.1, 0.35, 0, 0.1 },
			wingL = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.15, 0, 0, 0.17, 0, 0, 0.2, 0, 0, 0.23, 0, 0, 0.26, 0, 0, 0.29, 0, 0, 0.32, 0, 0, 0.35, 0, 0, 0.38, 0, 0, 0.41, 0, 0, 0.43, 0, 0, 0.45, 0, 0, 0.46, 0, 0, 0.47, 0, 0, 0.27, 0, 0, -0.01, 0, 0, -0.13, 0, 0, -0.15, 0, 0, -0.14, 0, 0, -0.1, 0, 0, -0.05, 0, 0, 0.01, 0, 0, 0.06, 0, 0, 0.1, 0, 0, 0.12 },
			wingR = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.15, 0, 0, 0.17, 0, 0, 0.2, 0, 0, 0.23, 0, 0, 0.26, 0, 0, 0.29, 0, 0, 0.32, 0, 0, 0.35, 0, 0, 0.38, 0, 0, 0.41, 0, 0, 0.43, 0, 0, 0.45, 0, 0, 0.46, 0, 0, 0.47, 0, 0, 0.27, 0, 0, -0.01, 0, 0, -0.13, 0, 0, -0.15, 0, 0, -0.14, 0, 0, -0.1, 0, 0, -0.05, 0, 0, 0.01, 0, 0, 0.06, 0, 0, 0.1, 0, 0, 0.12 },
			cloth = { -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, 0.44, 0, 0, 0.41, 0, 0, 0.39, 0, 0, 0.36, 0, 0, 0.33, 0, 0, 0.31, 0, 0, 0.28, 0, 0, 0.26, 0, 0, 0.23, 0, 0, 0.2, 0, 0, 0.18, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06 },
		} },
		thrust = { fps = 15, length = 1.6, hit = 0.9, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.15, 0, 0, 0.16, 0, 0, 0.32, 0, 0, 0.35, 0, 0, 0.33, 0, 0, 0.27, 0, 0, 0.19, 0, 0, 0.11, 0, 0, 0.04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0 },
			armL = { -0.15, 0, 0, -0.15, 0, 0.02, -0.15, 0, 0.07, -0.15, 0, 0.15, -0.15, 0, 0.24, -0.15, 0, 0.36, -0.15, 0, 0.48, -0.15, 0, 0.61, -0.15, 0, 0.73, -0.15, 0, 0.85, -0.15, 0, 0.96, -0.15, 0, 1.05, -0.15, 0, 1.11, -0.15, 0, 1.15, 0.23, 0, 0.23, 0.46, 0, 0.46, 0.5, 0, 0.5, 0.5, 0, 0.5, 0.5, 0, 0.5, 0.5, 0, 0.5, 0.5, 0, 0.5, 0.5, 0, 0.5, 0.5, 0, 0.5, 0.5, 0, 0.5, 0.5, 0, 0.5 },
			armR = { -0.15, 0, 0, -0.15, 0, 0.02, -0.15, 0, 0.07, -0.15, 0, 0.15, -0.15, 0, 0.24, -0.15, 0, 0.36, -0.15, 0, 0.48, -0.15, 0, 0.61, -0.15, 0, 0.73, -0.15, 0, 0.85, -0.15, 0, 0.96, -0.15, 0, 1.05, -0.15, 0, 1.11, -0.15, 0, 1.15, -0.79, 0, 0.68, -1.43, 0, 0.21, -1.55, 0, 0.12, -1.48, 0, 0.12, -1.23, 0, 0.12, -0.89, 0, 0.13, -0.53, 0, 0.13, -0.23, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, -0.37, 0, 0.12, -0.73, 0, 0.12, -0.8, 0, 0.12, -0.8, 0, 0.12, -0.8, 0, 0.12, -0.8, 0, 0.12, -0.8, 0, 0.12, -0.8, 0, 0.12, -0.8, 0, 0.12, -0.8, 0, 0.12, -0.8, 0, 0.12 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0.21, 0, 0.1, 0.41, 0, 0.1, 0.45, 0, 0.1, 0.45, 0, 0.1, 0.45, 0, 0.1, 0.45, 0, 0.1, 0.45, 0, 0.1, 0.45, 0, 0.1, 0.45, 0, 0.1, 0.45, 0, 0.1, 0.45, 0, 0.1 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02 },
		} },
		pull = { fps = 15, length = 1.2, hit = 0, loop = true, bones = {
			torso = { 0.18, 0, 0, 0.2, 0, 0, 0.22, 0, 0, 0.23, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.23, 0, 0, 0.22, 0, 0, 0.2, 0, 0, 0.18, 0, 0, 0.16, 0, 0, 0.14, 0, 0, 0.13, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.14, 0, 0, 0.16, 0, 0, 0.18, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0 },
			armL = { -1.25, 0, 0.2, -1.34, 0, 0.17, -1.41, 0, 0.14, -1.47, 0, 0.11, -1.5, 0, 0.1, -1.5, 0, 0.1, -1.47, 0, 0.11, -1.41, 0, 0.14, -1.34, 0, 0.17, -1.25, 0, 0.2, -1.16, 0, 0.23, -1.09, 0, 0.26, -1.03, 0, 0.29, -1, 0, 0.3, -1, 0, 0.3, -1.03, 0, 0.29, -1.09, 0, 0.26, -1.16, 0, 0.23, -1.25, 0, 0.2 },
			armR = { -1.25, 0, 0.2, -1.16, 0, 0.23, -1.09, 0, 0.26, -1.03, 0, 0.29, -1, 0, 0.3, -1, 0, 0.3, -1.03, 0, 0.29, -1.09, 0, 0.26, -1.16, 0, 0.23, -1.25, 0, 0.2, -1.34, 0, 0.17, -1.41, 0, 0.14, -1.47, 0, 0.11, -1.5, 0, 0.1, -1.5, 0, 0.1, -1.47, 0, 0.11, -1.41, 0, 0.14, -1.34, 0, 0.17, -1.25, 0, 0.2 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06 },
		} },
		sweep = { fps = 15, length = 2, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0.12, 0, 0.19, 0.12, 0, 0.37, 0.12, 0, 0.53, 0.12, 0, 0.67, 0.12, 0, 0.78, 0.12, 0, 0.86, 0.12, 0, 0.9, 0.12, 0, 0.9, 0.12, 0, 0.86, 0.12, 0, 0.78, 0.12, 0, 0.67, 0.12, 0, 0.53, 0.12, 0, 0.37, 0.12, 0, 0.19, 0.12, 0, 0, 0.12, 0, -0.19, 0.12, 0, -0.37, 0.12, 0, -0.53, 0.12, 0, -0.67, 0.12, 0, -0.78, 0.12, 0, -0.86, 0.12, 0, -0.9, 0.12, 0, -0.9, 0.12, 0, -0.86, 0.12, 0, -0.78, 0.12, 0, -0.67, 0.12, 0, -0.53, 0.12, 0, -0.37, 0.12, 0, -0.19, 0.12, 0, 0, 0.12 },
			head = { 0, 0, 0, 0.01, -0.08, 0, 0.02, -0.16, 0, 0.02, -0.24, 0, 0.03, -0.3, 0, 0.03, -0.35, 0, 0.04, -0.38, 0, 0.04, -0.4, 0, 0.04, -0.4, 0, 0.04, -0.38, 0, 0.04, -0.35, 0, 0.03, -0.3, 0, 0.03, -0.24, 0, 0.02, -0.16, 0, 0.02, -0.08, 0, 0.01, 0, 0, 0, 0.08, 0, -0.01, 0.16, 0, -0.01, 0.24, 0, -0.02, 0.3, 0, -0.03, 0.35, 0, -0.03, 0.38, 0, -0.04, 0.4, 0, -0.04, 0.4, 0, -0.04, 0.38, 0, -0.04, 0.35, 0, -0.04, 0.3, 0, -0.03, 0.24, 0, -0.03, 0.16, 0, -0.02, 0.08, 0, -0.02, 0, 0 },
			armL = { -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05 },
			armR = { -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3 },
			wingR = { 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09 },
		} },
		floor = { fps = 15, length = 1, hit = 0, loop = true, bones = {
			torso = { 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0 },
			armL = { 0.35, 0, 0.35, 0.4, 0, 0.35, 0.44, 0, 0.35, 0.45, 0, 0.35, 0.43, 0, 0.35, 0.39, 0, 0.35, 0.34, 0, 0.35, 0.29, 0, 0.35, 0.26, 0, 0.35, 0.25, 0, 0.35, 0.28, 0, 0.35, 0.32, 0, 0.35, 0.37, 0, 0.35, 0.42, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35 },
			armR = { 0.43, 0, 0.35, 0.45, 0, 0.35, 0.44, 0, 0.35, 0.4, 0, 0.35, 0.35, 0, 0.35, 0.3, 0, 0.35, 0.26, 0, 0.35, 0.25, 0, 0.35, 0.27, 0, 0.35, 0.31, 0, 0.35, 0.37, 0, 0.35, 0.41, 0, 0.35, 0.44, 0, 0.35, 0.45, 0, 0.35, 0.42, 0, 0.35, 0.38, 0, 0.35 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09 },
		} },
		roar = { fps = 15, length = 1.8, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, -0.1, 0, 0, -0.17, 0, 0, -0.22, 0, 0, -0.25, 0, 0, -0.27, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0 },
			head = { 0, 0, 0, -0.17, 0, 0, -0.3, 0, 0, -0.39, 0, 0, -0.45, 0, 0, -0.48, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0 },
			armL = { 0, 0, 0, -0.12, 0, 0.45, -0.21, 0, 0.79, -0.27, 0, 1.02, -0.31, 0, 1.17, -0.34, 0, 1.25, -0.35, 0, 1.29, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3 },
			armR = { 0, 0, 0.2, -0.8, 0, 0.2, -1.34, 0, 0.2, -1.66, 0, 0.2, -1.83, 0, 0.2, -1.89, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2, -1.9, 0, 0.2 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.34, 0, 0, 0.49, 0, 0, 0.55, 0, 0, 0.6, 0, 0, 0.68, 0, 0, 0.74, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73 },
			wingR = { 0, 0, 0.12, 0, 0, 0.34, 0, 0, 0.49, 0, 0, 0.55, 0, 0, 0.6, 0, 0, 0.68, 0, 0, 0.74, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73 },
			cloth = { 0.1, 0, 0, 0.01, 0, 0, -0.05, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06 },
		} },
		summon = { fps = 15, length = 2, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, -0.04, 0, 0, -0.07, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.13, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			head = { 0, 0, 0, -0.08, 0, 0, -0.14, 0, 0, -0.19, 0, 0, -0.23, 0, 0, -0.26, 0, 0, -0.28, 0, 0, -0.29, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0 },
			armL = { 0, 0, 0, -0.46, 0, 0.13, -0.86, 0, 0.23, -1.22, 0, 0.32, -1.54, 0, 0.38, -1.78, 0, 0.43, -1.92, 0, 0.46, -1.96, 0, 0.48, -1.94, 0, 0.49, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5, -1.94, 0, 0.5, -1.92, 0, 0.5, -1.95, 0, 0.5, -2.02, 0, 0.5, -2.07, 0, 0.5, -2.08, 0, 0.5, -2.03, 0, 0.5, -1.97, 0, 0.5, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5 },
			armR = { 0, 0, 0, -0.46, 0, 0.13, -0.86, 0, 0.23, -1.22, 0, 0.32, -1.54, 0, 0.38, -1.78, 0, 0.43, -1.92, 0, 0.46, -1.96, 0, 0.48, -1.94, 0, 0.49, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5, -1.94, 0, 0.5, -1.92, 0, 0.5, -1.95, 0, 0.5, -2.02, 0, 0.5, -2.07, 0, 0.5, -2.08, 0, 0.5, -2.03, 0, 0.5, -1.97, 0, 0.5, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.22, 0, 0, 0.31, 0, 0, 0.37, 0, 0, 0.43, 0, 0, 0.46, 0, 0, 0.49, 0, 0, 0.51, 0, 0, 0.51, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52 },
			wingR = { 0, 0, 0.12, 0, 0, 0.22, 0, 0, 0.31, 0, 0, 0.37, 0, 0, 0.43, 0, 0, 0.46, 0, 0, 0.49, 0, 0, 0.51, 0, 0, 0.51, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09 },
		} },
		hit = { fps = 15, length = 0.5, hit = 0, loop = false, bones = {
			torso = { -0.35, 0, 0.1, -0.26, 0, 0.08, -0.19, 0, 0.05, -0.13, 0, 0.04, -0.08, 0, 0.02, -0.04, 0, 0.01, -0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
			head = { -0.3, 0, 0, -0.23, 0, 0, -0.16, 0, 0, -0.11, 0, 0, -0.07, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
			armL = { -0.2, 0, 0.4, -0.15, 0, 0.3, -0.11, 0, 0.22, -0.07, 0, 0.14, -0.04, 0, 0.09, -0.02, 0, 0.04, -0.01, 0, 0.02, 0, 0, 0, 0, 0, 0 },
			armR = { -0.2, 0, 0.4, -0.15, 0, 0.3, -0.11, 0, 0.22, -0.07, 0, 0.14, -0.04, 0, 0.09, -0.02, 0, 0.04, -0.01, 0, 0.02, 0, 0, 0, 0, 0, 0 },
			cloth = { 0.3, 0, 0, 0.23, 0, 0, 0.16, 0, 0, 0.11, 0, 0, 0.07, 0, 0, 0.03, 0, 0, 0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
		} },
		death = { fps = 15, length = 2.4, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0.01, 0.05, 0, 0.01, 0.07, 0, 0.02, 0.1, 0, 0.03, 0.13, 0, 0.04, 0.17, 0, 0.05, 0.21, 0, 0.06, 0.24, 0, 0.08, 0.28, 0, 0.09, 0.32, 0, 0.1, 0.37, 0, 0.11, 0.41, 0, 0.12, 0.44, 0, 0.14, 0.48, 0, 0.15, 0.52, 0, 0.16, 0.55, 0, 0.17, 0.58, 0, 0.18, 0.6, 0, 0.19, 0.62, 0, 0.19, 0.64, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.03, 0, 0.01, 0.05, 0, 0.02, 0.08, 0, 0.03, 0.11, 0, 0.05, 0.14, 0, 0.06, 0.18, 0, 0.08, 0.22, 0, 0.09, 0.26, 0, 0.11, 0.31, 0, 0.13, 0.35, 0, 0.15, 0.39, 0, 0.17, 0.44, 0, 0.19, 0.48, 0, 0.21, 0.52, 0, 0.22, 0.56, 0, 0.24, 0.59, 0, 0.25, 0.62, 0, 0.27, 0.65, 0, 0.28, 0.67, 0, 0.29, 0.69, 0, 0.29, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3 },
			armL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.03, 0, 0.02, 0.04, 0, 0.03, 0.05, 0, 0.04, 0.06, 0, 0.05, 0.07, 0, 0.06, 0.08, 0, 0.06, 0.09, 0, 0.07, 0.1, 0, 0.08, 0.11, 0, 0.09, 0.12, 0, 0.1, 0.13, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			armR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.03, 0, 0.02, 0.04, 0, 0.03, 0.05, 0, 0.04, 0.06, 0, 0.05, 0.07, 0, 0.06, 0.08, 0, 0.06, 0.09, 0, 0.07, 0.1, 0, 0.08, 0.11, 0, 0.09, 0.12, 0, 0.1, 0.13, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			legL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.06, 0.04, 0, 0.07, 0.06, 0, 0.07, 0.08, 0, 0.08, 0.1, 0, 0.09, 0.13, 0, 0.09, 0.16, 0, 0.09, 0.19, 0, 0.1, 0.22, 0, 0.1, 0.25, 0, 0.1, 0.28, 0, 0.1, 0.31, 0, 0.1, 0.34, 0, 0.1, 0.37, 0, 0.1, 0.4, 0, 0.1, 0.42, 0, 0.1, 0.44, 0, 0.1, 0.46, 0, 0.1, 0.48, 0, 0.1, 0.49, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1 },
			legR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.06, 0.04, 0, 0.07, 0.06, 0, 0.07, 0.08, 0, 0.08, 0.1, 0, 0.09, 0.13, 0, 0.09, 0.16, 0, 0.09, 0.19, 0, 0.1, 0.22, 0, 0.1, 0.25, 0, 0.1, 0.28, 0, 0.1, 0.31, 0, 0.1, 0.34, 0, 0.1, 0.37, 0, 0.1, 0.4, 0, 0.1, 0.42, 0, 0.1, 0.44, 0, 0.1, 0.46, 0, 0.1, 0.48, 0, 0.1, 0.49, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1 },
			wingL = { 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.05, 0, 0, -0.09, 0, 0, -0.13, 0, 0, -0.18, 0, 0, -0.23, 0, 0, -0.29, 0, 0, -0.35, 0, 0, -0.42, 0, 0, -0.48, 0, 0, -0.55, 0, 0, -0.61, 0, 0, -0.67, 0, 0, -0.72, 0, 0, -0.77, 0, 0, -0.81, 0, 0, -0.85, 0, 0, -0.88, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			wingR = { 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.05, 0, 0, -0.09, 0, 0, -0.13, 0, 0, -0.18, 0, 0, -0.23, 0, 0, -0.29, 0, 0, -0.35, 0, 0, -0.42, 0, 0, -0.48, 0, 0, -0.55, 0, 0, -0.61, 0, 0, -0.67, 0, 0, -0.72, 0, 0, -0.77, 0, 0, -0.81, 0, 0, -0.85, 0, 0, -0.88, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			cloth = { 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.06, 0, 0, 0.08, 0, 0, 0.1, 0, 0, 0.12, 0, 0, 0.14, 0, 0, 0.16, 0, 0, 0.18, 0, 0, 0.2, 0, 0, 0.22, 0, 0, 0.24, 0, 0, 0.26, 0, 0, 0.27, 0, 0, 0.28, 0, 0, 0.29, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0 },
		} },
	},
	Seraph = {
		idle = { fps = 15, length = 3, hit = 0, loop = true, bones = {
			torso = { 0.05, 0, 0, 0.05, 0, 0, 0.06, 0, 0.01, 0.06, 0, 0.01, 0.06, 0, 0.01, 0.07, 0, 0.02, 0.07, 0, 0.02, 0.07, 0, 0.02, 0.07, 0, 0.02, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.06, 0, 0.03, 0.06, 0, 0.02, 0.06, 0, 0.02, 0.05, 0, 0.02, 0.05, 0, 0.02, 0.04, 0, 0.01, 0.04, 0, 0.01, 0.04, 0, 0.01, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.03, 0, -0.01, 0.03, 0, -0.01, 0.03, 0, -0.02, 0.03, 0, -0.02, 0.03, 0, -0.02, 0.03, 0, -0.02, 0.03, 0, -0.03, 0.03, 0, -0.03, 0.03, 0, -0.03, 0.03, 0, -0.03, 0.04, 0, -0.03, 0.04, 0, -0.03, 0.04, 0, -0.03, 0.05, 0, -0.03, 0.05, 0, -0.03 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.01, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0 },
			armL = { -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5 },
			armR = { -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5 },
			legL = { 0.35, 0, 0.06, 0.36, 0, 0.06, 0.36, 0, 0.06, 0.37, 0, 0.06, 0.38, 0, 0.06, 0.38, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.38, 0, 0.06, 0.38, 0, 0.06, 0.37, 0, 0.06, 0.36, 0, 0.06, 0.36, 0, 0.06, 0.35, 0, 0.06, 0.34, 0, 0.06, 0.34, 0, 0.06, 0.33, 0, 0.06, 0.32, 0, 0.06, 0.32, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.32, 0, 0.06, 0.32, 0, 0.06, 0.33, 0, 0.06 },
			legR = { 0.35, 0, 0.06, 0.36, 0, 0.06, 0.36, 0, 0.06, 0.37, 0, 0.06, 0.38, 0, 0.06, 0.38, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.38, 0, 0.06, 0.38, 0, 0.06, 0.37, 0, 0.06, 0.36, 0, 0.06, 0.36, 0, 0.06, 0.35, 0, 0.06, 0.34, 0, 0.06, 0.34, 0, 0.06, 0.33, 0, 0.06, 0.32, 0, 0.06, 0.32, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.32, 0, 0.06, 0.32, 0, 0.06, 0.33, 0, 0.06 },
			wingL = { 0, 0, 0.25, 0, 0, 0.33, 0, 0, 0.41, 0, 0, 0.48, 0, 0, 0.53, 0, 0, 0.56, 0, 0, 0.57, 0, 0, 0.56, 0, 0, 0.53, 0, 0, 0.48, 0, 0, 0.41, 0, 0, 0.33, 0, 0, 0.25, 0, 0, 0.17, 0, 0, 0.09, 0, 0, 0.02, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.02, 0, 0, 0.09, 0, 0, 0.17, 0, 0, 0.25, 0, 0, 0.33, 0, 0, 0.41, 0, 0, 0.48, 0, 0, 0.53, 0, 0, 0.56, 0, 0, 0.57, 0, 0, 0.56, 0, 0, 0.53, 0, 0, 0.48, 0, 0, 0.41, 0, 0, 0.33, 0, 0, 0.25, 0, 0, 0.17, 0, 0, 0.09, 0, 0, 0.02, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.02 },
			wingR = { 0, 0, 0.25, 0, 0, 0.33, 0, 0, 0.41, 0, 0, 0.48, 0, 0, 0.53, 0, 0, 0.56, 0, 0, 0.57, 0, 0, 0.56, 0, 0, 0.53, 0, 0, 0.48, 0, 0, 0.41, 0, 0, 0.33, 0, 0, 0.25, 0, 0, 0.17, 0, 0, 0.09, 0, 0, 0.02, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.02, 0, 0, 0.09, 0, 0, 0.17, 0, 0, 0.25, 0, 0, 0.33, 0, 0, 0.41, 0, 0, 0.48, 0, 0, 0.53, 0, 0, 0.56, 0, 0, 0.57, 0, 0, 0.56, 0, 0, 0.53, 0, 0, 0.48, 0, 0, 0.41, 0, 0, 0.33, 0, 0, 0.25, 0, 0, 0.17, 0, 0, 0.09, 0, 0, 0.02, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.02 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04, 0.11, 0, -0.05, 0.13, 0, -0.05, 0.14, 0, -0.05, 0.15, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.15, 0, -0.03, 0.14, 0, -0.02, 0.13, 0, -0.01, 0.11, 0, -0.01, 0.1, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.05, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0 },
		} },
		forming = { fps = 15, length = 3, hit = 0, loop = true, bones = {
			torso = { 0.05, 0, 0, 0.05, 0, 0, 0.06, 0, 0.01, 0.06, 0, 0.01, 0.06, 0, 0.01, 0.07, 0, 0.02, 0.07, 0, 0.02, 0.07, 0, 0.02, 0.07, 0, 0.02, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.06, 0, 0.03, 0.06, 0, 0.02, 0.06, 0, 0.02, 0.05, 0, 0.02, 0.05, 0, 0.02, 0.04, 0, 0.01, 0.04, 0, 0.01, 0.04, 0, 0.01, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.03, 0, -0.01, 0.03, 0, -0.01, 0.03, 0, -0.02, 0.03, 0, -0.02, 0.03, 0, -0.02, 0.03, 0, -0.02, 0.03, 0, -0.03, 0.03, 0, -0.03, 0.03, 0, -0.03, 0.03, 0, -0.03, 0.04, 0, -0.03, 0.04, 0, -0.03, 0.04, 0, -0.03, 0.05, 0, -0.03, 0.05, 0, -0.03 },
			head = { 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0 },
			armL = { -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5 },
			armR = { -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5, -0.2, 0, 0.5 },
			legL = { 0.35, 0, 0.06, 0.36, 0, 0.06, 0.36, 0, 0.06, 0.37, 0, 0.06, 0.38, 0, 0.06, 0.38, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.38, 0, 0.06, 0.38, 0, 0.06, 0.37, 0, 0.06, 0.36, 0, 0.06, 0.36, 0, 0.06, 0.35, 0, 0.06, 0.34, 0, 0.06, 0.34, 0, 0.06, 0.33, 0, 0.06, 0.32, 0, 0.06, 0.32, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.32, 0, 0.06, 0.32, 0, 0.06, 0.33, 0, 0.06 },
			legR = { 0.35, 0, 0.06, 0.36, 0, 0.06, 0.36, 0, 0.06, 0.37, 0, 0.06, 0.38, 0, 0.06, 0.38, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.4, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.39, 0, 0.06, 0.38, 0, 0.06, 0.38, 0, 0.06, 0.37, 0, 0.06, 0.36, 0, 0.06, 0.36, 0, 0.06, 0.35, 0, 0.06, 0.34, 0, 0.06, 0.34, 0, 0.06, 0.33, 0, 0.06, 0.32, 0, 0.06, 0.32, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.3, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.31, 0, 0.06, 0.32, 0, 0.06, 0.32, 0, 0.06, 0.33, 0, 0.06 },
			wingL = { 0, 0, 0.25, 0, 0, 0.33, 0, 0, 0.41, 0, 0, 0.48, 0, 0, 0.53, 0, 0, 0.56, 0, 0, 0.57, 0, 0, 0.56, 0, 0, 0.53, 0, 0, 0.48, 0, 0, 0.41, 0, 0, 0.33, 0, 0, 0.25, 0, 0, 0.17, 0, 0, 0.09, 0, 0, 0.02, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.02, 0, 0, 0.09, 0, 0, 0.17, 0, 0, 0.25, 0, 0, 0.33, 0, 0, 0.41, 0, 0, 0.48, 0, 0, 0.53, 0, 0, 0.56, 0, 0, 0.57, 0, 0, 0.56, 0, 0, 0.53, 0, 0, 0.48, 0, 0, 0.41, 0, 0, 0.33, 0, 0, 0.25, 0, 0, 0.17, 0, 0, 0.09, 0, 0, 0.02, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.02 },
			wingR = { 0, 0, 0.25, 0, 0, 0.33, 0, 0, 0.41, 0, 0, 0.48, 0, 0, 0.53, 0, 0, 0.56, 0, 0, 0.57, 0, 0, 0.56, 0, 0, 0.53, 0, 0, 0.48, 0, 0, 0.41, 0, 0, 0.33, 0, 0, 0.25, 0, 0, 0.17, 0, 0, 0.09, 0, 0, 0.02, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.02, 0, 0, 0.09, 0, 0, 0.17, 0, 0, 0.25, 0, 0, 0.33, 0, 0, 0.41, 0, 0, 0.48, 0, 0, 0.53, 0, 0, 0.56, 0, 0, 0.57, 0, 0, 0.56, 0, 0, 0.53, 0, 0, 0.48, 0, 0, 0.41, 0, 0, 0.33, 0, 0, 0.25, 0, 0, 0.17, 0, 0, 0.09, 0, 0, 0.02, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.02 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04, 0.11, 0, -0.05, 0.13, 0, -0.05, 0.14, 0, -0.05, 0.15, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.15, 0, -0.03, 0.14, 0, -0.02, 0.13, 0, -0.01, 0.11, 0, -0.01, 0.1, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.05, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0 },
		} },
		slam = { fps = 15, length = 1.8, hit = 1.1, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.07, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.15, 0, 0, -0.18, 0, 0, -0.21, 0, 0, -0.24, 0, 0, -0.26, 0, 0, -0.28, 0, 0, -0.3, 0, 0, -0.31, 0, 0, -0.32, 0, 0, -0.05, 0, 0, 0.28, 0, 0, 0.42, 0, 0, 0.45, 0, 0, 0.43, 0, 0, 0.37, 0, 0, 0.29, 0, 0, 0.19, 0, 0, 0.1, 0, 0, 0.03, 0, 0, 0, 0, 0 },
			head = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.04, 0, 0, -0.05, 0, 0, -0.08, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.16, 0, 0, -0.19, 0, 0, -0.2, 0, 0, -0.22, 0, 0, -0.23, 0, 0, -0.24, 0, 0, -0.25, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.14, 0, 0, 0.12, 0, 0, 0.1, 0, 0, 0.06, 0, 0, 0.03, 0, 0, 0.01, 0, 0, 0, 0, 0 },
			armL = { 0, 0, 0.1, -0.02, 0, 0.1, -0.1, 0, 0.1, -0.2, 0, 0.1, -0.35, 0, 0.1, -0.52, 0, 0.1, -0.71, 0, 0.1, -0.91, 0, 0.1, -1.12, 0, 0.1, -1.33, 0, 0.1, -1.54, 0, 0.1, -1.74, 0, 0.1, -1.92, 0, 0.1, -2.08, 0, 0.1, -2.2, 0, 0.1, -2.3, 0, 0.1, -2.34, 0, 0.1, -1.41, 0, 0.1, -0.23, 0, 0.1, 0.25, 0, 0.1, 0.35, 0, 0.1, 0.34, 0, 0.1, 0.28, 0, 0.1, 0.19, 0, 0.1, 0.1, 0, 0.1, 0.01, 0, 0.1, -0.05, 0, 0.1, -0.08, 0, 0.1 },
			armR = { 0, 0, 0, -0.01, 0, 0, -0.03, 0, 0.01, -0.06, 0, 0.03, -0.1, 0, 0.05, -0.15, 0, 0.08, -0.21, 0, 0.11, -0.27, 0, 0.14, -0.33, 0, 0.17, -0.4, 0, 0.2, -0.46, 0, 0.23, -0.52, 0, 0.26, -0.57, 0, 0.29, -0.62, 0, 0.31, -0.66, 0, 0.33, -0.68, 0, 0.34, -0.7, 0, 0.35, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.29, -0.3, 0, 0.27, -0.3, 0, 0.24, -0.3, 0, 0.21, -0.3, 0, 0.17, -0.3, 0, 0.15, -0.3, 0, 0.14 },
			legL = { 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.05, 0.03, 0, 0.05, 0.05, 0, 0.05, 0.06, 0, 0.05, 0.07, 0, 0.05, 0.09, 0, 0.05, 0.1, 0, 0.05, 0.11, 0, 0.05, 0.12, 0, 0.05, 0.13, 0, 0.05, 0.14, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04 },
			legR = { 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.05, 0.03, 0, 0.05, 0.05, 0, 0.05, 0.06, 0, 0.05, 0.07, 0, 0.05, 0.09, 0, 0.05, 0.1, 0, 0.05, 0.11, 0, 0.05, 0.12, 0, 0.05, 0.13, 0, 0.05, 0.14, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04 },
			wingL = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.04, 0, 0, 0.08, 0, 0, 0.13, 0, 0, 0.2, 0, 0, 0.27, 0, 0, 0.35, 0, 0, 0.43, 0, 0, 0.51, 0, 0, 0.59, 0, 0, 0.67, 0, 0, 0.74, 0, 0, 0.8, 0, 0, 0.84, 0, 0, 0.88, 0, 0, 0.9, 0, 0, 0.23, 0, 0, -0.5, 0, 0, -0.69, 0, 0, -0.7, 0, 0, -0.7, 0, 0, -0.7, 0, 0, -0.7, 0, 0, -0.7, 0, 0, -0.7, 0, 0, -0.7, 0, 0, -0.7 },
			wingR = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.04, 0, 0, 0.08, 0, 0, 0.13, 0, 0, 0.2, 0, 0, 0.27, 0, 0, 0.35, 0, 0, 0.43, 0, 0, 0.51, 0, 0, 0.59, 0, 0, 0.67, 0, 0, 0.74, 0, 0, 0.8, 0, 0, 0.84, 0, 0, 0.88, 0, 0, 0.9, 0, 0, 0.23, 0, 0, -0.5, 0, 0, -0.69, 0, 0, -0.7, 0, 0, -0.7, 0, 0, -0.7, 0, 0, -0.7, 0, 0, -0.7, 0, 0, -0.7, 0, 0, -0.7, 0, 0, -0.7 },
			cloth = { -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, 0.44, 0, 0, 0.41, 0, 0, 0.39, 0, 0, 0.36, 0, 0, 0.33, 0, 0, 0.31, 0, 0, 0.28, 0, 0, 0.26, 0, 0, 0.23, 0, 0, 0.2, 0, 0, 0.18, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06 },
		} },
		thrust = { fps = 15, length = 1.6, hit = 0.9, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.15, 0, 0, 0.16, 0, 0, 0.32, 0, 0, 0.35, 0, 0, 0.33, 0, 0, 0.27, 0, 0, 0.19, 0, 0, 0.11, 0, 0, 0.04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0 },
			armL = { -0.15, 0, 0, -0.15, 0, 0.02, -0.15, 0, 0.07, -0.15, 0, 0.15, -0.15, 0, 0.24, -0.15, 0, 0.36, -0.15, 0, 0.48, -0.15, 0, 0.61, -0.15, 0, 0.73, -0.15, 0, 0.85, -0.15, 0, 0.96, -0.15, 0, 1.05, -0.15, 0, 1.11, -0.15, 0, 1.15, -0.79, 0, 0.68, -1.43, 0, 0.21, -1.55, 0, 0.12, -1.48, 0, 0.12, -1.23, 0, 0.12, -0.89, 0, 0.13, -0.53, 0, 0.13, -0.23, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14 },
			armR = { -0.15, 0, 0, -0.15, 0, 0.02, -0.15, 0, 0.07, -0.15, 0, 0.15, -0.15, 0, 0.24, -0.15, 0, 0.36, -0.15, 0, 0.48, -0.15, 0, 0.61, -0.15, 0, 0.73, -0.15, 0, 0.85, -0.15, 0, 0.96, -0.15, 0, 1.05, -0.15, 0, 1.11, -0.15, 0, 1.15, -0.79, 0, 0.68, -1.43, 0, 0.21, -1.55, 0, 0.12, -1.48, 0, 0.12, -1.23, 0, 0.12, -0.89, 0, 0.13, -0.53, 0, 0.13, -0.23, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02 },
		} },
		pull = { fps = 15, length = 1.2, hit = 0, loop = true, bones = {
			torso = { 0.18, 0, 0, 0.2, 0, 0, 0.22, 0, 0, 0.23, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.23, 0, 0, 0.22, 0, 0, 0.2, 0, 0, 0.18, 0, 0, 0.16, 0, 0, 0.14, 0, 0, 0.13, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.14, 0, 0, 0.16, 0, 0, 0.18, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0 },
			armL = { -1.25, 0, 0.2, -1.34, 0, 0.17, -1.41, 0, 0.14, -1.47, 0, 0.11, -1.5, 0, 0.1, -1.5, 0, 0.1, -1.47, 0, 0.11, -1.41, 0, 0.14, -1.34, 0, 0.17, -1.25, 0, 0.2, -1.16, 0, 0.23, -1.09, 0, 0.26, -1.03, 0, 0.29, -1, 0, 0.3, -1, 0, 0.3, -1.03, 0, 0.29, -1.09, 0, 0.26, -1.16, 0, 0.23, -1.25, 0, 0.2 },
			armR = { -1.25, 0, 0.2, -1.16, 0, 0.23, -1.09, 0, 0.26, -1.03, 0, 0.29, -1, 0, 0.3, -1, 0, 0.3, -1.03, 0, 0.29, -1.09, 0, 0.26, -1.16, 0, 0.23, -1.25, 0, 0.2, -1.34, 0, 0.17, -1.41, 0, 0.14, -1.47, 0, 0.11, -1.5, 0, 0.1, -1.5, 0, 0.1, -1.47, 0, 0.11, -1.41, 0, 0.14, -1.34, 0, 0.17, -1.25, 0, 0.2 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06 },
		} },
		sweep = { fps = 15, length = 2, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.02, 0, 0, -0.02, 0, 0 },
			armL = { -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05 },
			armR = { -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3 },
			wingR = { 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09 },
		} },
		floor = { fps = 15, length = 1, hit = 0, loop = true, bones = {
			torso = { 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0 },
			armL = { 0.35, 0, 0.35, 0.4, 0, 0.35, 0.44, 0, 0.35, 0.45, 0, 0.35, 0.43, 0, 0.35, 0.39, 0, 0.35, 0.34, 0, 0.35, 0.29, 0, 0.35, 0.26, 0, 0.35, 0.25, 0, 0.35, 0.28, 0, 0.35, 0.32, 0, 0.35, 0.37, 0, 0.35, 0.42, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35 },
			armR = { 0.43, 0, 0.35, 0.45, 0, 0.35, 0.44, 0, 0.35, 0.4, 0, 0.35, 0.35, 0, 0.35, 0.3, 0, 0.35, 0.26, 0, 0.35, 0.25, 0, 0.35, 0.27, 0, 0.35, 0.31, 0, 0.35, 0.37, 0, 0.35, 0.41, 0, 0.35, 0.44, 0, 0.35, 0.45, 0, 0.35, 0.42, 0, 0.35, 0.38, 0, 0.35 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09 },
		} },
		roar = { fps = 15, length = 1.8, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, -0.1, 0, 0, -0.17, 0, 0, -0.22, 0, 0, -0.25, 0, 0, -0.27, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0 },
			head = { 0, 0, 0, -0.17, 0, 0, -0.3, 0, 0, -0.39, 0, 0, -0.45, 0, 0, -0.48, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0 },
			armL = { 0, 0, 0, -0.12, 0, 0.45, -0.21, 0, 0.79, -0.27, 0, 1.02, -0.31, 0, 1.17, -0.34, 0, 1.25, -0.35, 0, 1.29, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3 },
			armR = { 0, 0, 0, -0.12, 0, 0.45, -0.21, 0, 0.79, -0.27, 0, 1.02, -0.31, 0, 1.17, -0.34, 0, 1.25, -0.35, 0, 1.29, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04 },
			wingL = { 0, 0, 0, 0, 0, 0.48, 0, 0, 0.69, 0, 0, 0.82, 0, 0, 0.99, 0, 0, 1.05, 0, 0, 0.96, 0, 0, 0.96, 0, 0, 1.04, 0, 0, 1.04, 0, 0, 0.95, 0, 0, 0.98, 0, 0, 1.06, 0, 0, 1.01, 0, 0, 0.94, 0, 0, 1, 0, 0, 1.06, 0, 0, 0.99, 0, 0, 0.94, 0, 0, 1.02, 0, 0, 1.05, 0, 0, 0.96, 0, 0, 0.96, 0, 0, 1.04, 0, 0, 1.04, 0, 0, 0.95, 0, 0, 0.98, 0, 0, 1.06 },
			wingR = { 0, 0, 0, 0, 0, 0.48, 0, 0, 0.69, 0, 0, 0.82, 0, 0, 0.99, 0, 0, 1.05, 0, 0, 0.96, 0, 0, 0.96, 0, 0, 1.04, 0, 0, 1.04, 0, 0, 0.95, 0, 0, 0.98, 0, 0, 1.06, 0, 0, 1.01, 0, 0, 0.94, 0, 0, 1, 0, 0, 1.06, 0, 0, 0.99, 0, 0, 0.94, 0, 0, 1.02, 0, 0, 1.05, 0, 0, 0.96, 0, 0, 0.96, 0, 0, 1.04, 0, 0, 1.04, 0, 0, 0.95, 0, 0, 0.98, 0, 0, 1.06 },
			cloth = { 0.1, 0, 0, 0.01, 0, 0, -0.05, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06 },
		} },
		summon = { fps = 15, length = 2, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, -0.04, 0, 0, -0.07, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.13, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			head = { 0, 0, 0, -0.08, 0, 0, -0.14, 0, 0, -0.19, 0, 0, -0.23, 0, 0, -0.26, 0, 0, -0.28, 0, 0, -0.29, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0 },
			armL = { 0, 0, 0, -0.46, 0, 0.13, -0.86, 0, 0.23, -1.22, 0, 0.32, -1.54, 0, 0.38, -1.78, 0, 0.43, -1.92, 0, 0.46, -1.96, 0, 0.48, -1.94, 0, 0.49, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5, -1.94, 0, 0.5, -1.92, 0, 0.5, -1.95, 0, 0.5, -2.02, 0, 0.5, -2.07, 0, 0.5, -2.08, 0, 0.5, -2.03, 0, 0.5, -1.97, 0, 0.5, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5 },
			armR = { 0, 0, 0, -0.46, 0, 0.13, -0.86, 0, 0.23, -1.22, 0, 0.32, -1.54, 0, 0.38, -1.78, 0, 0.43, -1.92, 0, 0.46, -1.96, 0, 0.48, -1.94, 0, 0.49, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5, -1.94, 0, 0.5, -1.92, 0, 0.5, -1.95, 0, 0.5, -2.02, 0, 0.5, -2.07, 0, 0.5, -2.08, 0, 0.5, -2.03, 0, 0.5, -1.97, 0, 0.5, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.7, 0, 0, 0.81, 0, 0, 0.85, 0, 0, 0.79, 0, 0, 0.67, 0, 0, 0.57, 0, 0, 0.56, 0, 0, 0.64, 0, 0, 0.76, 0, 0, 0.84, 0, 0, 0.83, 0, 0, 0.73, 0, 0, 0.61, 0, 0, 0.55, 0, 0, 0.59, 0, 0, 0.7, 0, 0, 0.81, 0, 0, 0.85, 0, 0, 0.79, 0, 0, 0.67, 0, 0, 0.57, 0, 0, 0.56, 0, 0, 0.64, 0, 0, 0.76, 0, 0, 0.84, 0, 0, 0.83, 0, 0, 0.73, 0, 0, 0.61, 0, 0, 0.55, 0, 0, 0.59, 0, 0, 0.7 },
			wingR = { 0, 0, 0.7, 0, 0, 0.81, 0, 0, 0.85, 0, 0, 0.79, 0, 0, 0.67, 0, 0, 0.57, 0, 0, 0.56, 0, 0, 0.64, 0, 0, 0.76, 0, 0, 0.84, 0, 0, 0.83, 0, 0, 0.73, 0, 0, 0.61, 0, 0, 0.55, 0, 0, 0.59, 0, 0, 0.7, 0, 0, 0.81, 0, 0, 0.85, 0, 0, 0.79, 0, 0, 0.67, 0, 0, 0.57, 0, 0, 0.56, 0, 0, 0.64, 0, 0, 0.76, 0, 0, 0.84, 0, 0, 0.83, 0, 0, 0.73, 0, 0, 0.61, 0, 0, 0.55, 0, 0, 0.59, 0, 0, 0.7 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09 },
		} },
		hit = { fps = 15, length = 0.5, hit = 0, loop = false, bones = {
			torso = { -0.35, 0, 0.1, -0.26, 0, 0.08, -0.19, 0, 0.05, -0.13, 0, 0.04, -0.08, 0, 0.02, -0.04, 0, 0.01, -0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
			head = { -0.3, 0, 0, -0.23, 0, 0, -0.16, 0, 0, -0.11, 0, 0, -0.07, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
			armL = { -0.2, 0, 0.4, -0.15, 0, 0.3, -0.11, 0, 0.22, -0.07, 0, 0.14, -0.04, 0, 0.09, -0.02, 0, 0.04, -0.01, 0, 0.02, 0, 0, 0, 0, 0, 0 },
			armR = { -0.2, 0, 0.4, -0.15, 0, 0.3, -0.11, 0, 0.22, -0.07, 0, 0.14, -0.04, 0, 0.09, -0.02, 0, 0.04, -0.01, 0, 0.02, 0, 0, 0, 0, 0, 0 },
			cloth = { 0.3, 0, 0, 0.23, 0, 0, 0.16, 0, 0, 0.11, 0, 0, 0.07, 0, 0, 0.03, 0, 0, 0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
		} },
		death = { fps = 15, length = 2.4, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0.01, 0.05, 0, 0.01, 0.07, 0, 0.02, 0.1, 0, 0.03, 0.13, 0, 0.04, 0.17, 0, 0.05, 0.21, 0, 0.06, 0.24, 0, 0.08, 0.28, 0, 0.09, 0.32, 0, 0.1, 0.37, 0, 0.11, 0.41, 0, 0.12, 0.44, 0, 0.14, 0.48, 0, 0.15, 0.52, 0, 0.16, 0.55, 0, 0.17, 0.58, 0, 0.18, 0.6, 0, 0.19, 0.62, 0, 0.19, 0.64, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.03, 0, 0.01, 0.05, 0, 0.02, 0.08, 0, 0.03, 0.11, 0, 0.05, 0.14, 0, 0.06, 0.18, 0, 0.08, 0.22, 0, 0.09, 0.26, 0, 0.11, 0.31, 0, 0.13, 0.35, 0, 0.15, 0.39, 0, 0.17, 0.44, 0, 0.19, 0.48, 0, 0.21, 0.52, 0, 0.22, 0.56, 0, 0.24, 0.59, 0, 0.25, 0.62, 0, 0.27, 0.65, 0, 0.28, 0.67, 0, 0.29, 0.69, 0, 0.29, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3 },
			armL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.03, 0, 0.02, 0.04, 0, 0.03, 0.05, 0, 0.04, 0.06, 0, 0.05, 0.07, 0, 0.06, 0.08, 0, 0.06, 0.09, 0, 0.07, 0.1, 0, 0.08, 0.11, 0, 0.09, 0.12, 0, 0.1, 0.13, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			armR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.03, 0, 0.02, 0.04, 0, 0.03, 0.05, 0, 0.04, 0.06, 0, 0.05, 0.07, 0, 0.06, 0.08, 0, 0.06, 0.09, 0, 0.07, 0.1, 0, 0.08, 0.11, 0, 0.09, 0.12, 0, 0.1, 0.13, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			legL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.06, 0.04, 0, 0.07, 0.06, 0, 0.07, 0.08, 0, 0.08, 0.1, 0, 0.09, 0.13, 0, 0.09, 0.16, 0, 0.09, 0.19, 0, 0.1, 0.22, 0, 0.1, 0.25, 0, 0.1, 0.28, 0, 0.1, 0.31, 0, 0.1, 0.34, 0, 0.1, 0.37, 0, 0.1, 0.4, 0, 0.1, 0.42, 0, 0.1, 0.44, 0, 0.1, 0.46, 0, 0.1, 0.48, 0, 0.1, 0.49, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1 },
			legR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.06, 0.04, 0, 0.07, 0.06, 0, 0.07, 0.08, 0, 0.08, 0.1, 0, 0.09, 0.13, 0, 0.09, 0.16, 0, 0.09, 0.19, 0, 0.1, 0.22, 0, 0.1, 0.25, 0, 0.1, 0.28, 0, 0.1, 0.31, 0, 0.1, 0.34, 0, 0.1, 0.37, 0, 0.1, 0.4, 0, 0.1, 0.42, 0, 0.1, 0.44, 0, 0.1, 0.46, 0, 0.1, 0.48, 0, 0.1, 0.49, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1 },
			wingL = { 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.05, 0, 0, -0.09, 0, 0, -0.13, 0, 0, -0.18, 0, 0, -0.23, 0, 0, -0.29, 0, 0, -0.35, 0, 0, -0.42, 0, 0, -0.48, 0, 0, -0.55, 0, 0, -0.61, 0, 0, -0.67, 0, 0, -0.72, 0, 0, -0.77, 0, 0, -0.81, 0, 0, -0.85, 0, 0, -0.88, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			wingR = { 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.05, 0, 0, -0.09, 0, 0, -0.13, 0, 0, -0.18, 0, 0, -0.23, 0, 0, -0.29, 0, 0, -0.35, 0, 0, -0.42, 0, 0, -0.48, 0, 0, -0.55, 0, 0, -0.61, 0, 0, -0.67, 0, 0, -0.72, 0, 0, -0.77, 0, 0, -0.81, 0, 0, -0.85, 0, 0, -0.88, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			cloth = { 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.06, 0, 0, 0.08, 0, 0, 0.1, 0, 0, 0.12, 0, 0, 0.14, 0, 0, 0.16, 0, 0, 0.18, 0, 0, 0.2, 0, 0, 0.22, 0, 0, 0.24, 0, 0, 0.26, 0, 0, 0.27, 0, 0, 0.28, 0, 0, 0.29, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0 },
		} },
	},
	Regent = {
		idle = { fps = 15, length = 3.9, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0.01, 0.02, 0, 0.01, 0.02, 0, 0.01, 0.03, 0, 0.01, 0.03, 0, 0.01, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.05, 0, 0.02, 0.05, 0, 0.02, 0.05, 0, 0.03, 0.05, 0, 0.03, 0.05, 0, 0.03, 0.05, 0, 0.03, 0.05, 0, 0.03, 0.05, 0, 0.03, 0.05, 0, 0.03, 0.05, 0, 0.03, 0.05, 0, 0.03, 0.05, 0, 0.03, 0.04, 0, 0.03, 0.04, 0, 0.03, 0.04, 0, 0.03, 0.03, 0, 0.03, 0.03, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.01, 0, 0.02, 0.01, 0, 0.02, 0, 0, 0.01, 0, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0.01, -0.02, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, -0.01, -0.04, 0, -0.01, -0.04, 0, -0.01, -0.05, 0, -0.01, -0.05, 0, -0.02, -0.05, 0, -0.02, -0.05, 0, -0.02, -0.05, 0, -0.02, -0.05, 0, -0.02, -0.05, 0, -0.02, -0.05, 0, -0.03, -0.05, 0, -0.03, -0.05, 0, -0.03, -0.05, 0, -0.03, -0.04, 0, -0.03, -0.04, 0, -0.03, -0.04, 0, -0.03, -0.03, 0, -0.03, -0.03, 0, -0.03, -0.02, 0, -0.03 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.01, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0 },
			armL = { 0.1, 0, 0.45, 0.1, 0, 0.45, 0.11, 0, 0.45, 0.11, 0, 0.45, 0.11, 0, 0.45, 0.12, 0, 0.45, 0.12, 0, 0.45, 0.12, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.12, 0, 0.45, 0.12, 0, 0.45, 0.12, 0, 0.45, 0.11, 0, 0.45, 0.11, 0, 0.45, 0.1, 0, 0.45, 0.1, 0, 0.45, 0.1, 0, 0.45, 0.09, 0, 0.45, 0.09, 0, 0.45, 0.09, 0, 0.45, 0.08, 0, 0.45, 0.08, 0, 0.45, 0.08, 0, 0.45, 0.07, 0, 0.45, 0.07, 0, 0.45, 0.07, 0, 0.45, 0.07, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.07, 0, 0.45, 0.07, 0, 0.45, 0.07, 0, 0.45 },
			armR = { 0.1, 0, 0.45, 0.1, 0, 0.45, 0.11, 0, 0.45, 0.11, 0, 0.45, 0.11, 0, 0.45, 0.12, 0, 0.45, 0.12, 0, 0.45, 0.12, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.14, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.13, 0, 0.45, 0.12, 0, 0.45, 0.12, 0, 0.45, 0.12, 0, 0.45, 0.11, 0, 0.45, 0.11, 0, 0.45, 0.1, 0, 0.45, 0.1, 0, 0.45, 0.1, 0, 0.45, 0.09, 0, 0.45, 0.09, 0, 0.45, 0.09, 0, 0.45, 0.08, 0, 0.45, 0.08, 0, 0.45, 0.08, 0, 0.45, 0.07, 0, 0.45, 0.07, 0, 0.45, 0.07, 0, 0.45, 0.07, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.06, 0, 0.45, 0.07, 0, 0.45, 0.07, 0, 0.45, 0.07, 0, 0.45 },
			legL = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12 },
			legR = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12 },
			wingL = { 0, 0, 0.12, 0, 0, 0.18, 0, 0, 0.23, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.25, 0, 0, 0.2, 0, 0, 0.15, 0, 0, 0.09, 0, 0, 0.03, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.01, 0, 0, 0.07, 0, 0, 0.13, 0, 0, 0.19, 0, 0, 0.24, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.25, 0, 0, 0.2, 0, 0, 0.14, 0, 0, 0.08, 0, 0, 0.02, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.02, 0, 0, 0.07, 0, 0, 0.13, 0, 0, 0.19, 0, 0, 0.24, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.24, 0, 0, 0.19, 0, 0, 0.13, 0, 0, 0.07, 0, 0, 0.02, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.08 },
			wingR = { 0, 0, 0.12, 0, 0, 0.18, 0, 0, 0.23, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.25, 0, 0, 0.2, 0, 0, 0.15, 0, 0, 0.09, 0, 0, 0.03, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.01, 0, 0, 0.07, 0, 0, 0.13, 0, 0, 0.19, 0, 0, 0.24, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.25, 0, 0, 0.2, 0, 0, 0.14, 0, 0, 0.08, 0, 0, 0.02, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.02, 0, 0, 0.07, 0, 0, 0.13, 0, 0, 0.19, 0, 0, 0.24, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.24, 0, 0, 0.19, 0, 0, 0.13, 0, 0, 0.07, 0, 0, 0.02, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.08 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.12, 0, 0.01, 0.13, 0, 0.02, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.12, 0, 0.05, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.07, 0, 0.04, 0.06, 0, 0.03, 0.05, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.08, 0, -0.04, 0.09, 0, -0.04, 0.1, 0, -0.04, 0.11, 0, -0.05, 0.12, 0, -0.05, 0.13, 0, -0.05, 0.14, 0, -0.05, 0.15, 0, -0.05, 0.16, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.15, 0, -0.03, 0.15, 0, -0.02, 0.14, 0, -0.02, 0.13, 0, -0.01, 0.12, 0, -0.01, 0.11, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.05, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.02, 0, 0, -0.01 },
		} },
		forming = { fps = 15, length = 3.9, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.01, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.01, 0, 0.03, 0.01, 0, 0.03, 0.01, 0, 0.02, 0.01, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.01, 0, -0.03, -0.01, 0, -0.03, -0.01, 0, -0.03, -0.01, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03 },
			head = { 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0 },
			armL = { -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25 },
			armR = { -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25, -0.75, 0, -0.25 },
			legL = { 0, 0, 0.04, 0.02, 0, 0.04, 0.04, 0, 0.04, 0.06, 0, 0.04, 0.08, 0, 0.04, 0.09, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.06, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.01, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.07, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.01, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.08, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.04, 0.06, 0, 0.04, 0.04, 0, 0.04, 0.02, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.04, 0, 0.04, -0.06, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.02, 0, 0.04, -0.04, 0, 0.04, -0.06, 0, 0.04, -0.08, 0, 0.04, -0.09, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.06, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.01, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.07, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.01, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.08, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.09, 0, 0.04, -0.07, 0, 0.04, -0.06, 0, 0.04, -0.04, 0, 0.04, -0.02, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.04, 0, 0.04, 0.06, 0, 0.04 },
			wingL = { 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5 },
			wingR = { 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.12, 0, 0.01, 0.13, 0, 0.02, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.12, 0, 0.05, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.07, 0, 0.04, 0.06, 0, 0.03, 0.05, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.08, 0, -0.04, 0.09, 0, -0.04, 0.1, 0, -0.04, 0.11, 0, -0.05, 0.12, 0, -0.05, 0.13, 0, -0.05, 0.14, 0, -0.05, 0.15, 0, -0.05, 0.16, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.15, 0, -0.03, 0.15, 0, -0.02, 0.14, 0, -0.02, 0.13, 0, -0.01, 0.12, 0, -0.01, 0.11, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.05, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.02, 0, 0, -0.01 },
		} },
		slam = { fps = 15, length = 2.34, hit = 1.43, loop = false, bones = {
			torso = { -0.1, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.12, 0, 0, -0.13, 0, 0, -0.14, 0, 0, -0.16, 0, 0, -0.18, 0, 0, -0.2, 0, 0, -0.22, 0, 0, -0.24, 0, 0, -0.27, 0, 0, -0.29, 0, 0, -0.31, 0, 0, -0.33, 0, 0, -0.35, 0, 0, -0.37, 0, 0, -0.38, 0, 0, -0.4, 0, 0, -0.41, 0, 0, -0.42, 0, 0, -0.42, 0, 0, 0.06, 0, 0, 0.36, 0, 0, 0.52, 0, 0, 0.58, 0, 0, 0.6, 0, 0, 0.59, 0, 0, 0.56, 0, 0, 0.5, 0, 0, 0.43, 0, 0, 0.35, 0, 0, 0.28, 0, 0, 0.21, 0, 0, 0.17, 0, 0, 0.15, 0, 0 },
			head = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.13, 0, 0, -0.15, 0, 0, -0.16, 0, 0, -0.18, 0, 0, -0.2, 0, 0, -0.21, 0, 0, -0.22, 0, 0, -0.23, 0, 0, -0.24, 0, 0, -0.25, 0, 0, -0.25, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.14, 0, 0, 0.12, 0, 0, 0.09, 0, 0, 0.07, 0, 0, 0.04, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0 },
			armL = { 0, 0, 0.1, -0.01, 0, 0.1, -0.06, 0, 0.1, -0.13, 0, 0.1, -0.21, 0, 0.1, -0.32, 0, 0.1, -0.45, 0, 0.1, -0.59, 0, 0.1, -0.74, 0, 0.1, -0.89, 0, 0.1, -1.06, 0, 0.1, -1.22, 0, 0.1, -1.38, 0, 0.1, -1.54, 0, 0.1, -1.7, 0, 0.1, -1.84, 0, 0.1, -1.97, 0, 0.1, -2.09, 0, 0.1, -2.19, 0, 0.1, -2.27, 0, 0.1, -2.32, 0, 0.1, -2.35, 0, 0.1, -1.54, 0, 0.1, -0.51, 0, 0.1, 0.06, 0, 0.1, 0.3, 0, 0.1, 0.35, 0, 0.1, 0.34, 0, 0.1, 0.31, 0, 0.1, 0.25, 0, 0.1, 0.19, 0, 0.1, 0.11, 0, 0.1, 0.04, 0, 0.1, -0.02, 0, 0.1, -0.06, 0, 0.1, -0.08, 0, 0.1 },
			armR = { 0, 0, 0.2, -0.01, 0, 0.2, -0.06, 0, 0.2, -0.13, 0, 0.2, -0.21, 0, 0.2, -0.32, 0, 0.2, -0.45, 0, 0.2, -0.59, 0, 0.2, -0.74, 0, 0.2, -0.89, 0, 0.2, -1.06, 0, 0.2, -1.22, 0, 0.2, -1.38, 0, 0.2, -1.54, 0, 0.2, -1.7, 0, 0.2, -1.84, 0, 0.2, -1.97, 0, 0.2, -2.09, 0, 0.2, -2.19, 0, 0.2, -2.27, 0, 0.2, -2.32, 0, 0.2, -2.35, 0, 0.2, -1.54, 0, 0.2, -0.51, 0, 0.2, 0.06, 0, 0.2, 0.3, 0, 0.2, 0.35, 0, 0.2, 0.34, 0, 0.2, 0.31, 0, 0.2, 0.25, 0, 0.2, 0.19, 0, 0.2, 0.11, 0, 0.2, 0.04, 0, 0.2, -0.02, 0, 0.2, -0.06, 0, 0.2, -0.08, 0, 0.2 },
			legL = { 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.05, 0.03, 0, 0.05, 0.04, 0, 0.05, 0.05, 0, 0.05, 0.06, 0, 0.05, 0.07, 0, 0.05, 0.08, 0, 0.05, 0.09, 0, 0.05, 0.1, 0, 0.05, 0.11, 0, 0.05, 0.12, 0, 0.05, 0.13, 0, 0.05, 0.13, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.07, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04 },
			legR = { 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.05, 0.03, 0, 0.05, 0.04, 0, 0.05, 0.05, 0, 0.05, 0.06, 0, 0.05, 0.07, 0, 0.05, 0.08, 0, 0.05, 0.09, 0, 0.05, 0.1, 0, 0.05, 0.11, 0, 0.05, 0.12, 0, 0.05, 0.13, 0, 0.05, 0.13, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.07, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.14, 0, 0, 0.15, 0, 0, 0.17, 0, 0, 0.19, 0, 0, 0.21, 0, 0, 0.23, 0, 0, 0.25, 0, 0, 0.28, 0, 0, 0.3, 0, 0, 0.33, 0, 0, 0.35, 0, 0, 0.37, 0, 0, 0.39, 0, 0, 0.41, 0, 0, 0.43, 0, 0, 0.45, 0, 0, 0.46, 0, 0, 0.47, 0, 0, 0.47, 0, 0, 0.3, 0, 0, 0.06, 0, 0, -0.08, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.12, 0, 0, -0.09, 0, 0, -0.05, 0, 0, 0, 0, 0, 0.04, 0, 0, 0.08, 0, 0, 0.11, 0, 0, 0.12 },
			wingR = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.14, 0, 0, 0.15, 0, 0, 0.17, 0, 0, 0.19, 0, 0, 0.21, 0, 0, 0.23, 0, 0, 0.25, 0, 0, 0.28, 0, 0, 0.3, 0, 0, 0.33, 0, 0, 0.35, 0, 0, 0.37, 0, 0, 0.39, 0, 0, 0.41, 0, 0, 0.43, 0, 0, 0.45, 0, 0, 0.46, 0, 0, 0.47, 0, 0, 0.47, 0, 0, 0.3, 0, 0, 0.06, 0, 0, -0.08, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.12, 0, 0, -0.09, 0, 0, -0.05, 0, 0, 0, 0, 0, 0.04, 0, 0, 0.08, 0, 0, 0.11, 0, 0, 0.12 },
			cloth = { -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, 0.44, 0, 0, 0.42, 0, 0, 0.4, 0, 0, 0.38, 0, 0, 0.36, 0, 0, 0.34, 0, 0, 0.32, 0, 0, 0.3, 0, 0, 0.28, 0, 0, 0.26, 0, 0, 0.24, 0, 0, 0.22, 0, 0, 0.2, 0, 0, 0.18, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.05, 0, 0, -0.06 },
		} },
		thrust = { fps = 15, length = 2.08, hit = 1.17, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.05, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.12, 0, 0, -0.13, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, 0.12, 0, 0, 0.28, 0, 0, 0.34, 0, 0, 0.35, 0, 0, 0.34, 0, 0, 0.3, 0, 0, 0.24, 0, 0, 0.17, 0, 0, 0.11, 0, 0, 0.05, 0, 0, 0.01, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0 },
			armL = { -0.15, 0, 0, -0.15, 0, 0.01, -0.15, 0, 0.04, -0.15, 0, 0.09, -0.15, 0, 0.15, -0.15, 0, 0.23, -0.15, 0, 0.31, -0.15, 0, 0.4, -0.15, 0, 0.5, -0.15, 0, 0.6, -0.15, 0, 0.69, -0.15, 0, 0.79, -0.15, 0, 0.88, -0.15, 0, 0.96, -0.15, 0, 1.03, -0.15, 0, 1.08, -0.15, 0, 1.12, -0.15, 0, 1.15, -0.62, 0, 0.8, -1.27, 0, 0.33, -1.51, 0, 0.15, -1.55, 0, 0.12, -1.49, 0, 0.12, -1.32, 0, 0.12, -1.08, 0, 0.13, -0.8, 0, 0.13, -0.53, 0, 0.13, -0.29, 0, 0.14, -0.13, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14 },
			armR = { -0.15, 0, 0, -0.15, 0, 0.01, -0.15, 0, 0.04, -0.15, 0, 0.09, -0.15, 0, 0.15, -0.15, 0, 0.23, -0.15, 0, 0.31, -0.15, 0, 0.4, -0.15, 0, 0.5, -0.15, 0, 0.6, -0.15, 0, 0.69, -0.15, 0, 0.79, -0.15, 0, 0.88, -0.15, 0, 0.96, -0.15, 0, 1.03, -0.15, 0, 1.08, -0.15, 0, 1.12, -0.15, 0, 1.15, -0.62, 0, 0.8, -1.27, 0, 0.33, -1.51, 0, 0.15, -1.55, 0, 0.12, -1.49, 0, 0.12, -1.32, 0, 0.12, -1.08, 0, 0.13, -0.8, 0, 0.13, -0.53, 0, 0.13, -0.29, 0, 0.14, -0.13, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14 },
			legL = { 0, 0, 0.04, 0.02, 0, 0.04, 0.04, 0, 0.04, 0.06, 0, 0.04, 0.08, 0, 0.04, 0.09, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.06, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.01, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.02, 0, 0.04, -0.04, 0, 0.04, -0.06, 0, 0.04, -0.08, 0, 0.04, -0.09, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.06, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.01, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.18, 0, 0, 0.23, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.25, 0, 0, 0.2, 0, 0, 0.15, 0, 0, 0.09, 0, 0, 0.03, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.01, 0, 0, 0.07, 0, 0, 0.13, 0, 0, 0.19, 0, 0, 0.24, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.25, 0, 0, 0.2, 0, 0, 0.14 },
			wingR = { 0, 0, 0.12, 0, 0, 0.18, 0, 0, 0.23, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.25, 0, 0, 0.2, 0, 0, 0.15, 0, 0, 0.09, 0, 0, 0.03, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.01, 0, 0, 0.07, 0, 0, 0.13, 0, 0, 0.19, 0, 0, 0.24, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.25, 0, 0, 0.2, 0, 0, 0.14 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.12, 0, 0.01, 0.13, 0, 0.02, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.12, 0, 0.05, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.07, 0, 0.04, 0.06, 0, 0.03, 0.05, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02 },
		} },
		pull = { fps = 15, length = 1.56, hit = 0, loop = true, bones = {
			torso = { 0.18, 0, 0, 0.2, 0, 0, 0.21, 0, 0, 0.22, 0, 0, 0.23, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.23, 0, 0, 0.22, 0, 0, 0.21, 0, 0, 0.19, 0, 0, 0.18, 0, 0, 0.16, 0, 0, 0.15, 0, 0, 0.13, 0, 0, 0.13, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.14, 0, 0, 0.16, 0, 0, 0.17, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0 },
			armL = { -1.05, 0, 0.4, -1.12, 0, 0.37, -1.18, 0, 0.35, -1.23, 0, 0.33, -1.27, 0, 0.31, -1.29, 0, 0.3, -1.3, 0, 0.3, -1.29, 0, 0.3, -1.26, 0, 0.32, -1.22, 0, 0.33, -1.16, 0, 0.36, -1.1, 0, 0.38, -1.03, 0, 0.41, -0.96, 0, 0.43, -0.91, 0, 0.46, -0.86, 0, 0.48, -0.82, 0, 0.49, -0.8, 0, 0.5, -0.8, 0, 0.5, -0.82, 0, 0.49, -0.85, 0, 0.48, -0.9, 0, 0.46, -0.96, 0, 0.44, -1.02, 0, 0.41 },
			armR = { -1.05, 0, 0.4, -0.98, 0, 0.43, -0.92, 0, 0.45, -0.87, 0, 0.47, -0.83, 0, 0.49, -0.81, 0, 0.5, -0.8, 0, 0.5, -0.81, 0, 0.5, -0.84, 0, 0.48, -0.88, 0, 0.47, -0.94, 0, 0.44, -1, 0, 0.42, -1.07, 0, 0.39, -1.14, 0, 0.37, -1.19, 0, 0.34, -1.24, 0, 0.32, -1.28, 0, 0.31, -1.3, 0, 0.3, -1.3, 0, 0.3, -1.28, 0, 0.31, -1.25, 0, 0.32, -1.2, 0, 0.34, -1.14, 0, 0.36, -1.08, 0, 0.39 },
			legL = { 0, 0, 0.04, 0.02, 0, 0.04, 0.04, 0, 0.04, 0.06, 0, 0.04, 0.08, 0, 0.04, 0.09, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.06, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.01, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.02, 0, 0.04, -0.04, 0, 0.04, -0.06, 0, 0.04, -0.08, 0, 0.04, -0.09, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.06, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.01, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.18, 0, 0, 0.23, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.25, 0, 0, 0.2, 0, 0, 0.15, 0, 0, 0.09, 0, 0, 0.03, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.01, 0, 0, 0.07, 0, 0, 0.13, 0, 0, 0.19, 0, 0, 0.24 },
			wingR = { 0, 0, 0.12, 0, 0, 0.18, 0, 0, 0.23, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.25, 0, 0, 0.2, 0, 0, 0.15, 0, 0, 0.09, 0, 0, 0.03, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.01, 0, 0, 0.07, 0, 0, 0.13, 0, 0, 0.19, 0, 0, 0.24 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.12, 0, 0.01, 0.13, 0, 0.02, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.12, 0, 0.05, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.07, 0, 0.04, 0.06, 0, 0.03 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06 },
		} },
		sweep = { fps = 15, length = 2.6, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.02, 0, 0, -0.02, 0, 0 },
			armL = { -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05 },
			armR = { -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5 },
			legL = { 0, 0, 0.04, 0.02, 0, 0.04, 0.04, 0, 0.04, 0.06, 0, 0.04, 0.08, 0, 0.04, 0.09, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.06, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.01, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.07, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.01, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.02, 0, 0.04, -0.04, 0, 0.04, -0.06, 0, 0.04, -0.08, 0, 0.04, -0.09, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.06, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.01, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.07, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.01, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.3, 0, 0, 0.39, 0, 0, 0.44, 0, 0, 0.44, 0, 0, 0.38, 0, 0, 0.29, 0, 0, 0.2, 0, 0, 0.15, 0, 0, 0.16, 0, 0, 0.23, 0, 0, 0.32, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.43, 0, 0, 0.36, 0, 0, 0.26, 0, 0, 0.18, 0, 0, 0.15, 0, 0, 0.18, 0, 0, 0.25, 0, 0, 0.35, 0, 0, 0.42, 0, 0, 0.45, 0, 0, 0.42, 0, 0, 0.34, 0, 0, 0.24, 0, 0, 0.17, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.28, 0, 0, 0.37, 0, 0, 0.44, 0, 0, 0.45, 0, 0, 0.4, 0, 0, 0.31, 0, 0, 0.22, 0, 0, 0.16, 0, 0, 0.16, 0, 0, 0.21, 0, 0, 0.3 },
			wingR = { 0, 0, 0.3, 0, 0, 0.39, 0, 0, 0.44, 0, 0, 0.44, 0, 0, 0.38, 0, 0, 0.29, 0, 0, 0.2, 0, 0, 0.15, 0, 0, 0.16, 0, 0, 0.23, 0, 0, 0.32, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.43, 0, 0, 0.36, 0, 0, 0.26, 0, 0, 0.18, 0, 0, 0.15, 0, 0, 0.18, 0, 0, 0.25, 0, 0, 0.35, 0, 0, 0.42, 0, 0, 0.45, 0, 0, 0.42, 0, 0, 0.34, 0, 0, 0.24, 0, 0, 0.17, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.28, 0, 0, 0.37, 0, 0, 0.44, 0, 0, 0.45, 0, 0, 0.4, 0, 0, 0.31, 0, 0, 0.22, 0, 0, 0.16, 0, 0, 0.16, 0, 0, 0.21, 0, 0, 0.3 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.12, 0, 0.01, 0.13, 0, 0.02, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.12, 0, 0.05, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.07, 0, 0.04, 0.06, 0, 0.03, 0.05, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.08, 0, -0.04, 0.09, 0, -0.04, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09 },
		} },
		floor = { fps = 15, length = 1.3, hit = 0, loop = true, bones = {
			torso = { 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0.01, 0, 0 },
			armL = { 0.35, 0, 0.35, 0.39, 0, 0.35, 0.42, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35, 0.44, 0, 0.35, 0.41, 0, 0.35, 0.37, 0, 0.35, 0.33, 0, 0.35, 0.29, 0, 0.35, 0.26, 0, 0.35, 0.25, 0, 0.35, 0.25, 0, 0.35, 0.28, 0, 0.35, 0.31, 0, 0.35, 0.35, 0, 0.35, 0.39, 0, 0.35, 0.42, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35, 0.44, 0, 0.35 },
			armR = { 0.43, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35, 0.43, 0, 0.35, 0.39, 0, 0.35, 0.35, 0, 0.35, 0.31, 0, 0.35, 0.28, 0, 0.35, 0.26, 0, 0.35, 0.25, 0, 0.35, 0.26, 0, 0.35, 0.29, 0, 0.35, 0.32, 0, 0.35, 0.37, 0, 0.35, 0.4, 0, 0.35, 0.43, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35, 0.43, 0, 0.35, 0.39, 0, 0.35, 0.35, 0, 0.35 },
			legL = { 0, 0, 0.04, 0.02, 0, 0.04, 0.04, 0, 0.04, 0.06, 0, 0.04, 0.08, 0, 0.04, 0.09, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.06, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.01, 0, 0.04, -0.03, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.02, 0, 0.04, -0.04, 0, 0.04, -0.06, 0, 0.04, -0.08, 0, 0.04, -0.09, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.06, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.01, 0, 0.04, 0.03, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.18, 0, 0, 0.23, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.25, 0, 0, 0.2, 0, 0, 0.15, 0, 0, 0.09, 0, 0, 0.03, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.01, 0, 0, 0.07 },
			wingR = { 0, 0, 0.12, 0, 0, 0.18, 0, 0, 0.23, 0, 0, 0.28, 0, 0, 0.31, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.29, 0, 0, 0.25, 0, 0, 0.2, 0, 0, 0.15, 0, 0, 0.09, 0, 0, 0.03, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.06, 0, 0, -0.03, 0, 0, 0.01, 0, 0, 0.07 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.12, 0, 0.01, 0.13, 0, 0.02, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.12, 0, 0.05, 0.11, 0, 0.04, 0.09, 0, 0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08 },
		} },
		roar = { fps = 15, length = 2.34, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, -0.08, 0, 0, -0.14, 0, 0, -0.19, 0, 0, -0.22, 0, 0, -0.25, 0, 0, -0.26, 0, 0, -0.27, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0 },
			head = { 0, 0, 0, -0.14, 0, 0, -0.25, 0, 0, -0.33, 0, 0, -0.4, 0, 0, -0.44, 0, 0, -0.47, 0, 0, -0.49, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0 },
			armL = { 0, 0, 0, -0.1, 0, 0.36, -0.17, 0, 0.65, -0.23, 0, 0.87, -0.28, 0, 1.03, -0.31, 0, 1.15, -0.33, 0, 1.23, -0.34, 0, 1.27, -0.35, 0, 1.29, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3 },
			armR = { 0, 0, 0, -0.1, 0, 0.36, -0.17, 0, 0.65, -0.23, 0, 0.87, -0.28, 0, 1.03, -0.31, 0, 1.15, -0.33, 0, 1.23, -0.34, 0, 1.27, -0.35, 0, 1.29, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3 },
			legL = { 0, 0, 0.04, 0.02, 0, 0.04, 0.04, 0, 0.04, 0.06, 0, 0.04, 0.08, 0, 0.04, 0.09, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.06, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.01, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.07, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.02, 0, 0.04, -0.04, 0, 0.04, -0.06, 0, 0.04, -0.08, 0, 0.04, -0.09, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.06, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.01, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.07, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.29, 0, 0, 0.43, 0, 0, 0.52, 0, 0, 0.55, 0, 0, 0.59, 0, 0, 0.65, 0, 0, 0.71, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.69, 0, 0, 0.65, 0, 0, 0.66, 0, 0, 0.7, 0, 0, 0.74, 0, 0, 0.75, 0, 0, 0.71, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.68, 0, 0, 0.72, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.69, 0, 0, 0.65, 0, 0, 0.66, 0, 0, 0.7, 0, 0, 0.74, 0, 0, 0.75, 0, 0, 0.71, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.68, 0, 0, 0.72, 0, 0, 0.75, 0, 0, 0.73 },
			wingR = { 0, 0, 0.12, 0, 0, 0.29, 0, 0, 0.43, 0, 0, 0.52, 0, 0, 0.55, 0, 0, 0.59, 0, 0, 0.65, 0, 0, 0.71, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.69, 0, 0, 0.65, 0, 0, 0.66, 0, 0, 0.7, 0, 0, 0.74, 0, 0, 0.75, 0, 0, 0.71, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.68, 0, 0, 0.72, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.69, 0, 0, 0.65, 0, 0, 0.66, 0, 0, 0.7, 0, 0, 0.74, 0, 0, 0.75, 0, 0, 0.71, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.68, 0, 0, 0.72, 0, 0, 0.75, 0, 0, 0.73 },
			cloth = { 0.1, 0, 0, 0.03, 0, 0, -0.02, 0, 0, -0.07, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.05, 0, 0, -0.06 },
		} },
		summon = { fps = 15, length = 2.6, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.12, 0, 0, -0.13, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			head = { 0, 0, 0, -0.06, 0, 0, -0.11, 0, 0, -0.16, 0, 0, -0.19, 0, 0, -0.22, 0, 0, -0.25, 0, 0, -0.27, 0, 0, -0.28, 0, 0, -0.29, 0, 0, -0.29, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0 },
			armL = { 0, 0, 0, -0.36, 0, 0.1, -0.68, 0, 0.19, -0.98, 0, 0.26, -1.25, 0, 0.32, -1.5, 0, 0.37, -1.7, 0, 0.41, -1.85, 0, 0.44, -1.93, 0, 0.46, -1.96, 0, 0.48, -1.95, 0, 0.49, -1.93, 0, 0.5, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.97, 0, 0.5, -2.02, 0, 0.5, -2.06, 0, 0.5, -2.08, 0, 0.5, -2.07, 0, 0.5, -2.03, 0, 0.5, -1.97, 0, 0.5, -1.93, 0, 0.5, -1.92, 0, 0.5, -1.94, 0, 0.5, -1.98, 0, 0.5, -2.03, 0, 0.5, -2.07, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2.01, 0, 0.5, -1.96, 0, 0.5, -1.93, 0, 0.5, -1.92, 0, 0.5, -1.95, 0, 0.5, -1.99, 0, 0.5, -2.04, 0, 0.5, -2.07, 0, 0.5, -2.08, 0, 0.5, -2.05, 0, 0.5, -2, 0, 0.5 },
			armR = { 0, 0, 0, -0.36, 0, 0.1, -0.68, 0, 0.19, -0.98, 0, 0.26, -1.25, 0, 0.32, -1.5, 0, 0.37, -1.7, 0, 0.41, -1.85, 0, 0.44, -1.93, 0, 0.46, -1.96, 0, 0.48, -1.95, 0, 0.49, -1.93, 0, 0.5, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.97, 0, 0.5, -2.02, 0, 0.5, -2.06, 0, 0.5, -2.08, 0, 0.5, -2.07, 0, 0.5, -2.03, 0, 0.5, -1.97, 0, 0.5, -1.93, 0, 0.5, -1.92, 0, 0.5, -1.94, 0, 0.5, -1.98, 0, 0.5, -2.03, 0, 0.5, -2.07, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2.01, 0, 0.5, -1.96, 0, 0.5, -1.93, 0, 0.5, -1.92, 0, 0.5, -1.95, 0, 0.5, -1.99, 0, 0.5, -2.04, 0, 0.5, -2.07, 0, 0.5, -2.08, 0, 0.5, -2.05, 0, 0.5, -2, 0, 0.5 },
			legL = { 0, 0, 0.04, 0.02, 0, 0.04, 0.04, 0, 0.04, 0.06, 0, 0.04, 0.08, 0, 0.04, 0.09, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.06, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.01, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.07, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.01, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.02, 0, 0.04, -0.04, 0, 0.04, -0.06, 0, 0.04, -0.08, 0, 0.04, -0.09, 0, 0.04, -0.1, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.06, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.01, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.1, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.07, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.01, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.27, 0, 0, 0.33, 0, 0, 0.38, 0, 0, 0.42, 0, 0, 0.45, 0, 0, 0.47, 0, 0, 0.49, 0, 0, 0.5, 0, 0, 0.51, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.27, 0, 0, 0.33, 0, 0, 0.38, 0, 0, 0.42, 0, 0, 0.45, 0, 0, 0.47, 0, 0, 0.49, 0, 0, 0.5, 0, 0, 0.51, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.12, 0, 0.01, 0.13, 0, 0.02, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.12, 0, 0.05, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.07, 0, 0.04, 0.06, 0, 0.03, 0.05, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.08, 0, -0.04, 0.09, 0, -0.04, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09 },
		} },
		hit = { fps = 15, length = 0.65, hit = 0, loop = false, bones = {
			torso = { -0.35, 0, 0.1, -0.28, 0, 0.08, -0.22, 0, 0.06, -0.17, 0, 0.05, -0.12, 0, 0.03, -0.08, 0, 0.02, -0.05, 0, 0.01, -0.03, 0, 0.01, -0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
			head = { -0.3, 0, 0, -0.24, 0, 0, -0.19, 0, 0, -0.14, 0, 0, -0.1, 0, 0, -0.07, 0, 0, -0.04, 0, 0, -0.02, 0, 0, -0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
			armL = { -0.2, 0, 0.4, -0.16, 0, 0.32, -0.13, 0, 0.25, -0.1, 0, 0.19, -0.07, 0, 0.14, -0.05, 0, 0.09, -0.03, 0, 0.06, -0.02, 0, 0.03, -0.01, 0, 0.01, 0, 0, 0, 0, 0, 0 },
			armR = { -0.2, 0, 0.4, -0.16, 0, 0.32, -0.13, 0, 0.25, -0.1, 0, 0.19, -0.07, 0, 0.14, -0.05, 0, 0.09, -0.03, 0, 0.06, -0.02, 0, 0.03, -0.01, 0, 0.01, 0, 0, 0, 0, 0, 0 },
			cloth = { 0.3, 0, 0, 0.24, 0, 0, 0.19, 0, 0, 0.14, 0, 0, 0.1, 0, 0, 0.07, 0, 0, 0.04, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
		} },
		death = { fps = 15, length = 3.12, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0.01, 0.03, 0, 0.01, 0.05, 0, 0.02, 0.07, 0, 0.02, 0.09, 0, 0.03, 0.11, 0, 0.03, 0.14, 0, 0.04, 0.17, 0, 0.05, 0.19, 0, 0.06, 0.22, 0, 0.07, 0.25, 0, 0.08, 0.28, 0, 0.09, 0.32, 0, 0.1, 0.35, 0, 0.11, 0.38, 0, 0.12, 0.41, 0, 0.13, 0.44, 0, 0.13, 0.47, 0, 0.14, 0.5, 0, 0.15, 0.52, 0, 0.16, 0.55, 0, 0.17, 0.57, 0, 0.17, 0.59, 0, 0.18, 0.61, 0, 0.19, 0.62, 0, 0.19, 0.63, 0, 0.2, 0.64, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0.01, 0.04, 0, 0.02, 0.05, 0, 0.02, 0.07, 0, 0.03, 0.1, 0, 0.04, 0.12, 0, 0.05, 0.15, 0, 0.06, 0.18, 0, 0.08, 0.21, 0, 0.09, 0.24, 0, 0.1, 0.27, 0, 0.12, 0.31, 0, 0.13, 0.34, 0, 0.15, 0.37, 0, 0.16, 0.41, 0, 0.17, 0.44, 0, 0.19, 0.47, 0, 0.2, 0.5, 0, 0.22, 0.53, 0, 0.23, 0.56, 0, 0.24, 0.59, 0, 0.25, 0.61, 0, 0.26, 0.63, 0, 0.27, 0.65, 0, 0.28, 0.67, 0, 0.29, 0.68, 0, 0.29, 0.69, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3 },
			armL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.01, 0.02, 0, 0.02, 0.03, 0, 0.02, 0.04, 0, 0.03, 0.05, 0, 0.04, 0.05, 0, 0.04, 0.06, 0, 0.05, 0.07, 0, 0.06, 0.08, 0, 0.06, 0.09, 0, 0.07, 0.09, 0, 0.08, 0.1, 0, 0.08, 0.11, 0, 0.09, 0.12, 0, 0.09, 0.12, 0, 0.1, 0.13, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.14, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			armR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.01, 0.02, 0, 0.02, 0.03, 0, 0.02, 0.04, 0, 0.03, 0.05, 0, 0.04, 0.05, 0, 0.04, 0.06, 0, 0.05, 0.07, 0, 0.06, 0.08, 0, 0.06, 0.09, 0, 0.07, 0.09, 0, 0.08, 0.1, 0, 0.08, 0.11, 0, 0.09, 0.12, 0, 0.09, 0.12, 0, 0.1, 0.13, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.14, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			legL = { 0, 0, 0.1, 0, 0, 0.1, -0.01, 0, 0.1, -0.02, 0, 0.1, -0.04, 0, 0.1, -0.06, 0, 0.1, -0.08, 0, 0.1, -0.1, 0, 0.1, -0.13, 0, 0.1, -0.16, 0, 0.1, -0.19, 0, 0.1, -0.23, 0, 0.1, -0.26, 0, 0.1, -0.3, 0, 0.1, -0.34, 0, 0.1, -0.38, 0, 0.1, -0.42, 0, 0.1, -0.45, 0, 0.1, -0.49, 0, 0.1, -0.53, 0, 0.1, -0.56, 0, 0.1, -0.6, 0, 0.1, -0.63, 0, 0.1, -0.66, 0, 0.1, -0.69, 0, 0.1, -0.72, 0, 0.1, -0.74, 0, 0.1, -0.76, 0, 0.1, -0.78, 0, 0.1, -0.79, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1 },
			legR = { 0, 0, 0.1, 0, 0, 0.1, -0.01, 0, 0.1, -0.02, 0, 0.1, -0.04, 0, 0.1, -0.06, 0, 0.1, -0.08, 0, 0.1, -0.1, 0, 0.1, -0.13, 0, 0.1, -0.16, 0, 0.1, -0.19, 0, 0.1, -0.23, 0, 0.1, -0.26, 0, 0.1, -0.3, 0, 0.1, -0.34, 0, 0.1, -0.38, 0, 0.1, -0.42, 0, 0.1, -0.45, 0, 0.1, -0.49, 0, 0.1, -0.53, 0, 0.1, -0.56, 0, 0.1, -0.6, 0, 0.1, -0.63, 0, 0.1, -0.66, 0, 0.1, -0.69, 0, 0.1, -0.72, 0, 0.1, -0.74, 0, 0.1, -0.76, 0, 0.1, -0.78, 0, 0.1, -0.79, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1, -0.8, 0, 0.1 },
			wingL = { 0, 0, 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.08, 0, 0, -0.11, 0, 0, -0.15, 0, 0, -0.19, 0, 0, -0.23, 0, 0, -0.27, 0, 0, -0.32, 0, 0, -0.37, 0, 0, -0.42, 0, 0, -0.47, 0, 0, -0.52, 0, 0, -0.57, 0, 0, -0.61, 0, 0, -0.66, 0, 0, -0.7, 0, 0, -0.74, 0, 0, -0.78, 0, 0, -0.81, 0, 0, -0.84, 0, 0, -0.86, 0, 0, -0.88, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			wingR = { 0, 0, 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.08, 0, 0, -0.11, 0, 0, -0.15, 0, 0, -0.19, 0, 0, -0.23, 0, 0, -0.27, 0, 0, -0.32, 0, 0, -0.37, 0, 0, -0.42, 0, 0, -0.47, 0, 0, -0.52, 0, 0, -0.57, 0, 0, -0.61, 0, 0, -0.66, 0, 0, -0.7, 0, 0, -0.74, 0, 0, -0.78, 0, 0, -0.81, 0, 0, -0.84, 0, 0, -0.86, 0, 0, -0.88, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			cloth = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.11, 0, 0, 0.12, 0, 0, 0.14, 0, 0, 0.16, 0, 0, 0.17, 0, 0, 0.19, 0, 0, 0.2, 0, 0, 0.22, 0, 0, 0.23, 0, 0, 0.25, 0, 0, 0.26, 0, 0, 0.27, 0, 0, 0.28, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0 },
		} },
	},
	Rime = {
		idle = { fps = 15, length = 4.5, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.01, 0, 0.02, 0.01, 0, 0.02, 0.01, 0, 0.02, 0.01, 0, 0.02, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, -0.01, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.01, 0, -0.02, -0.01, 0, -0.02, -0.01, 0, -0.02, -0.01, 0, -0.02, 0, 0, -0.02 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.02, 0, 0 },
			armL = { 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.03, 0, 0.3 },
			armR = { 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.03, 0, 0.3 },
			legL = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, 0.05, 0, 0.04, 0.05, 0, 0.04, 0.05, 0, 0.04, 0.05, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, -0.01, 0, 0.04, -0.01, 0, 0.04, -0.01, 0, 0.04, -0.01, 0, 0.04, -0.07, 0, 0.04 },
			legR = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, -0.05, 0, 0.04, -0.05, 0, 0.04, -0.05, 0, 0.04, -0.05, 0, 0.04, -0.1, 0, 0.04, -0.1, 0, 0.04, -0.1, 0, 0.04, -0.1, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.1, 0, 0.04, -0.1, 0, 0.04, -0.1, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, 0.01, 0, 0.04, 0.01, 0, 0.04, 0.01, 0, 0.04, 0.01, 0, 0.04, 0.07, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.16, 0, 0, 0.16, 0, 0, 0.16, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.23, 0, 0, 0.23, 0, 0, 0.23, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0, 0, -0.07, 0, 0, -0.07, 0, 0, -0.07, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.13, 0, 0, 0.13, 0, 0, 0.13, 0, 0, 0.13, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.07 },
			wingR = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.16, 0, 0, 0.16, 0, 0, 0.16, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.23, 0, 0, 0.23, 0, 0, 0.23, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0, 0, -0.07, 0, 0, -0.07, 0, 0, -0.07, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.13, 0, 0, 0.13, 0, 0, 0.13, 0, 0, 0.13, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.07 },
			cloth = { 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.06, 0, 0.03, 0.06, 0, 0.03, 0.06, 0, 0.03, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, -0.02, 0.04, 0, -0.02, 0.04, 0, -0.02, 0.04, 0, -0.02, 0.06, 0, -0.03, 0.06, 0, -0.03, 0.06, 0, -0.03, 0.1, 0, -0.04, 0.1, 0, -0.04, 0.1, 0, -0.04, 0.1, 0, -0.04, 0.14, 0, -0.05, 0.14, 0, -0.05, 0.14, 0, -0.05, 0.14, 0, -0.05, 0.16, 0, -0.05, 0.16, 0, -0.05, 0.16, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.16, 0, -0.03, 0.16, 0, -0.03, 0.16, 0, -0.03, 0.14, 0, -0.02, 0.14, 0, -0.02, 0.14, 0, -0.02, 0.14, 0, -0.02, 0.1, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, 0 },
		} },
		forming = { fps = 15, length = 4.5, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.01, 0, 0.02, 0.01, 0, 0.02, 0.01, 0, 0.02, 0.01, 0, 0.02, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, -0.01, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.01, 0, -0.02, -0.01, 0, -0.02, -0.01, 0, -0.02, -0.01, 0, -0.02, 0, 0, -0.02 },
			head = { 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0 },
			armL = { 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.03, 0, 0.3 },
			armR = { 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.07, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.06, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.05, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.04, 0, 0.3, 0.03, 0, 0.3 },
			legL = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, 0.05, 0, 0.04, 0.05, 0, 0.04, 0.05, 0, 0.04, 0.05, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, -0.01, 0, 0.04, -0.01, 0, 0.04, -0.01, 0, 0.04, -0.01, 0, 0.04, -0.07, 0, 0.04 },
			legR = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, -0.05, 0, 0.04, -0.05, 0, 0.04, -0.05, 0, 0.04, -0.05, 0, 0.04, -0.1, 0, 0.04, -0.1, 0, 0.04, -0.1, 0, 0.04, -0.1, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.1, 0, 0.04, -0.1, 0, 0.04, -0.1, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, 0.01, 0, 0.04, 0.01, 0, 0.04, 0.01, 0, 0.04, 0.01, 0, 0.04, 0.07, 0, 0.04 },
			wingL = { 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5 },
			wingR = { 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5 },
			cloth = { 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.06, 0, 0.03, 0.06, 0, 0.03, 0.06, 0, 0.03, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, -0.02, 0.04, 0, -0.02, 0.04, 0, -0.02, 0.04, 0, -0.02, 0.06, 0, -0.03, 0.06, 0, -0.03, 0.06, 0, -0.03, 0.1, 0, -0.04, 0.1, 0, -0.04, 0.1, 0, -0.04, 0.1, 0, -0.04, 0.14, 0, -0.05, 0.14, 0, -0.05, 0.14, 0, -0.05, 0.14, 0, -0.05, 0.16, 0, -0.05, 0.16, 0, -0.05, 0.16, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.16, 0, -0.03, 0.16, 0, -0.03, 0.16, 0, -0.03, 0.14, 0, -0.02, 0.14, 0, -0.02, 0.14, 0, -0.02, 0.14, 0, -0.02, 0.1, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, 0 },
		} },
		slam = { fps = 15, length = 2.7, hit = 1.65, loop = false, bones = {
			torso = { -0.05, 0, 0, -0.05, 0, 0, -0.05, 0, 0, -0.05, 0, 0, -0.07, 0, 0, -0.07, 0, 0, -0.07, 0, 0, -0.07, 0, 0, -0.12, 0, 0, -0.12, 0, 0, -0.12, 0, 0, -0.12, 0, 0, -0.19, 0, 0, -0.19, 0, 0, -0.19, 0, 0, -0.26, 0, 0, -0.26, 0, 0, -0.26, 0, 0, -0.26, 0, 0, -0.32, 0, 0, -0.32, 0, 0, -0.32, 0, 0, -0.32, 0, 0, -0.36, 0, 0, -0.36, 0, 0, -0.36, 0, 0, -0.36, 0, 0, 0.25, 0, 0, 0.25, 0, 0, 0.25, 0, 0, 0.55, 0, 0, 0.55, 0, 0, 0.55, 0, 0, 0.55, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.2, 0, 0, 0.2, 0, 0, 0.2, 0, 0 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.05, 0, 0, -0.05, 0, 0, -0.05, 0, 0, -0.05, 0, 0, -0.11, 0, 0, -0.11, 0, 0, -0.11, 0, 0, -0.16, 0, 0, -0.16, 0, 0, -0.16, 0, 0, -0.16, 0, 0, -0.21, 0, 0, -0.21, 0, 0, -0.21, 0, 0, -0.21, 0, 0, -0.24, 0, 0, -0.24, 0, 0, -0.24, 0, 0, -0.24, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.11, 0, 0, 0.11, 0, 0, 0.11, 0, 0, 0.11, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0 },
			armL = { 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, -0.15, 0, 0.1, -0.15, 0, 0.1, -0.15, 0, 0.1, -0.15, 0, 0.1, -0.52, 0, 0.1, -0.52, 0, 0.1, -0.52, 0, 0.1, -0.52, 0, 0.1, -1.02, 0, 0.1, -1.02, 0, 0.1, -1.02, 0, 0.1, -1.54, 0, 0.1, -1.54, 0, 0.1, -1.54, 0, 0.1, -1.54, 0, 0.1, -2, 0, 0.1, -2, 0, 0.1, -2, 0, 0.1, -2, 0, 0.1, -2.3, 0, 0.1, -2.3, 0, 0.1, -2.3, 0, 0.1, -2.3, 0, 0.1, -0.71, 0, 0.1, -0.71, 0, 0.1, -0.71, 0, 0.1, 0.35, 0, 0.1, 0.35, 0, 0.1, 0.35, 0, 0.1, 0.35, 0, 0.1, 0.24, 0, 0.1, 0.24, 0, 0.1, 0.24, 0, 0.1, 0.24, 0, 0.1, 0.01, 0, 0.1, 0.01, 0, 0.1, 0.01, 0, 0.1 },
			armR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.04, 0, 0.02, -0.04, 0, 0.02, -0.04, 0, 0.02, -0.04, 0, 0.02, -0.15, 0, 0.08, -0.15, 0, 0.08, -0.15, 0, 0.08, -0.15, 0, 0.08, -0.3, 0, 0.15, -0.3, 0, 0.15, -0.3, 0, 0.15, -0.46, 0, 0.23, -0.46, 0, 0.23, -0.46, 0, 0.23, -0.46, 0, 0.23, -0.6, 0, 0.3, -0.6, 0, 0.3, -0.6, 0, 0.3, -0.6, 0, 0.3, -0.68, 0, 0.34, -0.68, 0, 0.34, -0.68, 0, 0.34, -0.68, 0, 0.34, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.26, -0.3, 0, 0.26, -0.3, 0, 0.26, -0.3, 0, 0.26, -0.3, 0, 0.17, -0.3, 0, 0.17, -0.3, 0, 0.17 },
			legL = { 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.03, 0, 0.05, 0.03, 0, 0.05, 0.03, 0, 0.05, 0.03, 0, 0.05, 0.06, 0, 0.05, 0.06, 0, 0.05, 0.06, 0, 0.05, 0.1, 0, 0.05, 0.1, 0, 0.05, 0.1, 0, 0.05, 0.1, 0, 0.05, 0.13, 0, 0.05, 0.13, 0, 0.05, 0.13, 0, 0.05, 0.13, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04 },
			legR = { 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.03, 0, 0.05, 0.03, 0, 0.05, 0.03, 0, 0.05, 0.03, 0, 0.05, 0.06, 0, 0.05, 0.06, 0, 0.05, 0.06, 0, 0.05, 0.1, 0, 0.05, 0.1, 0, 0.05, 0.1, 0, 0.05, 0.1, 0, 0.05, 0.13, 0, 0.05, 0.13, 0, 0.05, 0.13, 0, 0.05, 0.13, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.14, 0, 0, 0.14, 0, 0, 0.14, 0, 0, 0.14, 0, 0, 0.2, 0, 0, 0.2, 0, 0, 0.2, 0, 0, 0.2, 0, 0, 0.27, 0, 0, 0.27, 0, 0, 0.27, 0, 0, 0.35, 0, 0, 0.35, 0, 0, 0.35, 0, 0, 0.35, 0, 0, 0.42, 0, 0, 0.42, 0, 0, 0.42, 0, 0, 0.42, 0, 0, 0.46, 0, 0, 0.46, 0, 0, 0.46, 0, 0, 0.46, 0, 0, 0.11, 0, 0, 0.11, 0, 0, 0.11, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06 },
			wingR = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.14, 0, 0, 0.14, 0, 0, 0.14, 0, 0, 0.14, 0, 0, 0.2, 0, 0, 0.2, 0, 0, 0.2, 0, 0, 0.2, 0, 0, 0.27, 0, 0, 0.27, 0, 0, 0.27, 0, 0, 0.35, 0, 0, 0.35, 0, 0, 0.35, 0, 0, 0.35, 0, 0, 0.42, 0, 0, 0.42, 0, 0, 0.42, 0, 0, 0.42, 0, 0, 0.46, 0, 0, 0.46, 0, 0, 0.46, 0, 0, 0.46, 0, 0, 0.11, 0, 0, 0.11, 0, 0, 0.11, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06 },
			cloth = { -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, 0.42, 0, 0, 0.42, 0, 0, 0.42, 0, 0, 0.36, 0, 0, 0.36, 0, 0, 0.36, 0, 0, 0.36, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.23, 0, 0, 0.23, 0, 0, 0.23, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03 },
		} },
		thrust = { fps = 15, length = 2.4, hit = 1.35, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.05, 0, 0, -0.05, 0, 0, -0.05, 0, 0, -0.05, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.12, 0, 0, -0.12, 0, 0, -0.12, 0, 0, -0.12, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.11, 0, 0, 0.11, 0, 0, 0.11, 0, 0, 0.11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0 },
			armL = { -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0.1, -0.15, 0, 0.1, -0.15, 0, 0.1, -0.15, 0, 0.1, -0.15, 0, 0.36, -0.15, 0, 0.36, -0.15, 0, 0.36, -0.15, 0, 0.36, -0.15, 0, 0.67, -0.15, 0, 0.67, -0.15, 0, 0.67, -0.15, 0, 0.96, -0.15, 0, 0.96, -0.15, 0, 0.96, -0.15, 0, 0.96, -0.15, 0, 1.13, -0.15, 0, 1.13, -0.15, 0, 1.13, -0.15, 0, 1.13, -1.43, 0, 0.21, -1.43, 0, 0.21, -1.43, 0, 0.21, -1.43, 0, 0.21, -1.37, 0, 0.12, -1.37, 0, 0.12, -1.37, 0, 0.12, -0.53, 0, 0.13, -0.53, 0, 0.13, -0.53, 0, 0.13, -0.53, 0, 0.13, -0.08, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14 },
			armR = { -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0.1, -0.15, 0, 0.1, -0.15, 0, 0.1, -0.15, 0, 0.1, -0.15, 0, 0.36, -0.15, 0, 0.36, -0.15, 0, 0.36, -0.15, 0, 0.36, -0.15, 0, 0.67, -0.15, 0, 0.67, -0.15, 0, 0.67, -0.15, 0, 0.96, -0.15, 0, 0.96, -0.15, 0, 0.96, -0.15, 0, 0.96, -0.15, 0, 1.13, -0.15, 0, 1.13, -0.15, 0, 1.13, -0.15, 0, 1.13, -1.43, 0, 0.21, -1.43, 0, 0.21, -1.43, 0, 0.21, -1.43, 0, 0.21, -1.37, 0, 0.12, -1.37, 0, 0.12, -1.37, 0, 0.12, -0.53, 0, 0.13, -0.53, 0, 0.13, -0.53, 0, 0.13, -0.53, 0, 0.13, -0.08, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14 },
			legL = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04 },
			legR = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.16, 0, 0, 0.16, 0, 0, 0.16, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.23, 0, 0, 0.23, 0, 0, 0.23, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.24 },
			wingR = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.16, 0, 0, 0.16, 0, 0, 0.16, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.23, 0, 0, 0.23, 0, 0, 0.23, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.32, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.24 },
			cloth = { 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.06, 0, 0.03, 0.06, 0, 0.03, 0.06, 0, 0.03, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
		} },
		pull = { fps = 15, length = 1.8, hit = 0, loop = true, bones = {
			torso = { 0.18, 0, 0, 0.18, 0, 0, 0.18, 0, 0, 0.18, 0, 0, 0.23, 0, 0, 0.23, 0, 0, 0.23, 0, 0, 0.23, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.21, 0, 0, 0.21, 0, 0, 0.21, 0, 0, 0.16, 0, 0, 0.16, 0, 0, 0.16, 0, 0, 0.16, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.13, 0, 0, 0.13, 0, 0, 0.13, 0, 0, 0.17, 0, 0 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, -0.01, 0, 0 },
			armL = { -1.25, 0, 0.2, -1.25, 0, 0.2, -1.25, 0, 0.2, -1.25, 0, 0.2, -1.44, 0, 0.12, -1.44, 0, 0.12, -1.44, 0, 0.12, -1.44, 0, 0.12, -1.5, 0, 0.1, -1.5, 0, 0.1, -1.5, 0, 0.1, -1.5, 0, 0.1, -1.38, 0, 0.15, -1.38, 0, 0.15, -1.38, 0, 0.15, -1.16, 0, 0.23, -1.16, 0, 0.23, -1.16, 0, 0.23, -1.16, 0, 0.23, -1.02, 0, 0.29, -1.02, 0, 0.29, -1.02, 0, 0.29, -1.02, 0, 0.29, -1.03, 0, 0.29, -1.03, 0, 0.29, -1.03, 0, 0.29, -1.03, 0, 0.29, -1.21, 0, 0.22 },
			armR = { -1.25, 0, 0.2, -1.25, 0, 0.2, -1.25, 0, 0.2, -1.25, 0, 0.2, -1.06, 0, 0.28, -1.06, 0, 0.28, -1.06, 0, 0.28, -1.06, 0, 0.28, -1, 0, 0.3, -1, 0, 0.3, -1, 0, 0.3, -1, 0, 0.3, -1.12, 0, 0.25, -1.12, 0, 0.25, -1.12, 0, 0.25, -1.34, 0, 0.17, -1.34, 0, 0.17, -1.34, 0, 0.17, -1.34, 0, 0.17, -1.48, 0, 0.11, -1.48, 0, 0.11, -1.48, 0, 0.11, -1.48, 0, 0.11, -1.47, 0, 0.11, -1.47, 0, 0.11, -1.47, 0, 0.11, -1.47, 0, 0.11, -1.29, 0, 0.18 },
			legL = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.08, 0, 0.04 },
			legR = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.08, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.16, 0, 0, 0.16, 0, 0, 0.16, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.23 },
			wingR = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.16, 0, 0, 0.16, 0, 0, 0.16, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.23 },
			cloth = { 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.06, 0, 0.03 },
			blades = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.06 },
		} },
		sweep = { fps = 15, length = 3, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.02, 0, 0 },
			armL = { -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05 },
			armR = { -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5 },
			legL = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.3 },
			wingR = { 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.43, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.17, 0, 0, 0.3 },
			cloth = { 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.06, 0, 0.03, 0.06, 0, 0.03, 0.06, 0, 0.03, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, -0.02, 0.04, 0, -0.02, 0.04, 0, -0.02, 0.04, 0, -0.02, 0.06, 0, -0.03, 0.06, 0, -0.03, 0.06, 0, -0.03, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.09 },
		} },
		floor = { fps = 15, length = 1.5, hit = 0, loop = true, bones = {
			torso = { 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0 },
			armL = { 0.35, 0, 0.35, 0.35, 0, 0.35, 0.35, 0, 0.35, 0.35, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35, 0.39, 0, 0.35, 0.39, 0, 0.35, 0.39, 0, 0.35, 0.39, 0, 0.35, 0.27, 0, 0.35, 0.27, 0, 0.35, 0.27, 0, 0.35, 0.28, 0, 0.35, 0.28, 0, 0.35, 0.28, 0, 0.35, 0.28, 0, 0.35, 0.4, 0, 0.35, 0.4, 0, 0.35, 0.4, 0, 0.35, 0.4, 0, 0.35 },
			armR = { 0.43, 0, 0.35, 0.43, 0, 0.35, 0.43, 0, 0.35, 0.43, 0, 0.35, 0.42, 0, 0.35, 0.42, 0, 0.35, 0.42, 0, 0.35, 0.42, 0, 0.35, 0.3, 0, 0.35, 0.3, 0, 0.35, 0.3, 0, 0.35, 0.3, 0, 0.35, 0.26, 0, 0.35, 0.26, 0, 0.35, 0.26, 0, 0.35, 0.37, 0, 0.35, 0.37, 0, 0.35, 0.37, 0, 0.35, 0.37, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35 },
			legL = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04 },
			legR = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.16, 0, 0, 0.16, 0, 0, 0.16, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08 },
			wingR = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.29, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.31, 0, 0, 0.16, 0, 0, 0.16, 0, 0, 0.16, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08 },
			cloth = { 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05 },
			blades = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1 },
		} },
		roar = { fps = 15, length = 2.7, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.27, 0, 0, -0.27, 0, 0, -0.27, 0, 0, -0.27, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.35, 0, 0, -0.35, 0, 0, -0.35, 0, 0, -0.35, 0, 0, -0.48, 0, 0, -0.48, 0, 0, -0.48, 0, 0, -0.48, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0 },
			armL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.25, 0, 0.91, -0.25, 0, 0.91, -0.25, 0, 0.91, -0.25, 0, 0.91, -0.34, 0, 1.25, -0.34, 0, 1.25, -0.34, 0, 1.25, -0.34, 0, 1.25, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3 },
			armR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.25, 0, 0.91, -0.25, 0, 0.91, -0.25, 0, 0.91, -0.25, 0, 0.91, -0.34, 0, 1.25, -0.34, 0, 1.25, -0.34, 0, 1.25, -0.34, 0, 1.25, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3 },
			legL = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04 },
			legR = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.53, 0, 0, 0.53, 0, 0, 0.53, 0, 0, 0.53, 0, 0, 0.68, 0, 0, 0.68, 0, 0, 0.68, 0, 0, 0.68, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7 },
			wingR = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.53, 0, 0, 0.53, 0, 0, 0.53, 0, 0, 0.53, 0, 0, 0.68, 0, 0, 0.68, 0, 0, 0.68, 0, 0, 0.68, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7, 0, 0, 0.7 },
			cloth = { 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03 },
		} },
		summon = { fps = 15, length = 3, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.08, 0, 0, -0.13, 0, 0, -0.13, 0, 0, -0.13, 0, 0, -0.13, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.17, 0, 0, -0.17, 0, 0, -0.17, 0, 0, -0.17, 0, 0, -0.26, 0, 0, -0.26, 0, 0, -0.26, 0, 0, -0.26, 0, 0, -0.29, 0, 0, -0.29, 0, 0, -0.29, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0 },
			armL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1.05, 0, 0.28, -1.05, 0, 0.28, -1.05, 0, 0.28, -1.05, 0, 0.28, -1.78, 0, 0.43, -1.78, 0, 0.43, -1.78, 0, 0.43, -1.78, 0, 0.43, -1.95, 0, 0.49, -1.95, 0, 0.49, -1.95, 0, 0.49, -1.93, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2, 0, 0.5, -2, 0, 0.5, -2, 0, 0.5, -2, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2, 0, 0.5, -2, 0, 0.5, -2, 0, 0.5, -2, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2, 0, 0.5 },
			armR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1.05, 0, 0.28, -1.05, 0, 0.28, -1.05, 0, 0.28, -1.05, 0, 0.28, -1.78, 0, 0.43, -1.78, 0, 0.43, -1.78, 0, 0.43, -1.78, 0, 0.43, -1.95, 0, 0.49, -1.95, 0, 0.49, -1.95, 0, 0.49, -1.93, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2, 0, 0.5, -2, 0, 0.5, -2, 0, 0.5, -2, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2, 0, 0.5, -2, 0, 0.5, -2, 0, 0.5, -2, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -1.93, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2.07, 0, 0.5, -2, 0, 0.5 },
			legL = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.06, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.09, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, 0.04, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.08, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.06, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.09, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, -0.04, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.11, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.08, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, 0.02, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.34, 0, 0, 0.34, 0, 0, 0.34, 0, 0, 0.34, 0, 0, 0.46, 0, 0, 0.46, 0, 0, 0.46, 0, 0, 0.46, 0, 0, 0.51, 0, 0, 0.51, 0, 0, 0.51, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52 },
			wingR = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.34, 0, 0, 0.34, 0, 0, 0.34, 0, 0, 0.34, 0, 0, 0.46, 0, 0, 0.46, 0, 0, 0.46, 0, 0, 0.46, 0, 0, 0.51, 0, 0, 0.51, 0, 0, 0.51, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52 },
			cloth = { 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.14, 0, 0.02, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.16, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.14, 0, 0.05, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.1, 0, 0.04, 0.06, 0, 0.03, 0.06, 0, 0.03, 0.06, 0, 0.03, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, -0.02, 0.04, 0, -0.02, 0.04, 0, -0.02, 0.04, 0, -0.02, 0.06, 0, -0.03, 0.06, 0, -0.03, 0.06, 0, -0.03, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.06, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.06, 0, 0, -0.09 },
		} },
		hit = { fps = 15, length = 0.75, hit = 0, loop = false, bones = {
			torso = { -0.35, 0, 0.1, -0.35, 0, 0.1, -0.35, 0, 0.1, -0.35, 0, 0.1, -0.16, 0, 0.04, -0.16, 0, 0.04, -0.16, 0, 0.04, -0.16, 0, 0.04, -0.04, 0, 0.01, -0.04, 0, 0.01, -0.04, 0, 0.01, -0.04, 0, 0.01 },
			head = { -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.13, 0, 0, -0.13, 0, 0, -0.13, 0, 0, -0.13, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03, 0, 0 },
			armL = { -0.2, 0, 0.4, -0.2, 0, 0.4, -0.2, 0, 0.4, -0.2, 0, 0.4, -0.09, 0, 0.18, -0.09, 0, 0.18, -0.09, 0, 0.18, -0.09, 0, 0.18, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04 },
			armR = { -0.2, 0, 0.4, -0.2, 0, 0.4, -0.2, 0, 0.4, -0.2, 0, 0.4, -0.09, 0, 0.18, -0.09, 0, 0.18, -0.09, 0, 0.18, -0.09, 0, 0.18, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04, -0.02, 0, 0.04 },
			cloth = { 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.13, 0, 0, 0.13, 0, 0, 0.13, 0, 0, 0.13, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0 },
		} },
		death = { fps = 15, length = 3.6, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.04, 0, 0.01, 0.04, 0, 0.01, 0.04, 0, 0.01, 0.04, 0, 0.01, 0.1, 0, 0.03, 0.1, 0, 0.03, 0.1, 0, 0.03, 0.1, 0, 0.03, 0.19, 0, 0.06, 0.19, 0, 0.06, 0.19, 0, 0.06, 0.28, 0, 0.09, 0.28, 0, 0.09, 0.28, 0, 0.09, 0.28, 0, 0.09, 0.39, 0, 0.12, 0.39, 0, 0.12, 0.39, 0, 0.12, 0.39, 0, 0.12, 0.48, 0, 0.15, 0.48, 0, 0.15, 0.48, 0, 0.15, 0.48, 0, 0.15, 0.56, 0, 0.17, 0.56, 0, 0.17, 0.56, 0, 0.17, 0.62, 0, 0.19, 0.62, 0, 0.19, 0.62, 0, 0.19, 0.62, 0, 0.19, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.04, 0, 0.02, 0.11, 0, 0.05, 0.11, 0, 0.05, 0.11, 0, 0.05, 0.11, 0, 0.05, 0.2, 0, 0.09, 0.2, 0, 0.09, 0.2, 0, 0.09, 0.31, 0, 0.13, 0.31, 0, 0.13, 0.31, 0, 0.13, 0.31, 0, 0.13, 0.42, 0, 0.18, 0.42, 0, 0.18, 0.42, 0, 0.18, 0.42, 0, 0.18, 0.52, 0, 0.22, 0.52, 0, 0.22, 0.52, 0, 0.22, 0.52, 0, 0.22, 0.61, 0, 0.26, 0.61, 0, 0.26, 0.61, 0, 0.26, 0.67, 0, 0.29, 0.67, 0, 0.29, 0.67, 0, 0.29, 0.67, 0, 0.29, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3 },
			armL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.04, 0, 0.03, 0.04, 0, 0.03, 0.04, 0, 0.03, 0.07, 0, 0.06, 0.07, 0, 0.06, 0.07, 0, 0.06, 0.07, 0, 0.06, 0.1, 0, 0.08, 0.1, 0, 0.08, 0.1, 0, 0.08, 0.1, 0, 0.08, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			armR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.04, 0, 0.03, 0.04, 0, 0.03, 0.04, 0, 0.03, 0.07, 0, 0.06, 0.07, 0, 0.06, 0.07, 0, 0.06, 0.07, 0, 0.06, 0.1, 0, 0.08, 0.1, 0, 0.08, 0.1, 0, 0.08, 0.1, 0, 0.08, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			legL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0.03, 0, 0.06, 0.03, 0, 0.06, 0.03, 0, 0.06, 0.03, 0, 0.06, 0.08, 0, 0.08, 0.08, 0, 0.08, 0.08, 0, 0.08, 0.08, 0, 0.08, 0.14, 0, 0.09, 0.14, 0, 0.09, 0.14, 0, 0.09, 0.22, 0, 0.1, 0.22, 0, 0.1, 0.22, 0, 0.1, 0.22, 0, 0.1, 0.3, 0, 0.1, 0.3, 0, 0.1, 0.3, 0, 0.1, 0.3, 0, 0.1, 0.37, 0, 0.1, 0.37, 0, 0.1, 0.37, 0, 0.1, 0.37, 0, 0.1, 0.43, 0, 0.1, 0.43, 0, 0.1, 0.43, 0, 0.1, 0.48, 0, 0.1, 0.48, 0, 0.1, 0.48, 0, 0.1, 0.48, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1 },
			legR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0, 0, 0.05, 0.03, 0, 0.06, 0.03, 0, 0.06, 0.03, 0, 0.06, 0.03, 0, 0.06, 0.08, 0, 0.08, 0.08, 0, 0.08, 0.08, 0, 0.08, 0.08, 0, 0.08, 0.14, 0, 0.09, 0.14, 0, 0.09, 0.14, 0, 0.09, 0.22, 0, 0.1, 0.22, 0, 0.1, 0.22, 0, 0.1, 0.22, 0, 0.1, 0.3, 0, 0.1, 0.3, 0, 0.1, 0.3, 0, 0.1, 0.3, 0, 0.1, 0.37, 0, 0.1, 0.37, 0, 0.1, 0.37, 0, 0.1, 0.37, 0, 0.1, 0.43, 0, 0.1, 0.43, 0, 0.1, 0.43, 0, 0.1, 0.48, 0, 0.1, 0.48, 0, 0.1, 0.48, 0, 0.1, 0.48, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1 },
			wingL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.13, 0, 0, -0.13, 0, 0, -0.13, 0, 0, -0.13, 0, 0, -0.26, 0, 0, -0.26, 0, 0, -0.26, 0, 0, -0.42, 0, 0, -0.42, 0, 0, -0.42, 0, 0, -0.42, 0, 0, -0.58, 0, 0, -0.58, 0, 0, -0.58, 0, 0, -0.58, 0, 0, -0.72, 0, 0, -0.72, 0, 0, -0.72, 0, 0, -0.72, 0, 0, -0.83, 0, 0, -0.83, 0, 0, -0.83, 0, 0, -0.89, 0, 0, -0.89, 0, 0, -0.89, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			wingR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.13, 0, 0, -0.13, 0, 0, -0.13, 0, 0, -0.13, 0, 0, -0.26, 0, 0, -0.26, 0, 0, -0.26, 0, 0, -0.42, 0, 0, -0.42, 0, 0, -0.42, 0, 0, -0.42, 0, 0, -0.58, 0, 0, -0.58, 0, 0, -0.58, 0, 0, -0.58, 0, 0, -0.72, 0, 0, -0.72, 0, 0, -0.72, 0, 0, -0.72, 0, 0, -0.83, 0, 0, -0.83, 0, 0, -0.83, 0, 0, -0.89, 0, 0, -0.89, 0, 0, -0.89, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			cloth = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.14, 0, 0, 0.14, 0, 0, 0.14, 0, 0, 0.14, 0, 0, 0.19, 0, 0, 0.19, 0, 0, 0.19, 0, 0, 0.19, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.28, 0, 0, 0.28, 0, 0, 0.28, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0 },
		} },
	},
	Warden = {
		idle = { fps = 15, length = 3, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.01, 0, 0.03, 0.01, 0, 0.03, 0.01, 0, 0.02, 0.01, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, -0.01, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.01, 0, -0.03, -0.01, 0, -0.03, -0.01, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03 },
			head = { -0.1, 0, 0, -0.09, 0.01, 0, -0.09, 0.02, 0, -0.08, 0.03, 0, -0.07, 0.03, 0, -0.07, 0.04, 0, -0.06, 0.05, 0, -0.06, 0.06, 0, -0.05, 0.07, 0, -0.05, 0.08, 0, -0.05, 0.08, 0, -0.05, 0.09, 0, -0.05, 0.1, 0, -0.05, 0.1, 0, -0.06, 0.11, 0, -0.06, 0.11, 0, -0.07, 0.12, 0, -0.07, 0.13, 0, -0.08, 0.13, 0, -0.09, 0.13, 0, -0.09, 0.14, 0, -0.1, 0.14, 0, -0.11, 0.14, 0, -0.12, 0.15, 0, -0.12, 0.15, 0, -0.13, 0.15, 0, -0.14, 0.15, 0, -0.14, 0.15, 0, -0.14, 0.15, 0, -0.15, 0.15, 0, -0.15, 0.15, 0, -0.15, 0.15, 0, -0.15, 0.14, 0, -0.15, 0.14, 0, -0.15, 0.14, 0, -0.14, 0.13, 0, -0.14, 0.13, 0, -0.13, 0.13, 0, -0.13, 0.12, 0, -0.12, 0.11, 0, -0.11, 0.11, 0, -0.1, 0.1, 0, -0.1, 0.1, 0, -0.09, 0.09, 0, -0.08, 0.08, 0, -0.08, 0.08, 0 },
			armL = { -0.7, 0, 0.63, -0.69, 0, 0.64, -0.67, 0, 0.64, -0.66, 0, 0.65, -0.65, 0, 0.65, -0.63, 0, 0.65, -0.62, 0, 0.65, -0.61, 0, 0.65, -0.6, 0, 0.64, -0.6, 0, 0.64, -0.59, 0, 0.63, -0.59, 0, 0.63, -0.58, 0, 0.62, -0.58, 0, 0.61, -0.58, 0, 0.6, -0.58, 0, 0.59, -0.59, 0, 0.58, -0.59, 0, 0.57, -0.6, 0, 0.55, -0.6, 0, 0.54, -0.61, 0, 0.53, -0.62, 0, 0.52, -0.63, 0, 0.51, -0.65, 0, 0.5, -0.66, 0, 0.49, -0.67, 0, 0.48, -0.69, 0, 0.47, -0.7, 0, 0.47, -0.71, 0, 0.46, -0.73, 0, 0.46, -0.74, 0, 0.45, -0.75, 0, 0.45, -0.77, 0, 0.45, -0.78, 0, 0.45, -0.79, 0, 0.45, -0.8, 0, 0.46, -0.8, 0, 0.46, -0.81, 0, 0.47, -0.81, 0, 0.47, -0.82, 0, 0.48, -0.82, 0, 0.49, -0.82, 0, 0.5, -0.82, 0, 0.51, -0.81, 0, 0.52, -0.81, 0, 0.53, -0.8, 0, 0.55 },
			armR = { -0.59, 0, 0.56, -0.6, 0, 0.55, -0.61, 0, 0.54, -0.61, 0, 0.53, -0.62, 0, 0.52, -0.64, 0, 0.51, -0.65, 0, 0.5, -0.66, 0, 0.49, -0.67, 0, 0.48, -0.69, 0, 0.47, -0.7, 0, 0.46, -0.72, 0, 0.46, -0.73, 0, 0.45, -0.74, 0, 0.45, -0.76, 0, 0.45, -0.77, 0, 0.45, -0.78, 0, 0.45, -0.79, 0, 0.45, -0.8, 0, 0.46, -0.81, 0, 0.46, -0.81, 0, 0.47, -0.82, 0, 0.48, -0.82, 0, 0.48, -0.82, 0, 0.49, -0.82, 0, 0.5, -0.82, 0, 0.51, -0.81, 0, 0.52, -0.81, 0, 0.54, -0.8, 0, 0.55, -0.79, 0, 0.56, -0.79, 0, 0.57, -0.78, 0, 0.58, -0.76, 0, 0.59, -0.75, 0, 0.6, -0.74, 0, 0.61, -0.73, 0, 0.62, -0.71, 0, 0.63, -0.7, 0, 0.64, -0.68, 0, 0.64, -0.67, 0, 0.65, -0.66, 0, 0.65, -0.64, 0, 0.65, -0.63, 0, 0.65, -0.62, 0, 0.65, -0.61, 0, 0.65, -0.6, 0, 0.64 },
			legL = { 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02 },
			legR = { 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13, 0, 0, 0.05, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.03, 0, 0, 0.03, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.25, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.21, 0, 0, 0.13, 0, 0, 0.06, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13, 0, 0, 0.05, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.03, 0, 0, 0.03, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.25, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.21, 0, 0, 0.13, 0, 0, 0.06, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04, 0.11, 0, -0.05, 0.13, 0, -0.05, 0.14, 0, -0.05, 0.15, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.15, 0, -0.03, 0.14, 0, -0.02, 0.13, 0, -0.01, 0.11, 0, -0.01, 0.1, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.05, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0 },
		} },
		forming = { fps = 15, length = 3, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.02, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.02, 0, 0.03, 0.01, 0, 0.03, 0.01, 0, 0.03, 0.01, 0, 0.02, 0.01, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, -0.01, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0.01, -0.01, 0, 0, -0.02, 0, 0, -0.02, 0, 0, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.01, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.02, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.02, 0, -0.03, -0.01, 0, -0.03, -0.01, 0, -0.03, -0.01, 0, -0.03, 0, 0, -0.03, 0, 0, -0.03 },
			head = { -0.1, 0, 0, -0.09, 0.01, 0, -0.09, 0.02, 0, -0.08, 0.03, 0, -0.07, 0.03, 0, -0.07, 0.04, 0, -0.06, 0.05, 0, -0.06, 0.06, 0, -0.05, 0.07, 0, -0.05, 0.08, 0, -0.05, 0.08, 0, -0.05, 0.09, 0, -0.05, 0.1, 0, -0.05, 0.1, 0, -0.06, 0.11, 0, -0.06, 0.11, 0, -0.07, 0.12, 0, -0.07, 0.13, 0, -0.08, 0.13, 0, -0.09, 0.13, 0, -0.09, 0.14, 0, -0.1, 0.14, 0, -0.11, 0.14, 0, -0.12, 0.15, 0, -0.12, 0.15, 0, -0.13, 0.15, 0, -0.14, 0.15, 0, -0.14, 0.15, 0, -0.14, 0.15, 0, -0.15, 0.15, 0, -0.15, 0.15, 0, -0.15, 0.15, 0, -0.15, 0.14, 0, -0.15, 0.14, 0, -0.15, 0.14, 0, -0.14, 0.13, 0, -0.14, 0.13, 0, -0.13, 0.13, 0, -0.13, 0.12, 0, -0.12, 0.11, 0, -0.11, 0.11, 0, -0.1, 0.1, 0, -0.1, 0.1, 0, -0.09, 0.09, 0, -0.08, 0.08, 0, -0.08, 0.08, 0 },
			armL = { -0.7, 0, 0.63, -0.69, 0, 0.64, -0.67, 0, 0.64, -0.66, 0, 0.65, -0.65, 0, 0.65, -0.63, 0, 0.65, -0.62, 0, 0.65, -0.61, 0, 0.65, -0.6, 0, 0.64, -0.6, 0, 0.64, -0.59, 0, 0.63, -0.59, 0, 0.63, -0.58, 0, 0.62, -0.58, 0, 0.61, -0.58, 0, 0.6, -0.58, 0, 0.59, -0.59, 0, 0.58, -0.59, 0, 0.57, -0.6, 0, 0.55, -0.6, 0, 0.54, -0.61, 0, 0.53, -0.62, 0, 0.52, -0.63, 0, 0.51, -0.65, 0, 0.5, -0.66, 0, 0.49, -0.67, 0, 0.48, -0.69, 0, 0.47, -0.7, 0, 0.47, -0.71, 0, 0.46, -0.73, 0, 0.46, -0.74, 0, 0.45, -0.75, 0, 0.45, -0.77, 0, 0.45, -0.78, 0, 0.45, -0.79, 0, 0.45, -0.8, 0, 0.46, -0.8, 0, 0.46, -0.81, 0, 0.47, -0.81, 0, 0.47, -0.82, 0, 0.48, -0.82, 0, 0.49, -0.82, 0, 0.5, -0.82, 0, 0.51, -0.81, 0, 0.52, -0.81, 0, 0.53, -0.8, 0, 0.55 },
			armR = { -0.59, 0, 0.56, -0.6, 0, 0.55, -0.61, 0, 0.54, -0.61, 0, 0.53, -0.62, 0, 0.52, -0.64, 0, 0.51, -0.65, 0, 0.5, -0.66, 0, 0.49, -0.67, 0, 0.48, -0.69, 0, 0.47, -0.7, 0, 0.46, -0.72, 0, 0.46, -0.73, 0, 0.45, -0.74, 0, 0.45, -0.76, 0, 0.45, -0.77, 0, 0.45, -0.78, 0, 0.45, -0.79, 0, 0.45, -0.8, 0, 0.46, -0.81, 0, 0.46, -0.81, 0, 0.47, -0.82, 0, 0.48, -0.82, 0, 0.48, -0.82, 0, 0.49, -0.82, 0, 0.5, -0.82, 0, 0.51, -0.81, 0, 0.52, -0.81, 0, 0.54, -0.8, 0, 0.55, -0.79, 0, 0.56, -0.79, 0, 0.57, -0.78, 0, 0.58, -0.76, 0, 0.59, -0.75, 0, 0.6, -0.74, 0, 0.61, -0.73, 0, 0.62, -0.71, 0, 0.63, -0.7, 0, 0.64, -0.68, 0, 0.64, -0.67, 0, 0.65, -0.66, 0, 0.65, -0.64, 0, 0.65, -0.63, 0, 0.65, -0.62, 0, 0.65, -0.61, 0, 0.65, -0.6, 0, 0.64 },
			legL = { 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02 },
			legR = { 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.02 },
			wingL = { 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5 },
			wingR = { 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04, 0.11, 0, -0.05, 0.13, 0, -0.05, 0.14, 0, -0.05, 0.15, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.15, 0, -0.03, 0.14, 0, -0.02, 0.13, 0, -0.01, 0.11, 0, -0.01, 0.1, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.05, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0 },
		} },
		slam = { fps = 15, length = 1.8, hit = 1.1, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.07, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.15, 0, 0, -0.18, 0, 0, -0.21, 0, 0, -0.24, 0, 0, -0.26, 0, 0, -0.28, 0, 0, -0.3, 0, 0, -0.31, 0, 0, -0.32, 0, 0, -0.05, 0, 0, 0.28, 0, 0, 0.42, 0, 0, 0.45, 0, 0, 0.43, 0, 0, 0.37, 0, 0, 0.29, 0, 0, 0.19, 0, 0, 0.1, 0, 0, 0.03, 0, 0, 0, 0, 0 },
			head = { -0.15, 0, 0, -0.15, 0, 0, -0.16, 0, 0, -0.17, 0, 0, -0.19, 0, 0, -0.2, 0, 0, -0.23, 0, 0, -0.25, 0, 0, -0.27, 0, 0, -0.29, 0, 0, -0.31, 0, 0, -0.34, 0, 0, -0.35, 0, 0, -0.37, 0, 0, -0.38, 0, 0, -0.39, 0, 0, -0.4, 0, 0, 0.35, 0, 0, 0.35, 0, 0, 0.35, 0, 0, 0.35, 0, 0, 0.34, 0, 0, 0.32, 0, 0, 0.3, 0, 0, 0.26, 0, 0, 0.23, 0, 0, 0.21, 0, 0, 0.2, 0, 0 },
			armL = { 0, 0, 0.1, -0.02, 0, 0.1, -0.1, 0, 0.1, -0.2, 0, 0.1, -0.35, 0, 0.1, -0.52, 0, 0.1, -0.71, 0, 0.1, -0.91, 0, 0.1, -1.12, 0, 0.1, -1.33, 0, 0.1, -1.54, 0, 0.1, -1.74, 0, 0.1, -1.92, 0, 0.1, -2.08, 0, 0.1, -2.2, 0, 0.1, -2.3, 0, 0.1, -2.34, 0, 0.1, -1.41, 0, 0.1, -0.23, 0, 0.1, 0.25, 0, 0.1, 0.35, 0, 0.1, 0.34, 0, 0.1, 0.28, 0, 0.1, 0.19, 0, 0.1, 0.1, 0, 0.1, 0.01, 0, 0.1, -0.05, 0, 0.1, -0.08, 0, 0.1 },
			armR = { 0, 0, 0, -0.01, 0, 0, -0.03, 0, 0.01, -0.06, 0, 0.03, -0.1, 0, 0.05, -0.15, 0, 0.08, -0.21, 0, 0.11, -0.27, 0, 0.14, -0.33, 0, 0.17, -0.4, 0, 0.2, -0.46, 0, 0.23, -0.52, 0, 0.26, -0.57, 0, 0.29, -0.62, 0, 0.31, -0.66, 0, 0.33, -0.68, 0, 0.34, -0.7, 0, 0.35, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.3, -0.3, 0, 0.29, -0.3, 0, 0.27, -0.3, 0, 0.24, -0.3, 0, 0.21, -0.3, 0, 0.17, -0.3, 0, 0.15, -0.3, 0, 0.14 },
			legL = { 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.05, 0.03, 0, 0.05, 0.05, 0, 0.05, 0.06, 0, 0.05, 0.07, 0, 0.05, 0.09, 0, 0.05, 0.1, 0, 0.05, 0.11, 0, 0.05, 0.12, 0, 0.05, 0.13, 0, 0.05, 0.14, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04 },
			legR = { 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.05, 0.03, 0, 0.05, 0.05, 0, 0.05, 0.06, 0, 0.05, 0.07, 0, 0.05, 0.09, 0, 0.05, 0.1, 0, 0.05, 0.11, 0, 0.05, 0.12, 0, 0.05, 0.13, 0, 0.05, 0.14, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.15, 0, 0, 0.17, 0, 0, 0.2, 0, 0, 0.23, 0, 0, 0.26, 0, 0, 0.29, 0, 0, 0.32, 0, 0, 0.35, 0, 0, 0.38, 0, 0, 0.41, 0, 0, 0.43, 0, 0, 0.45, 0, 0, 0.46, 0, 0, 0.47, 0, 0, 0.27, 0, 0, -0.01, 0, 0, -0.13, 0, 0, -0.15, 0, 0, -0.14, 0, 0, -0.1, 0, 0, -0.05, 0, 0, 0.01, 0, 0, 0.06, 0, 0, 0.1, 0, 0, 0.12 },
			wingR = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.15, 0, 0, 0.17, 0, 0, 0.2, 0, 0, 0.23, 0, 0, 0.26, 0, 0, 0.29, 0, 0, 0.32, 0, 0, 0.35, 0, 0, 0.38, 0, 0, 0.41, 0, 0, 0.43, 0, 0, 0.45, 0, 0, 0.46, 0, 0, 0.47, 0, 0, 0.27, 0, 0, -0.01, 0, 0, -0.13, 0, 0, -0.15, 0, 0, -0.14, 0, 0, -0.1, 0, 0, -0.05, 0, 0, 0.01, 0, 0, 0.06, 0, 0, 0.1, 0, 0, 0.12 },
			cloth = { -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, 0.44, 0, 0, 0.41, 0, 0, 0.39, 0, 0, 0.36, 0, 0, 0.33, 0, 0, 0.31, 0, 0, 0.28, 0, 0, 0.26, 0, 0, 0.23, 0, 0, 0.2, 0, 0, 0.18, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06 },
		} },
		thrust = { fps = 15, length = 1.6, hit = 0.9, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.15, 0, 0, 0.16, 0, 0, 0.32, 0, 0, 0.35, 0, 0, 0.33, 0, 0, 0.27, 0, 0, 0.19, 0, 0, 0.11, 0, 0, 0.04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0 },
			armL = { -0.15, 0, 0, -0.15, 0, 0.02, -0.15, 0, 0.07, -0.15, 0, 0.15, -0.15, 0, 0.24, -0.15, 0, 0.36, -0.15, 0, 0.48, -0.15, 0, 0.61, -0.15, 0, 0.73, -0.15, 0, 0.85, -0.15, 0, 0.96, -0.15, 0, 1.05, -0.15, 0, 1.11, -0.15, 0, 1.15, -0.79, 0, 0.68, -1.43, 0, 0.21, -1.55, 0, 0.12, -1.48, 0, 0.12, -1.23, 0, 0.12, -0.89, 0, 0.13, -0.53, 0, 0.13, -0.23, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14 },
			armR = { -0.15, 0, 0, -0.15, 0, 0.02, -0.15, 0, 0.07, -0.15, 0, 0.15, -0.15, 0, 0.24, -0.15, 0, 0.36, -0.15, 0, 0.48, -0.15, 0, 0.61, -0.15, 0, 0.73, -0.15, 0, 0.85, -0.15, 0, 0.96, -0.15, 0, 1.05, -0.15, 0, 1.11, -0.15, 0, 1.15, -0.79, 0, 0.68, -1.43, 0, 0.21, -1.55, 0, 0.12, -1.48, 0, 0.12, -1.23, 0, 0.12, -0.89, 0, 0.13, -0.53, 0, 0.13, -0.23, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02 },
		} },
		pull = { fps = 15, length = 1.2, hit = 0, loop = true, bones = {
			torso = { 0.18, 0, 0, 0.2, 0, 0, 0.22, 0, 0, 0.23, 0, 0, 0.24, 0, 0, 0.24, 0, 0, 0.23, 0, 0, 0.22, 0, 0, 0.2, 0, 0, 0.18, 0, 0, 0.16, 0, 0, 0.14, 0, 0, 0.13, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.14, 0, 0, 0.16, 0, 0, 0.18, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0 },
			armL = { -1.25, 0, 0.2, -1.34, 0, 0.17, -1.41, 0, 0.14, -1.47, 0, 0.11, -1.5, 0, 0.1, -1.5, 0, 0.1, -1.47, 0, 0.11, -1.41, 0, 0.14, -1.34, 0, 0.17, -1.25, 0, 0.2, -1.16, 0, 0.23, -1.09, 0, 0.26, -1.03, 0, 0.29, -1, 0, 0.3, -1, 0, 0.3, -1.03, 0, 0.29, -1.09, 0, 0.26, -1.16, 0, 0.23, -1.25, 0, 0.2 },
			armR = { -1.25, 0, 0.2, -1.16, 0, 0.23, -1.09, 0, 0.26, -1.03, 0, 0.29, -1, 0, 0.3, -1, 0, 0.3, -1.03, 0, 0.29, -1.09, 0, 0.26, -1.16, 0, 0.23, -1.25, 0, 0.2, -1.34, 0, 0.17, -1.41, 0, 0.14, -1.47, 0, 0.11, -1.5, 0, 0.1, -1.5, 0, 0.1, -1.47, 0, 0.11, -1.41, 0, 0.14, -1.34, 0, 0.17, -1.25, 0, 0.2 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06 },
		} },
		sweep = { fps = 15, length = 2, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.12 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.02, 0, 0, -0.02, 0, 0 },
			armL = { -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05, -1.55, 0, 0.05 },
			armR = { -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5, -0.4, 0, 0.5 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3 },
			wingR = { 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09 },
		} },
		floor = { fps = 15, length = 1, hit = 0, loop = true, bones = {
			torso = { 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0 },
			armL = { 0.35, 0, 0.35, 0.4, 0, 0.35, 0.44, 0, 0.35, 0.45, 0, 0.35, 0.43, 0, 0.35, 0.39, 0, 0.35, 0.34, 0, 0.35, 0.29, 0, 0.35, 0.26, 0, 0.35, 0.25, 0, 0.35, 0.28, 0, 0.35, 0.32, 0, 0.35, 0.37, 0, 0.35, 0.42, 0, 0.35, 0.45, 0, 0.35, 0.45, 0, 0.35 },
			armR = { 0.43, 0, 0.35, 0.45, 0, 0.35, 0.44, 0, 0.35, 0.4, 0, 0.35, 0.35, 0, 0.35, 0.3, 0, 0.35, 0.26, 0, 0.35, 0.25, 0, 0.35, 0.27, 0, 0.35, 0.31, 0, 0.35, 0.37, 0, 0.35, 0.41, 0, 0.35, 0.44, 0, 0.35, 0.45, 0, 0.35, 0.42, 0, 0.35, 0.38, 0, 0.35 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09 },
		} },
		roar = { fps = 15, length = 1.8, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, -0.1, 0, 0, -0.17, 0, 0, -0.22, 0, 0, -0.25, 0, 0, -0.27, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0 },
			head = { 0, 0, 0, -0.17, 0, 0, -0.3, 0, 0, -0.39, 0, 0, -0.45, 0, 0, -0.48, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0 },
			armL = { 0, 0, 0, -0.12, 0, 0.45, -0.21, 0, 0.79, -0.27, 0, 1.02, -0.31, 0, 1.17, -0.34, 0, 1.25, -0.35, 0, 1.29, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3 },
			armR = { 0, 0, 0, -0.12, 0, 0.45, -0.21, 0, 0.79, -0.27, 0, 1.02, -0.31, 0, 1.17, -0.34, 0, 1.25, -0.35, 0, 1.29, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3, -0.35, 0, 1.3 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.34, 0, 0, 0.49, 0, 0, 0.55, 0, 0, 0.6, 0, 0, 0.68, 0, 0, 0.74, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73 },
			wingR = { 0, 0, 0.12, 0, 0, 0.34, 0, 0, 0.49, 0, 0, 0.55, 0, 0, 0.6, 0, 0, 0.68, 0, 0, 0.74, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73 },
			cloth = { 0.1, 0, 0, 0.01, 0, 0, -0.05, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06 },
		} },
		summon = { fps = 15, length = 2, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, -0.04, 0, 0, -0.07, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.13, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			head = { 0, 0, 0, -0.08, 0, 0, -0.14, 0, 0, -0.19, 0, 0, -0.23, 0, 0, -0.26, 0, 0, -0.28, 0, 0, -0.29, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0 },
			armL = { 0, 0, 0, -0.46, 0, 0.25, -0.86, 0, 0.45, -1.22, 0, 0.6, -1.54, 0, 0.71, -1.78, 0, 0.79, -1.92, 0, 0.85, -1.96, 0, 0.88, -1.94, 0, 0.89, -1.92, 0, 0.9, -1.93, 0, 0.9, -1.98, 0, 0.9, -2.05, 0, 0.9, -2.08, 0, 0.9, -2.06, 0, 0.9, -2, 0, 0.9, -1.94, 0, 0.9, -1.92, 0, 0.9, -1.95, 0, 0.9, -2.02, 0, 0.9, -2.07, 0, 0.9, -2.08, 0, 0.9, -2.03, 0, 0.9, -1.97, 0, 0.9, -1.92, 0, 0.9, -1.93, 0, 0.9, -1.98, 0, 0.9, -2.05, 0, 0.9, -2.08, 0, 0.9, -2.06, 0, 0.9, -2, 0, 0.9 },
			armR = { 0, 0, 0, -0.46, 0, 0.25, -0.86, 0, 0.45, -1.22, 0, 0.6, -1.54, 0, 0.71, -1.78, 0, 0.79, -1.92, 0, 0.85, -1.96, 0, 0.88, -1.94, 0, 0.89, -1.92, 0, 0.9, -1.93, 0, 0.9, -1.98, 0, 0.9, -2.05, 0, 0.9, -2.08, 0, 0.9, -2.06, 0, 0.9, -2, 0, 0.9, -1.94, 0, 0.9, -1.92, 0, 0.9, -1.95, 0, 0.9, -2.02, 0, 0.9, -2.07, 0, 0.9, -2.08, 0, 0.9, -2.03, 0, 0.9, -1.97, 0, 0.9, -1.92, 0, 0.9, -1.93, 0, 0.9, -1.98, 0, 0.9, -2.05, 0, 0.9, -2.08, 0, 0.9, -2.06, 0, 0.9, -2, 0, 0.9 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.22, 0, 0, 0.31, 0, 0, 0.37, 0, 0, 0.43, 0, 0, 0.46, 0, 0, 0.49, 0, 0, 0.51, 0, 0, 0.51, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52 },
			wingR = { 0, 0, 0.12, 0, 0, 0.22, 0, 0, 0.31, 0, 0, 0.37, 0, 0, 0.43, 0, 0, 0.46, 0, 0, 0.49, 0, 0, 0.51, 0, 0, 0.51, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09 },
		} },
		hit = { fps = 15, length = 0.5, hit = 0, loop = false, bones = {
			torso = { -0.35, 0, 0.1, -0.26, 0, 0.08, -0.19, 0, 0.05, -0.13, 0, 0.04, -0.08, 0, 0.02, -0.04, 0, 0.01, -0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
			head = { -0.3, 0, 0, -0.23, 0, 0, -0.16, 0, 0, -0.11, 0, 0, -0.07, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
			armL = { -0.2, 0, 0.4, -0.15, 0, 0.3, -0.11, 0, 0.22, -0.07, 0, 0.14, -0.04, 0, 0.09, -0.02, 0, 0.04, -0.01, 0, 0.02, 0, 0, 0, 0, 0, 0 },
			armR = { -0.2, 0, 0.4, -0.15, 0, 0.3, -0.11, 0, 0.22, -0.07, 0, 0.14, -0.04, 0, 0.09, -0.02, 0, 0.04, -0.01, 0, 0.02, 0, 0, 0, 0, 0, 0 },
			cloth = { 0.3, 0, 0, 0.23, 0, 0, 0.16, 0, 0, 0.11, 0, 0, 0.07, 0, 0, 0.03, 0, 0, 0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
		} },
		death = { fps = 15, length = 2.4, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0.01, 0.05, 0, 0.01, 0.07, 0, 0.02, 0.1, 0, 0.03, 0.13, 0, 0.04, 0.17, 0, 0.05, 0.21, 0, 0.06, 0.24, 0, 0.08, 0.28, 0, 0.09, 0.32, 0, 0.1, 0.37, 0, 0.11, 0.41, 0, 0.12, 0.44, 0, 0.14, 0.48, 0, 0.15, 0.52, 0, 0.16, 0.55, 0, 0.17, 0.58, 0, 0.18, 0.6, 0, 0.19, 0.62, 0, 0.19, 0.64, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.03, 0, 0.01, 0.05, 0, 0.02, 0.08, 0, 0.03, 0.11, 0, 0.05, 0.14, 0, 0.06, 0.18, 0, 0.08, 0.22, 0, 0.09, 0.26, 0, 0.11, 0.31, 0, 0.13, 0.35, 0, 0.15, 0.39, 0, 0.17, 0.44, 0, 0.19, 0.48, 0, 0.21, 0.52, 0, 0.22, 0.56, 0, 0.24, 0.59, 0, 0.25, 0.62, 0, 0.27, 0.65, 0, 0.28, 0.67, 0, 0.29, 0.69, 0, 0.29, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3 },
			armL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.03, 0, 0.02, 0.04, 0, 0.03, 0.05, 0, 0.04, 0.06, 0, 0.05, 0.07, 0, 0.06, 0.08, 0, 0.06, 0.09, 0, 0.07, 0.1, 0, 0.08, 0.11, 0, 0.09, 0.12, 0, 0.1, 0.13, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			armR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.03, 0, 0.02, 0.04, 0, 0.03, 0.05, 0, 0.04, 0.06, 0, 0.05, 0.07, 0, 0.06, 0.08, 0, 0.06, 0.09, 0, 0.07, 0.1, 0, 0.08, 0.11, 0, 0.09, 0.12, 0, 0.1, 0.13, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			legL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.06, 0.04, 0, 0.07, 0.06, 0, 0.07, 0.08, 0, 0.08, 0.1, 0, 0.09, 0.13, 0, 0.09, 0.16, 0, 0.09, 0.19, 0, 0.1, 0.22, 0, 0.1, 0.25, 0, 0.1, 0.28, 0, 0.1, 0.31, 0, 0.1, 0.34, 0, 0.1, 0.37, 0, 0.1, 0.4, 0, 0.1, 0.42, 0, 0.1, 0.44, 0, 0.1, 0.46, 0, 0.1, 0.48, 0, 0.1, 0.49, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1 },
			legR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.06, 0.04, 0, 0.07, 0.06, 0, 0.07, 0.08, 0, 0.08, 0.1, 0, 0.09, 0.13, 0, 0.09, 0.16, 0, 0.09, 0.19, 0, 0.1, 0.22, 0, 0.1, 0.25, 0, 0.1, 0.28, 0, 0.1, 0.31, 0, 0.1, 0.34, 0, 0.1, 0.37, 0, 0.1, 0.4, 0, 0.1, 0.42, 0, 0.1, 0.44, 0, 0.1, 0.46, 0, 0.1, 0.48, 0, 0.1, 0.49, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1 },
			wingL = { 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.05, 0, 0, -0.09, 0, 0, -0.13, 0, 0, -0.18, 0, 0, -0.23, 0, 0, -0.29, 0, 0, -0.35, 0, 0, -0.42, 0, 0, -0.48, 0, 0, -0.55, 0, 0, -0.61, 0, 0, -0.67, 0, 0, -0.72, 0, 0, -0.77, 0, 0, -0.81, 0, 0, -0.85, 0, 0, -0.88, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			wingR = { 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.05, 0, 0, -0.09, 0, 0, -0.13, 0, 0, -0.18, 0, 0, -0.23, 0, 0, -0.29, 0, 0, -0.35, 0, 0, -0.42, 0, 0, -0.48, 0, 0, -0.55, 0, 0, -0.61, 0, 0, -0.67, 0, 0, -0.72, 0, 0, -0.77, 0, 0, -0.81, 0, 0, -0.85, 0, 0, -0.88, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			cloth = { 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.06, 0, 0, 0.08, 0, 0, 0.1, 0, 0, 0.12, 0, 0, 0.14, 0, 0, 0.16, 0, 0, 0.18, 0, 0, 0.2, 0, 0, 0.22, 0, 0, 0.24, 0, 0, 0.26, 0, 0, 0.27, 0, 0, 0.28, 0, 0, 0.29, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0 },
		} },
	},
	Choir = {
		idle = { fps = 15, length = 3, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0, 0, 0.01, 0, 0.01, 0.02, 0.01, 0.01, 0.04, 0.01, 0.01, 0.05, 0.01, 0.02, 0.06, 0.02, 0.02, 0.07, 0.02, 0.02, 0.08, 0.02, 0.02, 0.09, 0.02, 0.02, 0.1, 0.03, 0.02, 0.1, 0.03, 0.02, 0.11, 0.03, 0.02, 0.11, 0.03, 0.02, 0.12, 0.03, 0.02, 0.12, 0.03, 0.02, 0.12, 0.03, 0.02, 0.12, 0.03, 0.02, 0.12, 0.03, 0.01, 0.11, 0.03, 0.01, 0.11, 0.03, 0.01, 0.1, 0.02, 0.01, 0.1, 0.02, 0, 0.09, 0.02, 0, 0.08, 0.02, -0.01, 0.07, 0.01, -0.01, 0.06, 0.01, -0.01, 0.05, 0.01, -0.01, 0.04, 0, -0.02, 0.02, 0, -0.02, 0.01, 0, -0.02, 0, -0.01, -0.02, -0.01, -0.01, -0.02, -0.02, -0.01, -0.02, -0.04, -0.02, -0.02, -0.05, -0.02, -0.02, -0.06, -0.02, -0.02, -0.07, -0.02, -0.02, -0.08, -0.03, -0.02, -0.09, -0.03, -0.02, -0.1, -0.03, -0.02, -0.1, -0.03, -0.01, -0.11, -0.03, -0.01, -0.11, -0.03, -0.01, -0.12, -0.03, 0, -0.12, -0.03, 0, -0.12, -0.03 },
			head = { 0.05, 0, 0, 0.05, 0.02, 0.01, 0.05, 0.04, 0.02, 0.05, 0.06, 0.03, 0.05, 0.08, 0.04, 0.05, 0.1, 0.04, 0.05, 0.12, 0.05, 0.05, 0.13, 0.05, 0.05, 0.15, 0.05, 0.05, 0.16, 0.05, 0.05, 0.17, 0.04, 0.05, 0.18, 0.04, 0.05, 0.19, 0.03, 0.05, 0.2, 0.02, 0.05, 0.2, 0.01, 0.05, 0.2, 0, 0.05, 0.2, -0.01, 0.05, 0.2, -0.02, 0.05, 0.19, -0.03, 0.05, 0.18, -0.04, 0.05, 0.17, -0.04, 0.05, 0.16, -0.05, 0.05, 0.15, -0.05, 0.05, 0.13, -0.05, 0.05, 0.12, -0.05, 0.05, 0.1, -0.04, 0.05, 0.08, -0.04, 0.05, 0.06, -0.03, 0.05, 0.04, -0.02, 0.05, 0.02, -0.01, 0.05, 0, 0, 0.05, -0.02, 0.01, 0.05, -0.04, 0.02, 0.05, -0.06, 0.03, 0.05, -0.08, 0.04, 0.05, -0.1, 0.04, 0.05, -0.12, 0.05, 0.05, -0.13, 0.05, 0.05, -0.15, 0.05, 0.05, -0.16, 0.05, 0.05, -0.17, 0.04, 0.05, -0.18, 0.04, 0.05, -0.19, 0.03, 0.05, -0.2, 0.02, 0.05, -0.2, 0.01, 0.05, -0.2, 0 },
			armL = { -0.6, 0, 0.55, -0.67, 0, 0.63, -0.74, 0, 0.7, -0.81, 0, 0.74, -0.86, 0, 0.75, -0.9, 0, 0.72, -0.93, 0, 0.67, -0.95, 0, 0.59, -0.95, 0, 0.51, -0.93, 0, 0.43, -0.9, 0, 0.38, -0.86, 0, 0.35, -0.81, 0, 0.36, -0.74, 0, 0.4, -0.67, 0, 0.47, -0.6, 0, 0.55, -0.53, 0, 0.63, -0.46, 0, 0.7, -0.39, 0, 0.74, -0.34, 0, 0.75, -0.3, 0, 0.72, -0.27, 0, 0.67, -0.25, 0, 0.59, -0.25, 0, 0.51, -0.27, 0, 0.43, -0.3, 0, 0.38, -0.34, 0, 0.35, -0.39, 0, 0.36, -0.46, 0, 0.4, -0.53, 0, 0.47, -0.6, 0, 0.55, -0.67, 0, 0.63, -0.74, 0, 0.7, -0.81, 0, 0.74, -0.86, 0, 0.75, -0.9, 0, 0.72, -0.93, 0, 0.67, -0.95, 0, 0.59, -0.95, 0, 0.51, -0.93, 0, 0.43, -0.9, 0, 0.38, -0.86, 0, 0.35, -0.81, 0, 0.36, -0.74, 0, 0.4, -0.67, 0, 0.47, -0.6, 0, 0.55 },
			armR = { -1.1, 0, 0.6, -0.99, 0.12, 0.59, -0.88, 0.22, 0.57, -0.78, 0.29, 0.53, -0.69, 0.3, 0.48, -0.62, 0.26, 0.43, -0.58, 0.18, 0.36, -0.55, 0.06, 0.29, -0.55, -0.06, 0.21, -0.58, -0.18, 0.14, -0.62, -0.26, 0.08, -0.69, -0.3, 0.02, -0.78, -0.29, -0.03, -0.88, -0.22, -0.07, -0.99, -0.12, -0.09, -1.1, 0, -0.1, -1.21, 0.12, -0.09, -1.32, 0.22, -0.07, -1.42, 0.29, -0.03, -1.51, 0.3, 0.02, -1.58, 0.26, 0.08, -1.62, 0.18, 0.14, -1.65, 0.06, 0.21, -1.65, -0.06, 0.29, -1.62, -0.18, 0.36, -1.58, -0.26, 0.43, -1.51, -0.3, 0.48, -1.42, -0.29, 0.53, -1.32, -0.22, 0.57, -1.21, -0.12, 0.59, -1.1, 0, 0.6, -0.99, 0.12, 0.59, -0.88, 0.22, 0.57, -0.78, 0.29, 0.53, -0.69, 0.3, 0.48, -0.62, 0.26, 0.43, -0.58, 0.18, 0.36, -0.55, 0.06, 0.29, -0.55, -0.06, 0.21, -0.58, -0.18, 0.14, -0.62, -0.26, 0.08, -0.69, -0.3, 0.02, -0.78, -0.29, -0.03, -0.88, -0.22, -0.07, -0.99, -0.12, -0.09, -1.1, 0, -0.1 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.06, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.06, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13, 0, 0, 0.05, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.03, 0, 0, 0.03, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.25, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.21, 0, 0, 0.13, 0, 0, 0.06, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13, 0, 0, 0.05, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.03, 0, 0, 0.03, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.25, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.21, 0, 0, 0.13, 0, 0, 0.06, 0, 0, -0.01, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04, 0.11, 0, -0.05, 0.13, 0, -0.05, 0.14, 0, -0.05, 0.15, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.15, 0, -0.03, 0.14, 0, -0.02, 0.13, 0, -0.01, 0.11, 0, -0.01, 0.1, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.05, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0 },
		} },
		forming = { fps = 15, length = 3, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0, 0, 0.01, 0, 0.01, 0.02, 0.01, 0.01, 0.04, 0.01, 0.01, 0.05, 0.01, 0.02, 0.06, 0.02, 0.02, 0.07, 0.02, 0.02, 0.08, 0.02, 0.02, 0.09, 0.02, 0.02, 0.1, 0.03, 0.02, 0.1, 0.03, 0.02, 0.11, 0.03, 0.02, 0.11, 0.03, 0.02, 0.12, 0.03, 0.02, 0.12, 0.03, 0.02, 0.12, 0.03, 0.02, 0.12, 0.03, 0.02, 0.12, 0.03, 0.01, 0.11, 0.03, 0.01, 0.11, 0.03, 0.01, 0.1, 0.02, 0.01, 0.1, 0.02, 0, 0.09, 0.02, 0, 0.08, 0.02, -0.01, 0.07, 0.01, -0.01, 0.06, 0.01, -0.01, 0.05, 0.01, -0.01, 0.04, 0, -0.02, 0.02, 0, -0.02, 0.01, 0, -0.02, 0, -0.01, -0.02, -0.01, -0.01, -0.02, -0.02, -0.01, -0.02, -0.04, -0.02, -0.02, -0.05, -0.02, -0.02, -0.06, -0.02, -0.02, -0.07, -0.02, -0.02, -0.08, -0.03, -0.02, -0.09, -0.03, -0.02, -0.1, -0.03, -0.02, -0.1, -0.03, -0.01, -0.11, -0.03, -0.01, -0.11, -0.03, -0.01, -0.12, -0.03, 0, -0.12, -0.03, 0, -0.12, -0.03 },
			head = { 0.05, 0, 0, 0.05, 0.02, 0.01, 0.05, 0.04, 0.02, 0.05, 0.06, 0.03, 0.05, 0.08, 0.04, 0.05, 0.1, 0.04, 0.05, 0.12, 0.05, 0.05, 0.13, 0.05, 0.05, 0.15, 0.05, 0.05, 0.16, 0.05, 0.05, 0.17, 0.04, 0.05, 0.18, 0.04, 0.05, 0.19, 0.03, 0.05, 0.2, 0.02, 0.05, 0.2, 0.01, 0.05, 0.2, 0, 0.05, 0.2, -0.01, 0.05, 0.2, -0.02, 0.05, 0.19, -0.03, 0.05, 0.18, -0.04, 0.05, 0.17, -0.04, 0.05, 0.16, -0.05, 0.05, 0.15, -0.05, 0.05, 0.13, -0.05, 0.05, 0.12, -0.05, 0.05, 0.1, -0.04, 0.05, 0.08, -0.04, 0.05, 0.06, -0.03, 0.05, 0.04, -0.02, 0.05, 0.02, -0.01, 0.05, 0, 0, 0.05, -0.02, 0.01, 0.05, -0.04, 0.02, 0.05, -0.06, 0.03, 0.05, -0.08, 0.04, 0.05, -0.1, 0.04, 0.05, -0.12, 0.05, 0.05, -0.13, 0.05, 0.05, -0.15, 0.05, 0.05, -0.16, 0.05, 0.05, -0.17, 0.04, 0.05, -0.18, 0.04, 0.05, -0.19, 0.03, 0.05, -0.2, 0.02, 0.05, -0.2, 0.01, 0.05, -0.2, 0 },
			armL = { -0.6, 0, 0.55, -0.67, 0, 0.63, -0.74, 0, 0.7, -0.81, 0, 0.74, -0.86, 0, 0.75, -0.9, 0, 0.72, -0.93, 0, 0.67, -0.95, 0, 0.59, -0.95, 0, 0.51, -0.93, 0, 0.43, -0.9, 0, 0.38, -0.86, 0, 0.35, -0.81, 0, 0.36, -0.74, 0, 0.4, -0.67, 0, 0.47, -0.6, 0, 0.55, -0.53, 0, 0.63, -0.46, 0, 0.7, -0.39, 0, 0.74, -0.34, 0, 0.75, -0.3, 0, 0.72, -0.27, 0, 0.67, -0.25, 0, 0.59, -0.25, 0, 0.51, -0.27, 0, 0.43, -0.3, 0, 0.38, -0.34, 0, 0.35, -0.39, 0, 0.36, -0.46, 0, 0.4, -0.53, 0, 0.47, -0.6, 0, 0.55, -0.67, 0, 0.63, -0.74, 0, 0.7, -0.81, 0, 0.74, -0.86, 0, 0.75, -0.9, 0, 0.72, -0.93, 0, 0.67, -0.95, 0, 0.59, -0.95, 0, 0.51, -0.93, 0, 0.43, -0.9, 0, 0.38, -0.86, 0, 0.35, -0.81, 0, 0.36, -0.74, 0, 0.4, -0.67, 0, 0.47, -0.6, 0, 0.55 },
			armR = { -1.1, 0, 0.6, -0.99, 0.12, 0.59, -0.88, 0.22, 0.57, -0.78, 0.29, 0.53, -0.69, 0.3, 0.48, -0.62, 0.26, 0.43, -0.58, 0.18, 0.36, -0.55, 0.06, 0.29, -0.55, -0.06, 0.21, -0.58, -0.18, 0.14, -0.62, -0.26, 0.08, -0.69, -0.3, 0.02, -0.78, -0.29, -0.03, -0.88, -0.22, -0.07, -0.99, -0.12, -0.09, -1.1, 0, -0.1, -1.21, 0.12, -0.09, -1.32, 0.22, -0.07, -1.42, 0.29, -0.03, -1.51, 0.3, 0.02, -1.58, 0.26, 0.08, -1.62, 0.18, 0.14, -1.65, 0.06, 0.21, -1.65, -0.06, 0.29, -1.62, -0.18, 0.36, -1.58, -0.26, 0.43, -1.51, -0.3, 0.48, -1.42, -0.29, 0.53, -1.32, -0.22, 0.57, -1.21, -0.12, 0.59, -1.1, 0, 0.6, -0.99, 0.12, 0.59, -0.88, 0.22, 0.57, -0.78, 0.29, 0.53, -0.69, 0.3, 0.48, -0.62, 0.26, 0.43, -0.58, 0.18, 0.36, -0.55, 0.06, 0.29, -0.55, -0.06, 0.21, -0.58, -0.18, 0.14, -0.62, -0.26, 0.08, -0.69, -0.3, 0.02, -0.78, -0.29, -0.03, -0.88, -0.22, -0.07, -0.99, -0.12, -0.09, -1.1, 0, -0.1 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.06, 0, 0.04, 0.03, 0, 0.04, 0.01, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.06, 0, 0.04, -0.03, 0, 0.04, -0.01, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04 },
			wingL = { 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5 },
			wingR = { 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5, 0, 0.4, -0.5 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04, 0.11, 0, -0.05, 0.13, 0, -0.05, 0.14, 0, -0.05, 0.15, 0, -0.05, 0.16, 0, -0.05, 0.17, 0, -0.05, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.17, 0, -0.04, 0.16, 0, -0.03, 0.15, 0, -0.03, 0.14, 0, -0.02, 0.13, 0, -0.01, 0.11, 0, -0.01, 0.1, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09, 0, 0, -0.09, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.1, 0, 0, -0.09, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.06, 0, 0, -0.05, 0, 0, -0.04, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0 },
		} },
		slam = { fps = 15, length = 1.8, hit = 1.1, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.07, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.15, 0, 0, -0.18, 0, 0, -0.21, 0, 0, -0.24, 0, 0, -0.26, 0, 0, -0.28, 0, 0, -0.3, 0, 0, -0.31, 0, 0, -0.32, 0, 0, -0.05, 0, 0, 0.28, 0, 0, 0.42, 0, 0, 0.45, 0, 0, 0.43, 0, 0, 0.37, 0, 0, 0.29, 0, 0, 0.19, 0, 0, 0.1, 0, 0, 0.03, 0, 0, 0, 0, 0 },
			head = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.04, 0, 0, -0.05, 0, 0, -0.08, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.16, 0, 0, -0.19, 0, 0, -0.2, 0, 0, -0.22, 0, 0, -0.23, 0, 0, -0.24, 0, 0, -0.25, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.15, 0, 0, 0.14, 0, 0, 0.12, 0, 0, 0.1, 0, 0, 0.06, 0, 0, 0.03, 0, 0, 0.01, 0, 0, 0, 0, 0 },
			armL = { 0, 0, 0.1, -0.02, 0, 0.1, -0.1, 0, 0.1, -0.2, 0, 0.1, -0.35, 0, 0.1, -0.52, 0, 0.1, -0.71, 0, 0.1, -0.91, 0, 0.1, -1.12, 0, 0.1, -1.33, 0, 0.1, -1.54, 0, 0.1, -1.74, 0, 0.1, -1.92, 0, 0.1, -2.08, 0, 0.1, -2.2, 0, 0.1, -2.3, 0, 0.1, -2.34, 0, 0.1, -1.41, 0, 0.1, -0.23, 0, 0.1, 0.25, 0, 0.1, 0.35, 0, 0.1, 0.34, 0, 0.1, 0.28, 0, 0.1, 0.19, 0, 0.1, 0.1, 0, 0.1, 0.01, 0, 0.1, -0.05, 0, 0.1, -0.08, 0, 0.1 },
			armR = { 0, 0, 0.2, -0.02, 0, 0.2, -0.1, 0, 0.2, -0.2, 0, 0.2, -0.35, 0, 0.2, -0.52, 0, 0.2, -0.71, 0, 0.2, -0.91, 0, 0.2, -1.12, 0, 0.2, -1.33, 0, 0.2, -1.54, 0, 0.2, -1.74, 0, 0.2, -1.92, 0, 0.2, -2.08, 0, 0.2, -2.2, 0, 0.2, -2.3, 0, 0.2, -2.34, 0, 0.2, -1.41, 0, 0.2, -0.23, 0, 0.2, 0.25, 0, 0.2, 0.35, 0, 0.2, 0.34, 0, 0.2, 0.28, 0, 0.2, 0.19, 0, 0.2, 0.1, 0, 0.2, 0.01, 0, 0.2, -0.05, 0, 0.2, -0.08, 0, 0.2 },
			legL = { 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.05, 0.03, 0, 0.05, 0.05, 0, 0.05, 0.06, 0, 0.05, 0.07, 0, 0.05, 0.09, 0, 0.05, 0.1, 0, 0.05, 0.11, 0, 0.05, 0.12, 0, 0.05, 0.13, 0, 0.05, 0.14, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04 },
			legR = { 0, 0, 0.05, 0, 0, 0.05, 0.01, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.05, 0.03, 0, 0.05, 0.05, 0, 0.05, 0.06, 0, 0.05, 0.07, 0, 0.05, 0.09, 0, 0.05, 0.1, 0, 0.05, 0.11, 0, 0.05, 0.12, 0, 0.05, 0.13, 0, 0.05, 0.14, 0, 0.05, 0.15, 0, 0.05, 0.15, 0, 0.05, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.15, 0, 0, 0.17, 0, 0, 0.2, 0, 0, 0.23, 0, 0, 0.26, 0, 0, 0.29, 0, 0, 0.32, 0, 0, 0.35, 0, 0, 0.38, 0, 0, 0.41, 0, 0, 0.43, 0, 0, 0.45, 0, 0, 0.46, 0, 0, 0.47, 0, 0, 0.27, 0, 0, -0.01, 0, 0, -0.13, 0, 0, -0.15, 0, 0, -0.14, 0, 0, -0.1, 0, 0, -0.05, 0, 0, 0.01, 0, 0, 0.06, 0, 0, 0.1, 0, 0, 0.12 },
			wingR = { 0, 0, 0.12, 0, 0, 0.12, 0, 0, 0.13, 0, 0, 0.15, 0, 0, 0.17, 0, 0, 0.2, 0, 0, 0.23, 0, 0, 0.26, 0, 0, 0.29, 0, 0, 0.32, 0, 0, 0.35, 0, 0, 0.38, 0, 0, 0.41, 0, 0, 0.43, 0, 0, 0.45, 0, 0, 0.46, 0, 0, 0.47, 0, 0, 0.27, 0, 0, -0.01, 0, 0, -0.13, 0, 0, -0.15, 0, 0, -0.14, 0, 0, -0.1, 0, 0, -0.05, 0, 0, 0.01, 0, 0, 0.06, 0, 0, 0.1, 0, 0, 0.12 },
			cloth = { -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, -0.2, 0, 0, 0.44, 0, 0, 0.41, 0, 0, 0.39, 0, 0, 0.36, 0, 0, 0.33, 0, 0, 0.31, 0, 0, 0.28, 0, 0, 0.26, 0, 0, 0.23, 0, 0, 0.2, 0, 0, 0.18, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06 },
		} },
		thrust = { fps = 15, length = 1.6, hit = 0.9, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.15, 0, 0, 0.16, 0, 0, 0.32, 0, 0, 0.35, 0, 0, 0.33, 0, 0, 0.27, 0, 0, 0.19, 0, 0, 0.11, 0, 0, 0.04, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
			head = { 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.04, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.02, 0, 0, 0.01, 0, 0, 0, 0, 0, -0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.03, 0, 0, -0.04, 0, 0, -0.04, 0, 0, -0.04, 0, 0 },
			armL = { -0.15, 0, 0, -0.15, 0, 0.02, -0.15, 0, 0.07, -0.15, 0, 0.15, -0.15, 0, 0.24, -0.15, 0, 0.36, -0.15, 0, 0.48, -0.15, 0, 0.61, -0.15, 0, 0.73, -0.15, 0, 0.85, -0.15, 0, 0.96, -0.15, 0, 1.05, -0.15, 0, 1.11, -0.15, 0, 1.15, -0.79, 0, 0.68, -1.43, 0, 0.21, -1.55, 0, 0.12, -1.48, 0, 0.12, -1.23, 0, 0.12, -0.89, 0, 0.13, -0.53, 0, 0.13, -0.23, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14 },
			armR = { -0.15, 0, 0, -0.15, 0, 0.02, -0.15, 0, 0.07, -0.15, 0, 0.15, -0.15, 0, 0.24, -0.15, 0, 0.36, -0.15, 0, 0.48, -0.15, 0, 0.61, -0.15, 0, 0.73, -0.15, 0, 0.85, -0.15, 0, 0.96, -0.15, 0, 1.05, -0.15, 0, 1.11, -0.15, 0, 1.15, -0.79, 0, 0.68, -1.43, 0, 0.21, -1.55, 0, 0.12, -1.48, 0, 0.12, -1.23, 0, 0.12, -0.89, 0, 0.13, -0.53, 0, 0.13, -0.23, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14, -0.08, 0, 0.14 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.27, 0, 0, 0.2, 0, 0, 0.13 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02 },
		} },
		pull = { fps = 15, length = 1.2, hit = 0, loop = true, bones = {
			torso = { 0.18, 0, 0, 0.2, 0.01, 0, 0.22, 0.02, 0, 0.23, 0.04, 0, 0.24, 0.05, 0, 0.24, 0.06, 0, 0.23, 0.07, 0, 0.22, 0.08, 0, 0.2, 0.09, 0, 0.18, 0.1, 0, 0.16, 0.1, 0, 0.14, 0.11, 0, 0.13, 0.11, 0, 0.12, 0.12, 0, 0.12, 0.12, 0, 0.13, 0.12, 0, 0.14, 0.12, 0, 0.16, 0.12, 0, 0.18, 0.11, 0 },
			head = { 0.05, 0, 0, 0.05, 0.02, 0.01, 0.05, 0.04, 0.02, 0.05, 0.06, 0.03, 0.05, 0.08, 0.04, 0.05, 0.1, 0.04, 0.05, 0.12, 0.05, 0.05, 0.13, 0.05, 0.05, 0.15, 0.05, 0.05, 0.16, 0.05, 0.05, 0.17, 0.04, 0.05, 0.18, 0.04, 0.05, 0.19, 0.03, 0.05, 0.2, 0.02, 0.05, 0.2, 0.01, 0.05, 0.2, 0, 0.05, 0.2, -0.01, 0.05, 0.2, -0.02, 0.05, 0.19, -0.03 },
			armL = { -0.6, 0, 0.55, -0.67, 0, 0.63, -0.74, 0, 0.7, -0.81, 0, 0.74, -0.86, 0, 0.75, -0.9, 0, 0.72, -0.93, 0, 0.67, -0.95, 0, 0.59, -0.95, 0, 0.51, -0.93, 0, 0.43, -0.9, 0, 0.38, -0.86, 0, 0.35, -0.81, 0, 0.36, -0.74, 0, 0.4, -0.67, 0, 0.47, -0.6, 0, 0.55, -0.53, 0, 0.63, -0.46, 0, 0.7, -0.39, 0, 0.74 },
			armR = { -1.1, 0, 0.6, -0.99, 0.12, 0.59, -0.88, 0.22, 0.57, -0.78, 0.29, 0.53, -0.69, 0.3, 0.48, -0.62, 0.26, 0.43, -0.58, 0.18, 0.36, -0.55, 0.06, 0.29, -0.55, -0.06, 0.21, -0.58, -0.18, 0.14, -0.62, -0.26, 0.08, -0.69, -0.3, 0.02, -0.78, -0.29, -0.03, -0.88, -0.22, -0.07, -0.99, -0.12, -0.09, -1.1, 0, -0.1, -1.21, 0.12, -0.09, -1.32, 0.22, -0.07, -1.42, 0.29, -0.03 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04, 0, 0, 0.11, 0, 0, 0.19, 0, 0, 0.26 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06 },
		} },
		sweep = { fps = 15, length = 2, hit = 0, loop = true, bones = {
			torso = { 0, 0, 0.12, 0, 0.01, 0.12, 0, 0.02, 0.12, 0, 0.04, 0.12, 0, 0.05, 0.12, 0, 0.06, 0.12, 0, 0.07, 0.12, 0, 0.08, 0.12, 0, 0.09, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.11, 0.12, 0, 0.11, 0.12, 0, 0.12, 0.12, 0, 0.12, 0.12, 0, 0.12, 0.12, 0, 0.12, 0.12, 0, 0.12, 0.12, 0, 0.11, 0.12, 0, 0.11, 0.12, 0, 0.1, 0.12, 0, 0.1, 0.12, 0, 0.09, 0.12, 0, 0.08, 0.12, 0, 0.07, 0.12, 0, 0.06, 0.12, 0, 0.05, 0.12, 0, 0.04, 0.12, 0, 0.02, 0.12, 0, 0.01, 0.12, 0, 0, 0.12 },
			head = { 0.05, 0, 0, 0.05, 0.02, 0.01, 0.05, 0.04, 0.02, 0.05, 0.06, 0.03, 0.05, 0.08, 0.04, 0.05, 0.1, 0.04, 0.05, 0.12, 0.05, 0.05, 0.13, 0.05, 0.05, 0.15, 0.05, 0.05, 0.16, 0.05, 0.05, 0.17, 0.04, 0.05, 0.18, 0.04, 0.05, 0.19, 0.03, 0.05, 0.2, 0.02, 0.05, 0.2, 0.01, 0.05, 0.2, 0, 0.05, 0.2, -0.01, 0.05, 0.2, -0.02, 0.05, 0.19, -0.03, 0.05, 0.18, -0.04, 0.05, 0.17, -0.04, 0.05, 0.16, -0.05, 0.05, 0.15, -0.05, 0.05, 0.13, -0.05, 0.05, 0.12, -0.05, 0.05, 0.1, -0.04, 0.05, 0.08, -0.04, 0.05, 0.06, -0.03, 0.05, 0.04, -0.02, 0.05, 0.02, -0.01, 0.05, 0, 0 },
			armL = { -0.6, 0, 0.55, -0.67, 0, 0.63, -0.74, 0, 0.7, -0.81, 0, 0.74, -0.86, 0, 0.75, -0.9, 0, 0.72, -0.93, 0, 0.67, -0.95, 0, 0.59, -0.95, 0, 0.51, -0.93, 0, 0.43, -0.9, 0, 0.38, -0.86, 0, 0.35, -0.81, 0, 0.36, -0.74, 0, 0.4, -0.67, 0, 0.47, -0.6, 0, 0.55, -0.53, 0, 0.63, -0.46, 0, 0.7, -0.39, 0, 0.74, -0.34, 0, 0.75, -0.3, 0, 0.72, -0.27, 0, 0.67, -0.25, 0, 0.59, -0.25, 0, 0.51, -0.27, 0, 0.43, -0.3, 0, 0.38, -0.34, 0, 0.35, -0.39, 0, 0.36, -0.46, 0, 0.4, -0.53, 0, 0.47, -0.6, 0, 0.55 },
			armR = { -1.1, 0, 0.6, -0.99, 0.12, 0.59, -0.88, 0.22, 0.57, -0.78, 0.29, 0.53, -0.69, 0.3, 0.48, -0.62, 0.26, 0.43, -0.58, 0.18, 0.36, -0.55, 0.06, 0.29, -0.55, -0.06, 0.21, -0.58, -0.18, 0.14, -0.62, -0.26, 0.08, -0.69, -0.3, 0.02, -0.78, -0.29, -0.03, -0.88, -0.22, -0.07, -0.99, -0.12, -0.09, -1.1, 0, -0.1, -1.21, 0.12, -0.09, -1.32, 0.22, -0.07, -1.42, 0.29, -0.03, -1.51, 0.3, 0.02, -1.58, 0.26, 0.08, -1.62, 0.18, 0.14, -1.65, 0.06, 0.21, -1.65, -0.06, 0.29, -1.62, -0.18, 0.36, -1.58, -0.26, 0.43, -1.51, -0.3, 0.48, -1.42, -0.29, 0.53, -1.32, -0.22, 0.57, -1.21, -0.12, 0.59, -1.1, 0, 0.6 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3 },
			wingR = { 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3, 0, 0, 0.41, 0, 0, 0.45, 0, 0, 0.39, 0, 0, 0.27, 0, 0, 0.17, 0, 0, 0.16, 0, 0, 0.24, 0, 0, 0.36, 0, 0, 0.44, 0, 0, 0.43, 0, 0, 0.33, 0, 0, 0.21, 0, 0, 0.15, 0, 0, 0.19, 0, 0, 0.3 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09 },
		} },
		floor = { fps = 15, length = 1, hit = 0, loop = true, bones = {
			torso = { 0.3, 0, 0, 0.3, 0.01, 0, 0.3, 0.02, 0, 0.3, 0.04, 0, 0.3, 0.05, 0, 0.3, 0.06, 0, 0.3, 0.07, 0, 0.3, 0.08, 0, 0.3, 0.09, 0, 0.3, 0.1, 0, 0.3, 0.1, 0, 0.3, 0.11, 0, 0.3, 0.11, 0, 0.3, 0.12, 0, 0.3, 0.12, 0, 0.3, 0.12, 0 },
			head = { 0.05, 0, 0, 0.05, 0.02, 0.01, 0.05, 0.04, 0.02, 0.05, 0.06, 0.03, 0.05, 0.08, 0.04, 0.05, 0.1, 0.04, 0.05, 0.12, 0.05, 0.05, 0.13, 0.05, 0.05, 0.15, 0.05, 0.05, 0.16, 0.05, 0.05, 0.17, 0.04, 0.05, 0.18, 0.04, 0.05, 0.19, 0.03, 0.05, 0.2, 0.02, 0.05, 0.2, 0.01, 0.05, 0.2, 0 },
			armL = { -0.6, 0, 0.55, -0.67, 0, 0.63, -0.74, 0, 0.7, -0.81, 0, 0.74, -0.86, 0, 0.75, -0.9, 0, 0.72, -0.93, 0, 0.67, -0.95, 0, 0.59, -0.95, 0, 0.51, -0.93, 0, 0.43, -0.9, 0, 0.38, -0.86, 0, 0.35, -0.81, 0, 0.36, -0.74, 0, 0.4, -0.67, 0, 0.47, -0.6, 0, 0.55 },
			armR = { -1.1, 0, 0.6, -0.99, 0.12, 0.59, -0.88, 0.22, 0.57, -0.78, 0.29, 0.53, -0.69, 0.3, 0.48, -0.62, 0.26, 0.43, -0.58, 0.18, 0.36, -0.55, 0.06, 0.29, -0.55, -0.06, 0.21, -0.58, -0.18, 0.14, -0.62, -0.26, 0.08, -0.69, -0.3, 0.02, -0.78, -0.29, -0.03, -0.88, -0.22, -0.07, -0.99, -0.12, -0.09, -1.1, 0, -0.1 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04 },
			wingR = { 0, 0, 0.12, 0, 0, 0.2, 0, 0, 0.26, 0, 0, 0.3, 0, 0, 0.32, 0, 0, 0.31, 0, 0, 0.26, 0, 0, 0.2, 0, 0, 0.12, 0, 0, 0.05, 0, 0, -0.02, 0, 0, -0.06, 0, 0, -0.08, 0, 0, -0.07, 0, 0, -0.02, 0, 0, 0.04 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09 },
		} },
		roar = { fps = 15, length = 1.8, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, -0.1, 0, 0, -0.17, 0, 0, -0.22, 0, 0, -0.25, 0, 0, -0.27, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0, -0.28, 0, 0 },
			head = { 0, 0, 0, -0.17, 0, 0, -0.3, 0, 0, -0.39, 0, 0, -0.45, 0, 0, -0.48, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0, -0.5, 0, 0 },
			armL = { 0, 0, 0.9, -0.72, 0, 0.9, -1.2, 0, 0.9, -1.49, 0, 0.9, -1.64, 0, 0.9, -1.69, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9 },
			armR = { 0, 0, 0.9, -0.72, 0, 0.9, -1.2, 0, 0.9, -1.49, 0, 0.9, -1.64, 0, 0.9, -1.69, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9, -1.7, 0, 0.9 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.34, 0, 0, 0.49, 0, 0, 0.55, 0, 0, 0.6, 0, 0, 0.68, 0, 0, 0.74, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73 },
			wingR = { 0, 0, 0.12, 0, 0, 0.34, 0, 0, 0.49, 0, 0, 0.55, 0, 0, 0.6, 0, 0, 0.68, 0, 0, 0.74, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73, 0, 0, 0.67, 0, 0, 0.65, 0, 0, 0.7, 0, 0, 0.75, 0, 0, 0.73 },
			cloth = { 0.1, 0, 0, 0.01, 0, 0, -0.05, 0, 0, -0.1, 0, 0, -0.12, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06 },
		} },
		summon = { fps = 15, length = 2, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, -0.04, 0, 0, -0.07, 0, 0, -0.1, 0, 0, -0.11, 0, 0, -0.13, 0, 0, -0.14, 0, 0, -0.14, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0, -0.15, 0, 0 },
			head = { 0, 0, 0, -0.08, 0, 0, -0.14, 0, 0, -0.19, 0, 0, -0.23, 0, 0, -0.26, 0, 0, -0.28, 0, 0, -0.29, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0, -0.3, 0, 0 },
			armL = { 0, 0, 0, -0.46, 0, 0.13, -0.86, 0, 0.23, -1.22, 0, 0.32, -1.54, 0, 0.38, -1.78, 0, 0.43, -1.92, 0, 0.46, -1.96, 0, 0.48, -1.94, 0, 0.49, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5, -1.94, 0, 0.5, -1.92, 0, 0.5, -1.95, 0, 0.5, -2.02, 0, 0.5, -2.07, 0, 0.5, -2.08, 0, 0.5, -2.03, 0, 0.5, -1.97, 0, 0.5, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5 },
			armR = { 0, 0, 0, -0.46, 0, 0.13, -0.86, 0, 0.23, -1.22, 0, 0.32, -1.54, 0, 0.38, -1.78, 0, 0.43, -1.92, 0, 0.46, -1.96, 0, 0.48, -1.94, 0, 0.49, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5, -1.94, 0, 0.5, -1.92, 0, 0.5, -1.95, 0, 0.5, -2.02, 0, 0.5, -2.07, 0, 0.5, -2.08, 0, 0.5, -2.03, 0, 0.5, -1.97, 0, 0.5, -1.92, 0, 0.5, -1.93, 0, 0.5, -1.98, 0, 0.5, -2.05, 0, 0.5, -2.08, 0, 0.5, -2.06, 0, 0.5, -2, 0, 0.5 },
			legL = { 0, 0, 0.04, 0.03, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.09, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.1, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04 },
			legR = { 0, 0, 0.04, -0.03, 0, 0.04, -0.05, 0, 0.04, -0.07, 0, 0.04, -0.09, 0, 0.04, -0.11, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.12, 0, 0.04, -0.11, 0, 0.04, -0.09, 0, 0.04, -0.08, 0, 0.04, -0.05, 0, 0.04, -0.03, 0, 0.04, 0, 0, 0.04, 0.02, 0, 0.04, 0.05, 0, 0.04, 0.07, 0, 0.04, 0.09, 0, 0.04, 0.11, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.12, 0, 0.04, 0.11, 0, 0.04, 0.1, 0, 0.04, 0.08, 0, 0.04, 0.05, 0, 0.04, 0.03, 0, 0.04, 0, 0, 0.04, -0.02, 0, 0.04, -0.05, 0, 0.04 },
			wingL = { 0, 0, 0.12, 0, 0, 0.22, 0, 0, 0.31, 0, 0, 0.37, 0, 0, 0.43, 0, 0, 0.46, 0, 0, 0.49, 0, 0, 0.51, 0, 0, 0.51, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52 },
			wingR = { 0, 0, 0.12, 0, 0, 0.22, 0, 0, 0.31, 0, 0, 0.37, 0, 0, 0.43, 0, 0, 0.46, 0, 0, 0.49, 0, 0, 0.51, 0, 0, 0.51, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52, 0, 0, 0.52 },
			cloth = { 0.1, 0, 0, 0.11, 0, 0.01, 0.13, 0, 0.01, 0.14, 0, 0.02, 0.15, 0, 0.03, 0.16, 0, 0.03, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.04, 0.17, 0, 0.05, 0.16, 0, 0.05, 0.15, 0, 0.05, 0.14, 0, 0.05, 0.13, 0, 0.05, 0.11, 0, 0.05, 0.1, 0, 0.04, 0.09, 0, 0.04, 0.07, 0, 0.03, 0.06, 0, 0.03, 0.05, 0, 0.02, 0.04, 0, 0.02, 0.03, 0, 0.01, 0.03, 0, 0, 0.03, 0, 0, 0.03, 0, -0.01, 0.04, 0, -0.02, 0.05, 0, -0.02, 0.06, 0, -0.03, 0.07, 0, -0.03, 0.09, 0, -0.04, 0.1, 0, -0.04 },
			blades = { 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0, 0, 0.06, 0, 0, 0.07, 0, 0, 0.08, 0, 0, 0.09, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.1, 0, 0, 0.09, 0, 0, 0.09, 0, 0, 0.08, 0, 0, 0.07, 0, 0, 0.06, 0, 0, 0.05, 0, 0, 0.03, 0, 0, 0.02, 0, 0, 0.01, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.03, 0, 0, -0.05, 0, 0, -0.06, 0, 0, -0.07, 0, 0, -0.08, 0, 0, -0.09 },
		} },
		hit = { fps = 15, length = 0.5, hit = 0, loop = false, bones = {
			torso = { -0.35, 0, 0.1, -0.26, 0, 0.08, -0.19, 0, 0.05, -0.13, 0, 0.04, -0.08, 0, 0.02, -0.04, 0, 0.01, -0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
			head = { -0.3, 0, 0, -0.23, 0, 0, -0.16, 0, 0, -0.11, 0, 0, -0.07, 0, 0, -0.03, 0, 0, -0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
			armL = { -0.2, 0, 0.4, -0.15, 0, 0.3, -0.11, 0, 0.22, -0.07, 0, 0.14, -0.04, 0, 0.09, -0.02, 0, 0.04, -0.01, 0, 0.02, 0, 0, 0, 0, 0, 0 },
			armR = { -0.2, 0, 0.4, -0.15, 0, 0.3, -0.11, 0, 0.22, -0.07, 0, 0.14, -0.04, 0, 0.09, -0.02, 0, 0.04, -0.01, 0, 0.02, 0, 0, 0, 0, 0, 0 },
			cloth = { 0.3, 0, 0, 0.23, 0, 0, 0.16, 0, 0, 0.11, 0, 0, 0.07, 0, 0, 0.03, 0, 0, 0.01, 0, 0, 0, 0, 0, 0, 0, 0 },
		} },
		death = { fps = 15, length = 2.4, hit = 0, loop = false, bones = {
			torso = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.03, 0, 0.01, 0.05, 0, 0.01, 0.07, 0, 0.02, 0.1, 0, 0.03, 0.13, 0, 0.04, 0.17, 0, 0.05, 0.21, 0, 0.06, 0.24, 0, 0.08, 0.28, 0, 0.09, 0.32, 0, 0.1, 0.37, 0, 0.11, 0.41, 0, 0.12, 0.44, 0, 0.14, 0.48, 0, 0.15, 0.52, 0, 0.16, 0.55, 0, 0.17, 0.58, 0, 0.18, 0.6, 0, 0.19, 0.62, 0, 0.19, 0.64, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2, 0.65, 0, 0.2 },
			head = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.03, 0, 0.01, 0.05, 0, 0.02, 0.08, 0, 0.03, 0.11, 0, 0.05, 0.14, 0, 0.06, 0.18, 0, 0.08, 0.22, 0, 0.09, 0.26, 0, 0.11, 0.31, 0, 0.13, 0.35, 0, 0.15, 0.39, 0, 0.17, 0.44, 0, 0.19, 0.48, 0, 0.21, 0.52, 0, 0.22, 0.56, 0, 0.24, 0.59, 0, 0.25, 0.62, 0, 0.27, 0.65, 0, 0.28, 0.67, 0, 0.29, 0.69, 0, 0.29, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3, 0.7, 0, 0.3 },
			armL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.03, 0, 0.02, 0.04, 0, 0.03, 0.05, 0, 0.04, 0.06, 0, 0.05, 0.07, 0, 0.06, 0.08, 0, 0.06, 0.09, 0, 0.07, 0.1, 0, 0.08, 0.11, 0, 0.09, 0.12, 0, 0.1, 0.13, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			armR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0.01, 0.01, 0, 0.01, 0.02, 0, 0.02, 0.03, 0, 0.02, 0.04, 0, 0.03, 0.05, 0, 0.04, 0.06, 0, 0.05, 0.07, 0, 0.06, 0.08, 0, 0.06, 0.09, 0, 0.07, 0.1, 0, 0.08, 0.11, 0, 0.09, 0.12, 0, 0.1, 0.13, 0, 0.1, 0.14, 0, 0.11, 0.14, 0, 0.11, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12, 0.15, 0, 0.12 },
			legL = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.06, 0.04, 0, 0.07, 0.06, 0, 0.07, 0.08, 0, 0.08, 0.1, 0, 0.09, 0.13, 0, 0.09, 0.16, 0, 0.09, 0.19, 0, 0.1, 0.22, 0, 0.1, 0.25, 0, 0.1, 0.28, 0, 0.1, 0.31, 0, 0.1, 0.34, 0, 0.1, 0.37, 0, 0.1, 0.4, 0, 0.1, 0.42, 0, 0.1, 0.44, 0, 0.1, 0.46, 0, 0.1, 0.48, 0, 0.1, 0.49, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1 },
			legR = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.05, 0.01, 0, 0.05, 0.02, 0, 0.06, 0.04, 0, 0.07, 0.06, 0, 0.07, 0.08, 0, 0.08, 0.1, 0, 0.09, 0.13, 0, 0.09, 0.16, 0, 0.09, 0.19, 0, 0.1, 0.22, 0, 0.1, 0.25, 0, 0.1, 0.28, 0, 0.1, 0.31, 0, 0.1, 0.34, 0, 0.1, 0.37, 0, 0.1, 0.4, 0, 0.1, 0.42, 0, 0.1, 0.44, 0, 0.1, 0.46, 0, 0.1, 0.48, 0, 0.1, 0.49, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1, 0.5, 0, 0.1 },
			wingL = { 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.05, 0, 0, -0.09, 0, 0, -0.13, 0, 0, -0.18, 0, 0, -0.23, 0, 0, -0.29, 0, 0, -0.35, 0, 0, -0.42, 0, 0, -0.48, 0, 0, -0.55, 0, 0, -0.61, 0, 0, -0.67, 0, 0, -0.72, 0, 0, -0.77, 0, 0, -0.81, 0, 0, -0.85, 0, 0, -0.88, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			wingR = { 0, 0, 0, 0, 0, -0.01, 0, 0, -0.02, 0, 0, -0.05, 0, 0, -0.09, 0, 0, -0.13, 0, 0, -0.18, 0, 0, -0.23, 0, 0, -0.29, 0, 0, -0.35, 0, 0, -0.42, 0, 0, -0.48, 0, 0, -0.55, 0, 0, -0.61, 0, 0, -0.67, 0, 0, -0.72, 0, 0, -0.77, 0, 0, -0.81, 0, 0, -0.85, 0, 0, -0.88, 0, 0, -0.89, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9, 0, 0, -0.9 },
			cloth = { 0, 0, 0, 0, 0, 0, 0.01, 0, 0, 0.02, 0, 0, 0.03, 0, 0, 0.04, 0, 0, 0.06, 0, 0, 0.08, 0, 0, 0.1, 0, 0, 0.12, 0, 0, 0.14, 0, 0, 0.16, 0, 0, 0.18, 0, 0, 0.2, 0, 0, 0.22, 0, 0, 0.24, 0, 0, 0.26, 0, 0, 0.27, 0, 0, 0.28, 0, 0, 0.29, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0 },
		} },
	},
}
-- BOSS-CLIPS-END

-- The bosses' particle sprites rendered in Blender (tools/assetgen/blender_bosstex.py): name -> image id.
-- BOSS-TEX-BEGIN (rewritten by tools/assetgen/upload_boss_tex.py)
SanctuaryConfig.BossTex = {
	["ember"] = 85962707132226,
	["feather"] = 104528808885003,
	["flame_lick"] = 115929224879208,
	["ice_shard"] = 71710010902569,
	["note"] = 74483443066181,
	["ripple"] = 130460545143355,
	["rune_glyph"] = 77402760487945,
	["shadow_wisp"] = 82088940764653,
	["slash"] = 134047664141603,
	["snowflake"] = 75892315918261,
	["spark_streak"] = 91697596100117,
	["void_wisp"] = 100854483128652,
}
-- BOSS-TEX-END

-- The bosses' signature VFX meshes, modelled in Blender (tools/assetgen/blender_bossvfx.py).
-- BOSS-VFXKIT-BEGIN (rewritten by tools/assetgen/upload_boss_vfx.py)
SanctuaryConfig.BossVfxKit = { Id = 71613840883017 }
-- BOSS-VFXKIT-END

-- When each word of a spoken line begins (seconds into its audio), so the text types in time with it.
-- BOSS-VOICE-TIMING-BEGIN (rewritten by tools/assetgen/voice_gen.py)
SanctuaryConfig.BossVoiceTiming = {
	["A [shake]sour[/] note."] = { d = 4.23, w = { 0.00, 0.12, 0.59 } },
	["A cage of [hot]thunder[/]."] = { d = 2.75, w = { 0.00, 0.08, 0.40, 0.56 } },
	["A chord, in [hot]every direction[/]."] = { d = 5.28, w = { 0.00, 0.12, 0.97, 1.12, 1.49 } },
	["A crown of flame -- [hot]for you[/]."] = { d = 2.92, w = { 0.00, 0.07, 0.43, 0.58, 0.94, 1.08, 1.30 } },
	["A good... [slow]duel[/]."] = { d = 2.47, w = { 0.00, 0.06, 0.81 } },
	["A king... does not... [slow]fall[/] to..."] = { d = 3.96, w = { 0.00, 0.07, 0.89, 1.12, 1.78, 2.16 } },
	["A wall of night -- find the [hot]gap[/]."] = { d = 3.03, w = { 0.00, 0.08, 0.38, 0.53, 0.91, 1.06, 1.36, 1.59 } },
	["Again, [slow]but listen this time[/]."] = { d = 5.80, w = { 0.00, 0.96, 1.26, 1.86, 2.27 } },
	["Arcs of the sky -- [big]cut![/]"] = { d = 2.87, w = { 0.00, 0.30, 0.44, 0.67, 0.89, 1.04 } },
	["Be [slow]still[/]. Be [hot]kept[/]."] = { d = 5.45, w = { 0.00, 0.20, 1.13, 1.32 } },
	["Come [slow]closer[/]."] = { d = 3.16, w = { 0.00, 0.33 } },
	["Come into the [hot]cold[/]."] = { d = 4.57, w = { 0.00, 0.23, 0.46, 0.64 } },
	["Every cloud is a [shake]hammer[/]."] = { d = 2.83, w = { 0.00, 0.32, 0.64, 0.77, 0.84 } },
	["Every one of you is a [hot]target[/]."] = { d = 2.78, w = { 0.00, 0.31, 0.50, 0.63, 0.81, 0.94, 1.00 } },
	["Every wire of the sky [wave]answers me[/]."] = { d = 3.52, w = { 0.00, 0.37, 0.66, 0.81, 1.03, 1.25, 1.76 } },
	["Fall. [beat] [slow]Again.[/]"] = { d = 4.14, w = { 0.00, 1.15 } },
	["Fall."] = { d = 2.65, w = { 0.00 } },
	["Find it. [beat] Or we shall sing you [shake]quiet[/]."] = { d = 5.88, w = { 0.00, 0.39, 1.43, 1.56, 1.69, 2.01, 2.26, 2.46 } },
	["Find the [hot]harmony[/]."] = { d = 4.12, w = { 0.00, 0.29, 0.51 } },
	["Flinch. [beat] [slow]Go on.[/]"] = { d = 3.68, w = { 0.00, 1.25, 1.61 } },
	["From the heart, [hot]outward[/]."] = { d = 2.41, w = { 0.00, 0.16, 0.28, 0.66 } },
	["Frost, [hot]bloom[/]."] = { d = 4.87, w = { 0.00, 0.71 } },
	["Guard the [shake]throne[/]!"] = { d = 2.30, w = { 0.00, 0.32, 0.51 } },
	["I am the storm that was [hot]promised[/]."] = { d = 3.08, w = { 0.00, 0.06, 0.17, 0.34, 0.63, 0.86, 1.03 } },
	["I am... [wave]cracking[/]."] = { d = 4.78, w = { 0.00, 0.05, 0.64 } },
	["I have kept this door [beat] since before your stars had [hot]names[/]."] = { d = 5.17, w = { 0.00, 0.06, 0.29, 0.52, 0.75, 1.40, 1.66, 1.98, 2.19, 2.45, 2.61 } },
	["I have waited under the snow for [hot]ten thousand winters[/]."] = { d = 6.26, w = { 0.00, 0.06, 0.29, 0.64, 0.93, 1.11, 1.34, 1.51, 1.69, 2.15 } },
	["I retreat to my [hot]embers[/]. [beat] Not to you."] = { d = 4.52, w = { 0.00, 0.08, 0.65, 0.81, 0.97, 2.28, 2.58, 2.78 } },
	["I sink back into the ice. [beat] It will [hot]keep[/]."] = { d = 6.56, w = { 0.00, 0.07, 0.38, 0.68, 0.98, 1.21, 2.25, 2.37, 2.62 } },
	["I swore an oath to the [hot]space between stars[/]."] = { d = 3.87, w = { 0.00, 0.08, 0.47, 0.62, 0.94, 1.09, 1.33, 1.72, 2.27 } },
	["Is that all the [hot]fire[/] you carry?"] = { d = 3.15, w = { 0.00, 0.14, 0.43, 0.65, 0.86, 1.15, 1.36 } },
	["It is so [whisper]quiet[/]. [beat] [hot]Thank you.[/]"] = { d = 5.68, w = { 0.00, 0.22, 0.43, 0.65, 2.04, 2.38 } },
	["Let the dark have [glitch]hands[/]."] = { d = 3.39, w = { 0.00, 0.17, 0.34, 0.57, 0.81 } },
	["Let the fire decide [beat] [shake]how long you last.[/]"] = { d = 4.16, w = { 0.00, 0.24, 0.47, 0.79, 1.69, 1.91, 2.22, 2.44 } },
	["Let the heavens burn [slow]with me[/]."] = { d = 3.06, w = { 0.00, 0.21, 0.43, 0.93, 1.22, 1.50 } },
	["Let the sky fall in [hot]bolts[/]."] = { d = 3.09, w = { 0.00, 0.22, 0.44, 0.67, 0.96, 1.11 } },
	["Listen. [beat] Between every note, there is a place to [hot]stand[/]."] = { d = 7.63, w = { 0.00, 1.41, 1.98, 2.38, 2.93, 3.32, 3.48, 3.56, 3.96, 4.12 } },
	["Little sparks, [hot]take wing[/]."] = { d = 3.42, w = { 0.00, 0.44, 1.10, 1.45 } },
	["My echoes -- [hot]sing for me[/]."] = { d = 4.49, w = { 0.00, 0.14, 0.58, 0.73, 1.02, 1.23 } },
	["My frozen children -- [hot]wake[/]."] = { d = 4.82, w = { 0.00, 0.10, 0.41, 0.82, 0.92 } },
	["No [hot]retreat[/]."] = { d = 1.78, w = { 0.00, 0.13 } },
	["No crown. [beat] No name. [beat] [slow]Only the blade.[/]"] = { d = 4.87, w = { 0.00, 0.17, 1.41, 1.58, 2.72, 3.03, 3.27 } },
	["Only the [slow]still[/] notes are safe."] = { d = 5.69, w = { 0.00, 0.42, 0.74, 1.27, 1.80, 2.12 } },
	["Only the pockets of [hot]warmth[/] survive."] = { d = 5.54, w = { 0.00, 0.25, 0.44, 0.89, 1.01, 1.40 } },
	["Rise, [hot]keepers of the door[/]."] = { d = 3.97, w = { 0.00, 0.74, 1.15, 1.27, 1.44 } },
	["Rise, my [hot]cinders[/]!"] = { d = 2.78, w = { 0.00, 0.78, 0.91 } },
	["Run in circles, [hot]little ember[/]."] = { d = 3.10, w = { 0.00, 0.21, 0.36, 1.07, 1.42 } },
	["Shades, [hot]to arms[/]."] = { d = 2.50, w = { 0.00, 0.64, 0.84 } },
	["Sloppy. [beat] [hot]Try harder.[/]"] = { d = 3.23, w = { 0.00, 1.29, 1.53 } },
	["Something that was never meant to wake [glitch]is waking[/]."] = { d = 4.21, w = { 0.00, 0.43, 0.63, 0.77, 1.01, 1.25, 1.35, 1.54, 1.64 } },
	["Stay [hot]down[/]."] = { d = 2.89, w = { 0.00, 0.29 } },
	["Stay. [beat] The seal will [hot]close round you[/]."] = { d = 4.66, w = { 0.00, 1.18, 1.33, 1.53, 1.73, 1.98, 2.23 } },
	["Step between the [pulse]beats[/]."] = { d = 4.80, w = { 0.00, 0.35, 0.97, 1.24 } },
	["Struck [pulse]three times[/]. Hear it grow?"] = { d = 5.95, w = { 0.00, 0.62, 1.14, 2.08, 2.37, 2.52 } },
	["That one [wave]rang false[/]."] = { d = 4.92, w = { 0.00, 0.44, 0.78, 1.22 } },
	["The air tastes of [hot]iron[/]. [beat] Something is [pulse]gathering[/]."] = { d = 5.03, w = { 0.00, 0.25, 0.51, 1.01, 1.18, 2.34, 2.83, 2.94 } },
	["The blade [slow]reaches[/]."] = { d = 2.37, w = { 0.00, 0.23, 0.61 } },
	["The clouds... are [wave]parting[/]."] = { d = 3.83, w = { 0.00, 0.23, 1.23, 1.51 } },
	["The cold is [hot]patient[/]. [beat] [shake]I am not.[/]"] = { d = 6.09, w = { 0.00, 0.19, 0.43, 0.56, 1.80, 1.89, 2.08 } },
	["The dark [hot]rains[/] down."] = { d = 2.25, w = { 0.00, 0.20, 0.46, 0.79 } },
	["The door [hot]STAYS SHUT[/]. [beat] Even if I must close it [glitch]with you inside[/]."] = { d = 5.75, w = { 0.00, 0.16, 0.37, 0.63, 1.63, 1.87, 1.99, 2.04, 2.28, 2.57, 2.69, 2.93, 3.10 } },
	["The door closes. [beat] [wave]Remember what you could not finish.[/]"] = { d = 5.55, w = { 0.00, 0.20, 0.47, 1.68, 2.11, 2.33, 2.49, 2.76, 2.93 } },
	["The door opens [hot]where you stand[/]."] = { d = 3.60, w = { 0.00, 0.16, 0.37, 0.63, 0.89, 1.04 } },
	["The earth [hot]splits[/] for its king."] = { d = 3.21, w = { 0.00, 0.22, 0.60, 1.05, 1.27, 1.50 } },
	["The embers remember their [hot]king[/]."] = { d = 2.68, w = { 0.00, 0.15, 0.45, 0.84, 1.09 } },
	["The floor [hot]remembers[/] weight."] = { d = 3.27, w = { 0.00, 0.13, 0.34, 0.73 } },
	["The floor remembers the [hot]door[/]."] = { d = 3.58, w = { 0.00, 0.16, 0.43, 0.91, 1.07 } },
	["The frost spreads in [hot]rings[/]."] = { d = 5.25, w = { 0.00, 0.21, 0.56, 1.05, 1.19 } },
	["The oath is ended. [beat] [hot]The dark is yours.[/]"] = { d = 3.83, w = { 0.00, 0.20, 0.47, 0.61, 1.75, 1.94, 2.19, 2.31 } },
	["The rift will [hot]have you[/]."] = { d = 3.04, w = { 0.00, 0.13, 0.29, 0.46, 0.63 } },
	["The seal's own edge. [beat] Cross it and be [hot]cut[/]."] = { d = 5.09, w = { 0.00, 0.16, 0.49, 0.66, 1.67, 2.04, 2.19, 2.41, 2.56 } },
	["The seal... [shake]cracks[/]?"] = { d = 3.59, w = { 0.00, 0.15, 0.83 } },
	["The sky is [hot]mine[/] to throw!"] = { d = 3.15, w = { 0.00, 0.27, 0.54, 0.72, 1.08, 1.27 } },
	["The sky is full of [shake]knives[/]."] = { d = 5.06, w = { 0.00, 0.20, 0.41, 0.54, 0.81, 0.94 } },
	["The storm moves on. [beat] [hot]So will its thunder.[/]"] = { d = 4.48, w = { 0.00, 0.20, 0.53, 0.85, 1.79, 1.93, 2.19, 2.40 } },
	["The wall advances. Find the [hot]gap[/] -- or [shake]burn[/]."] = { d = 4.00, w = { 0.00, 0.22, 0.51, 1.49, 1.74, 1.93, 2.11, 2.23, 2.36 } },
	["Then I shall stop being [slow]gentle[/]."] = { d = 4.13, w = { 0.00, 0.29, 0.36, 0.73, 1.02, 1.39 } },
	["Thunder [hot]runs[/] to you."] = { d = 2.65, w = { 0.00, 0.46, 0.72, 0.85 } },
	["Two fall as [hot]one[/]."] = { d = 3.13, w = { 0.00, 0.21, 0.48, 0.62 } },
	["Two! [beat] [hot]Two at once![/]"] = { d = 3.60, w = { 0.00, 1.33, 1.61, 1.80 } },
	["We will finish this [hot]another night[/]."] = { d = 2.71, w = { 0.00, 0.11, 0.32, 0.65, 0.86, 1.24 } },
	["You [shake]dare[/] make me bleed? [beat] [hot]Fine.[/]"] = { d = 3.81, w = { 0.00, 0.20, 0.46, 0.72, 0.85, 2.00 } },
	["You are [hot]quick[/]. [beat] Good. [beat] I am [shake]quicker[/]."] = { d = 4.94, w = { 0.00, 0.18, 0.36, 1.46, 2.61, 2.68, 2.83 } },
	["You are [wave]warm[/]. [beat] Warm things do not last here."] = { d = 6.56, w = { 0.00, 0.19, 0.39, 1.45, 1.69, 2.06, 2.18, 2.37, 2.61 } },
	["You are a spark. I am the [big]STORM[/]."] = { d = 4.15, w = { 0.00, 0.30, 0.60, 0.70, 1.62, 1.71, 1.87, 2.12 } },
	["You burn [slow]so brightly[/]. How briefly."] = { d = 4.29, w = { 0.00, 0.29, 0.69, 0.88, 2.08, 2.32 } },
	["You fight like the rift itself. [beat] [hot]Without end.[/]"] = { d = 5.01, w = { 0.00, 0.15, 0.40, 0.59, 0.74, 0.94, 2.03, 2.50 } },
	["You have earned my [hot]full attention[/]."] = { d = 2.96, w = { 0.00, 0.19, 0.44, 0.82, 0.94, 1.19 } },
	["You trespass on my throne [beat] and expect [slow]mercy?[/]"] = { d = 4.88, w = { 0.00, 0.20, 0.74, 0.87, 1.01, 1.83, 2.17, 2.84 } },
	["Your heat is [slow]leaving you[/]."] = { d = 4.90, w = { 0.00, 0.24, 0.48, 0.60, 1.02 } },
	["Your light is [wave]small[/]."] = { d = 3.30, w = { 0.00, 0.25, 0.56, 0.68 } },
	["[big]A false note![/]"] = { d = 4.12, w = { 0.00, 0.10, 0.59 } },
	["[big]ALL OF IT.[/]"] = { d = 1.72, w = { 0.00, 0.22, 0.36 } },
	["[big]Beneath my heel.[/]"] = { d = 2.35, w = { 0.00, 0.51, 0.65 } },
	["[big]Bloom, void.[/]"] = { d = 2.17, w = { 0.00, 0.58 } },
	["[big]Bloom.[/]"] = { d = 3.50, w = { 0.00 } },
	["[big]Burst, storm.[/]"] = { d = 2.95, w = { 0.00, 0.65 } },
	["[big]CLOSE.[/]"] = { d = 4.29, w = { 0.00 } },
	["[big]CRACK.[/]"] = { d = 2.00, w = { 0.00 } },
	["[big]Draw.[/] [beat] Let us see what you are [hot]made of[/]."] = { d = 3.94, w = { 0.00, 1.33, 1.51, 1.62, 1.80, 2.03, 2.21, 2.38, 2.62 } },
	["[big]FALL, STARS.[/]"] = { d = 2.73, w = { 0.00, 0.60 } },
	["[big]FOLLOW.[/]"] = { d = 1.62, w = { 0.00 } },
	["[big]FREEZE.[/] [shake]FREEZE.[/] [glitch]EVERYTHING FREEZE.[/]"] = { d = 6.23, w = { 0.00, 0.74, 1.53, 2.15 } },
	["[big]Fortissimo.[/]"] = { d = 3.83, w = { 0.00 } },
	["[big]Hail.[/]"] = { d = 4.07, w = { 0.00 } },
	["[big]INSOLENT.[/]"] = { d = 1.96, w = { 0.00 } },
	["[big]Impossible![/]"] = { d = 3.06, w = { 0.00 } },
	["[big]Insolent embers![/]"] = { d = 2.38, w = { 0.00, 0.55 } },
	["[big]KNEEL.[/]"] = { d = 2.66, w = { 0.00 } },
	["[big]KNEEL[/] before the last crown of [hot]Emberreach[/]."] = { d = 3.57, w = { 0.00, 0.31, 0.68, 0.87, 1.12, 1.43, 1.55 } },
	["[big]Louder.[/] The hall has not heard a true [hot]chord[/] in an age."] = { d = 6.88, w = { 0.00, 0.96, 1.20, 1.52, 1.76, 2.00, 2.40, 2.48, 2.80, 3.20, 3.36, 3.52 } },
	["[big]MY PATIENCE BURNS.[/]"] = { d = 3.04, w = { 0.00, 0.21, 1.06 } },
	["[big]NO MORE WAITING.[/]"] = { d = 2.60, w = { 0.00, 0.15, 0.45 } },
	["[big]No![/]"] = { d = 4.04, w = { 0.00 } },
	["[big]RAIN.[/]"] = { d = 2.21, w = { 0.00 } },
	["[big]Rain, fire![/]"] = { d = 2.70, w = { 0.00, 0.75 } },
	["[big]Split.[/]"] = { d = 2.90, w = { 0.00 } },
	["[big]THE WHOLE SKY --[/] [shake]COME DOWN![/]"] = { d = 2.94, w = { 0.00, 0.19, 0.51, 0.70, 0.83, 1.08 } },
	["[big][shake]BURN.[/][/] Burn it all -- the throne, the sky, [hot]you[/]!"] = { d = 5.12, w = { 0.00, 0.92, 1.17, 1.29, 1.48, 1.60, 1.79, 2.36, 2.67, 3.22 } },
	["[big][shake]ENOUGH.[/][/]"] = { d = 2.61, w = { 0.00 } },
	["[glitch]All discord, all at once.[/]"] = { d = 5.51, w = { 0.00, 0.35, 1.44, 1.75, 1.96 } },
	["[glitch]Cut. Cut. Cut.[/]"] = { d = 2.98, w = { 0.00, 0.70, 1.38 } },
	["[glitch]ENOUGH GAMES.[/]"] = { d = 3.01, w = { 0.00, 0.38 } },
	["[glitch]Every note, a blade.[/]"] = { d = 5.06, w = { 0.00, 0.52, 1.19, 1.30 } },
	["[glitch]Fork and flash.[/]"] = { d = 2.52, w = { 0.00, 0.30, 0.53 } },
	["[glitch]Grounded...?[/]"] = { d = 2.20, w = { 0.00 } },
	["[glitch]I will be nothing -- and nothing cannot be cut![/]"] = { d = 3.17, w = { 0.00, 0.05, 0.27, 0.37, 0.75, 0.85, 1.01, 1.39, 1.71, 1.82 } },
	["[glitch]If I fall, the world falls with me![/]"] = { d = 3.79, w = { 0.00, 0.23, 0.35, 1.08, 1.28, 1.63, 1.97, 2.24 } },
	["[glitch]Let every cloud break at once![/]"] = { d = 3.66, w = { 0.00, 0.26, 0.68, 1.10, 1.53, 1.70 } },
	["[glitch]Let the whole hall shatter with us![/]"] = { d = 5.30, w = { 0.00, 0.23, 0.47, 0.86, 1.17, 1.72, 2.03 } },
	["[glitch]Lines of the door.[/]"] = { d = 3.08, w = { 0.00, 0.28, 0.39, 0.56 } },
	["[glitch]Out of tune.[/]"] = { d = 4.11, w = { 0.00, 0.32, 0.53 } },
	["[glitch]Out of... time...[/]"] = { d = 4.67, w = { 0.00, 0.27, 1.03 } },
	["[glitch]Pathetic.[/]"] = { d = 2.84, w = { 0.00 } },
	["[glitch]Static.[/]"] = { d = 2.15, w = { 0.00 } },
	["[glitch]The circle closes.[/]"] = { d = 2.50, w = { 0.00, 0.26, 0.77 } },
	["[glitch]There is nowhere to run.[/]"] = { d = 2.78, w = { 0.00, 0.31, 0.43, 0.87, 0.99 } },
	["[hot]Ash.[/]"] = { d = 1.77, w = { 0.00 } },
	["[hot]Brittle.[/]"] = { d = 4.01, w = { 0.00 } },
	["[hot]Flat.[/]"] = { d = 3.80, w = { 0.00 } },
	["[hot]Hear[/] the rhythm."] = { d = 4.05, w = { 0.00, 0.29, 0.51 } },
	["[hot]Icicles.[/] One for each of you."] = { d = 5.95, w = { 0.00, 1.26, 1.46, 1.65, 1.91, 2.04 } },
	["[hot]Lightning[/] finds you."] = { d = 2.68, w = { 0.00, 0.57, 0.89 } },
	["[hot]Lines[/] of the void."] = { d = 2.00, w = { 0.00, 0.29, 0.40, 0.58 } },
	["[hot]No more games.[/]"] = { d = 2.11, w = { 0.00, 0.16, 0.49 } },
	["[hot]One cut.[/]"] = { d = 1.62, w = { 0.00, 0.20 } },
	["[hot]Rails of lightning.[/]"] = { d = 2.58, w = { 0.00, 0.30, 0.43 } },
	["[hot]Shatter.[/]"] = { d = 3.74, w = { 0.00 } },
	["[hot]Too slow.[/]"] = { d = 2.32, w = { 0.00, 0.29 } },
	["[hot]Twice.[/]"] = { d = 1.59, w = { 0.00 } },
	["[hot]Unguarded.[/]"] = { d = 1.75, w = { 0.00 } },
	["[hot]Well struck.[/]"] = { d = 1.75, w = { 0.00, 0.22 } },
	["[shake]A clean cut...[/]"] = { d = 1.79, w = { 0.00, 0.05, 0.33 } },
	["[shake]All voices -- together --[/] [big]NOW.[/]"] = { d = 4.60, w = { 0.00, 0.19, 0.56, 0.69, 1.18, 1.31 } },
	["[shake]Both of you.[/]"] = { d = 2.79, w = { 0.00, 0.22, 0.33 } },
	["[shake]Crawl.[/]"] = { d = 1.95, w = { 0.00 } },
	["[shake]Crushed.[/]"] = { d = 1.97, w = { 0.00 } },
	["[shake]Do not rise.[/]"] = { d = 3.09, w = { 0.00, 0.17, 0.42 } },
	["[shake]FASTER. LOUDER.[/]"] = { d = 4.83, w = { 0.00, 0.95 } },
	["[shake]Fall through.[/]"] = { d = 2.82, w = { 0.00, 0.19 } },
	["[shake]Feel that?[/]"] = { d = 2.10, w = { 0.00, 0.24 } },
	["[shake]Fly, my storm-children.[/]"] = { d = 3.70, w = { 0.00, 0.73, 0.90 } },
	["[shake]I tire of this duel.[/]"] = { d = 2.34, w = { 0.00, 0.07, 0.37, 0.52, 0.82 } },
	["[shake]Impossible![/]"] = { d = 2.36, w = { 0.00 } },
	["[shake]Kneel inside it.[/]"] = { d = 2.37, w = { 0.00, 0.37, 0.81 } },
	["[shake]NO MORE HONOUR.[/] [beat] [big]ONLY THE DARK.[/]"] = { d = 3.63, w = { 0.00, 0.12, 0.35, 1.50, 1.83, 2.08 } },
	["[shake]Needles of winter.[/]"] = { d = 4.53, w = { 0.00, 0.39, 0.50 } },
	["[shake]Neither escapes.[/]"] = { d = 2.32, w = { 0.00, 0.46 } },
	["[shake]Slower.[/] You are slowing."] = { d = 5.25, w = { 0.00, 0.80, 0.97, 1.15 } },
	["[shake]Sour.[/] Sour!"] = { d = 4.67, w = { 0.00, 0.88 } },
	["[shake]Strike, strike, strike![/]"] = { d = 3.75, w = { 0.00, 0.83, 1.59 } },
	["[shake]The crown demands [hot]ash[/]![/]"] = { d = 2.78, w = { 0.00, 0.23, 0.61, 1.14 } },
	["[shake]The storm [hot]breaks[/] its leash![/]"] = { d = 2.88, w = { 0.00, 0.17, 0.47, 0.82, 0.99 } },
	["[shake]Turn back.[/] [beat] Or be [glitch]unmade[/]."] = { d = 4.52, w = { 0.00, 0.28, 1.37, 1.53, 1.70 } },
	["[shake]Two strokes.[/]"] = { d = 1.85, w = { 0.00, 0.19 } },
	["[shake]WINTER WILL NOT WAIT.[/]"] = { d = 4.75, w = { 0.00, 0.37, 0.62, 0.81 } },
	["[shake]Walk through the dark.[/]"] = { d = 2.06, w = { 0.00, 0.19, 0.53, 0.68 } },
	["[shake]You are taking too long.[/] [beat] The door [hot]hungers[/]."] = { d = 5.02, w = { 0.00, 0.18, 0.35, 0.70, 0.88, 1.91, 2.09, 2.32 } },
	["[shake]You... [hot]DARE[/]?[/]"] = { d = 2.84, w = { 0.00, 0.85 } },
	["[shake]Your stance is weak.[/]"] = { d = 2.12, w = { 0.00, 0.23, 0.57, 0.69 } },
	["[slow]A river of fire... for you.[/]"] = { d = 4.12, w = { 0.00, 0.11, 0.64, 0.86, 1.93, 2.29 } },
	["[slow]Again.[/]"] = { d = 1.62, w = { 0.00 } },
	["[slow]Bow to the flame.[/]"] = { d = 2.54, w = { 0.00, 0.26, 0.43, 0.69 } },
	["[slow]Enclosed.[/]"] = { d = 2.42, w = { 0.00 } },
	["[slow]Find the last fire.[/]"] = { d = 5.20, w = { 0.00, 0.39, 0.68, 1.07 } },
	["[slow]Follow the crack...[/]"] = { d = 3.24, w = { 0.00, 0.35, 0.53 } },
	["[slow]Follow the light to its end.[/]"] = { d = 3.31, w = { 0.00, 0.46, 0.69, 1.07, 1.23, 1.46 } },
	["[slow]Go on, then.[/] [beat] See what waits [hot]behind it[/]."] = { d = 5.38, w = { 0.00, 0.20, 0.64, 1.77, 1.97, 2.23, 2.56, 2.95 } },
	["[slow]It all comes down.[/]"] = { d = 5.04, w = { 0.00, 0.19, 0.47, 0.94 } },
	["[slow]Let it fall.[/]"] = { d = 2.05, w = { 0.00, 0.27, 0.46 } },
	["[slow]Let the quiet have the sky.[/]"] = { d = 3.49, w = { 0.00, 0.27, 0.53, 0.97, 1.33, 1.59 } },
	["[slow]Let the world forget the sun.[/]"] = { d = 5.33, w = { 0.00, 0.21, 0.42, 0.78, 1.20, 1.41 } },
	["[slow]Settle... settle...[/]"] = { d = 5.24, w = { 0.00, 0.91 } },
	["[slow]Sleep.[/] [beat] I will [hot]keep[/] you."] = { d = 5.82, w = { 0.00, 1.44, 1.49, 1.72, 1.95 } },
	["[slow]Stand still.[/] [beat] It will be over before the [big]thunder[/]."] = { d = 5.16, w = { 0.00, 0.56, 1.97, 2.08, 2.31, 2.42, 2.65, 2.99, 3.16 } },
	["[slow]The frost... [hot]hardens[/].[/]"] = { d = 6.12, w = { 0.00, 0.32, 1.49 } },
	["[slow]The hall... falls [wave]silent[/].[/]"] = { d = 6.29, w = { 0.00, 0.34, 1.47, 2.21 } },
	["[slow]The whole arc.[/]"] = { d = 2.19, w = { 0.00, 0.26, 0.70 } },
	["[slow]Walk through fire, if you can.[/]"] = { d = 4.18, w = { 0.00, 0.40, 1.11, 1.76, 2.00, 2.36 } },
	["[slow]Who opens[/] [big]the Riftmaw?[/]"] = { d = 3.62, w = { 0.00, 0.21, 0.57, 0.79 } },
	["[wave]A crack... in the ice...[/]"] = { d = 5.87, w = { 0.00, 0.08, 1.04, 1.26, 1.58 } },
	["[wave]A note, held too long, begins to [hot]crack[/].[/]"] = { d = 6.33, w = { 0.00, 0.10, 0.73, 1.11, 1.40, 2.01, 2.56, 2.74 } },
	["[wave]A snowflake, grown huge.[/]"] = { d = 5.62, w = { 0.00, 0.08, 1.05, 1.51 } },
	["[wave]Armour assembles itself out of nothing.[/]"] = { d = 3.51, w = { 0.00, 0.42, 1.04, 1.46, 1.67, 1.81 } },
	["[wave]Come, come, come.[/]"] = { d = 3.38, w = { 0.00, 0.67, 1.37 } },
	["[wave]Echo... echo... [/][hot]echo[/]."] = { d = 5.90, w = { 0.00, 1.20, 2.17 } },
	["[wave]Ember spirits, attend me.[/]"] = { d = 3.09, w = { 0.00, 0.39, 1.16, 1.55 } },
	["[wave]Everything drifts to winter.[/]"] = { d = 4.93, w = { 0.00, 0.52, 0.83, 0.93 } },
	["[wave]Everything falls inward.[/]"] = { d = 3.50, w = { 0.00, 0.57, 0.86 } },
	["[wave]Frost on your breath... on your blade...[/]"] = { d = 6.07, w = { 0.00, 0.30, 0.41, 0.65, 1.50, 1.64, 1.90 } },
	["[wave]Glass rain.[/]"] = { d = 4.01, w = { 0.00, 0.49 } },
	["[wave]Heat rises... [/][shake]as it should.[/]"] = { d = 3.47, w = { 0.00, 0.34, 1.34, 1.48, 1.63 } },
	["[wave]Ice creaks.[/] [beat] Something very [slow]old[/] is turning over."] = { d = 7.25, w = { 0.00, 0.24, 1.54, 2.16, 2.44, 2.64, 2.78, 3.26 } },
	["[wave]In all directions.[/]"] = { d = 2.88, w = { 0.00, 0.17, 0.42 } },
	["[wave]Is that your best?[/]"] = { d = 2.26, w = { 0.00, 0.15, 0.44, 0.73 } },
	["[wave]Join the chorus.[/]"] = { d = 4.48, w = { 0.00, 0.41, 0.72 } },
	["[wave]More voices... more... [/][pulse]more[/]."] = { d = 5.93, w = { 0.00, 0.33, 1.38, 2.28 } },
	["[wave]No way out but through me.[/]"] = { d = 3.42, w = { 0.00, 0.11, 0.28, 0.45, 0.62, 1.01 } },
	["[wave]Numb yet?[/]"] = { d = 4.34, w = { 0.00, 0.34 } },
	["[wave]One... two... three...[/]"] = { d = 5.34, w = { 0.00, 0.84, 1.78 } },
	["[wave]Rifts, rifts, rifts.[/]"] = { d = 4.52, w = { 0.00, 0.81, 1.61 } },
	["[wave]Ripples of cold.[/]"] = { d = 4.60, w = { 0.00, 0.48, 0.62 } },
	["[wave]Rise from the snow.[/]"] = { d = 4.87, w = { 0.00, 0.31, 0.61, 0.85 } },
	["[wave]Rise, my lost companions.[/]"] = { d = 3.32, w = { 0.00, 0.84, 0.99, 1.31 } },
	["[wave]Seven voices woke.[/] [beat] One of them is singing [hot]for you[/]."] = { d = 7.30, w = { 0.00, 0.51, 1.12, 2.38, 2.60, 2.75, 3.05, 3.21, 3.73, 3.96 } },
	["[wave]The beam turns... and turns...[/]"] = { d = 3.80, w = { 0.00, 0.23, 0.53, 1.45, 1.72 } },
	["[wave]The clouds are gathering their courage.[/]"] = { d = 3.37, w = { 0.00, 0.16, 0.48, 0.64, 1.13, 1.40 } },
	["[wave]The hall grows [hot]impatient[/].[/]"] = { d = 4.76, w = { 0.00, 0.23, 0.55, 0.94 } },
	["[wave]The song goes on without you.[/]"] = { d = 4.85, w = { 0.00, 0.23, 0.53, 0.83, 0.98, 1.51 } },
	["[wave]Turn with me.[/]"] = { d = 1.89, w = { 0.00, 0.27, 0.54 } },
	["[wave]Walls of winter.[/]"] = { d = 4.60, w = { 0.00, 0.34, 0.48 } },
	["[whisper]A blade, drawn from the dark.[/]"] = { d = 3.52, w = { 0.00, 0.14, 1.10, 1.48, 1.78, 2.00 } },
	["[whisper]Cold little guardians.[/]"] = { d = 4.96, w = { 0.00, 0.26, 0.66 } },
	["[whisper]Cold little voices... wake.[/]"] = { d = 5.97, w = { 0.00, 0.40, 1.01, 2.24 } },
	["[whisper]Come, little shadows.[/]"] = { d = 3.56, w = { 0.00, 0.49, 0.85 } },
	["[whisper]Do you hear the wires of the sky?[/]"] = { d = 3.48, w = { 0.00, 0.15, 0.37, 0.67, 0.89, 1.26, 1.41, 1.63 } },
	["[whisper]Few ever did.[/]"] = { d = 2.28, w = { 0.00, 0.31, 0.72 } },
	["[whisper]Listen...[/] the hall is [pulse]humming[/]."] = { d = 5.44, w = { 0.00, 1.00, 1.25, 1.58, 1.74 } },
	["[whisper]Shadows... attend.[/]"] = { d = 2.86, w = { 0.00, 1.02 } },
	["[whisper]Snow falls upward here.[/]"] = { d = 5.01, w = { 0.00, 0.27, 0.61, 1.03 } },
	["[whisper]So tired...[/]"] = { d = 4.44, w = { 0.00, 0.16 } },
	["[whisper]Spring... was so far away.[/]"] = { d = 5.76, w = { 0.00, 0.97, 1.24, 1.41, 1.68 } },
	["[whisper]The crown is yours.[/] [beat] It was always [hot]heavy[/]."] = { d = 4.35, w = { 0.00, 0.25, 0.68, 0.85, 2.10, 2.20, 2.37, 2.69 } },
	["[whisper]The seal... is [wave]thinning[/].[/]"] = { d = 3.74, w = { 0.00, 0.16, 0.87, 0.98 } },
	["[whisper]The seal... was never [wave]mine[/] to keep.[/]"] = { d = 4.27, w = { 0.00, 0.20, 0.97, 1.14, 1.42, 1.64, 1.75 } },
}
-- BOSS-VOICE-TIMING-END

-- Spoken lines: subtitle text -> uploaded audio id, so each boss line is voiced as well as shown.
-- BOSS-VOICE-BEGIN (rewritten by tools/assetgen/upload_voice.py)
SanctuaryConfig.BossVoice = {
	["A [shake]sour[/] note."] = 95344746632864,
	["A cage of [hot]thunder[/]."] = 78746718179925,
	["A chord, in [hot]every direction[/]."] = 98346027448955,
	["A crown of flame -- [hot]for you[/]."] = 96433045606426,
	["A good... [slow]duel[/]."] = 77700470747683,
	["A king... does not... [slow]fall[/] to..."] = 89777560305247,
	["A wall of night -- find the [hot]gap[/]."] = 91604740245146,
	["Again, [slow]but listen this time[/]."] = 131007339320063,
	["Arcs of the sky -- [big]cut![/]"] = 73558115345769,
	["Be [slow]still[/]. Be [hot]kept[/]."] = 110597196213414,
	["Come [slow]closer[/]."] = 100467986030284,
	["Come into the [hot]cold[/]."] = 106513458775347,
	["Every cloud is a [shake]hammer[/]."] = 109362295728959,
	["Every one of you is a [hot]target[/]."] = 126663011231230,
	["Every wire of the sky [wave]answers me[/]."] = 135590678846352,
	["Fall. [beat] [slow]Again.[/]"] = 120435826767272,
	["Fall."] = 113362253571603,
	["Find it. [beat] Or we shall sing you [shake]quiet[/]."] = 85536272825493,
	["Find the [hot]harmony[/]."] = 83579596196731,
	["Flinch. [beat] [slow]Go on.[/]"] = 86883176069760,
	["From the heart, [hot]outward[/]."] = 89277044486605,
	["Frost, [hot]bloom[/]."] = 127513777903425,
	["Guard the [shake]throne[/]!"] = 125169080961002,
	["I am the storm that was [hot]promised[/]."] = 81634649129478,
	["I am... [wave]cracking[/]."] = 86575656642265,
	["I have kept this door [beat] since before your stars had [hot]names[/]."] = 78822617863494,
	["I have waited under the snow for [hot]ten thousand winters[/]."] = 97815684790608,
	["I retreat to my [hot]embers[/]. [beat] Not to you."] = 118899930886827,
	["I sink back into the ice. [beat] It will [hot]keep[/]."] = 100968656834235,
	["I swore an oath to the [hot]space between stars[/]."] = 84442591077413,
	["Is that all the [hot]fire[/] you carry?"] = 93640392354045,
	["It is so [whisper]quiet[/]. [beat] [hot]Thank you.[/]"] = 132299759273872,
	["Let the dark have [glitch]hands[/]."] = 93587421122359,
	["Let the fire decide [beat] [shake]how long you last.[/]"] = 87161547328892,
	["Let the heavens burn [slow]with me[/]."] = 81679988086016,
	["Let the sky fall in [hot]bolts[/]."] = 136624977227738,
	["Listen. [beat] Between every note, there is a place to [hot]stand[/]."] = 91686590763975,
	["Little sparks, [hot]take wing[/]."] = 99230989045364,
	["My echoes -- [hot]sing for me[/]."] = 123250887115766,
	["My frozen children -- [hot]wake[/]."] = 128784187681153,
	["No [hot]retreat[/]."] = 127113977936075,
	["No crown. [beat] No name. [beat] [slow]Only the blade.[/]"] = 137432686433932,
	["Only the [slow]still[/] notes are safe."] = 108385161576859,
	["Only the pockets of [hot]warmth[/] survive."] = 99417295556156,
	["Rise, [hot]keepers of the door[/]."] = 129399954266295,
	["Rise, my [hot]cinders[/]!"] = 127932431528237,
	["Run in circles, [hot]little ember[/]."] = 71438884715194,
	["Shades, [hot]to arms[/]."] = 87912650270079,
	["Sloppy. [beat] [hot]Try harder.[/]"] = 134653097070378,
	["Something that was never meant to wake [glitch]is waking[/]."] = 107901348113909,
	["Stay [hot]down[/]."] = 93137758118296,
	["Stay. [beat] The seal will [hot]close round you[/]."] = 104259843330267,
	["Step between the [pulse]beats[/]."] = 95854517524181,
	["Struck [pulse]three times[/]. Hear it grow?"] = 93273056837358,
	["That one [wave]rang false[/]."] = 126174281007806,
	["The air tastes of [hot]iron[/]. [beat] Something is [pulse]gathering[/]."] = 88711104342107,
	["The blade [slow]reaches[/]."] = 105207435046033,
	["The clouds... are [wave]parting[/]."] = 118109827713211,
	["The cold is [hot]patient[/]. [beat] [shake]I am not.[/]"] = 95393081708618,
	["The dark [hot]rains[/] down."] = 132866005551404,
	["The door [hot]STAYS SHUT[/]. [beat] Even if I must close it [glitch]with you inside[/]."] = 110538042306061,
	["The door closes. [beat] [wave]Remember what you could not finish.[/]"] = 134876746371293,
	["The door opens [hot]where you stand[/]."] = 90390139367589,
	["The earth [hot]splits[/] for its king."] = 75786266589913,
	["The embers remember their [hot]king[/]."] = 138283194598448,
	["The floor [hot]remembers[/] weight."] = 101763754209953,
	["The floor remembers the [hot]door[/]."] = 116453334209661,
	["The frost spreads in [hot]rings[/]."] = 112276666923221,
	["The oath is ended. [beat] [hot]The dark is yours.[/]"] = 112257668590205,
	["The rift will [hot]have you[/]."] = 131964934868851,
	["The seal's own edge. [beat] Cross it and be [hot]cut[/]."] = 121122454859820,
	["The sky is [hot]mine[/] to throw!"] = 94106611068865,
	["The sky is full of [shake]knives[/]."] = 86678073501699,
	["The storm moves on. [beat] [hot]So will its thunder.[/]"] = 108824748910255,
	["The wall advances. Find the [hot]gap[/] -- or [shake]burn[/]."] = 101095701141066,
	["Then I shall stop being [slow]gentle[/]."] = 77571427619031,
	["Thunder [hot]runs[/] to you."] = 82627197352686,
	["Two fall as [hot]one[/]."] = 110790829484306,
	["Two! [beat] [hot]Two at once![/]"] = 95197136453801,
	["We will finish this [hot]another night[/]."] = 76641406729699,
	["You [shake]dare[/] make me bleed? [beat] [hot]Fine.[/]"] = 121078819066510,
	["You are [hot]quick[/]. [beat] Good. [beat] I am [shake]quicker[/]."] = 92702871127900,
	["You are [wave]warm[/]. [beat] Warm things do not last here."] = 132324149166852,
	["You are a spark. I am the [big]STORM[/]."] = 79713242560826,
	["You burn [slow]so brightly[/]. How briefly."] = 129867649174236,
	["You fight like the rift itself. [beat] [hot]Without end.[/]"] = 76069736409894,
	["You have earned my [hot]full attention[/]."] = 117219678889740,
	["You trespass on my throne [beat] and expect [slow]mercy?[/]"] = 70402976926218,
	["Your heat is [slow]leaving you[/]."] = 95231819805067,
	["Your light is [wave]small[/]."] = 87110814309124,
	["[big]ALL OF IT.[/]"] = 96810806258016,
	["[big]Beneath my heel.[/]"] = 137424012686089,
	["[big]Bloom, void.[/]"] = 109649809427231,
	["[big]Bloom.[/]"] = 91643357280740,
	["[big]Burst, storm.[/]"] = 112615902250966,
	["[big]CLOSE.[/]"] = 103919288104018,
	["[big]CRACK.[/]"] = 71486911775575,
	["[big]Draw.[/] [beat] Let us see what you are [hot]made of[/]."] = 122633883958106,
	["[big]FALL, STARS.[/]"] = 97329125324516,
	["[big]FOLLOW.[/]"] = 84417546415372,
	["[big]FREEZE.[/] [shake]FREEZE.[/] [glitch]EVERYTHING FREEZE.[/]"] = 132441015615100,
	["[big]Fortissimo.[/]"] = 85091422078069,
	["[big]Hail.[/]"] = 133011039153598,
	["[big]INSOLENT.[/]"] = 104292629338123,
	["[big]KNEEL.[/]"] = 97986157005048,
	["[big]KNEEL[/] before the last crown of [hot]Emberreach[/]."] = 88269226657979,
	["[big]Louder.[/] The hall has not heard a true [hot]chord[/] in an age."] = 124960627276635,
	["[big]RAIN.[/]"] = 82246704856489,
	["[big]Rain, fire![/]"] = 102337895236680,
	["[big]Split.[/]"] = 112828628875508,
	["[big]THE WHOLE SKY --[/] [shake]COME DOWN![/]"] = 138319362132656,
	["[big][shake]BURN.[/][/] Burn it all -- the throne, the sky, [hot]you[/]!"] = 101965958068319,
	["[big][shake]ENOUGH.[/][/]"] = 131528892735208,
	["[glitch]All discord, all at once.[/]"] = 108050575856024,
	["[glitch]Cut. Cut. Cut.[/]"] = 106893634218840,
	["[glitch]Every note, a blade.[/]"] = 79859684585007,
	["[glitch]Fork and flash.[/]"] = 127520892079301,
	["[glitch]I will be nothing -- and nothing cannot be cut![/]"] = 124477494019151,
	["[glitch]If I fall, the world falls with me![/]"] = 133485171196175,
	["[glitch]Let every cloud break at once![/]"] = 95812224930522,
	["[glitch]Let the whole hall shatter with us![/]"] = 87447659581395,
	["[glitch]Lines of the door.[/]"] = 75379236376361,
	["[glitch]Out of tune.[/]"] = 100989721163746,
	["[glitch]Pathetic.[/]"] = 98427557676180,
	["[glitch]Static.[/]"] = 111170860146297,
	["[glitch]The circle closes.[/]"] = 135945295893666,
	["[glitch]There is nowhere to run.[/]"] = 94025251097243,
	["[hot]Ash.[/]"] = 82050447028199,
	["[hot]Brittle.[/]"] = 134130705306225,
	["[hot]Flat.[/]"] = 109125705199740,
	["[hot]Hear[/] the rhythm."] = 135837365859338,
	["[hot]Icicles.[/] One for each of you."] = 82689846358497,
	["[hot]Lightning[/] finds you."] = 132944508844153,
	["[hot]Lines[/] of the void."] = 95541749891094,
	["[hot]One cut.[/]"] = 103845347791167,
	["[hot]Rails of lightning.[/]"] = 111283014638718,
	["[hot]Shatter.[/]"] = 93573986064347,
	["[hot]Too slow.[/]"] = 92910711472280,
	["[hot]Twice.[/]"] = 119176067099868,
	["[hot]Unguarded.[/]"] = 134835343245567,
	["[shake]All voices -- together --[/] [big]NOW.[/]"] = 89581059281615,
	["[shake]Both of you.[/]"] = 87935597562853,
	["[shake]Crawl.[/]"] = 137666334771030,
	["[shake]Crushed.[/]"] = 102294777269451,
	["[shake]Do not rise.[/]"] = 121051154176875,
	["[shake]Fall through.[/]"] = 73078319932246,
	["[shake]Feel that?[/]"] = 118444370069415,
	["[shake]Fly, my storm-children.[/]"] = 105139152542373,
	["[shake]Kneel inside it.[/]"] = 104028166019317,
	["[shake]NO MORE HONOUR.[/] [beat] [big]ONLY THE DARK.[/]"] = 78368337008326,
	["[shake]Needles of winter.[/]"] = 108678926498562,
	["[shake]Neither escapes.[/]"] = 129712918140834,
	["[shake]Slower.[/] You are slowing."] = 91266263287081,
	["[shake]Sour.[/] Sour!"] = 85889742921601,
	["[shake]Strike, strike, strike![/]"] = 140513380036220,
	["[shake]Turn back.[/] [beat] Or be [glitch]unmade[/]."] = 138183418304059,
	["[shake]Two strokes.[/]"] = 93588940853310,
	["[shake]Walk through the dark.[/]"] = 93639926523842,
	["[shake]Your stance is weak.[/]"] = 73472017961354,
	["[slow]A river of fire... for you.[/]"] = 103513045824506,
	["[slow]Again.[/]"] = 97678941126822,
	["[slow]Bow to the flame.[/]"] = 95001151081543,
	["[slow]Enclosed.[/]"] = 71639486722035,
	["[slow]Find the last fire.[/]"] = 93384045737574,
	["[slow]Follow the crack...[/]"] = 73276247474546,
	["[slow]Follow the light to its end.[/]"] = 106456937004745,
	["[slow]Go on, then.[/] [beat] See what waits [hot]behind it[/]."] = 103077106049774,
	["[slow]It all comes down.[/]"] = 134009183257560,
	["[slow]Let it fall.[/]"] = 116534623261074,
	["[slow]Let the quiet have the sky.[/]"] = 97376916963623,
	["[slow]Let the world forget the sun.[/]"] = 70580095059922,
	["[slow]Settle... settle...[/]"] = 134232953374625,
	["[slow]Sleep.[/] [beat] I will [hot]keep[/] you."] = 82824035986596,
	["[slow]Stand still.[/] [beat] It will be over before the [big]thunder[/]."] = 129820104719023,
	["[slow]The hall... falls [wave]silent[/].[/]"] = 73942577213955,
	["[slow]The whole arc.[/]"] = 128605835380947,
	["[slow]Walk through fire, if you can.[/]"] = 112333932350587,
	["[slow]Who opens[/] [big]the Riftmaw?[/]"] = 139650842347758,
	["[wave]A note, held too long, begins to [hot]crack[/].[/]"] = 89092120532926,
	["[wave]A snowflake, grown huge.[/]"] = 114544020479850,
	["[wave]Armour assembles itself out of nothing.[/]"] = 116854063654512,
	["[wave]Come, come, come.[/]"] = 95173405105390,
	["[wave]Echo... echo... [/][hot]echo[/]."] = 134230314278897,
	["[wave]Ember spirits, attend me.[/]"] = 132403028576443,
	["[wave]Everything drifts to winter.[/]"] = 117162547212783,
	["[wave]Everything falls inward.[/]"] = 100417112552168,
	["[wave]Frost on your breath... on your blade...[/]"] = 111769373926423,
	["[wave]Glass rain.[/]"] = 135910917554777,
	["[wave]Heat rises... [/][shake]as it should.[/]"] = 87437811307756,
	["[wave]Ice creaks.[/] [beat] Something very [slow]old[/] is turning over."] = 76163254447371,
	["[wave]In all directions.[/]"] = 115184423361550,
	["[wave]Is that your best?[/]"] = 73298054606888,
	["[wave]Join the chorus.[/]"] = 112188742003731,
	["[wave]More voices... more... [/][pulse]more[/]."] = 134363625819822,
	["[wave]No way out but through me.[/]"] = 114469432391838,
	["[wave]Numb yet?[/]"] = 101411350932466,
	["[wave]One... two... three...[/]"] = 99460963954783,
	["[wave]Rifts, rifts, rifts.[/]"] = 130890370359959,
	["[wave]Ripples of cold.[/]"] = 135252863819016,
	["[wave]Rise from the snow.[/]"] = 77178594307361,
	["[wave]Rise, my lost companions.[/]"] = 123426789151866,
	["[wave]Seven voices woke.[/] [beat] One of them is singing [hot]for you[/]."] = 117855684563224,
	["[wave]The beam turns... and turns...[/]"] = 105462829481092,
	["[wave]The clouds are gathering their courage.[/]"] = 83359844543479,
	["[wave]The song goes on without you.[/]"] = 100440258942137,
	["[wave]Turn with me.[/]"] = 85512797093288,
	["[wave]Walls of winter.[/]"] = 135392177232595,
	["[whisper]A blade, drawn from the dark.[/]"] = 111469843829967,
	["[whisper]Cold little guardians.[/]"] = 98638414153690,
	["[whisper]Cold little voices... wake.[/]"] = 82352831584845,
	["[whisper]Come, little shadows.[/]"] = 81329281478436,
	["[whisper]Do you hear the wires of the sky?[/]"] = 139936809311731,
	["[whisper]Few ever did.[/]"] = 96799896238670,
	["[whisper]Listen...[/] the hall is [pulse]humming[/]."] = 137317334386072,
	["[whisper]Shadows... attend.[/]"] = 97119948224358,
	["[whisper]Snow falls upward here.[/]"] = 85765132607990,
	["[whisper]So tired...[/]"] = 79889573467864,
	["[whisper]Spring... was so far away.[/]"] = 89699520579198,
	["[whisper]The crown is yours.[/] [beat] It was always [hot]heavy[/]."] = 100501135810679,
	["[whisper]The seal... is [wave]thinning[/].[/]"] = 81603732118266,
	["[whisper]The seal... was never [wave]mine[/] to keep.[/]"] = 92639001055498,
}
-- BOSS-VOICE-END

-- Combos: after the boss finishes `After` it may chain straight into `Then` (a short gap, no breather).
SanctuaryConfig.RiftBoss.Combos = {
	{ After = "Fissure", Then = "Cage", Chance = 0.5, MinPhase = 3 },
	{ After = "Volley", Then = "Lances", Chance = 0.4, MinPhase = 1 },
	{ After = "Slam", Then = "TwinSlam", Chance = 0.45, MinPhase = 2 },
	{ After = "Lances", Then = "GravityWell", Chance = 0.4, MinPhase = 2 },
}
HollowChoir.Combos = {
	{ After = "Rings", Then = "EchoSlam", Chance = 0.5, MinPhase = 2 },
	{ After = "Dissonance", Then = "Volley", Chance = 0.45, MinPhase = 1 },
	{ After = "Starburst", Then = "Rings", Chance = 0.5, MinPhase = 2 },
	{ After = "Volley", Then = "Starburst", Chance = 0.35, MinPhase = 2 },
}
CinderRegent.Combos = {
	{ After = "Meteors", Then = "Slam", Chance = 0.5, MinPhase = 2 },
	{ After = "Fissure", Then = "TwinSlam", Chance = 0.5, MinPhase = 2 },
	{ After = "Sweep", Then = "Volley", Chance = 0.4, MinPhase = 1 },
	{ After = "Wall", Then = "Fissure", Chance = 0.4, MinPhase = 2 },
}
StormSeraph.Combos = {
	{ After = "Volley", Then = "Fissure", Chance = 0.5, MinPhase = 1 },
	{ After = "Fissure", Then = "Starburst", Chance = 0.5, MinPhase = 2 },
	{ After = "Lances", Then = "Volley", Chance = 0.4, MinPhase = 1 },
	{ After = "Cage", Then = "Meteors", Chance = 0.5, MinPhase = 3 },
}
Rimeheart.Combos = {
	{ After = "Cage", Then = "Volley", Chance = 0.5, MinPhase = 1 },
	{ After = "Rings", Then = "Dissonance", Chance = 0.45, MinPhase = 2 },
	{ After = "Meteors", Then = "GravityWell", Chance = 0.5, MinPhase = 3 },
	{ After = "Starburst", Then = "Cage", Chance = 0.4, MinPhase = 2 },
}
UmbralKnight.Combos = {
	{ After = "Fissure", Then = "TwinSlam", Chance = 0.55, MinPhase = 1 },
	{ After = "Sweep", Then = "Cage", Chance = 0.5, MinPhase = 2 },
	{ After = "Wall", Then = "Lances", Chance = 0.5, MinPhase = 3 },
	{ After = "Lances", Then = "Meteors", Chance = 0.4, MinPhase = 3 },
	{ After = "Cage", Then = "Starburst", Chance = 0.45, MinPhase = 3 },
}
SanctuaryConfig.RiftBosses = table.freeze({ SanctuaryConfig.RiftBoss, HollowChoir, CinderRegent, StormSeraph, Rimeheart, UmbralKnight })

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
Layout.WORLD_RADIUS = 760
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
	{
		Id = "StormIsle",
		Name = "The Tempest Aerie",
		Center = { X = -160, Y = -4, Z = 575 },
		Radius = 72,
		Top = "Slate",
		Under = "Rock",
		Ore = nil,
		OreSites = 0,
	},
	{
		Id = "RimeIsle",
		Name = "The Frozen Reliquary",
		Center = { X = 160, Y = 0, Z = 575 },
		Radius = 72,
		Top = "Snow",
		Under = "Glacier",
		Ore = nil,
		OreSites = 0,
	},
	{
		Id = "GloamIsle",
		Name = "The Gloaming Keep",
		Center = { X = 0, Y = 10, Z = 660 },
		Radius = 72,
		Top = "Slate",
		Under = "Basalt",
		Ore = nil,
		OreSites = 0,
	},
}
for _, isle in ISLES do	table.freeze(isle.Center)
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
-- Module: ProcAnim   (procedural animation maths)
-- ======================================================================
__defs["ProcAnim"] = function()
-- The numbers behind the bosses' procedural rigs: springs for weight and follow-through,
-- two-bone IK for arms, waves for trailing chains, and a strike curve with anticipation.
-- Plain numbers only (no Roblox types), so the rig code on the client and the Lune tests
-- (scripts/verify_proc_anim.luau) use exactly the same functions.

local ProcAnim = {}

-- A damped spring pulled toward `target`. Substepped so a long frame (or a huge stiffness)
-- never blows up. Returns the new position and velocity.
function ProcAnim.spring(position: number, velocity: number, target: number, stiffness: number, damping: number, dt: number): (number, number)
	-- Semi-implicit Euler is stable while h*sqrt(stiffness) and h*damping stay small, so the step
	-- shrinks for stiff or heavily damped springs (capped so one call stays cheap).
	local limit = math.min(1 / 120, 0.4 / math.sqrt(math.max(stiffness, 1e-6)), 0.8 / math.max(damping, 1e-6))
	local steps = math.clamp(math.ceil(dt / limit), 1, 400)
	local h = dt / steps
	for _ = 1, steps do
		velocity += (stiffness * (target - position) - damping * velocity) * h
		position += velocity * h
	end
	return position, velocity
end

-- Damping that makes a spring of this stiffness critically damped (ratio 1), under (<1, it
-- overshoots and rings) or over damped (>1, it creeps).
function ProcAnim.damping(stiffness: number, ratio: number): number
	return 2 * ratio * math.sqrt(stiffness)
end

-- Two-bone IK: bones of length l1 and l2 reaching a point `distance` away. The reach is
-- clamped to what the bones can span. Returns the angle at the shoulder between the line to
-- the target and the first bone, the interior angle at the elbow, and the reach used.
function ProcAnim.twoBone(l1: number, l2: number, distance: number): (number, number, number)
	local reach = math.clamp(distance, math.abs(l1 - l2) + 1e-3, l1 + l2 - 1e-3)
	local cosShoulder = (l1 * l1 + reach * reach - l2 * l2) / (2 * l1 * reach)
	local cosElbow = (l1 * l1 + l2 * l2 - reach * reach) / (2 * l1 * l2)
	return math.acos(math.clamp(cosShoulder, -1, 1)), math.acos(math.clamp(cosElbow, -1, 1)), reach
end

-- A wave travelling down a chain: segment `index` of `count` lags `lag` radians behind the
-- last, and swings wider toward the tip by `taper` (0 = even).
function ProcAnim.wave(index: number, count: number, t: number, frequency: number, lag: number, amplitude: number, taper: number): number
	local k = (index - 1) / math.max(1, count - 1)
	return amplitude * (1 + taper * k) * math.sin(t * frequency - index * lag)
end

-- A blow over k in [0, 1]: wind back a little, snap through to a touch past the target, then
-- settle on it. 0 at the start, 1 at the end.
function ProcAnim.strike(k: number): number
	k = math.clamp(k, 0, 1)
	if k < 0.25 then
		return -0.22 * math.sin(k / 0.25 * math.pi / 2)
	elseif k < 0.45 then
		local u = (k - 0.25) / 0.2
		return -0.22 + 1.32 * (u * u * (3 - 2 * u))
	elseif k < 0.7 then
		local u = (k - 0.45) / 0.25
		return 1.1 - 0.1 * (u * u * (3 - 2 * u))
	end
	return 1
end

-- Shortest signed difference between two angles, in [-pi, pi].
function ProcAnim.angleDelta(target: number, current: number): number
	local delta = (target - current) % (2 * math.pi)
	if delta > math.pi then
		delta -= 2 * math.pi
	end
	return delta
end

return ProcAnim
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
