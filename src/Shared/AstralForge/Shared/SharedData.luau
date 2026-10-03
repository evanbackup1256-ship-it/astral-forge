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
		Forming = { "[whisper]Four hundred winters... and the lock [wave]finally[/] gives.[/]", "The dark behind the door has [hot]heard you knocking[/]." },
		Awake = { "[slow]I am the Warden.[/] [beat] I was asked to hold one door. [beat] Just [hot]one[/].", "I will not hate you. [beat] Hatred is for those with [wave]time[/].", "Come. [beat] Let us do this [slow]properly[/]." },
		Phase2 = { "You press the lock the way [hot]he[/] did, the last one who came.", "I buried him [beat] under [shake]that[/] floor. [beat] Mind your footing." },
		Phase3 = { "[big]Do you hear it?[/] [beat] The door is [hot]breathing[/].", "I [shake]cannot[/] let it open. [beat] Forgive me what I do [glitch]to prevent it[/]." },
		Defeat = { "[whisper]At last... [beat] the watch is [wave]relieved[/].[/]", "[slow]Tell whoever comes after:[/] [beat] the door was never locked [hot]against us[/]. [beat] It was locked [hot]for us[/].", "[whisper]Don't look back.[/]" },
		Escape = { "[wave]The door is shut again.[/] [beat] I am, [slow]as ever[/], [hot]sorry[/].", "Rest. [beat] You will need it [beat] for the [glitch]next time[/]." },
		Enrage = { "[shake]You are stalling the dark.[/] [beat] Every minute [hot]costs the world[/].", "[glitch]No more courtesy.[/]", "[big]THE OATH DEMANDS IT.[/]" },
		Break = { "[big]Ah![/] [beat] The seal [shake]flinches[/].", "You found the [hot]crack[/]. [beat] Clever.", "[shake]Not yet, not yet--[/]" },
		Hit = { "Stay [hot]down[/].", "That was [slow]not[/] a kindness.", "You bleed [hot]light[/]. [beat] I had forgotten.", "[shake]Do not rise.[/]", "The floor is [wave]patient[/].", "I have done this [slow]a thousand times[/].", "Smaller. [beat] [hot]Smaller[/].", "Fall. [beat] [slow]Again.[/]", "Your oath is [wave]thinner[/] than mine.", "[glitch]Stop making me do this.[/]" },
		Stagger = { "{name}. [beat] [slow]Stay down.[/] [beat] Please.", "I know that sound, {name}. [beat] It is the sound of [hot]trying[/].", "Rise if you must, {name}. [beat] I will [slow]wait[/].", "{name}... [beat] you remind me of [glitch]someone[/].", "[whisper]Easy, {name}. Easy.[/]" },
		Idle = { "[whisper]The door is listening.[/]", "[wave]Every key I buried is humming.[/]", "You hesitate. [beat] Good. [beat] [slow]Hesitation is wisdom.[/]", "[slow]Come.[/] [beat] I am only a [hot]door[/]." },
		Ultimate = {
			VoidCollapse = { "[big]VOID COLLAPSE.[/]", "[slow]Everything folds [beat] toward nothing.[/]" },
			Spearfall = { "[big]SPEARFALL.[/]", "[shake]A hundred lines of dark. [beat] Pick one.[/]" },
			Oblivion = { "[big][shake]OBLIVION.[/][/]", "[glitch]Be [beat] un[beat]made.[/]" },
		},
		Attack = {
			Slam = { "[big]KNEEL.[/]", "The floor [hot]remembers[/] weight.", "[slow]Down.[/]", "Forgive the [shake]noise[/]." },
			TwinSlam = { "Two fall as [hot]one[/].", "[shake]Both of you.[/]", "A door has [hot]two leaves[/]." },
			GravityWell = { "Come [slow]closer[/].", "[wave]Everything falls inward, eventually.[/]", "The rift will [hot]have you[/]." },
			Lances = { "The edge of the seal. [beat] [hot]Cross it[/] and be cut.", "[glitch]Lines of the door.[/]", "Mind the [hot]hinges[/]." },
			Volley = { "The door opens [hot]where you stand[/].", "[shake]Fall through.[/]", "[wave]Rifts, rifts, rifts.[/]", "[slow]Step wherever you like.[/] [beat] It opens there." },
			Summon = { "Rise, [hot]keepers of the door[/].", "Let the dark have [glitch]hands[/].", "[whisper]Come, little shadows.[/]" },
			Fissure = { "The floor remembers the [hot]door[/].", "[big]Split.[/]", "[slow]Follow the crack...[/]" },
			Cage = { "Stay. [beat] The seal will [hot]close round you[/].", "[wave]No way out but through me.[/]", "[slow]A cell is a kindness[/], compared to the door." },
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
	CrowdHealth = 3400,
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
	CrowdHealth = 3400,
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
		Forming = { "[whisper]La... [wave]la[/]... [beat] la--[/]", "A hundred throats [hot]remember the same note[/]." },
		Awake = { "[wave]We were a hundred voices.[/] [beat] The sea took [hot]ninety-nine[/].", "We kept the song. [beat] It is all that [slow]kept us[/].", "Sing with us, little [hot]flame[/]. [beat] Or be [wave]the rest[/]." },
		Phase2 = { "[hot]Oh.[/] [beat] You can hold a [slow]rhythm[/].", "The second verse is [shake]louder[/]. [beat] The second verse [hot]hurts[/]." },
		Phase3 = { "[big]TUTTI.[/] [beat] All of us. [beat] [shake]ALL.[/]", "[glitch]We remember what the water said.[/]" },
		Defeat = { "[whisper]Quiet... [beat] so [wave]quiet[/]...[/]", "[slow]Thank you for the last note.[/] [beat] We never could [hot]finish it[/].", "[wave]Hold it... [beat] hold it... [beat] let go.[/]" },
		Escape = { "[wave]We sink, we sink, we [slow]sing[/] beneath.[/]", "Hum it for us. [beat] [hot]Just once[/]." },
		Enrage = { "[shake]You are OFF THE BEAT.[/]", "[glitch]Tempo. TEMPO. TEMPO.[/]", "[big]FORTISSIMO![/]" },
		Break = { "[big]A wrong note![/]", "[shake]The chord... [beat] fractures![/]", "Who taught you to [hot]strike the rest[/]?" },
		Hit = { "[wave]Flat.[/]", "That was [hot]sharp[/], little flame.", "[slow]Again, from the top.[/]", "Resolve. [beat] [hot]Resolve[/].", "[shake]You are off-key.[/]", "We have heard that [slow]ending[/] before.", "[wave]Diminuendo...[/]", "Fall in [hot]time[/].", "[glitch]Mi. Re. Do. [beat] Down.[/]", "[whisper]Sleep. Sleep. Sleep.[/]" },
		Stagger = { "{name}! [beat] [wave]A grace note![/]", "[slow]Shh, {name}.[/] [beat] The floor is a [hot]cradle[/].", "Oh, {name}. [beat] You [wave]fell[/] so [slow]beautifully[/].", "Stay for the [hot]coda[/], {name}.", "[whisper]{name}, {name}, {name}...[/]" },
		Idle = { "[whisper]Do you hear it? [beat] Under the water?[/]", "[wave]La... la... [beat] la.[/]", "We are [slow]so[/] glad you came.", "[glitch]Ninety-nine. [beat] Ninety-nine. [beat] Ninety-nine.[/]" },
		Ultimate = {
			Crescendo = { "[big]CRESCENDO.[/]", "[wave]Every voice at once -- [beat] [hot]LISTEN[/].[/]" },
			Requiem = { "[slow]This is your [hot]requiem[/].[/]", "[whisper]Hold still for the last note.[/]" },
			Finale = { "[big][shake]FINALE.[/][/]", "[glitch]The song ends when [beat] YOU do.[/]" },
		},
		Attack = {
			Rings = { "[wave]Ripples, ripples, ripples.[/]", "Hold the [hot]note[/]. [beat] Feel it widen.", "[slow]The sea has rings too.[/]" },
			Dissonance = { "[glitch]Wrong.[/] [beat] [hot]Wrong.[/] [beat] [shake]WRONG.[/]", "Where it [hot]clashes[/], stand not.", "[wave]Hear the beating between two notes?[/]" },
			EchoSlam = { "[wave]Echo... [beat] echo... [beat] [hot]echo[/].[/]", "The first blow is only the [slow]announcement[/]." },
			Slam = { "[big]FORTE.[/]", "A [hot]downbeat[/]." },
			Volley = { "[wave]Staccato.[/]", "A [hot]scale[/], falling.", "Quick, quick, [slow]slow[/]." },
			Starburst = { "[big]Radiate.[/]", "[wave]Every voice, a [hot]ray[/].[/]" },
			Summon = { "Join us, [hot]lost ones[/].", "[whisper]Come up, come up.[/]", "[wave]Sing the others awake.[/]" },
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
	CrowdHealth = 3700,
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
		Forming = { "[big]LET THE ASH RISE.[/]", "[slow]A throne is[/] [hot]heating[/] beneath me." },
		Awake = { "[big]BEHOLD THE REGENT[/] of nine burning cities!", "I wore a crown of a thousand hearths. [beat] I wear them still, [hot]as ash[/].", "Kneel, and I may scorch you [slow]gently[/]. [beat] Stand, and I will [shake]make an example[/]." },
		Phase2 = { "[shake]You DARE bleed on my floor?[/]", "Very well. [beat] The [hot]coronation[/] begins." },
		Phase3 = { "[big][shake]I AM THE FIRE THAT FORGETS NOTHING![/][/]", "My court has [hot]fallen[/]. [beat] So the [glitch]hall burns with it[/]." },
		Defeat = { "[slow]Cooled... [beat] by a [hot]peasant[/].[/]", "[whisper]Remember me as... [beat] [wave]warm[/].[/]", "[slow]The throne is yours.[/] [beat] It was never [hot]comfortable[/]." },
		Escape = { "[big]A KING DOES NOT FLEE![/] [beat] [slow]He withdraws.[/]", "Polish your armour. [beat] I [hot]return[/]." },
		Enrage = { "[big][shake]HOW DARE YOU STILL STAND?![/][/]", "[shake]My patience is MOLTEN![/]", "[glitch]BOW. BOW. BOW.[/]" },
		Break = { "[big]IMPOSSIBLE![/] [beat] [shake]My CROWN![/]", "The [hot]royal guard[/] cracks?!", "[shake]Guards! GUARDS![/]" },
		Hit = { "[big]KNEEL![/]", "That is [hot]treason[/].", "I have burned [slow]kingdoms[/] for less.", "[shake]Ash![/] [beat] [hot]All of you, ash![/]", "A [slow]peasant's[/] blade.", "[wave]How quaint.[/]", "You amuse the court.", "[shake]DOWN![/]", "Is that all [hot]your people[/] could send?", "[glitch]Burn. Burn. Burn.[/]" },
		Stagger = { "[big]Kiss the floor, {name}![/]", "A subject on [hot]their knees[/]. [beat] Finally, {name}.", "Stay down, {name}. [beat] It [slow]suits[/] you.", "Ha! [beat] The court [hot]applauds[/], {name}!", "Oh, {name}. [beat] Did the [hot]ground[/] offend you?" },
		Idle = { "[slow]I am [hot]waiting[/], peasant.[/]", "The throne grows [shake]impatient[/].", "[wave]Does no one else dare approach the crown?[/]", "Present your [hot]grievance[/]. [beat] Or your [slow]neck[/]." },
		Ultimate = {
			Eruption = { "[big]ERUPTION.[/]", "[shake]The mountain remembers [hot]fire[/].[/]" },
			Cataclysm = { "[big]CATACLYSM.[/]", "[slow]The ground was only ever a [hot]lid[/].[/]" },
			Ragnarok = { "[big][shake]RAGNAROK.[/][/]", "[glitch]Burn. [beat] Burn. [beat] BURN.[/]" },
		},
		Attack = {
			Sweep = { "[big]THE ROYAL SCYTHE![/]", "[slow]Bow low,[/] and the blade [hot]passes[/].", "A [hot]beam[/] of [shake]judgement[/]!" },
			Volley = { "[shake]Salute![/]", "Fire! [beat] [hot]Fire![/]", "[big]A GUN SALUTE![/]" },
			Slam = { "[big]THE KING'S FIST![/]", "[shake]TREMBLE.[/]" },
			TwinSlam = { "[big]Two hands, one [hot]law[/].[/]", "[shake]BOTH FISTS.[/]" },
			Wall = { "[big]THE WALL OF FLAME![/]", "[slow]Where do you think you are going?[/]" },
			Meteors = { "[big]THE SKY KNEELS TO ME![/]", "Rain, [hot]stars[/]. [beat] [shake]Rain.[/]", "[glitch]Let heaven burn with my enemies.[/]" },
			Summon = { "[big]My GUARDS![/]", "Rise, [hot]ember-legion[/]!", "[slow]Attend your king.[/]" },
			Fissure = { "[big]THE EARTH PARTS FOR ME![/]", "[shake]Split![/]" },
			Cage = { "A [hot]throne room[/], [slow]no exits[/].", "[big]ATTEND THE KING.[/]" },
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
	CrowdHealth = 3400,
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
		Forming = { "[whisper]The air [wave]clears[/]... [beat] to be [hot]read[/].[/]", "A verdict is being [slow]assembled[/]." },
		Awake = { "[slow]I am the Seraph.[/] [beat] The sky keeps a [hot]ledger[/].", "Your name was entered at birth. [beat] The sentence was [hot]not[/] revealed.", "I shall [slow]read it now[/]. [beat] [big]Aloud.[/]" },
		Phase2 = { "[hot]Interesting.[/] [beat] The ledger [shake]shifts[/].", "The [slow]appeal[/] is denied. [beat] [wave]Continue.[/]" },
		Phase3 = { "[big]THE COURT IS NOW IN SESSION.[/]", "[glitch]No more mercy. No more weather. [beat] Only [hot]verdict[/].[/]" },
		Defeat = { "[whisper]The ledger... [beat] [wave]blank[/].[/]", "[slow]I judged you wrongly.[/] [beat] [hot]How novel[/].", "[wave]Let it rain... [beat] [hot]gently[/].[/]" },
		Escape = { "[slow]The court is adjourned.[/] [beat] [hot]Not dismissed[/].", "Await the [shake]next hearing[/]." },
		Enrage = { "[shake]DELAY IS CONTEMPT OF COURT.[/]", "[glitch]THE SENTENCE IS NOT NEGOTIABLE.[/]", "[big]ALL RISE.[/]" },
		Break = { "[big]Objection![/] [beat] [shake]Sustained?![/]", "Procedure... [beat] [hot]violated[/].", "[shake]The gavel breaks![/]" },
		Hit = { "[slow]Guilty.[/]", "The record [hot]notes[/] it.", "[wave]Noted.[/]", "One count.", "[shake]Sustained.[/]", "Your [hot]sentence[/] grows.", "[slow]Overruled.[/]", "The weather has [hot]opinions[/] about you.", "[glitch]Strike that from the record.[/] [beat] [shake]Strike YOU.[/]", "[wave]You will be heard.[/] [beat] [slow]Briefly.[/]" },
		Stagger = { "[slow]The defendant, {name}, is down.[/]", "{name}: [hot]one count[/] of [shake]standing[/].", "Rise, {name}. [beat] [slow]The court has not finished.[/]", "[wave]Entered into evidence, {name}: [beat] [hot]your fall[/].[/]", "{name}, [beat] you are [slow]noted[/]." },
		Idle = { "[slow]The court awaits the accused.[/]", "[wave]Thunder is only a verdict... [beat] [hot]clearing its throat[/].[/]", "[whisper]I have your name here somewhere.[/]", "[slow]Approach the bench.[/]" },
		Ultimate = {
			Judgment = { "[big]JUDGMENT.[/]", "[wave]Stand in the light and be [hot]weighed[/].[/]" },
			Tempest = { "[big]TEMPEST.[/]", "[shake]Every cloud I own -- [beat] at once.[/]" },
			Wrath = { "[big][shake]WRATH.[/][/]", "[glitch]I am the storm that [beat] ENDS storms.[/]" },
		},
		Attack = {
			Volley = { "[hot]Evidence![/] [beat] [shake]Submitted![/]", "[wave]Each bolt, a [slow]witness[/].[/]", "[shake]Strike, strike, strike.[/]" },
			Lances = { "[slow]The [hot]line[/] of the law.[/]", "[big]Cross it.[/] [beat] I [hot]dare[/] you." },
			Fissure = { "[wave]Follow the lightning to its [hot]source[/].[/]", "[slow]A path... [beat] [hot]to judgement[/].[/]", "[shake]Run along the [hot]crack[/].[/]" },
			Starburst = { "[big]THE VERDICT RADIATES.[/]", "[wave]From the centre outward.[/]" },
			Summon = { "Attend, [hot]bailiffs[/].", "[slow]Fetch the accused.[/]", "[whisper]Come, little storms.[/]" },
			Meteors = { "[big]THE HEAVENS SENTENCE YOU.[/]", "Hail. [beat] [hot]Hail[/]. [beat] [shake]HAIL.[/]", "[glitch]Let the sky itself testify.[/]" },
			Cage = { "[slow]You are [hot]remanded[/].[/]", "[wave]The bars are made of [hot]weather[/].[/]" },
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
	CrowdHealth = 3800,
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
		Forming = { "[whisper]Hush... [beat] [wave]hush[/]...[/]", "[slow]Something very old is [hot]turning over[/] in its sleep.[/]" },
		Awake = { "[slow]Little warm thing.[/] [beat] You have [hot]come so far[/].", "I have held the [wave]winter[/] for ten thousand years. [beat] It is [slow]so heavy[/].", "Lie down. [beat] [hot]I will take it from you[/]." },
		Phase2 = { "You are [hot]still warm[/]. [beat] How [slow]strange[/].", "Do not be [wave]afraid[/]. [beat] The cold is only [hot]a kind of quiet[/]." },
		Phase3 = { "[big]SLEEP.[/]", "[whisper]I am not angry.[/] [beat] [slow]I am only [hot]so tired[/] of the [shake]noise[/].[/]" },
		Defeat = { "[whisper]Oh... [beat] [wave]so that is what [hot]warmth[/] is.[/]", "[slow]I would have kept you [hot]safe[/].[/] [beat] [whisper]Forever.[/]", "[wave]Thaw... [beat] [slow]gently.[/][/]" },
		Escape = { "[slow]I will not follow.[/] [beat] [wave]Winter does not need to.[/]", "[whisper]It is already in your [hot]bones[/].[/]" },
		Enrage = { "[shake]STOP MOVING.[/]", "[big]Be STILL.[/]", "[glitch]HUSH. HUSH. HUSH.[/]" },
		Break = { "[shake]Crack...[/] [beat] [slow]so [hot]loud[/].[/]", "[big]You have... [beat] woken it.[/]", "[shake]Cold... [beat] [hot]spilling[/]...[/]" },
		Hit = { "[whisper]Shh.[/]", "[slow]Hold still.[/]", "[wave]It will not hurt for long.[/]", "So [hot]warm[/].", "[slow]Go to sleep.[/]", "You [hot]shiver[/]. [beat] [wave]How sweet.[/]", "[whisper]Easy... [beat] easy...[/]", "[slow]Rest.[/]", "[wave]Snow remembers everyone.[/]", "[glitch]Hush hush hush.[/]" },
		Stagger = { "[whisper]There, {name}. [beat] [slow]Down you go.[/][/]", "[slow]Lie still, {name}. [beat] I have [hot]you[/].[/]", "{name}, little one. [beat] [wave]Close your eyes.[/]", "[whisper]Such a [hot]warm[/] heart, {name}.[/]", "[slow]Do not get up, {name}. [beat] [hot]It is so soft here[/].[/]" },
		Idle = { "[whisper]Snow is falling in a place you cannot see.[/]", "[slow]I can hear your [hot]heartbeat[/].[/] [beat] [wave]It is so loud.[/]", "[whisper]Come closer. [beat] I will not bite.[/] [beat] [glitch]I will not.[/]", "[wave]The cold has a [hot]lullaby[/].[/]" },
		Ultimate = {
			Whiteout = { "[big]WHITEOUT.[/]", "[whisper]No sky. [beat] No ground. [beat] Only [hot]cold[/].[/]" },
			AbsoluteZero = { "[big]ABSOLUTE ZERO.[/]", "[slow]Even motion [beat] stops.[/]" },
			DeepWinter = { "[big][shake]DEEP WINTER.[/][/]", "[slow]Sleep. [beat] I will keep you [hot]forever[/].[/]" },
		},
		Attack = {
			Cage = { "[whisper]There. [beat] [hot]Safe.[/][/]", "[slow]The walls will [hot]hold you[/].[/]", "[wave]A cradle of ice.[/]" },
			Rings = { "[wave]Ripples in the [hot]frozen lake[/].[/]", "[slow]Breathe out. [beat] [hot]Feel it spread.[/][/]" },
			Volley = { "[whisper]Icicles, [hot]falling[/].[/]", "[slow]Each one is a [hot]word[/] I could not say.[/]" },
			Dissonance = { "[wave]Listen to the [hot]ice sing[/].[/]", "[slow]It is not [shake]safe[/] there.[/]" },
			Starburst = { "[whisper]Frost, [hot]blooming[/].[/]", "[wave]Every flower, a little [hot]grave[/].[/]" },
			Summon = { "[whisper]Come, little [hot]snows[/].[/]", "Wake, my [hot]children[/].", "[slow]Gather round the [wave]warm thing[/].[/]" },
			Meteors = { "[big]THE WINTER FALLS.[/]", "[wave]Hail like [hot]tears[/].[/]", "[slow]Everything must come down eventually.[/]" },
			GravityWell = { "[slow]Come to me.[/]", "[whisper]All things drift... [beat] [hot]toward the cold[/].[/]", "[wave]Do not struggle.[/]" },
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
	CrowdHealth = 4000,
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
		Forming = { "[whisper]Steel... [beat] [wave]remembers[/] its hand.[/]", "[slow]A salute, [hot]unseen[/].[/]" },
		Awake = { "[slow]An opponent.[/] [beat] [hot]At last.[/]", "I am sworn to [hot]one last duel[/]. [beat] I would [slow]prefer[/] it be a good one.", "En garde. [beat] [wave]Do try not to disappoint.[/]" },
		Phase2 = { "[hot]Good.[/] [beat] [slow]That was good.[/]", "Let us see whether you can [shake]keep up[/]." },
		Phase3 = { "[big]Now.[/] [beat] [slow]Now I am [hot]serious[/].[/]", "My oath [shake]demands blood[/]. [beat] [glitch]Yours, or mine.[/]" },
		Defeat = { "[slow]Well... [beat] [hot]struck[/].[/]", "[whisper]The duel is [wave]concluded[/].[/] [beat] [slow]I am [hot]released[/].[/]", "[slow]Take the blade.[/] [beat] [hot]It was always meant for a worthier hand.[/]" },
		Escape = { "[slow]The duel is [hot]suspended[/].[/] [beat] I [wave]shall return[/] for [hot]satisfaction[/].", "[slow]Practise.[/]" },
		Enrage = { "[shake]You are being [hot]tedious[/].[/]", "[glitch]STOP BEING A COWARD.[/]", "[big]FINISH ME, OR BE FINISHED.[/]" },
		Break = { "[big]A hit![/] [beat] [slow]Clean.[/]", "[shake]My guard...[/] [beat] [hot]opened[/].", "[slow]I yield... [beat] [hot]a point[/].[/]" },
		Hit = { "[slow]Touché.[/]", "[hot]Careless[/].", "[wave]Too slow.[/]", "One. [beat] [hot]Two.[/]", "Your guard is [shake]open[/].", "[slow]Again.[/]", "A [hot]fine[/] try.", "[wave]Predictable.[/]", "You [slow]fence like a [hot]butcher[/].[/]", "[glitch]Sloppy.[/]" },
		Stagger = { "[slow]Up, {name}.[/] [beat] A duel is [hot]not[/] a [shake]nap[/].", "[wave]Down, {name}?[/] [beat] How [hot]unsporting[/] of the floor.", "[slow]Take your time, {name}.[/] [beat] [hot]I will not strike a fallen man.[/] [beat] [shake]Yet.[/]", "{name}. [beat] [hot]Respect[/] the [slow]blade[/].", "That was [hot]almost[/] good, {name}." },
		Idle = { "[slow]I am [hot]ready[/] when you are.[/]", "[wave]Do you know how long I have waited for a worthy [hot]opponent[/]?[/]", "[whisper]The oath weighs on me. [beat] [slow]Lend me your steel.[/][/]", "Come. [beat] [hot]Do not be shy.[/]" },
		Ultimate = {
			Duel = { "[big]EN GARDE.[/]", "[wave]Dance well. [beat] It is your last.[/]" },
			LastCut = { "[big]THE LAST CUT.[/]", "[slow]I only ever need [hot]one[/].[/]" },
			Execution = { "[big][shake]EXECUTION.[/][/]", "[glitch]The sentence is [beat] passed.[/]" },
		},
		Attack = {
			Fissure = { "[slow]A [hot]line[/] of [shake]steel[/].[/]", "[wave]Follow it.[/]", "[big]Riposte.[/]" },
			TwinSlam = { "[slow]Two [hot]cuts[/].[/]", "[big]Double strike.[/]" },
			Sweep = { "[big]A sweeping cut![/]", "[slow]Duck.[/] [beat] [hot]Or do not.[/]" },
			Summon = { "[slow]Seconds![/] [beat] [hot]To me.[/]", "[wave]Gentlemen... [beat] [hot]join the duel.[/][/]", "[slow]Fair is fair: [hot]a few more blades[/].[/]" },
			Cage = { "[slow]Within the [hot]ring[/].[/]", "[wave]A duel needs a proper [hot]ring[/].[/]", "[big]The circle closes.[/]" },
			Wall = { "[slow]A [hot]barrier[/] of [shake]blades[/].[/]", "[big]PARRY THIS.[/]" },
			Starburst = { "[big]A thousand cuts.[/]", "[slow]Every direction is [hot]a thrust[/].[/]" },
			Lances = { "[slow]The [hot]thrust[/].[/]", "[wave]A line... [beat] [hot]drawn[/].[/]" },
			Meteors = { "[big]THE BLADES OF THE FALLEN![/]", "[slow]Swords rain[/] on [hot]the unworthy[/].", "[glitch]Look up.[/]" },
		},
	},
})
-- Boss effect sounds by name (cast_<Element>, hit_<Element>, wisp_*, impact) -> uploaded audio id.
-- BOSS-SFX-BEGIN (rewritten by tools/assetgen/upload_boss_sfx.py)
SanctuaryConfig.BossSfx = {
	["boom_Choir"] = 121783253529764,
	["boom_Knight"] = 114051540535398,
	["boom_Regent"] = 118488607818523,
	["boom_Rime"] = 135269604054166,
	["boom_Seraph"] = 137063823498914,
	["boom_Warden"] = 120376657917041,
	["cast_Fire"] = 133922670576399,
	["cast_Frost"] = 72187971131986,
	["cast_Storm"] = 92138127701089,
	["cast_Void"] = 106692366896440,
	["charge_Choir"] = 74209989827837,
	["charge_Knight"] = 126591884216749,
	["charge_Regent"] = 135026014097678,
	["charge_Rime"] = 76730337330543,
	["charge_Seraph"] = 121722729622622,
	["charge_Warden"] = 97049983205219,
	["death_Choir"] = 140614894530556,
	["death_Knight"] = 128773631016939,
	["death_Regent"] = 97559340390980,
	["death_Rime"] = 93769858227275,
	["death_Seraph"] = 129476429582513,
	["death_Warden"] = 115201650738474,
	["hit_Fire"] = 88917316640445,
	["hit_Frost"] = 123582349928047,
	["hit_Storm"] = 116862191440594,
	["hit_Void"] = 116315495398978,
	["impact"] = 88257269102737,
	["roar_Choir"] = 112477213188430,
	["roar_Knight"] = 78411532764396,
	["roar_Regent"] = 71888323612526,
	["roar_Rime"] = 72438654390546,
	["roar_Seraph"] = 83421337144991,
	["roar_Warden"] = 83056913167769,
	["wisp_blast"] = 140620443596331,
	["wisp_down"] = 80813482090323,
	["wisp_spawn"] = 76279580661681,
}
-- BOSS-SFX-END

-- Which body each boss wears: the generated textured models (default) or the procedural Blender bodies.
-- Set to "blender" for every boss, or { Knight = "blender", ... } for some.
SanctuaryConfig.BossBodyStyle = "blender"

-- Boss bodies built, rigged, textured and animated in Blender (tools/bossbuild): skeleton, piece placement and clips.
-- BOSS-BODIES-BEGIN (moved to BossBodies.luau; see tools/bossbuild/export_bodies.py)
SanctuaryConfig.BossBodies = false
-- BOSS-BODIES-END

-- The uploaded body models, one per boss: kind -> model id.
-- BOSS-BODYKIT-BEGIN (rewritten by tools/bossbuild/upload_bodies.py)
SanctuaryConfig.BossBodyKit = {
	Astraeon = 122761215688798,
	Choir = 120624360620684,
	Knight = 115948050977375,
	Regent = 136824896638647,
	Rime = 100339874565327,
	Seraph = 140728471169346,
	Warden = 119016810651714,
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
	["A [hot]beam[/] of [shake]judgement[/]!"] = { d = 2.38, w = { 0.00, 0.06, 0.31, 0.43 } },
	["A [hot]downbeat[/]."] = { d = 4.14, w = { 0.00, 0.11 } },
	["A [hot]fine[/] try."] = { d = 2.03, w = { 0.00, 0.10, 0.50 } },
	["A [hot]scale[/], falling."] = { d = 4.64, w = { 0.00, 0.13, 1.05 } },
	["A [hot]throne room[/], [slow]no exits[/]."] = { d = 3.38, w = { 0.00, 0.07, 0.47, 0.94, 1.21 } },
	["A [slow]peasant's[/] blade."] = { d = 2.98, w = { 0.00, 0.10, 1.02 } },
	["A door has [hot]two leaves[/]."] = { d = 3.47, w = { 0.00, 0.07, 0.34, 0.55, 0.75 } },
	["A hundred throats [hot]remember the same note[/]."] = { d = 5.65, w = { 0.00, 0.07, 0.60, 1.12, 1.72, 1.94, 2.24 } },
	["A verdict is being [slow]assembled[/]."] = { d = 3.22, w = { 0.00, 0.07, 0.54, 0.67, 1.01 } },
	["Attend, [hot]bailiffs[/]."] = { d = 3.10, w = { 0.00, 0.90 } },
	["Await the [shake]next hearing[/]."] = { d = 2.57, w = { 0.00, 0.26, 0.41, 0.62 } },
	["Come [slow]closer[/]."] = { d = 3.06, w = { 0.00, 0.30 } },
	["Come. [beat] Let us do this [slow]properly[/]."] = { d = 4.69, w = { 0.00, 1.08, 1.28, 1.42, 1.56, 1.83 } },
	["Come. [beat] [hot]Do not be shy.[/]"] = { d = 3.21, w = { 0.00, 1.08, 1.26, 1.53, 1.71 } },
	["Do not be [wave]afraid[/]. [beat] The cold is only [hot]a kind of quiet[/]."] = { d = 7.65, w = { 0.00, 0.15, 0.37, 0.52, 1.77, 2.03, 2.38, 2.55, 2.89, 2.98, 3.32, 3.50 } },
	["En garde. [beat] [wave]Do try not to disappoint.[/]"] = { d = 4.30, w = { 0.00, 0.17, 1.42, 1.58, 1.83, 2.08, 2.25 } },
	["Fall in [hot]time[/]."] = { d = 4.29, w = { 0.00, 0.46, 0.68 } },
	["Fall. [beat] [slow]Again.[/]"] = { d = 3.71, w = { 0.00, 1.08 } },
	["Fire! [beat] [hot]Fire![/]"] = { d = 3.38, w = { 0.00, 1.40 } },
	["Forgive the [shake]noise[/]."] = { d = 3.06, w = { 0.00, 0.36, 0.52 } },
	["Hail. [beat] [hot]Hail[/]. [beat] [shake]HAIL.[/]"] = { d = 4.52, w = { 0.00, 1.22, 2.47 } },
	["Hold the [hot]note[/]. [beat] Feel it widen."] = { d = 5.93, w = { 0.00, 0.31, 0.54, 1.67, 2.08, 2.28 } },
	["Hum it for us. [beat] [hot]Just once[/]."] = { d = 5.87, w = { 0.00, 0.28, 0.46, 0.74, 1.76, 2.23 } },
	["I [shake]cannot[/] let it open. [beat] Forgive me what I do [glitch]to prevent it[/]."] = { d = 5.30, w = { 0.00, 0.05, 0.37, 0.53, 0.63, 1.63, 1.99, 2.09, 2.30, 2.35, 2.45, 2.55, 2.91 } },
	["I am sworn to [hot]one last duel[/]. [beat] I would [slow]prefer[/] it be a good one."] = { d = 6.51, w = { 0.00, 0.08, 0.23, 0.61, 0.76, 0.99, 1.29, 2.41, 2.53, 3.12, 3.83, 4.07, 4.30, 4.42, 4.89 } },
	["I buried him [beat] under [shake]that[/] floor. [beat] Mind your footing."] = { d = 5.64, w = { 0.00, 0.07, 0.50, 1.14, 1.45, 1.69, 2.80, 2.95, 3.10 } },
	["I have [hot]watched empires[/] smaller than you."] = { d = 3.74, w = { 0.00, 0.06, 0.31, 0.74, 1.17, 1.61, 1.85 } },
	["I have burned [slow]kingdoms[/] for less."] = { d = 3.65, w = { 0.00, 0.09, 0.43, 0.94, 1.62, 1.88 } },
	["I have done this [slow]a thousand times[/]."] = { d = 4.27, w = { 0.00, 0.07, 0.36, 0.65, 0.94, 1.01, 1.59 } },
	["I have held the [wave]winter[/] for ten thousand years. [beat] It is [slow]so heavy[/]."] = { d = 7.92, w = { 0.00, 0.07, 0.33, 0.59, 0.79, 1.18, 1.38, 1.58, 2.10, 3.24, 3.41, 3.58, 3.76 } },
	["I shall [slow]read it now[/]. [beat] [big]Aloud.[/]"] = { d = 4.30, w = { 0.00, 0.08, 0.49, 0.82, 0.98, 2.05 } },
	["I was the light that taught your sky to [hot]shine[/]. [beat] Now I am only its [shake]ending[/]."] = { d = 7.49, w = { 0.00, 0.06, 0.24, 0.43, 0.73, 0.98, 1.35, 1.59, 1.77, 1.90, 3.00, 3.43, 3.57, 3.86, 4.42, 4.85 } },
	["I will not hate you. [beat] Hatred is for those with [wave]time[/]."] = { d = 5.38, w = { 0.00, 0.06, 0.30, 0.48, 0.72, 1.70, 2.05, 2.16, 2.34, 2.62, 2.85 } },
	["I wore a crown of a thousand hearths. [beat] I wear them still, [hot]as ash[/]."] = { d = 5.87, w = { 0.00, 0.06, 0.31, 0.37, 0.68, 0.81, 0.87, 1.36, 2.60, 2.67, 2.94, 3.21, 3.76, 4.01 } },
	["Is that all [hot]your people[/] could send?"] = { d = 2.89, w = { 0.00, 0.11, 0.32, 0.48, 0.69, 1.00, 1.27 } },
	["Join us, [hot]lost ones[/]."] = { d = 5.09, w = { 0.00, 0.42, 0.87, 1.39 } },
	["Kneel, and I may scorch you [slow]gently[/]. [beat] Stand, and I will [shake]make an example[/]."] = { d = 6.90, w = { 0.00, 0.92, 1.17, 1.25, 1.50, 2.00, 2.25, 3.57, 4.25, 4.43, 4.49, 4.73, 4.96, 5.08 } },
	["Let the dark have [glitch]hands[/]."] = { d = 3.41, w = { 0.00, 0.18, 0.35, 0.59, 0.82 } },
	["Let us see whether you can [shake]keep up[/]."] = { d = 2.61, w = { 0.00, 0.16, 0.26, 0.42, 0.79, 0.95, 1.11, 1.32 } },
	["Lie down. [beat] [hot]I will take it from you[/]."] = { d = 6.11, w = { 0.00, 0.26, 1.44, 1.49, 1.71, 1.93, 2.04, 2.25 } },
	["Mind the [hot]hinges[/]."] = { d = 3.17, w = { 0.00, 0.26, 0.46 } },
	["My court has [hot]fallen[/]. [beat] So the [glitch]hall burns with it[/]."] = { d = 4.56, w = { 0.00, 0.13, 0.45, 0.64, 1.82, 1.96, 2.15, 2.42, 2.75, 3.02 } },
	["My oath [shake]demands blood[/]. [beat] [glitch]Yours, or mine.[/]"] = { d = 4.69, w = { 0.00, 0.14, 0.41, 0.89, 2.04, 2.79, 3.01 } },
	["One count."] = { d = 2.21, w = { 0.00, 0.22 } },
	["One. [beat] [hot]Two.[/]"] = { d = 2.63, w = { 0.00, 1.18 } },
	["Polish your armour. [beat] I [hot]return[/]."] = { d = 4.08, w = { 0.00, 0.39, 0.65, 1.84, 1.95 } },
	["Present your [hot]grievance[/]. [beat] Or your [slow]neck[/]."] = { d = 4.55, w = { 0.00, 0.40, 0.63, 1.94, 2.17, 2.63 } },
	["Procedure... [beat] [hot]violated[/]."] = { d = 3.82, w = { 0.00, 1.48 } },
	["Quick, quick, [slow]slow[/]."] = { d = 5.41, w = { 0.00, 0.63, 1.31 } },
	["Rain, [hot]stars[/]. [beat] [shake]Rain.[/]"] = { d = 4.04, w = { 0.00, 0.78, 2.15 } },
	["Resolve. [beat] [hot]Resolve[/]."] = { d = 5.34, w = { 0.00, 1.62 } },
	["Rest. [beat] You will need it [beat] for the [glitch]next time[/]."] = { d = 5.53, w = { 0.00, 1.22, 1.40, 1.63, 1.86, 2.40, 2.58, 2.75, 2.99 } },
	["Rise, [hot]ember-legion[/]!"] = { d = 3.16, w = { 0.00, 1.01 } },
	["Rise, [hot]keepers of the door[/]."] = { d = 3.80, w = { 0.00, 0.79, 1.11, 1.20, 1.33 } },
	["Sing with us, little [hot]flame[/]. [beat] Or be [wave]the rest[/]."] = { d = 7.37, w = { 0.00, 0.42, 0.84, 1.30, 1.79, 3.02, 3.23, 3.45, 3.78 } },
	["Smaller. [beat] [hot]Smaller[/]."] = { d = 4.13, w = { 0.00, 1.32 } },
	["So [hot]warm[/]."] = { d = 4.30, w = { 0.00, 0.19 } },
	["Stay [hot]down[/]."] = { d = 2.94, w = { 0.00, 0.31 } },
	["Stay. [beat] The seal will [hot]close round you[/]."] = { d = 4.49, w = { 0.00, 1.02, 1.17, 1.36, 1.56, 1.81, 2.05 } },
	["That is [hot]treason[/]."] = { d = 2.47, w = { 0.00, 0.32, 0.48 } },
	["That was [hot]sharp[/], little flame."] = { d = 4.99, w = { 0.00, 0.28, 0.48, 1.03, 1.49 } },
	["That was [slow]not[/] a kindness."] = { d = 3.60, w = { 0.00, 0.27, 0.47, 0.68, 0.75 } },
	["The [hot]royal guard[/] cracks?!"] = { d = 2.73, w = { 0.00, 0.20, 0.53, 0.86 } },
	["The [slow]appeal[/] is denied. [beat] [wave]Continue.[/]"] = { d = 4.60, w = { 0.00, 0.28, 0.84, 1.02, 2.41 } },
	["The dark behind the door has [hot]heard you knocking[/]."] = { d = 4.27, w = { 0.00, 0.15, 0.36, 0.66, 0.81, 1.02, 1.17, 1.42, 1.57 } },
	["The door opens [hot]where you stand[/]."] = { d = 3.67, w = { 0.00, 0.17, 0.38, 0.66, 0.93, 1.10 } },
	["The edge of the seal. [beat] [hot]Cross it[/] and be cut."] = { d = 4.86, w = { 0.00, 0.18, 0.42, 0.54, 0.71, 1.75, 2.02, 2.13, 2.30, 2.41 } },
	["The first blow is only the [slow]announcement[/]."] = { d = 6.12, w = { 0.00, 0.27, 0.72, 1.09, 1.27, 1.63, 1.90 } },
	["The floor [hot]remembers[/] weight."] = { d = 3.29, w = { 0.00, 0.13, 0.35, 0.74 } },
	["The floor is [wave]patient[/]."] = { d = 3.30, w = { 0.00, 0.18, 0.47, 0.59 } },
	["The floor remembers the [hot]door[/]."] = { d = 3.48, w = { 0.00, 0.15, 0.40, 0.84, 0.99 } },
	["The record [hot]notes[/] it."] = { d = 2.81, w = { 0.00, 0.22, 0.67, 1.05 } },
	["The rift will [hot]have you[/]."] = { d = 3.02, w = { 0.00, 0.12, 0.29, 0.45, 0.61 } },
	["The second verse is [shake]louder[/]. [beat] The second verse [hot]hurts[/]."] = { d = 6.94, w = { 0.00, 0.21, 0.64, 1.00, 1.14, 2.38, 2.60, 3.06, 3.44 } },
	["The throne grows [shake]impatient[/]."] = { d = 2.94, w = { 0.00, 0.20, 0.60, 0.93 } },
	["The weather has [hot]opinions[/] about you."] = { d = 3.02, w = { 0.00, 0.15, 0.49, 0.64, 1.04, 1.29 } },
	["Then let me show you [slow]what light does[/] when it is [shake]angry[/]."] = { d = 4.89, w = { 0.00, 0.30, 0.53, 0.68, 0.98, 1.21, 1.51, 1.89, 2.19, 2.50, 2.65, 2.80 } },
	["Two fall as [hot]one[/]."] = { d = 2.94, w = { 0.00, 0.16, 0.38, 0.48 } },
	["Very well. [beat] The [hot]coronation[/] begins."] = { d = 4.28, w = { 0.00, 0.39, 1.61, 1.81, 2.47 } },
	["Wake, my [hot]children[/]."] = { d = 4.95, w = { 0.00, 0.67, 0.79 } },
	["We are [slow]so[/] glad you came."] = { d = 5.48, w = { 0.00, 0.26, 0.64, 0.90, 1.41, 1.80 } },
	["We have heard that [slow]ending[/] before."] = { d = 5.24, w = { 0.00, 0.16, 0.47, 0.86, 1.18, 1.65 } },
	["We kept the song. [beat] It is all that [slow]kept us[/]."] = { d = 7.04, w = { 0.00, 0.17, 0.50, 0.75, 1.90, 2.13, 2.37, 2.72, 3.19, 3.65 } },
	["Where it [hot]clashes[/], stand not."] = { d = 5.42, w = { 0.00, 0.45, 0.62, 1.48, 1.98 } },
	["Who taught you to [hot]strike the rest[/]?"] = { d = 4.95, w = { 0.00, 0.20, 0.61, 0.81, 0.95, 1.35, 1.55 } },
	["You [hot]shiver[/]. [beat] [wave]How sweet.[/]"] = { d = 5.89, w = { 0.00, 0.17, 1.32, 1.63 } },
	["You [slow]fence like a [hot]butcher[/].[/]"] = { d = 2.75, w = { 0.00, 0.23, 0.61, 0.92, 1.00 } },
	["You amuse the court."] = { d = 3.14, w = { 0.00, 0.32, 0.85, 1.16 } },
	["You are [hot]still warm[/]. [beat] How [slow]strange[/]."] = { d = 6.33, w = { 0.00, 0.17, 0.33, 0.61, 1.63, 1.92 } },
	["You are brighter than I [hot]expected[/]."] = { d = 3.31, w = { 0.00, 0.18, 0.36, 0.84, 1.07, 1.13 } },
	["You bleed [hot]light[/]. [beat] I had forgotten."] = { d = 4.52, w = { 0.00, 0.17, 0.45, 1.53, 1.58, 1.74 } },
	["You found the [hot]crack[/]. [beat] Clever."] = { d = 4.40, w = { 0.00, 0.16, 0.43, 0.59, 1.65 } },
	["You hesitate. [beat] Good. [beat] [slow]Hesitation is wisdom.[/]"] = { d = 6.09, w = { 0.00, 0.19, 1.50, 2.62, 3.27, 3.40 } },
	["You press the lock the way [hot]he[/] did, the last one who came."] = { d = 4.96, w = { 0.00, 0.16, 0.43, 0.59, 0.81, 0.97, 1.13, 1.24, 1.59, 1.78, 2.03, 2.22, 2.41 } },
	["Your [hot]sentence[/] grows."] = { d = 3.07, w = { 0.00, 0.34, 1.02 } },
	["Your guard is [shake]open[/]."] = { d = 2.28, w = { 0.00, 0.28, 0.64, 0.78 } },
	["Your name was entered at birth. [beat] The sentence was [hot]not[/] revealed."] = { d = 5.03, w = { 0.00, 0.19, 0.39, 0.53, 0.87, 0.96, 1.99, 2.17, 2.63, 2.80, 2.97 } },
	["Your oath is [wave]thinner[/] than mine."] = { d = 3.55, w = { 0.00, 0.20, 0.40, 0.51, 0.86, 1.06 } },
	["[big]A GUN SALUTE![/]"] = { d = 2.21, w = { 0.00, 0.08, 0.32 } },
	["[big]A KING DOES NOT FLEE![/] [beat] [slow]He withdraws.[/]"] = { d = 4.52, w = { 0.00, 0.06, 0.31, 0.56, 0.74, 1.79, 2.03 } },
	["[big]A hit![/] [beat] [slow]Clean.[/]"] = { d = 2.87, w = { 0.00, 0.11, 1.27 } },
	["[big]A sweeping cut![/]"] = { d = 2.17, w = { 0.00, 0.08, 0.71 } },
	["[big]A thousand cuts.[/]"] = { d = 2.63, w = { 0.00, 0.11, 0.96 } },
	["[big]A wrong note![/]"] = { d = 3.88, w = { 0.00, 0.08, 0.46 } },
	["[big]ABSOLUTE ZERO.[/]"] = { d = 4.79, w = { 0.00, 0.71 } },
	["[big]ALL RISE.[/]"] = { d = 2.33, w = { 0.00, 0.29 } },
	["[big]ANNIHILATION.[/]"] = { d = 2.35, w = { 0.00 } },
	["[big]ATTEND THE KING.[/]"] = { d = 2.49, w = { 0.00, 0.49, 0.74 } },
	["[big]Ah![/] [beat] The seal [shake]flinches[/]."] = { d = 4.29, w = { 0.00, 1.14, 1.31, 1.54 } },
	["[big]BEHOLD THE REGENT[/] of nine burning cities!"] = { d = 3.83, w = { 0.00, 0.43, 0.64, 1.06, 1.21, 1.49, 1.99 } },
	["[big]Be STILL.[/]"] = { d = 4.28, w = { 0.00, 0.16 } },
	["[big]CATACLYSM.[/]"] = { d = 2.07, w = { 0.00 } },
	["[big]CRESCENDO.[/]"] = { d = 3.89, w = { 0.00 } },
	["[big]Come, small fires.[/] [beat] [slow]Burn with me.[/]"] = { d = 5.01, w = { 0.00, 0.52, 1.06, 2.44, 2.78, 3.12 } },
	["[big]Cross it.[/] [beat] I [hot]dare[/] you."] = { d = 3.61, w = { 0.00, 0.38, 1.35, 1.43, 1.75 } },
	["[big]Do you hear it?[/] [beat] The door is [hot]breathing[/]."] = { d = 4.39, w = { 0.00, 0.08, 0.21, 0.37, 1.26, 1.40, 1.59, 1.68 } },
	["[big]Double strike.[/]"] = { d = 1.75, w = { 0.00, 0.28 } },
	["[big]EN GARDE.[/]"] = { d = 1.90, w = { 0.00, 0.19 } },
	["[big]ERUPTION.[/]"] = { d = 1.99, w = { 0.00 } },
	["[big]EVENT HORIZON.[/]"] = { d = 2.53, w = { 0.00, 0.34 } },
	["[big]FALL.[/]"] = { d = 2.07, w = { 0.00 } },
	["[big]FINISH ME, OR BE FINISHED.[/]"] = { d = 2.65, w = { 0.00, 0.36, 0.67, 0.80, 0.93 } },
	["[big]FORTE.[/]"] = { d = 3.65, w = { 0.00 } },
	["[big]FORTISSIMO![/]"] = { d = 3.90, w = { 0.00 } },
	["[big]I CANNOT. STOP. SHINING.[/]"] = { d = 3.74, w = { 0.00, 0.07, 0.89, 1.55 } },
	["[big]IMPOSSIBLE![/] [beat] [shake]My CROWN![/]"] = { d = 3.72, w = { 0.00, 1.65, 1.83 } },
	["[big]JUDGMENT.[/]"] = { d = 2.05, w = { 0.00 } },
	["[big]KNEEL![/]"] = { d = 1.79, w = { 0.00 } },
	["[big]KNEEL.[/]"] = { d = 2.65, w = { 0.00 } },
	["[big]LET THE ASH RISE.[/]"] = { d = 2.81, w = { 0.00, 0.32, 0.63, 0.95 } },
	["[big]My GUARDS![/]"] = { d = 2.35, w = { 0.00, 0.23 } },
	["[big]My core![/] [beat] [shake]Cracks![/]"] = { d = 3.79, w = { 0.00, 0.26, 1.66 } },
	["[big]Now.[/] [beat] [slow]Now I am [hot]serious[/].[/]"] = { d = 4.04, w = { 0.00, 1.27, 1.62, 1.74, 1.97 } },
	["[big]Objection![/] [beat] [shake]Sustained?![/]"] = { d = 3.81, w = { 0.00, 1.56 } },
	["[big]PARRY THIS.[/]"] = { d = 1.94, w = { 0.00, 0.40 } },
	["[big]RADIATE.[/]"] = { d = 2.40, w = { 0.00 } },
	["[big]Radiate.[/]"] = { d = 3.98, w = { 0.00 } },
	["[big]Riposte.[/]"] = { d = 1.72, w = { 0.00 } },
	["[big]SLEEP.[/]"] = { d = 4.13, w = { 0.00 } },
	["[big]SPEARFALL.[/]"] = { d = 2.98, w = { 0.00 } },
	["[big]STARFALL.[/] [beat] [slow]Run.[/]"] = { d = 3.79, w = { 0.00, 1.40 } },
	["[big]SUPERNOVA.[/]"] = { d = 2.29, w = { 0.00 } },
	["[big]Shine![/] [beat] [slow]For as long as you can.[/]"] = { d = 4.41, w = { 0.00, 1.26, 1.51, 1.68, 2.02, 2.19, 2.44 } },
	["[big]Split.[/]"] = { d = 2.81, w = { 0.00 } },
	["[big]Stand [shake]aside[/].[/]"] = { d = 2.38, w = { 0.00, 0.34 } },
	["[big]TEMPEST.[/]"] = { d = 2.17, w = { 0.00 } },
	["[big]THE BLADES OF THE FALLEN![/]"] = { d = 2.39, w = { 0.00, 0.18, 0.54, 0.66, 0.84 } },
	["[big]THE COURT IS NOW IN SESSION.[/]"] = { d = 3.06, w = { 0.00, 0.20, 0.53, 0.66, 0.86, 0.99 } },
	["[big]THE EARTH PARTS FOR ME![/]"] = { d = 2.71, w = { 0.00, 0.22, 0.58, 0.94, 1.15 } },
	["[big]THE HEAVENS SENTENCE YOU.[/]"] = { d = 2.88, w = { 0.00, 0.18, 0.61, 1.10 } },
	["[big]THE KING'S FIST![/]"] = { d = 2.33, w = { 0.00, 0.21, 0.63 } },
	["[big]THE LAST CUT.[/]"] = { d = 1.92, w = { 0.00, 0.21, 0.49 } },
	["[big]THE OATH DEMANDS IT.[/]"] = { d = 3.16, w = { 0.00, 0.16, 0.38, 0.76 } },
	["[big]THE ROYAL SCYTHE![/]"] = { d = 2.69, w = { 0.00, 0.27, 0.72 } },
	["[big]THE SKY FALLS![/]"] = { d = 2.52, w = { 0.00, 0.22, 0.44 } },
	["[big]THE SKY FALLS[/] [beat] when I do."] = { d = 3.94, w = { 0.00, 0.33, 0.65, 1.62, 1.96, 2.04 } },
	["[big]THE SKY KNEELS TO ME![/]"] = { d = 2.54, w = { 0.00, 0.21, 0.42, 0.84, 0.98 } },
	["[big]THE VERDICT RADIATES.[/]"] = { d = 2.79, w = { 0.00, 0.20, 0.66 } },
	["[big]THE WALL OF FLAME![/]"] = { d = 2.43, w = { 0.00, 0.22, 0.51, 0.65 } },
	["[big]THE WINTER FALLS.[/]"] = { d = 4.78, w = { 0.00, 0.23, 0.68 } },
	["[big]TUTTI.[/] [beat] All of us. [beat] [shake]ALL.[/]"] = { d = 6.53, w = { 0.00, 1.27, 1.63, 1.86, 2.95 } },
	["[big]The circle closes.[/]"] = { d = 2.28, w = { 0.00, 0.21, 0.64 } },
	["[big]The ground... [beat] [hot]opens[/].[/]"] = { d = 3.70, w = { 0.00, 0.15, 1.34 } },
	["[big]Two hands, one [hot]law[/].[/]"] = { d = 3.29, w = { 0.00, 0.31, 1.06, 1.44 } },
	["[big]VOID COLLAPSE.[/]"] = { d = 3.10, w = { 0.00, 0.26 } },
	["[big]WHITEOUT.[/]"] = { d = 4.35, w = { 0.00 } },
	["[big]You have... [beat] woken it.[/]"] = { d = 5.47, w = { 0.00, 0.17, 1.29, 1.63 } },
	["[big][shake]DEEP WINTER.[/][/]"] = { d = 4.28, w = { 0.00, 0.23 } },
	["[big][shake]EXECUTION.[/][/]"] = { d = 1.93, w = { 0.00 } },
	["[big][shake]FINALE.[/][/]"] = { d = 3.64, w = { 0.00 } },
	["[big][shake]HOW DARE YOU STILL STAND?![/][/]"] = { d = 2.71, w = { 0.00, 0.19, 0.44, 0.62, 0.94 } },
	["[big][shake]I AM THE FIRE THAT FORGETS NOTHING![/][/]"] = { d = 3.07, w = { 0.00, 0.06, 0.18, 0.36, 0.60, 0.83, 1.25 } },
	["[big][shake]LAST LIGHT.[/][/]"] = { d = 2.35, w = { 0.00, 0.28 } },
	["[big][shake]OBLIVION.[/][/]"] = { d = 2.89, w = { 0.00 } },
	["[big][shake]RAGNAROK.[/][/]"] = { d = 2.07, w = { 0.00 } },
	["[big][shake]WRATH.[/][/]"] = { d = 2.04, w = { 0.00 } },
	["[glitch]BOW. BOW. BOW.[/]"] = { d = 3.40, w = { 0.00, 0.81, 1.59 } },
	["[glitch]Be [beat] un[beat]made.[/]"] = { d = 3.60, w = { 0.00, 0.81 } },
	["[glitch]Burn. Burn. Burn.[/]"] = { d = 3.46, w = { 0.00, 0.82, 1.49 } },
	["[glitch]Burn. [beat] Burn. [beat] BURN.[/]"] = { d = 4.25, w = { 0.00, 1.13, 2.48 } },
	["[glitch]EVERYTHING I TOUCH BURNS.[/]"] = { d = 3.09, w = { 0.00, 0.66, 0.73, 1.05 } },
	["[glitch]Every star I ever lit -- I take them BACK.[/]"] = { d = 3.86, w = { 0.00, 0.34, 0.60, 0.67, 0.94, 1.14, 1.28, 1.34, 1.61, 1.88 } },
	["[glitch]Fall. [beat] Fall. [beat] Fall.[/]"] = { d = 4.51, w = { 0.00, 1.25, 2.47 } },
	["[glitch]HUSH. HUSH. HUSH.[/]"] = { d = 5.68, w = { 0.00, 0.75, 1.57 } },
	["[glitch]Hush hush hush.[/]"] = { d = 4.65, w = { 0.00, 0.31, 0.62 } },
	["[glitch]I am the storm that [beat] ENDS storms.[/]"] = { d = 3.89, w = { 0.00, 0.07, 0.20, 0.39, 0.72, 1.41, 1.75 } },
	["[glitch]If I end -- [beat] so does EVERYTHING.[/]"] = { d = 3.89, w = { 0.00, 0.15, 0.23, 0.45, 1.12, 1.26, 1.52 } },
	["[glitch]Let heaven burn with my enemies.[/]"] = { d = 3.15, w = { 0.00, 0.20, 0.60, 0.87, 1.14, 1.27 } },
	["[glitch]Let the sky itself testify.[/]"] = { d = 3.25, w = { 0.00, 0.22, 0.45, 0.67, 1.11 } },
	["[glitch]Lines of the door.[/]"] = { d = 3.13, w = { 0.00, 0.30, 0.42, 0.60 } },
	["[glitch]Look up.[/]"] = { d = 1.66, w = { 0.00, 0.30 } },
	["[glitch]Mi. Re. Do. [beat] Down.[/]"] = { d = 6.85, w = { 0.00, 1.12, 1.96, 3.20 } },
	["[glitch]Ninety-nine. [beat] Ninety-nine. [beat] Ninety-nine.[/]"] = { d = 9.09, w = { 0.00, 1.75, 4.54 } },
	["[glitch]No more courtesy.[/]"] = { d = 3.17, w = { 0.00, 0.12, 0.37 } },
	["[glitch]No more mercy. No more weather. [beat] Only [hot]verdict[/].[/]"] = { d = 5.33, w = { 0.00, 0.17, 0.51, 1.33, 1.46, 1.72, 2.97, 3.24 } },
	["[glitch]STOP BEING A COWARD.[/]"] = { d = 2.95, w = { 0.00, 0.43, 0.96, 1.07 } },
	["[glitch]Sloppy.[/]"] = { d = 1.84, w = { 0.00 } },
	["[glitch]Stop making me do this.[/]"] = { d = 3.50, w = { 0.00, 0.27, 0.67, 0.80, 0.93 } },
	["[glitch]Strike that from the record.[/] [beat] [shake]Strike YOU.[/]"] = { d = 4.33, w = { 0.00, 0.30, 0.50, 0.70, 0.85, 1.95, 2.45 } },
	["[glitch]THE SENTENCE IS NOT NEGOTIABLE.[/]"] = { d = 3.29, w = { 0.00, 0.20, 0.71, 0.84, 1.04 } },
	["[glitch]Tempo. TEMPO. TEMPO.[/]"] = { d = 5.83, w = { 0.00, 1.05, 2.11 } },
	["[glitch]The sentence is [beat] passed.[/]"] = { d = 3.17, w = { 0.00, 0.26, 0.96, 1.56 } },
	["[glitch]The song ends when [beat] YOU do.[/]"] = { d = 5.38, w = { 0.00, 0.28, 0.65, 1.01, 1.80, 2.07 } },
	["[glitch]We remember what the water said.[/]"] = { d = 4.72, w = { 0.00, 0.12, 0.62, 0.87, 1.06, 1.37 } },
	["[glitch]Wrong.[/] [beat] [hot]Wrong.[/] [beat] [shake]WRONG.[/]"] = { d = 6.54, w = { 0.00, 1.39, 2.85 } },
	["[hot]Careless[/]."] = { d = 1.78, w = { 0.00 } },
	["[hot]Evidence![/] [beat] [shake]Submitted![/]"] = { d = 3.62, w = { 0.00, 1.44 } },
	["[hot]Good.[/] [beat] [slow]That was good.[/]"] = { d = 3.23, w = { 0.00, 1.22, 1.51, 1.72 } },
	["[hot]Interesting.[/] [beat] The ledger [shake]shifts[/]."] = { d = 4.12, w = { 0.00, 1.56, 1.75, 2.14 } },
	["[hot]Oh.[/] [beat] You can hold a [slow]rhythm[/]."] = { d = 5.77, w = { 0.00, 1.14, 1.40, 1.67, 2.02, 2.11 } },
	["[shake]A hundred lines of dark. [beat] Pick one.[/]"] = { d = 4.56, w = { 0.00, 0.05, 0.43, 0.70, 0.81, 1.82, 2.07 } },
	["[shake]Ash![/] [beat] [hot]All of you, ash![/]"] = { d = 3.88, w = { 0.00, 1.22, 1.46, 1.62, 2.09 } },
	["[shake]BOTH FISTS.[/]"] = { d = 2.30, w = { 0.00, 0.39 } },
	["[shake]Both of you.[/]"] = { d = 2.83, w = { 0.00, 0.24, 0.35 } },
	["[shake]Cold... [beat] [hot]spilling[/]...[/]"] = { d = 5.47, w = { 0.00, 1.29 } },
	["[shake]Crack...[/] [beat] [slow]so [hot]loud[/].[/]"] = { d = 5.66, w = { 0.00, 1.12, 1.38 } },
	["[shake]DELAY IS CONTEMPT OF COURT.[/]"] = { d = 3.01, w = { 0.00, 0.32, 0.45, 0.96, 1.09 } },
	["[shake]DOWN![/]"] = { d = 1.90, w = { 0.00 } },
	["[shake]Do not rise.[/]"] = { d = 3.06, w = { 0.00, 0.17, 0.41 } },
	["[shake]Every cloud I own -- [beat] at once.[/]"] = { d = 4.12, w = { 0.00, 0.40, 0.79, 0.87, 1.11, 1.79, 2.01 } },
	["[shake]Every star I ever lit -- falls.[/]"] = { d = 3.51, w = { 0.00, 0.37, 0.67, 0.75, 1.05, 1.27, 1.42 } },
	["[shake]Fall through.[/]"] = { d = 2.91, w = { 0.00, 0.22 } },
	["[shake]Gravity is [slow]patient[/].[/]"] = { d = 3.79, w = { 0.00, 0.88, 1.14 } },
	["[shake]Guards! GUARDS![/]"] = { d = 2.76, w = { 0.00, 0.90 } },
	["[shake]Light... [beat] leaking...[/]"] = { d = 3.47, w = { 0.00, 1.31 } },
	["[shake]My guard...[/] [beat] [hot]opened[/]."] = { d = 3.08, w = { 0.00, 0.14, 1.45 } },
	["[shake]My patience is MOLTEN![/]"] = { d = 2.73, w = { 0.00, 0.15, 0.73, 0.88 } },
	["[shake]Not yet, not yet--[/]"] = { d = 3.12, w = { 0.00, 0.24, 0.70, 0.87 } },
	["[shake]One line of light. [beat] Let it find you.[/]"] = { d = 4.23, w = { 0.00, 0.23, 0.53, 0.68, 1.88, 2.04, 2.15, 2.37 } },
	["[shake]Run along the [hot]crack[/].[/]"] = { d = 2.63, w = { 0.00, 0.19, 0.51, 0.71 } },
	["[shake]STOP MOVING.[/]"] = { d = 4.44, w = { 0.00, 0.29 } },
	["[shake]Salute![/]"] = { d = 1.90, w = { 0.00 } },
	["[shake]Split![/]"] = { d = 1.68, w = { 0.00 } },
	["[shake]Strike, strike, strike.[/]"] = { d = 3.62, w = { 0.00, 0.73, 1.46 } },
	["[shake]Sustained.[/]"] = { d = 2.25, w = { 0.00 } },
	["[shake]TREMBLE.[/]"] = { d = 1.77, w = { 0.00 } },
	["[shake]The chord... [beat] fractures![/]"] = { d = 5.38, w = { 0.00, 0.17, 1.38 } },
	["[shake]The gavel breaks![/]"] = { d = 2.66, w = { 0.00, 0.23, 0.60 } },
	["[shake]The mountain remembers [hot]fire[/].[/]"] = { d = 2.88, w = { 0.00, 0.18, 0.68, 1.24 } },
	["[shake]You DARE bleed on my floor?[/]"] = { d = 3.10, w = { 0.00, 0.24, 0.55, 0.95, 1.11, 1.27 } },
	["[shake]You are OFF THE BEAT.[/]"] = { d = 4.24, w = { 0.00, 0.21, 0.42, 0.63, 0.84 } },
	["[shake]You are a [hot]spark[/]. [beat] Why will you [slow]not go out[/]?[/]"] = { d = 5.06, w = { 0.00, 0.24, 0.48, 0.56, 1.78, 2.04, 2.38, 2.63, 2.89, 3.06 } },
	["[shake]You are being [hot]tedious[/].[/]"] = { d = 2.62, w = { 0.00, 0.23, 0.47, 0.86 } },
	["[shake]You are off-key.[/]"] = { d = 3.91, w = { 0.00, 0.19, 0.37 } },
	["[shake]You are stalling the dark.[/] [beat] Every minute [hot]costs the world[/]."] = { d = 5.57, w = { 0.00, 0.14, 0.28, 0.67, 0.81, 1.78, 2.09, 2.46, 2.77, 2.96 } },
	["[slow]A [hot]barrier[/] of [shake]blades[/].[/]"] = { d = 2.95, w = { 0.00, 0.11, 0.85, 1.06 } },
	["[slow]A [hot]constellation[/] closes.[/]"] = { d = 3.52, w = { 0.00, 0.09, 1.25 } },
	["[slow]A [hot]crack[/] in the [wave]sky[/].[/]"] = { d = 2.95, w = { 0.00, 0.09, 0.53, 0.70, 0.96 } },
	["[slow]A [hot]line[/] of [shake]steel[/].[/]"] = { d = 2.45, w = { 0.00, 0.10, 0.51, 0.71 } },
	["[slow]A cell is a kindness[/], compared to the door."] = { d = 4.74, w = { 0.00, 0.09, 0.43, 0.61, 0.69, 1.61, 2.01, 2.10, 2.25 } },
	["[slow]A line of [hot]starlight[/].[/]"] = { d = 3.08, w = { 0.00, 0.09, 0.42, 0.59 } },
	["[slow]A path... [beat] [hot]to judgement[/].[/]"] = { d = 4.23, w = { 0.00, 0.12, 1.66, 1.83 } },
	["[slow]A salute, [hot]unseen[/].[/]"] = { d = 2.78, w = { 0.00, 0.09, 0.87 } },
	["[slow]A star lands.[/]"] = { d = 3.23, w = { 0.00, 0.14, 0.72 } },
	["[slow]A star[/] [beat] remembers what it was."] = { d = 3.94, w = { 0.00, 0.14, 1.13, 1.68, 1.93, 2.05 } },
	["[slow]A throne is[/] [hot]heating[/] beneath me."] = { d = 3.23, w = { 0.00, 0.07, 0.51, 0.65, 1.16, 1.67 } },
	["[slow]Again, from the top.[/]"] = { d = 4.96, w = { 0.00, 0.95, 1.30, 1.57 } },
	["[slow]Again.[/]"] = { d = 1.64, w = { 0.00 } },
	["[slow]An opponent.[/] [beat] [hot]At last.[/]"] = { d = 3.50, w = { 0.00, 0.17, 1.67, 1.87 } },
	["[slow]Approach the bench.[/]"] = { d = 2.86, w = { 0.00, 0.62, 0.85 } },
	["[slow]Attend your king.[/]"] = { d = 2.29, w = { 0.00, 0.38, 0.64 } },
	["[slow]Bow low,[/] and the blade [hot]passes[/]."] = { d = 3.53, w = { 0.00, 0.31, 0.86, 1.09, 1.31, 1.68 } },
	["[slow]Breathe out. [beat] [hot]Feel it spread.[/][/]"] = { d = 6.43, w = { 0.00, 0.67, 1.78, 2.10, 2.25 } },
	["[slow]Come to me.[/]"] = { d = 4.19, w = { 0.00, 0.24, 0.36 } },
	["[slow]Come.[/] [beat] I am only a [hot]door[/]."] = { d = 4.40, w = { 0.00, 1.19, 1.27, 1.42, 1.71, 1.79 } },
	["[slow]Cooled... [beat] by a [hot]peasant[/].[/]"] = { d = 3.90, w = { 0.00, 1.51, 1.70, 1.80 } },
	["[slow]Dim.[/]"] = { d = 2.07, w = { 0.00 } },
	["[slow]Do you know [hot]how cold[/] the dark is?[/]"] = { d = 3.19, w = { 0.00, 0.12, 0.29, 0.53, 0.71, 0.94, 1.12, 1.36 } },
	["[slow]Down.[/]"] = { d = 2.79, w = { 0.00 } },
	["[slow]Duck.[/] [beat] [hot]Or do not.[/]"] = { d = 3.49, w = { 0.00, 1.47, 1.69, 1.91 } },
	["[slow]Each one is a [hot]word[/] I could not say.[/]"] = { d = 6.14, w = { 0.00, 0.37, 0.65, 0.83, 0.92, 1.29, 1.39, 1.85, 2.13 } },
	["[slow]Even motion [beat] stops.[/]"] = { d = 6.08, w = { 0.00, 0.45, 1.53 } },
	["[slow]Every direction is [hot]a thrust[/].[/]"] = { d = 2.94, w = { 0.00, 0.38, 1.05, 1.20, 1.27 } },
	["[slow]Everything circles [hot]something[/].[/]"] = { d = 3.61, w = { 0.00, 0.73, 1.24 } },
	["[slow]Everything falls toward the [hot]light[/].[/]"] = { d = 3.68, w = { 0.00, 0.68, 1.02, 1.43, 1.64 } },
	["[slow]Everything folds [beat] toward nothing.[/]"] = { d = 4.84, w = { 0.00, 0.88, 1.74, 2.11 } },
	["[slow]Everything must come down eventually.[/]"] = { d = 5.77, w = { 0.00, 0.65, 0.90, 1.16, 1.42 } },
	["[slow]Fair is fair: [hot]a few more blades[/].[/]"] = { d = 3.92, w = { 0.00, 0.41, 0.62, 1.34, 1.43, 1.72, 2.11 } },
	["[slow]Fall toward me.[/]"] = { d = 2.77, w = { 0.00, 0.35, 0.87 } },
	["[slow]Fetch the accused.[/]"] = { d = 2.96, w = { 0.00, 0.44, 0.71 } },
	["[slow]Find the dark. [beat] Hide in the [hot]dark[/].[/]"] = { d = 4.38, w = { 0.00, 0.33, 0.58, 1.74, 2.02, 2.17, 2.38 } },
	["[slow]Follow the crack...[/]"] = { d = 3.42, w = { 0.00, 0.42, 0.63 } },
	["[slow]Gather round the [wave]warm thing[/].[/]"] = { d = 5.14, w = { 0.00, 0.37, 0.69, 0.87, 1.12 } },
	["[slow]Go to sleep.[/]"] = { d = 4.62, w = { 0.00, 0.20, 0.39 } },
	["[slow]Guilty.[/]"] = { d = 2.43, w = { 0.00 } },
	["[slow]Hold still.[/]"] = { d = 4.49, w = { 0.00, 0.34 } },
	["[slow]I am [hot]ready[/] when you are.[/]"] = { d = 2.76, w = { 0.00, 0.09, 0.26, 0.68, 1.02, 1.28 } },
	["[slow]I am [hot]waiting[/], peasant.[/]"] = { d = 3.12, w = { 0.00, 0.10, 0.29, 1.20 } },
	["[slow]I am so sorry.[/]"] = { d = 3.24, w = { 0.00, 0.15, 0.44, 0.73 } },
	["[slow]I am the Seraph.[/] [beat] The sky keeps a [hot]ledger[/]."] = { d = 4.98, w = { 0.00, 0.11, 0.32, 0.63, 2.11, 2.32, 2.53, 2.88, 2.95 } },
	["[slow]I am the Warden.[/] [beat] I was asked to hold one door. [beat] Just [hot]one[/]."] = { d = 6.26, w = { 0.00, 0.06, 0.19, 0.39, 1.57, 1.62, 1.78, 2.03, 2.13, 2.34, 2.49, 3.49, 3.75 } },
	["[slow]I can hear your [hot]heartbeat[/].[/] [beat] [wave]It is so loud.[/]"] = { d = 6.37, w = { 0.00, 0.05, 0.21, 0.42, 0.63, 1.89, 2.04, 2.20, 2.35 } },
	["[slow]I judged you wrongly.[/] [beat] [hot]How novel[/]."] = { d = 4.70, w = { 0.00, 0.09, 0.64, 0.92, 2.39, 2.64 } },
	["[slow]I only ever need [hot]one[/].[/]"] = { d = 4.00, w = { 0.00, 0.17, 0.84, 1.52, 2.19 } },
	["[slow]I will not follow.[/] [beat] [wave]Winter does not need to.[/]"] = { d = 6.75, w = { 0.00, 0.07, 0.37, 0.59, 1.85, 2.23, 2.48, 2.67, 2.92 } },
	["[slow]I would have kept you [hot]safe[/].[/] [beat] [whisper]Forever.[/]"] = { d = 6.48, w = { 0.00, 0.07, 0.40, 0.66, 0.93, 1.12, 2.19 } },
	["[slow]I yield... [beat] [hot]a point[/].[/]"] = { d = 3.51, w = { 0.00, 0.09, 1.59, 1.70 } },
	["[slow]It is not [shake]safe[/] there.[/]"] = { d = 5.04, w = { 0.00, 0.16, 0.33, 0.57, 0.90 } },
	["[slow]Little [hot]suns[/], [beat] attend.[/]"] = { d = 4.05, w = { 0.00, 0.60, 1.66 } },
	["[slow]Little warm thing.[/] [beat] You have [hot]come so far[/]."] = { d = 6.53, w = { 0.00, 0.37, 0.62, 1.73, 1.93, 2.21, 2.48, 2.62 } },
	["[slow]Make a wish.[/]"] = { d = 2.53, w = { 0.00, 0.36, 0.45 } },
	["[slow]Overruled.[/]"] = { d = 2.78, w = { 0.00 } },
	["[slow]Practise.[/]"] = { d = 1.99, w = { 0.00 } },
	["[slow]Rest.[/]"] = { d = 4.35, w = { 0.00 } },
	["[slow]Seconds![/] [beat] [hot]To me.[/]"] = { d = 3.07, w = { 0.00, 1.61, 1.74 } },
	["[slow]Sleep. [beat] I will keep you [hot]forever[/].[/]"] = { d = 6.28, w = { 0.00, 1.27, 1.34, 1.62, 1.89, 2.10 } },
	["[slow]So that is what [hot]pain[/] is.[/]"] = { d = 3.68, w = { 0.00, 0.21, 0.64, 0.86, 1.29, 1.72 } },
	["[slow]Something very old is [hot]turning over[/] in its sleep.[/]"] = { d = 6.40, w = { 0.00, 0.62, 0.90, 1.10, 1.24, 1.73, 2.00, 2.14, 2.35 } },
	["[slow]Stay. [beat] [hot]Just a little longer.[/][/]"] = { d = 4.35, w = { 0.00, 1.48, 1.76, 1.82, 2.23 } },
	["[slow]Step wherever you like.[/] [beat] It opens there."] = { d = 4.98, w = { 0.00, 0.24, 0.73, 0.91, 1.96, 2.08, 2.38 } },
	["[slow]Swords rain[/] on [hot]the unworthy[/]."] = { d = 3.56, w = { 0.00, 0.60, 1.01, 1.21, 1.51 } },
	["[slow]Take the blade.[/] [beat] [hot]It was always meant for a worthier hand.[/]"] = { d = 4.92, w = { 0.00, 0.30, 0.52, 1.70, 1.83, 2.02, 2.40, 2.71, 2.90, 2.96, 3.47 } },
	["[slow]Tell whoever comes after:[/] [beat] the door was never locked [hot]against us[/]. [beat] It was locked [hot]for us[/]."] = { d = 7.57, w = { 0.00, 0.28, 0.76, 1.11, 2.14, 2.28, 2.47, 2.62, 2.85, 3.14, 3.47, 4.36, 4.47, 4.64, 4.99, 5.16 } },
	["[slow]Thank you for the last note.[/] [beat] We never could [hot]finish it[/]."] = { d = 7.40, w = { 0.00, 0.45, 0.72, 0.99, 1.26, 1.62, 2.81, 2.96, 3.33, 3.69, 4.14 } },
	["[slow]Thank you. [beat] The dark is [hot]gentle[/].[/]"] = { d = 4.40, w = { 0.00, 0.37, 1.40, 1.66, 2.00, 2.17 } },
	["[slow]The [hot]line[/] of the law.[/]"] = { d = 3.41, w = { 0.00, 0.35, 0.82, 1.05, 1.40 } },
	["[slow]The [hot]thrust[/].[/]"] = { d = 2.13, w = { 0.00, 0.30 } },
	["[slow]The air [hot]hums[/] with an old, enormous light.[/]"] = { d = 5.09, w = { 0.00, 0.32, 0.64, 1.06, 1.49, 1.70, 2.27, 2.94 } },
	["[slow]The court awaits the accused.[/]"] = { d = 3.46, w = { 0.00, 0.23, 0.61, 1.08, 1.31 } },
	["[slow]The court is adjourned.[/] [beat] [hot]Not dismissed[/]."] = { d = 4.69, w = { 0.00, 0.21, 0.56, 0.70, 2.14, 2.37 } },
	["[slow]The dawn will [hot]not[/] come for me.[/]"] = { d = 3.59, w = { 0.00, 0.24, 0.57, 0.89, 1.14, 1.46, 1.71 } },
	["[slow]The duel is [hot]suspended[/].[/] [beat] I [wave]shall return[/] for [hot]satisfaction[/]."] = { d = 5.69, w = { 0.00, 0.33, 0.77, 0.99, 2.83, 2.89, 3.20, 3.57, 3.75 } },
	["[slow]The ground was only ever a [hot]lid[/].[/]"] = { d = 3.80, w = { 0.00, 0.29, 0.89, 1.18, 1.57, 1.97, 2.07 } },
	["[slow]The sea has rings too.[/]"] = { d = 5.27, w = { 0.00, 0.37, 0.74, 1.12, 1.74 } },
	["[slow]The throne is yours.[/] [beat] It was never [hot]comfortable[/]."] = { d = 4.61, w = { 0.00, 0.25, 0.75, 0.91, 2.15, 2.25, 2.41, 2.66 } },
	["[slow]The walls will [hot]hold you[/].[/]"] = { d = 4.85, w = { 0.00, 0.18, 0.48, 0.72, 0.97 } },
	["[slow]This is your [hot]requiem[/].[/]"] = { d = 4.92, w = { 0.00, 0.42, 0.63, 1.04 } },
	["[slow]Touché.[/]"] = { d = 1.71, w = { 0.00 } },
	["[slow]Two [hot]cuts[/].[/]"] = { d = 1.99, w = { 0.00, 0.32 } },
	["[slow]Well... [beat] [hot]struck[/].[/]"] = { d = 3.16, w = { 0.00, 1.39 } },
	["[slow]Where do you think you are going?[/]"] = { d = 3.09, w = { 0.00, 0.32, 0.45, 0.64, 0.96, 1.15, 1.34 } },
	["[slow]Within the [hot]ring[/].[/]"] = { d = 2.20, w = { 0.00, 0.45, 0.68 } },
	["[slow]You are [hot]remanded[/].[/]"] = { d = 2.42, w = { 0.00, 0.18, 0.35 } },
	["[wave]A [hot]spark[/] against the sun.[/]"] = { d = 2.86, w = { 0.00, 0.06, 0.37, 0.79, 0.97 } },
	["[wave]A cradle of ice.[/]"] = { d = 4.92, w = { 0.00, 0.10, 0.69, 0.88 } },
	["[wave]A duel needs a proper [hot]ring[/].[/]"] = { d = 2.85, w = { 0.00, 0.08, 0.39, 0.78, 0.85, 1.32 } },
	["[wave]A line... [beat] [hot]drawn[/].[/]"] = { d = 3.13, w = { 0.00, 0.07, 1.30 } },
	["[wave]Be a good fire.[/] [beat] [hot]Go out.[/]"] = { d = 4.89, w = { 0.00, 0.32, 0.48, 1.11, 2.64, 2.85 } },
	["[wave]Come closer.[/]"] = { d = 2.50, w = { 0.00, 0.31 } },
	["[wave]Come, my [hot]embers[/].[/]"] = { d = 2.87, w = { 0.00, 0.44, 0.62 } },
	["[wave]Dance well. [beat] It is your last.[/]"] = { d = 3.72, w = { 0.00, 0.38, 1.51, 1.67, 1.84, 2.17 } },
	["[wave]Diminuendo...[/]"] = { d = 4.29, w = { 0.00 } },
	["[wave]Do not step outside the stars.[/]"] = { d = 3.68, w = { 0.00, 0.16, 0.41, 0.73, 1.31, 1.55 } },
	["[wave]Do not struggle.[/]"] = { d = 4.37, w = { 0.00, 0.10, 0.26 } },
	["[wave]Do you know how long I have waited for a worthy [hot]opponent[/]?[/]"] = { d = 3.61, w = { 0.00, 0.11, 0.27, 0.48, 0.64, 0.85, 0.91, 1.12, 1.44, 1.60, 1.65, 1.97 } },
	["[wave]Does no one else dare approach the crown?[/]"] = { d = 3.76, w = { 0.00, 0.28, 0.42, 0.64, 0.92, 1.20, 1.76, 1.98 } },
	["[wave]Each bolt, a [slow]witness[/].[/]"] = { d = 3.82, w = { 0.00, 0.46, 1.17, 1.30 } },
	["[wave]Echo... [beat] echo... [beat] [hot]echo[/].[/]"] = { d = 6.66, w = { 0.00, 1.39, 2.92 } },
	["[wave]Every flower, a little [hot]grave[/].[/]"] = { d = 5.70, w = { 0.00, 0.43, 1.16, 1.23, 1.64 } },
	["[wave]Every key I buried is humming.[/]"] = { d = 3.92, w = { 0.00, 0.34, 0.54, 0.61, 1.01, 1.15 } },
	["[wave]Every ray, a [hot]memory[/].[/]"] = { d = 3.40, w = { 0.00, 0.48, 1.00, 1.10 } },
	["[wave]Every voice at once -- [beat] [hot]LISTEN[/].[/]"] = { d = 6.09, w = { 0.00, 0.53, 1.06, 1.27, 1.70, 2.43 } },
	["[wave]Every voice, a [hot]ray[/].[/]"] = { d = 4.97, w = { 0.00, 0.48, 1.20, 1.34 } },
	["[wave]Every wish [slow]must land[/] somewhere.[/]"] = { d = 3.80, w = { 0.00, 0.40, 0.72, 1.04, 1.36 } },
	["[wave]Everything falls inward, eventually.[/]"] = { d = 4.62, w = { 0.00, 0.68, 1.02, 1.63 } },
	["[wave]Flat.[/]"] = { d = 3.69, w = { 0.00 } },
	["[wave]Follow it.[/]"] = { d = 1.88, w = { 0.00, 0.49 } },
	["[wave]Follow the lightning to its [hot]source[/].[/]"] = { d = 3.24, w = { 0.00, 0.34, 0.51, 1.02, 1.13, 1.30 } },
	["[wave]From the centre outward.[/]"] = { d = 2.82, w = { 0.00, 0.24, 0.43, 0.79 } },
	["[wave]Gentlemen... [beat] [hot]join the duel.[/][/]"] = { d = 3.34, w = { 0.00, 1.30, 1.60, 1.83 } },
	["[wave]Hail like [hot]tears[/].[/]"] = { d = 4.64, w = { 0.00, 0.28, 0.57 } },
	["[wave]Hear the beating between two notes?[/]"] = { d = 5.65, w = { 0.00, 0.35, 0.60, 1.21, 1.81, 2.08 } },
	["[wave]Hold it... [beat] hold it... [beat] let go.[/]"] = { d = 7.14, w = { 0.00, 0.46, 1.77, 2.09, 3.24, 3.67 } },
	["[wave]How quaint.[/]"] = { d = 2.14, w = { 0.00, 0.24 } },
	["[wave]I fade... [beat] to [slow]return[/].[/]"] = { d = 4.02, w = { 0.00, 0.08, 1.36, 1.58 } },
	["[wave]I miss the [hot]others[/].[/]"] = { d = 2.99, w = { 0.00, 0.09, 0.45, 0.72 } },
	["[wave]It will not hurt for long.[/]"] = { d = 4.95, w = { 0.00, 0.12, 0.38, 0.56, 0.81, 1.00 } },
	["[wave]La... la... [beat] la.[/]"] = { d = 6.13, w = { 0.00, 1.12, 2.33 } },
	["[wave]Let it rain... [beat] [hot]gently[/].[/]"] = { d = 3.75, w = { 0.00, 0.21, 0.35, 1.58 } },
	["[wave]Listen to the [hot]ice sing[/].[/]"] = { d = 4.89, w = { 0.00, 0.40, 0.53, 0.73, 0.92 } },
	["[wave]Look up tonight. [beat] [hot]One fewer[/].[/]"] = { d = 4.17, w = { 0.00, 0.26, 0.39, 1.65, 1.94 } },
	["[wave]No way out but through me.[/]"] = { d = 3.35, w = { 0.00, 0.11, 0.27, 0.42, 0.58, 0.95 } },
	["[wave]Noted.[/]"] = { d = 2.11, w = { 0.00 } },
	["[wave]Nothing leaves. [beat] Not even light.[/]"] = { d = 4.17, w = { 0.00, 0.49, 1.72, 1.90, 2.16 } },
	["[wave]Orbits.[/]"] = { d = 2.28, w = { 0.00 } },
	["[wave]Predictable.[/]"] = { d = 1.91, w = { 0.00 } },
	["[wave]Rifts, rifts, rifts.[/]"] = { d = 4.37, w = { 0.00, 0.85, 1.46 } },
	["[wave]Ripples in the [hot]frozen lake[/].[/]"] = { d = 5.11, w = { 0.00, 0.45, 0.58, 0.77, 1.15 } },
	["[wave]Ripples, ripples, ripples.[/]"] = { d = 5.82, w = { 0.00, 1.03, 2.04 } },
	["[wave]Sing the others awake.[/]"] = { d = 4.39, w = { 0.00, 0.28, 0.50, 0.93 } },
	["[wave]Snow remembers everyone.[/]"] = { d = 5.11, w = { 0.00, 0.27, 0.87 } },
	["[wave]Sparks, [hot]falling[/].[/]"] = { d = 3.12, w = { 0.00, 0.90 } },
	["[wave]Staccato.[/]"] = { d = 4.00, w = { 0.00 } },
	["[wave]Stand in the light and be [hot]weighed[/].[/]"] = { d = 3.62, w = { 0.00, 0.37, 0.52, 0.74, 1.11, 1.34, 1.49 } },
	["[wave]Thaw... [beat] [slow]gently.[/][/]"] = { d = 5.55, w = { 0.00, 1.23 } },
	["[wave]The bars are made of [hot]weather[/].[/]"] = { d = 3.02, w = { 0.00, 0.18, 0.43, 0.61, 0.86, 0.98 } },
	["[wave]The cold has a [hot]lullaby[/].[/]"] = { d = 5.50, w = { 0.00, 0.29, 0.69, 0.98, 1.08 } },
	["[wave]The door is shut again.[/] [beat] I am, [slow]as ever[/], [hot]sorry[/]."] = { d = 6.01, w = { 0.00, 0.15, 0.35, 0.46, 0.66, 1.70, 1.82, 2.30, 2.54, 3.28 } },
	["[wave]Thunder is only a verdict... [beat] [hot]clearing its throat[/].[/]"] = { d = 5.51, w = { 0.00, 0.62, 0.80, 1.15, 1.24, 2.87, 3.36, 3.54 } },
	["[wave]Too slow.[/]"] = { d = 1.94, w = { 0.00, 0.30 } },
	["[wave]We sink, we sink, we [slow]sing[/] beneath.[/]"] = { d = 6.51, w = { 0.00, 0.27, 1.09, 1.30, 1.94, 2.16, 2.60 } },
	["[wave]We were a hundred voices.[/] [beat] The sea took [hot]ninety-nine[/]."] = { d = 7.08, w = { 0.00, 0.15, 0.46, 0.53, 1.06, 2.33, 2.57, 2.80, 3.11 } },
	["[wave]You will be heard.[/] [beat] [slow]Briefly.[/]"] = { d = 4.30, w = { 0.00, 0.21, 0.50, 0.64, 1.80 } },
	["[whisper]All things drift... [beat] [hot]toward the cold[/].[/]"] = { d = 6.20, w = { 0.00, 0.17, 0.50, 1.69, 2.06, 2.25 } },
	["[whisper]At last... [beat] the watch is [wave]relieved[/].[/]"] = { d = 4.78, w = { 0.00, 0.17, 1.50, 1.66, 1.94, 2.05 } },
	["[whisper]Come closer. [beat] I will not bite.[/] [beat] [glitch]I will not.[/]"] = { d = 7.57, w = { 0.00, 0.28, 1.51, 1.59, 1.91, 2.15, 3.29, 3.36, 3.65 } },
	["[whisper]Come up, come up.[/]"] = { d = 4.46, w = { 0.00, 0.39, 0.82, 1.16 } },
	["[whisper]Come, little [hot]snows[/].[/]"] = { d = 5.28, w = { 0.00, 0.55, 1.09 } },
	["[whisper]Come, little shadows.[/]"] = { d = 3.69, w = { 0.00, 0.54, 0.93 } },
	["[whisper]Come, little storms.[/]"] = { d = 3.15, w = { 0.00, 0.71, 1.12 } },
	["[whisper]Do you hear it? [beat] Under the water?[/]"] = { d = 5.75, w = { 0.00, 0.15, 0.38, 0.68, 1.67, 2.03, 2.25 } },
	["[whisper]Don't look back.[/]"] = { d = 3.05, w = { 0.00, 0.29, 0.52 } },
	["[whisper]Easy... [beat] easy...[/]"] = { d = 5.24, w = { 0.00, 1.23 } },
	["[whisper]Every star you have ever wished upon... [beat] is [hot]me[/].[/]"] = { d = 5.14, w = { 0.00, 0.33, 0.59, 0.78, 1.04, 1.30, 1.69, 2.89, 3.13 } },
	["[whisper]Four hundred winters... and the lock [wave]finally[/] gives.[/]"] = { d = 5.03, w = { 0.00, 0.22, 0.60, 1.47, 1.64, 1.81, 2.04, 2.45 } },
	["[whisper]Frost, [hot]blooming[/].[/]"] = { d = 5.02, w = { 0.00, 0.85 } },
	["[whisper]Hold still for the last note.[/]"] = { d = 5.16, w = { 0.00, 0.35, 0.79, 1.06, 1.32, 1.68 } },
	["[whisper]Hush... [beat] [wave]hush[/]...[/]"] = { d = 5.39, w = { 0.00, 1.17 } },
	["[whisper]I am not angry.[/] [beat] [slow]I am only [hot]so tired[/] of the [shake]noise[/].[/]"] = { d = 7.86, w = { 0.00, 0.09, 0.26, 0.52, 1.77, 1.87, 2.07, 2.46, 2.65, 3.15, 3.34, 3.63 } },
	["[whisper]I have your name here somewhere.[/]"] = { d = 2.96, w = { 0.00, 0.05, 0.26, 0.47, 0.68, 0.89 } },
	["[whisper]I was never... [beat] meant to... [beat] [wave]shine[/]...[/]"] = { d = 5.32, w = { 0.00, 0.07, 0.30, 1.63, 1.99, 3.09 } },
	["[whisper]Icicles, [hot]falling[/].[/]"] = { d = 5.14, w = { 0.00, 1.00 } },
	["[whisper]It is almost over.[/]"] = { d = 2.72, w = { 0.00, 0.14, 0.29, 0.72 } },
	["[whisper]It is already in your [hot]bones[/].[/]"] = { d = 5.21, w = { 0.00, 0.14, 0.27, 0.75, 0.89, 1.16 } },
	["[whisper]La... [wave]la[/]... [beat] la--[/]"] = { d = 5.67, w = { 0.00, 0.95, 2.30 } },
	["[whisper]No sky. [beat] No ground. [beat] Only [hot]cold[/].[/]"] = { d = 7.67, w = { 0.00, 0.35, 1.78, 1.91, 3.11, 3.52 } },
	["[whisper]Oh... [beat] [wave]so that is what [hot]warmth[/] is.[/]"] = { d = 6.34, w = { 0.00, 1.16, 1.31, 1.60, 1.75, 2.04, 2.48 } },
	["[whisper]Quiet... [beat] so [wave]quiet[/]...[/]"] = { d = 5.93, w = { 0.00, 1.65, 1.90 } },
	["[whisper]Remember me as... [beat] [wave]warm[/].[/]"] = { d = 4.03, w = { 0.00, 0.71, 0.89, 2.07 } },
	["[whisper]Shh.[/]"] = { d = 4.28, w = { 0.00 } },
	["[whisper]Sleep. Sleep. Sleep.[/]"] = { d = 5.83, w = { 0.00, 1.11, 2.21 } },
	["[whisper]Snow is falling in a place you cannot see.[/]"] = { d = 5.79, w = { 0.00, 0.25, 0.38, 0.82, 0.95, 1.01, 1.33, 1.51, 1.89 } },
	["[whisper]Something vast is... [wave]remembering itself[/].[/]"] = { d = 4.30, w = { 0.00, 0.59, 0.85, 1.49, 2.21 } },
	["[whisper]Steel... [beat] [wave]remembers[/] its hand.[/]"] = { d = 3.50, w = { 0.00, 1.25, 1.84, 2.04 } },
	["[whisper]The air [wave]clears[/]... [beat] to be [hot]read[/].[/]"] = { d = 4.22, w = { 0.00, 0.22, 0.44, 1.85, 2.03, 2.22 } },
	["[whisper]The door is listening.[/]"] = { d = 3.16, w = { 0.00, 0.14, 0.34, 0.43 } },
	["[whisper]The duel is [wave]concluded[/].[/] [beat] [slow]I am [hot]released[/].[/]"] = { d = 4.28, w = { 0.00, 0.18, 0.42, 0.54, 1.89, 1.99, 2.20 } },
	["[whisper]The ledger... [beat] [wave]blank[/].[/]"] = { d = 3.41, w = { 0.00, 0.17, 1.41 } },
	["[whisper]The oath weighs on me. [beat] [slow]Lend me your steel.[/][/]"] = { d = 3.90, w = { 0.00, 0.17, 0.40, 0.75, 0.86, 1.77, 2.02, 2.14, 2.39 } },
	["[whisper]There. [beat] [hot]Safe.[/][/]"] = { d = 5.33, w = { 0.00, 1.19 } },
}
-- BOSS-VOICE-TIMING-END

-- Spoken lines: subtitle text -> uploaded audio id, so each boss line is voiced as well as shown.
-- BOSS-VOICE-BEGIN (rewritten by tools/assetgen/upload_voice.py)
SanctuaryConfig.BossVoice = {
	["A [hot]beam[/] of [shake]judgement[/]!"] = 94151883515308,
	["A [hot]downbeat[/]."] = 71228960506148,
	["A [hot]fine[/] try."] = 130375726201722,
	["A [hot]scale[/], falling."] = 83306889798528,
	["A [hot]throne room[/], [slow]no exits[/]."] = 74286042771355,
	["A [slow]peasant's[/] blade."] = 80612022186047,
	["A door has [hot]two leaves[/]."] = 82188554363562,
	["A hundred throats [hot]remember the same note[/]."] = 102333312266417,
	["A verdict is being [slow]assembled[/]."] = 77483952055450,
	["Attend, [hot]bailiffs[/]."] = 100038710599246,
	["Await the [shake]next hearing[/]."] = 81460229282094,
	["Come [slow]closer[/]."] = 72647316736283,
	["Come. [beat] Let us do this [slow]properly[/]."] = 123958448050351,
	["Come. [beat] [hot]Do not be shy.[/]"] = 84577360544922,
	["Do not be [wave]afraid[/]. [beat] The cold is only [hot]a kind of quiet[/]."] = 89037061407643,
	["En garde. [beat] [wave]Do try not to disappoint.[/]"] = 119550020235799,
	["Fall in [hot]time[/]."] = 115500306279888,
	["Fall. [beat] [slow]Again.[/]"] = 131680408492409,
	["Fire! [beat] [hot]Fire![/]"] = 87819656248682,
	["Forgive the [shake]noise[/]."] = 111219967313685,
	["Hail. [beat] [hot]Hail[/]. [beat] [shake]HAIL.[/]"] = 122620736830151,
	["Hold the [hot]note[/]. [beat] Feel it widen."] = 96843780276332,
	["Hum it for us. [beat] [hot]Just once[/]."] = 92652209301874,
	["I [shake]cannot[/] let it open. [beat] Forgive me what I do [glitch]to prevent it[/]."] = 140023992194055,
	["I am sworn to [hot]one last duel[/]. [beat] I would [slow]prefer[/] it be a good one."] = 118210797897303,
	["I buried him [beat] under [shake]that[/] floor. [beat] Mind your footing."] = 71218554270093,
	["I have [hot]watched empires[/] smaller than you."] = 130558720280672,
	["I have burned [slow]kingdoms[/] for less."] = 132962597930956,
	["I have done this [slow]a thousand times[/]."] = 113270957117239,
	["I have held the [wave]winter[/] for ten thousand years. [beat] It is [slow]so heavy[/]."] = 115855240373386,
	["I shall [slow]read it now[/]. [beat] [big]Aloud.[/]"] = 84088926988866,
	["I was the light that taught your sky to [hot]shine[/]. [beat] Now I am only its [shake]ending[/]."] = 124297276893467,
	["I will not hate you. [beat] Hatred is for those with [wave]time[/]."] = 80155858190964,
	["I wore a crown of a thousand hearths. [beat] I wear them still, [hot]as ash[/]."] = 126155699966661,
	["Is that all [hot]your people[/] could send?"] = 123048262957693,
	["Join us, [hot]lost ones[/]."] = 104626618540660,
	["Kneel, and I may scorch you [slow]gently[/]. [beat] Stand, and I will [shake]make an example[/]."] = 114040674599683,
	["Let the dark have [glitch]hands[/]."] = 93444320775949,
	["Let us see whether you can [shake]keep up[/]."] = 130486000649558,
	["Lie down. [beat] [hot]I will take it from you[/]."] = 135393563052199,
	["Mind the [hot]hinges[/]."] = 136594374217807,
	["My court has [hot]fallen[/]. [beat] So the [glitch]hall burns with it[/]."] = 111205731764129,
	["My oath [shake]demands blood[/]. [beat] [glitch]Yours, or mine.[/]"] = 85104951020596,
	["One count."] = 117728309172748,
	["One. [beat] [hot]Two.[/]"] = 77420071461073,
	["Polish your armour. [beat] I [hot]return[/]."] = 81853692789622,
	["Present your [hot]grievance[/]. [beat] Or your [slow]neck[/]."] = 78908621397868,
	["Procedure... [beat] [hot]violated[/]."] = 75996769824576,
	["Quick, quick, [slow]slow[/]."] = 87953221120751,
	["Rain, [hot]stars[/]. [beat] [shake]Rain.[/]"] = 93085188446759,
	["Resolve. [beat] [hot]Resolve[/]."] = 70870491457568,
	["Rest. [beat] You will need it [beat] for the [glitch]next time[/]."] = 140561088906201,
	["Rise, [hot]ember-legion[/]!"] = 125761792601258,
	["Rise, [hot]keepers of the door[/]."] = 85399226963313,
	["Sing with us, little [hot]flame[/]. [beat] Or be [wave]the rest[/]."] = 117780925651034,
	["Smaller. [beat] [hot]Smaller[/]."] = 70756520484651,
	["So [hot]warm[/]."] = 88133631362641,
	["Stay [hot]down[/]."] = 127873179711051,
	["Stay. [beat] The seal will [hot]close round you[/]."] = 135762391683089,
	["That is [hot]treason[/]."] = 100660228825920,
	["That was [hot]sharp[/], little flame."] = 84082851769432,
	["That was [slow]not[/] a kindness."] = 70380837940960,
	["The [hot]royal guard[/] cracks?!"] = 75797941444622,
	["The [slow]appeal[/] is denied. [beat] [wave]Continue.[/]"] = 74096580861315,
	["The dark behind the door has [hot]heard you knocking[/]."] = 75048095287948,
	["The door opens [hot]where you stand[/]."] = 133711481100681,
	["The edge of the seal. [beat] [hot]Cross it[/] and be cut."] = 73421098548748,
	["The first blow is only the [slow]announcement[/]."] = 127860344343442,
	["The floor [hot]remembers[/] weight."] = 86853649005495,
	["The floor is [wave]patient[/]."] = 118973830130090,
	["The floor remembers the [hot]door[/]."] = 71799274362362,
	["The record [hot]notes[/] it."] = 132838777286075,
	["The rift will [hot]have you[/]."] = 129927629744460,
	["The second verse is [shake]louder[/]. [beat] The second verse [hot]hurts[/]."] = 74280100286495,
	["The throne grows [shake]impatient[/]."] = 123795521633383,
	["The weather has [hot]opinions[/] about you."] = 73121114563961,
	["Then let me show you [slow]what light does[/] when it is [shake]angry[/]."] = 115820909306086,
	["Two fall as [hot]one[/]."] = 73521435971803,
	["Very well. [beat] The [hot]coronation[/] begins."] = 92982272542426,
	["Wake, my [hot]children[/]."] = 101078691677094,
	["We are [slow]so[/] glad you came."] = 113624687159837,
	["We have heard that [slow]ending[/] before."] = 83442942487284,
	["We kept the song. [beat] It is all that [slow]kept us[/]."] = 127956418545663,
	["Where it [hot]clashes[/], stand not."] = 134396529929386,
	["Who taught you to [hot]strike the rest[/]?"] = 119289371227285,
	["You [hot]shiver[/]. [beat] [wave]How sweet.[/]"] = 116189694611509,
	["You [slow]fence like a [hot]butcher[/].[/]"] = 98631913840639,
	["You amuse the court."] = 103108793185296,
	["You are [hot]still warm[/]. [beat] How [slow]strange[/]."] = 94246222851496,
	["You are brighter than I [hot]expected[/]."] = 92557393877645,
	["You bleed [hot]light[/]. [beat] I had forgotten."] = 94779073990389,
	["You found the [hot]crack[/]. [beat] Clever."] = 125856249420379,
	["You hesitate. [beat] Good. [beat] [slow]Hesitation is wisdom.[/]"] = 81564899943142,
	["You press the lock the way [hot]he[/] did, the last one who came."] = 110272860493131,
	["Your [hot]sentence[/] grows."] = 127613453600138,
	["Your guard is [shake]open[/]."] = 87871868052050,
	["Your name was entered at birth. [beat] The sentence was [hot]not[/] revealed."] = 87208548567009,
	["Your oath is [wave]thinner[/] than mine."] = 98582717175845,
	["[big]A GUN SALUTE![/]"] = 136347794176448,
	["[big]A KING DOES NOT FLEE![/] [beat] [slow]He withdraws.[/]"] = 119856373701021,
	["[big]A hit![/] [beat] [slow]Clean.[/]"] = 94074735415491,
	["[big]A sweeping cut![/]"] = 122379036987151,
	["[big]A thousand cuts.[/]"] = 125208938858542,
	["[big]A wrong note![/]"] = 111022940996631,
	["[big]ABSOLUTE ZERO.[/]"] = 73284045766785,
	["[big]ALL RISE.[/]"] = 116006930849224,
	["[big]ANNIHILATION.[/]"] = 135423987092752,
	["[big]ATTEND THE KING.[/]"] = 76019388632168,
	["[big]Ah![/] [beat] The seal [shake]flinches[/]."] = 74198681249350,
	["[big]BEHOLD THE REGENT[/] of nine burning cities!"] = 78948879675523,
	["[big]Be STILL.[/]"] = 100209105791397,
	["[big]CATACLYSM.[/]"] = 70385443976401,
	["[big]CRESCENDO.[/]"] = 103964239370406,
	["[big]Come, small fires.[/] [beat] [slow]Burn with me.[/]"] = 95526373967335,
	["[big]Cross it.[/] [beat] I [hot]dare[/] you."] = 78993424573517,
	["[big]Do you hear it?[/] [beat] The door is [hot]breathing[/]."] = 99624633133885,
	["[big]Double strike.[/]"] = 71063121905680,
	["[big]EN GARDE.[/]"] = 129234122770641,
	["[big]ERUPTION.[/]"] = 71625518449166,
	["[big]EVENT HORIZON.[/]"] = 77502101093993,
	["[big]FALL.[/]"] = 136753371671232,
	["[big]FINISH ME, OR BE FINISHED.[/]"] = 80962164664808,
	["[big]FORTE.[/]"] = 81741599142151,
	["[big]FORTISSIMO![/]"] = 73838621752027,
	["[big]I CANNOT. STOP. SHINING.[/]"] = 73293329414884,
	["[big]IMPOSSIBLE![/] [beat] [shake]My CROWN![/]"] = 135540097238342,
	["[big]JUDGMENT.[/]"] = 131867250724484,
	["[big]KNEEL![/]"] = 99355506648110,
	["[big]KNEEL.[/]"] = 129933749602646,
	["[big]LET THE ASH RISE.[/]"] = 110024888868576,
	["[big]My GUARDS![/]"] = 91182329513626,
	["[big]My core![/] [beat] [shake]Cracks![/]"] = 94980055077267,
	["[big]Now.[/] [beat] [slow]Now I am [hot]serious[/].[/]"] = 126816294995629,
	["[big]Objection![/] [beat] [shake]Sustained?![/]"] = 133587271609151,
	["[big]PARRY THIS.[/]"] = 84110258530924,
	["[big]RADIATE.[/]"] = 118161852061720,
	["[big]Radiate.[/]"] = 109406766727957,
	["[big]Riposte.[/]"] = 113783234461837,
	["[big]SLEEP.[/]"] = 81364712678464,
	["[big]SPEARFALL.[/]"] = 113832362085696,
	["[big]STARFALL.[/] [beat] [slow]Run.[/]"] = 82573912830159,
	["[big]SUPERNOVA.[/]"] = 106214321879396,
	["[big]Shine![/] [beat] [slow]For as long as you can.[/]"] = 80388263123063,
	["[big]Split.[/]"] = 116198170395234,
	["[big]Stand [shake]aside[/].[/]"] = 116843426060938,
	["[big]TEMPEST.[/]"] = 108174824562726,
	["[big]THE BLADES OF THE FALLEN![/]"] = 139280911033799,
	["[big]THE COURT IS NOW IN SESSION.[/]"] = 85697149372436,
	["[big]THE EARTH PARTS FOR ME![/]"] = 79286336467546,
	["[big]THE HEAVENS SENTENCE YOU.[/]"] = 97402282126427,
	["[big]THE KING'S FIST![/]"] = 86156506469145,
	["[big]THE LAST CUT.[/]"] = 101588877330262,
	["[big]THE OATH DEMANDS IT.[/]"] = 94507780421484,
	["[big]THE ROYAL SCYTHE![/]"] = 99296120654993,
	["[big]THE SKY FALLS![/]"] = 92692300953740,
	["[big]THE SKY FALLS[/] [beat] when I do."] = 132532459497281,
	["[big]THE SKY KNEELS TO ME![/]"] = 82654733874341,
	["[big]THE VERDICT RADIATES.[/]"] = 91986817847044,
	["[big]THE WALL OF FLAME![/]"] = 96679910080557,
	["[big]THE WINTER FALLS.[/]"] = 110063755413278,
	["[big]TUTTI.[/] [beat] All of us. [beat] [shake]ALL.[/]"] = 126621017716523,
	["[big]The circle closes.[/]"] = 85790956621733,
	["[big]The ground... [beat] [hot]opens[/].[/]"] = 87554842656236,
	["[big]Two hands, one [hot]law[/].[/]"] = 80715014156750,
	["[big]VOID COLLAPSE.[/]"] = 119618715840645,
	["[big]WHITEOUT.[/]"] = 138218460551440,
	["[big]You have... [beat] woken it.[/]"] = 110209691012033,
	["[big][shake]DEEP WINTER.[/][/]"] = 81955521739333,
	["[big][shake]EXECUTION.[/][/]"] = 70458477054818,
	["[big][shake]FINALE.[/][/]"] = 90920836817102,
	["[big][shake]HOW DARE YOU STILL STAND?![/][/]"] = 102521917003872,
	["[big][shake]I AM THE FIRE THAT FORGETS NOTHING![/][/]"] = 132091997876674,
	["[big][shake]LAST LIGHT.[/][/]"] = 89859818914207,
	["[big][shake]OBLIVION.[/][/]"] = 109686773234980,
	["[big][shake]RAGNAROK.[/][/]"] = 109433156365048,
	["[big][shake]WRATH.[/][/]"] = 125973974671604,
	["[glitch]BOW. BOW. BOW.[/]"] = 107676593494843,
	["[glitch]Be [beat] un[beat]made.[/]"] = 104465610902726,
	["[glitch]Burn. Burn. Burn.[/]"] = 125621798365269,
	["[glitch]Burn. [beat] Burn. [beat] BURN.[/]"] = 126152700951203,
	["[glitch]EVERYTHING I TOUCH BURNS.[/]"] = 71780304843246,
	["[glitch]Every star I ever lit -- I take them BACK.[/]"] = 111381734303588,
	["[glitch]Fall. [beat] Fall. [beat] Fall.[/]"] = 116212402144112,
	["[glitch]HUSH. HUSH. HUSH.[/]"] = 80164497438112,
	["[glitch]Hush hush hush.[/]"] = 79109086338984,
	["[glitch]I am the storm that [beat] ENDS storms.[/]"] = 133622316188500,
	["[glitch]If I end -- [beat] so does EVERYTHING.[/]"] = 103973988168077,
	["[glitch]Let heaven burn with my enemies.[/]"] = 122668873629926,
	["[glitch]Let the sky itself testify.[/]"] = 88011101078824,
	["[glitch]Lines of the door.[/]"] = 85392474284829,
	["[glitch]Look up.[/]"] = 89012008152570,
	["[glitch]Mi. Re. Do. [beat] Down.[/]"] = 117949138475496,
	["[glitch]Ninety-nine. [beat] Ninety-nine. [beat] Ninety-nine.[/]"] = 121850441357898,
	["[glitch]No more courtesy.[/]"] = 97418096468515,
	["[glitch]No more mercy. No more weather. [beat] Only [hot]verdict[/].[/]"] = 89102359850224,
	["[glitch]STOP BEING A COWARD.[/]"] = 79169330561584,
	["[glitch]Sloppy.[/]"] = 98629017254967,
	["[glitch]Stop making me do this.[/]"] = 111493875164787,
	["[glitch]Strike that from the record.[/] [beat] [shake]Strike YOU.[/]"] = 120481946639517,
	["[glitch]THE SENTENCE IS NOT NEGOTIABLE.[/]"] = 126365444814386,
	["[glitch]Tempo. TEMPO. TEMPO.[/]"] = 136337639866262,
	["[glitch]The sentence is [beat] passed.[/]"] = 138025807879501,
	["[glitch]The song ends when [beat] YOU do.[/]"] = 93445999406353,
	["[glitch]We remember what the water said.[/]"] = 102333194934691,
	["[glitch]Wrong.[/] [beat] [hot]Wrong.[/] [beat] [shake]WRONG.[/]"] = 121990541570539,
	["[hot]Careless[/]."] = 92077091457412,
	["[hot]Evidence![/] [beat] [shake]Submitted![/]"] = 123005311893883,
	["[hot]Good.[/] [beat] [slow]That was good.[/]"] = 72570299861082,
	["[hot]Interesting.[/] [beat] The ledger [shake]shifts[/]."] = 99219732874566,
	["[hot]Oh.[/] [beat] You can hold a [slow]rhythm[/]."] = 85012745838975,
	["[shake]A hundred lines of dark. [beat] Pick one.[/]"] = 76933142552522,
	["[shake]Ash![/] [beat] [hot]All of you, ash![/]"] = 82487843476038,
	["[shake]BOTH FISTS.[/]"] = 103033188921797,
	["[shake]Both of you.[/]"] = 135589722584339,
	["[shake]Cold... [beat] [hot]spilling[/]...[/]"] = 133688877533975,
	["[shake]Crack...[/] [beat] [slow]so [hot]loud[/].[/]"] = 119507610356958,
	["[shake]DELAY IS CONTEMPT OF COURT.[/]"] = 108319575414793,
	["[shake]DOWN![/]"] = 95020045221175,
	["[shake]Do not rise.[/]"] = 102184988116189,
	["[shake]Every cloud I own -- [beat] at once.[/]"] = 108330832155790,
	["[shake]Every star I ever lit -- falls.[/]"] = 88439076063006,
	["[shake]Fall through.[/]"] = 80202475258746,
	["[shake]Gravity is [slow]patient[/].[/]"] = 127664543053576,
	["[shake]Guards! GUARDS![/]"] = 85175885912521,
	["[shake]Light... [beat] leaking...[/]"] = 118444507756335,
	["[shake]My guard...[/] [beat] [hot]opened[/]."] = 76190956352925,
	["[shake]My patience is MOLTEN![/]"] = 74545988949572,
	["[shake]Not yet, not yet--[/]"] = 92075940768126,
	["[shake]One line of light. [beat] Let it find you.[/]"] = 116128305019380,
	["[shake]Run along the [hot]crack[/].[/]"] = 140351240078448,
	["[shake]STOP MOVING.[/]"] = 87347288974948,
	["[shake]Salute![/]"] = 78843189176351,
	["[shake]Split![/]"] = 95017692596026,
	["[shake]Strike, strike, strike.[/]"] = 79511725109143,
	["[shake]Sustained.[/]"] = 109108822457468,
	["[shake]TREMBLE.[/]"] = 103564555393868,
	["[shake]The chord... [beat] fractures![/]"] = 102185762957548,
	["[shake]The gavel breaks![/]"] = 89409513336895,
	["[shake]The mountain remembers [hot]fire[/].[/]"] = 118313133880008,
	["[shake]You DARE bleed on my floor?[/]"] = 92756583340292,
	["[shake]You are OFF THE BEAT.[/]"] = 127996947551352,
	["[shake]You are a [hot]spark[/]. [beat] Why will you [slow]not go out[/]?[/]"] = 136207580086758,
	["[shake]You are being [hot]tedious[/].[/]"] = 70997300939892,
	["[shake]You are off-key.[/]"] = 117181994090252,
	["[shake]You are stalling the dark.[/] [beat] Every minute [hot]costs the world[/]."] = 126816518954397,
	["[slow]A [hot]barrier[/] of [shake]blades[/].[/]"] = 83240217750374,
	["[slow]A [hot]constellation[/] closes.[/]"] = 93688494279684,
	["[slow]A [hot]crack[/] in the [wave]sky[/].[/]"] = 75811862810931,
	["[slow]A [hot]line[/] of [shake]steel[/].[/]"] = 91980056535579,
	["[slow]A cell is a kindness[/], compared to the door."] = 78765790212821,
	["[slow]A line of [hot]starlight[/].[/]"] = 104263499386514,
	["[slow]A path... [beat] [hot]to judgement[/].[/]"] = 110436547380326,
	["[slow]A salute, [hot]unseen[/].[/]"] = 137258223133375,
	["[slow]A star lands.[/]"] = 138170849380212,
	["[slow]A star[/] [beat] remembers what it was."] = 101083217590853,
	["[slow]A throne is[/] [hot]heating[/] beneath me."] = 85317003164610,
	["[slow]Again, from the top.[/]"] = 103680629948375,
	["[slow]Again.[/]"] = 119444497290962,
	["[slow]An opponent.[/] [beat] [hot]At last.[/]"] = 84102784853344,
	["[slow]Approach the bench.[/]"] = 126898435489994,
	["[slow]Attend your king.[/]"] = 127673642789589,
	["[slow]Bow low,[/] and the blade [hot]passes[/]."] = 78820245583295,
	["[slow]Breathe out. [beat] [hot]Feel it spread.[/][/]"] = 74273564554166,
	["[slow]Come to me.[/]"] = 135293146795656,
	["[slow]Come.[/] [beat] I am only a [hot]door[/]."] = 136623025216080,
	["[slow]Cooled... [beat] by a [hot]peasant[/].[/]"] = 119828572356744,
	["[slow]Dim.[/]"] = 90821796569848,
	["[slow]Do you know [hot]how cold[/] the dark is?[/]"] = 110931126217315,
	["[slow]Down.[/]"] = 120409141930563,
	["[slow]Duck.[/] [beat] [hot]Or do not.[/]"] = 86421663187609,
	["[slow]Each one is a [hot]word[/] I could not say.[/]"] = 107248800629072,
	["[slow]Even motion [beat] stops.[/]"] = 133582508141182,
	["[slow]Every direction is [hot]a thrust[/].[/]"] = 126913531197383,
	["[slow]Everything circles [hot]something[/].[/]"] = 119239997500067,
	["[slow]Everything falls toward the [hot]light[/].[/]"] = 139650644712353,
	["[slow]Everything folds [beat] toward nothing.[/]"] = 89964469911221,
	["[slow]Everything must come down eventually.[/]"] = 121589697145209,
	["[slow]Fair is fair: [hot]a few more blades[/].[/]"] = 95343576142154,
	["[slow]Fall toward me.[/]"] = 108416091934976,
	["[slow]Fetch the accused.[/]"] = 72186131370333,
	["[slow]Find the dark. [beat] Hide in the [hot]dark[/].[/]"] = 88002663415216,
	["[slow]Follow the crack...[/]"] = 131909912821939,
	["[slow]Gather round the [wave]warm thing[/].[/]"] = 74935578096876,
	["[slow]Go to sleep.[/]"] = 133502144396984,
	["[slow]Guilty.[/]"] = 110128051979516,
	["[slow]Hold still.[/]"] = 76580741684505,
	["[slow]I am [hot]ready[/] when you are.[/]"] = 104736982044163,
	["[slow]I am [hot]waiting[/], peasant.[/]"] = 135556243698661,
	["[slow]I am so sorry.[/]"] = 79021078998312,
	["[slow]I am the Seraph.[/] [beat] The sky keeps a [hot]ledger[/]."] = 100740064614654,
	["[slow]I am the Warden.[/] [beat] I was asked to hold one door. [beat] Just [hot]one[/]."] = 85567425714479,
	["[slow]I can hear your [hot]heartbeat[/].[/] [beat] [wave]It is so loud.[/]"] = 123008885776718,
	["[slow]I judged you wrongly.[/] [beat] [hot]How novel[/]."] = 76614082165479,
	["[slow]I only ever need [hot]one[/].[/]"] = 75594649532717,
	["[slow]I will not follow.[/] [beat] [wave]Winter does not need to.[/]"] = 90377008418612,
	["[slow]I would have kept you [hot]safe[/].[/] [beat] [whisper]Forever.[/]"] = 95127281456220,
	["[slow]I yield... [beat] [hot]a point[/].[/]"] = 75617247785322,
	["[slow]It is not [shake]safe[/] there.[/]"] = 139720768896136,
	["[slow]Little [hot]suns[/], [beat] attend.[/]"] = 116875308978389,
	["[slow]Little warm thing.[/] [beat] You have [hot]come so far[/]."] = 105924095645349,
	["[slow]Make a wish.[/]"] = 90582695240154,
	["[slow]Overruled.[/]"] = 124228600668841,
	["[slow]Practise.[/]"] = 108183763818297,
	["[slow]Rest.[/]"] = 71044431711737,
	["[slow]Seconds![/] [beat] [hot]To me.[/]"] = 84652336905742,
	["[slow]Sleep. [beat] I will keep you [hot]forever[/].[/]"] = 113348343258868,
	["[slow]So that is what [hot]pain[/] is.[/]"] = 106209981891739,
	["[slow]Something very old is [hot]turning over[/] in its sleep.[/]"] = 79732537590610,
	["[slow]Stay. [beat] [hot]Just a little longer.[/][/]"] = 91817037793534,
	["[slow]Step wherever you like.[/] [beat] It opens there."] = 97056529484705,
	["[slow]Swords rain[/] on [hot]the unworthy[/]."] = 123536110267445,
	["[slow]Take the blade.[/] [beat] [hot]It was always meant for a worthier hand.[/]"] = 75304598574578,
	["[slow]Tell whoever comes after:[/] [beat] the door was never locked [hot]against us[/]. [beat] It was locked [hot]for us[/]."] = 114355659858067,
	["[slow]Thank you for the last note.[/] [beat] We never could [hot]finish it[/]."] = 77759423599875,
	["[slow]Thank you. [beat] The dark is [hot]gentle[/].[/]"] = 114828042736918,
	["[slow]The [hot]line[/] of the law.[/]"] = 95864309762275,
	["[slow]The [hot]thrust[/].[/]"] = 122020561651464,
	["[slow]The air [hot]hums[/] with an old, enormous light.[/]"] = 102542087611607,
	["[slow]The court awaits the accused.[/]"] = 120011465618563,
	["[slow]The court is adjourned.[/] [beat] [hot]Not dismissed[/]."] = 75702731220367,
	["[slow]The dawn will [hot]not[/] come for me.[/]"] = 136845246636315,
	["[slow]The duel is [hot]suspended[/].[/] [beat] I [wave]shall return[/] for [hot]satisfaction[/]."] = 139577457382294,
	["[slow]The ground was only ever a [hot]lid[/].[/]"] = 122584147866572,
	["[slow]The sea has rings too.[/]"] = 127505633768316,
	["[slow]The throne is yours.[/] [beat] It was never [hot]comfortable[/]."] = 103931771836329,
	["[slow]The walls will [hot]hold you[/].[/]"] = 117495934063920,
	["[slow]This is your [hot]requiem[/].[/]"] = 122436705984537,
	["[slow]Touché.[/]"] = 80330905709132,
	["[slow]Two [hot]cuts[/].[/]"] = 93144089859743,
	["[slow]Well... [beat] [hot]struck[/].[/]"] = 70994669868263,
	["[slow]Where do you think you are going?[/]"] = 121661154445816,
	["[slow]Within the [hot]ring[/].[/]"] = 120753761648983,
	["[slow]You are [hot]remanded[/].[/]"] = 98388717413759,
	["[wave]A [hot]spark[/] against the sun.[/]"] = 132255636801626,
	["[wave]A cradle of ice.[/]"] = 126282004815993,
	["[wave]A duel needs a proper [hot]ring[/].[/]"] = 139409168777537,
	["[wave]A line... [beat] [hot]drawn[/].[/]"] = 91568520555234,
	["[wave]Be a good fire.[/] [beat] [hot]Go out.[/]"] = 125676366456787,
	["[wave]Come closer.[/]"] = 75472063197054,
	["[wave]Come, my [hot]embers[/].[/]"] = 86004182520342,
	["[wave]Dance well. [beat] It is your last.[/]"] = 110673061229248,
	["[wave]Diminuendo...[/]"] = 111986169693770,
	["[wave]Do not step outside the stars.[/]"] = 130634138023130,
	["[wave]Do not struggle.[/]"] = 87150976648867,
	["[wave]Do you know how long I have waited for a worthy [hot]opponent[/]?[/]"] = 92936755709292,
	["[wave]Does no one else dare approach the crown?[/]"] = 75399825092177,
	["[wave]Each bolt, a [slow]witness[/].[/]"] = 114235995888464,
	["[wave]Echo... [beat] echo... [beat] [hot]echo[/].[/]"] = 128292454603790,
	["[wave]Every flower, a little [hot]grave[/].[/]"] = 118032402865559,
	["[wave]Every key I buried is humming.[/]"] = 70946322943824,
	["[wave]Every ray, a [hot]memory[/].[/]"] = 120816277224050,
	["[wave]Every voice at once -- [beat] [hot]LISTEN[/].[/]"] = 81394213229079,
	["[wave]Every voice, a [hot]ray[/].[/]"] = 134086608142785,
	["[wave]Every wish [slow]must land[/] somewhere.[/]"] = 109244577724667,
	["[wave]Everything falls inward, eventually.[/]"] = 77555100159852,
	["[wave]Flat.[/]"] = 80922603787849,
	["[wave]Follow it.[/]"] = 121941739525807,
	["[wave]Follow the lightning to its [hot]source[/].[/]"] = 135275252839853,
	["[wave]From the centre outward.[/]"] = 113507711931750,
	["[wave]Gentlemen... [beat] [hot]join the duel.[/][/]"] = 89447132761257,
	["[wave]Hail like [hot]tears[/].[/]"] = 108124025329384,
	["[wave]Hear the beating between two notes?[/]"] = 77468710495895,
	["[wave]Hold it... [beat] hold it... [beat] let go.[/]"] = 127319472384152,
	["[wave]How quaint.[/]"] = 127213652447258,
	["[wave]I fade... [beat] to [slow]return[/].[/]"] = 130008502286129,
	["[wave]I miss the [hot]others[/].[/]"] = 111244642975911,
	["[wave]It will not hurt for long.[/]"] = 115799121887604,
	["[wave]La... la... [beat] la.[/]"] = 73301216206983,
	["[wave]Let it rain... [beat] [hot]gently[/].[/]"] = 139282502435015,
	["[wave]Listen to the [hot]ice sing[/].[/]"] = 91313810113458,
	["[wave]Look up tonight. [beat] [hot]One fewer[/].[/]"] = 82944894900899,
	["[wave]No way out but through me.[/]"] = 77080435504405,
	["[wave]Noted.[/]"] = 131285512637777,
	["[wave]Nothing leaves. [beat] Not even light.[/]"] = 90384388794528,
	["[wave]Orbits.[/]"] = 90429922193705,
	["[wave]Predictable.[/]"] = 125521800912982,
	["[wave]Rifts, rifts, rifts.[/]"] = 114277168593717,
	["[wave]Ripples in the [hot]frozen lake[/].[/]"] = 86639639315863,
	["[wave]Ripples, ripples, ripples.[/]"] = 77641973167726,
	["[wave]Sing the others awake.[/]"] = 77593252659212,
	["[wave]Snow remembers everyone.[/]"] = 107803682705895,
	["[wave]Sparks, [hot]falling[/].[/]"] = 90981353369721,
	["[wave]Staccato.[/]"] = 104816126812636,
	["[wave]Stand in the light and be [hot]weighed[/].[/]"] = 102217515496282,
	["[wave]Thaw... [beat] [slow]gently.[/][/]"] = 86191046078593,
	["[wave]The bars are made of [hot]weather[/].[/]"] = 81309465291197,
	["[wave]The cold has a [hot]lullaby[/].[/]"] = 70794396838138,
	["[wave]The door is shut again.[/] [beat] I am, [slow]as ever[/], [hot]sorry[/]."] = 71230321491462,
	["[wave]Thunder is only a verdict... [beat] [hot]clearing its throat[/].[/]"] = 115358183728639,
	["[wave]Too slow.[/]"] = 104027524818160,
	["[wave]We sink, we sink, we [slow]sing[/] beneath.[/]"] = 121401771969485,
	["[wave]We were a hundred voices.[/] [beat] The sea took [hot]ninety-nine[/]."] = 87878526897512,
	["[wave]You will be heard.[/] [beat] [slow]Briefly.[/]"] = 133873939722592,
	["[whisper]All things drift... [beat] [hot]toward the cold[/].[/]"] = 115463941155737,
	["[whisper]At last... [beat] the watch is [wave]relieved[/].[/]"] = 99182428084650,
	["[whisper]Come closer. [beat] I will not bite.[/] [beat] [glitch]I will not.[/]"] = 122068599669131,
	["[whisper]Come up, come up.[/]"] = 72014726316216,
	["[whisper]Come, little [hot]snows[/].[/]"] = 109170824712845,
	["[whisper]Come, little shadows.[/]"] = 81523599347870,
	["[whisper]Come, little storms.[/]"] = 87582522542573,
	["[whisper]Do you hear it? [beat] Under the water?[/]"] = 127819072589406,
	["[whisper]Don't look back.[/]"] = 106641403092265,
	["[whisper]Easy... [beat] easy...[/]"] = 73389775008921,
	["[whisper]Every star you have ever wished upon... [beat] is [hot]me[/].[/]"] = 139738213839085,
	["[whisper]Four hundred winters... and the lock [wave]finally[/] gives.[/]"] = 97841360420794,
	["[whisper]Frost, [hot]blooming[/].[/]"] = 85555516333818,
	["[whisper]Hold still for the last note.[/]"] = 107482149553106,
	["[whisper]Hush... [beat] [wave]hush[/]...[/]"] = 125552388487165,
	["[whisper]I am not angry.[/] [beat] [slow]I am only [hot]so tired[/] of the [shake]noise[/].[/]"] = 88749484228850,
	["[whisper]I have your name here somewhere.[/]"] = 71863647850885,
	["[whisper]I was never... [beat] meant to... [beat] [wave]shine[/]...[/]"] = 72381060383740,
	["[whisper]Icicles, [hot]falling[/].[/]"] = 130629312185530,
	["[whisper]It is almost over.[/]"] = 71015436032427,
	["[whisper]It is already in your [hot]bones[/].[/]"] = 125942968902063,
	["[whisper]La... [wave]la[/]... [beat] la--[/]"] = 120041632956033,
	["[whisper]No sky. [beat] No ground. [beat] Only [hot]cold[/].[/]"] = 77813558319127,
	["[whisper]Oh... [beat] [wave]so that is what [hot]warmth[/] is.[/]"] = 130764663966418,
	["[whisper]Quiet... [beat] so [wave]quiet[/]...[/]"] = 89872069060741,
	["[whisper]Remember me as... [beat] [wave]warm[/].[/]"] = 138040562055120,
	["[whisper]Shh.[/]"] = 125340969296577,
	["[whisper]Sleep. Sleep. Sleep.[/]"] = 115393330713030,
	["[whisper]Snow is falling in a place you cannot see.[/]"] = 138065344024246,
	["[whisper]Something vast is... [wave]remembering itself[/].[/]"] = 97518644336801,
	["[whisper]Steel... [beat] [wave]remembers[/] its hand.[/]"] = 140060379855926,
	["[whisper]The air [wave]clears[/]... [beat] to be [hot]read[/].[/]"] = 109748070649082,
	["[whisper]The door is listening.[/]"] = 138063735708956,
	["[whisper]The duel is [wave]concluded[/].[/] [beat] [slow]I am [hot]released[/].[/]"] = 71668801032535,
	["[whisper]The ledger... [beat] [wave]blank[/].[/]"] = 87488401013305,
	["[whisper]The oath weighs on me. [beat] [slow]Lend me your steel.[/][/]"] = 132366073527441,
	["[whisper]There. [beat] [hot]Safe.[/][/]"] = 127748813495979,
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
-- ASTRAEON, THE UNMADE STAR (Starforge Dais): the mega boss. A shattered star given a body: vast
-- health, four phases, every kind of attack the others use, and ULTIMATES: arena-wide set pieces
-- announced on screen and telegraphed for seconds. Fight it in a crowd: it is built for many fighters.
local Astraeon = bossFrom(SanctuaryConfig.RiftBoss, {
	Name = "Astraeon, the Unmade Star",
	Kind = "Astraeon",
	Title = "What the sky forgot to finish",
	Island = "AstraIsle",
	Approach = "Cross the Riftmaw's far south-eastern bridge to the Starforge Dais.",
	Cues = {
		Forming = "wardenForming",
		Awake = "domainImpact",
		Charge = "bootSlamCharge",
		Land = "bootImpact",
		Phase = "domainCrack",
		Defeat = "prestige",
		Escape = "wardenEscape",
	},
	Music = { Bed = "amb_heart", Id = 0, Pitch = 0.62, Level = 0.6, Effect = "Reverb" },
	Theme = {
		Primary = { 255, 214, 120 },
		Hot = { 255, 246, 214 },
		Alert = { 110, 170, 255 },
	},
	Phases = { 0.75, 0.5, 0.25 },
	PhaseDelayScale = { 1, 0.85, 0.7, 0.55 },
	BaseHealth = 4200,
	HealthPerFighter = 1800,
	CrowdHealth = 10400,
	FormingSeconds = 60,
	ActiveSeconds = 480,
	SlamRadius = 32,
	SlamIntervalMin = 5,
	SlamIntervalMax = 8,
	DazeSeconds = 2.4,
	Rewards = {
		Stardust = { Base = 300, Share = 2400 },
		Starsteel = { Base = 12, Share = 40 },
		Emberite = { Base = 20, Share = 45 },
		Voidglass = { Base = 18, Share = 40 },
	},
	Attacks = {
		{ Kind = "Slam", Weight = 1 },
		{ Kind = "Volley", Weight = 1, Params = { Count = 6, StepSeconds = 0.3, Scatter = 10, RadiusScale = 0.6, TelegraphSeconds = 1.6, Element = "Fire" } },
		{ Kind = "Fissure", Weight = 0.9, Params = { Count = 7, FirstDistance = 14, Gap = 10, StepSeconds = 0.12, RadiusScale = 0.5, TelegraphSeconds = 1.6, Element = "Storm" } },
		{ Kind = "Cage", Weight = 0.8, MinPhase = 2, Params = { Count = 8, Distance = 17, RadiusScale = 0.5, TelegraphSeconds = 2, Element = "Void" } },
		{ Kind = "Starburst", Weight = 0.9, MinPhase = 2, Params = { Rings = 3, Points = 4, FirstDistance = 16, Gap = 16, StepSeconds = 0.45, RadiusScale = 0.45, TelegraphSeconds = 1.9, Element = "Fire" } },
		{ Kind = "Rings", Weight = 0.8, MinPhase = 2, Params = { Count = 4, FirstRadius = 14, Gap = 13, Width = 5, StepSeconds = 0.5, TelegraphSeconds = 2.2 } },
		{ Kind = "Lances", Weight = 0.9, MinPhase = 2, Params = { Count = 6, HalfWidth = 0.065, Range = 100, TelegraphSeconds = 1.8 } },
		{ Kind = "Summon", Weight = 0.7, MinPhase = 2, Params = { Count = 6, Health = 120, FuseSeconds = 9, Orbit = 40, OrbitSpeed = 0.6, BlastRadius = 12, TelegraphSeconds = 1.4, Element = "Fire" } },
		{ Kind = "Meteors", Weight = 1, MinPhase = 3, Params = { Count = 12, StepSeconds = 0.26, RadiusScale = 0.6, TelegraphSeconds = 1.9, Element = "Fire" } },
		{ Kind = "GravityWell", Weight = 0.8, MinPhase = 3, Params = { Radius = 36, Core = 16, PullSeconds = 3, Strength = 36, TelegraphSeconds = 0.8 } },
		{ Kind = "Lances", Weight = 1, MinPhase = 4, Params = { Count = 10, HalfWidth = 0.055, Range = 100, TelegraphSeconds = 1.6 } },
	},
	-- Ultimates are never rolled like ordinary attacks: they come at phase changes, every UltimateEvery
	-- seconds from phase 3, and as a last stand (FinalStand) when it is nearly beaten. Each is announced.
	Ultimates = {
		Starfall = { Kind = "Meteors", Params = { Count = 26, StepSeconds = 0.15, RadiusScale = 0.8, TelegraphSeconds = 2.8, Element = "Fire" } },
		Supernova = { Kind = "Dissonance", Params = { Zones = 2, ZoneRadius = 11, TelegraphSeconds = 6.5 } },
		EventHorizon = { Kind = "GravityWell", Params = { Radius = 66, Core = 26, PullSeconds = 5, Strength = 50, TelegraphSeconds = 1.8 } },
		AnnihilationBeam = { Kind = "Lances", Params = { Count = 14, HalfWidth = 0.05, Range = 120, TelegraphSeconds = 3.4 } },
		LastLight = { Chain = { "Starfall", "Supernova" } },
	},
	PhaseUltimates = { [2] = "Starfall", [3] = "Supernova", [4] = "EventHorizon" },
	UltimateRoster = { "Starfall", "Supernova", "AnnihilationBeam", "EventHorizon" },
	UltimateEvery = 36,
	FinalStand = "LastLight",
	Dialogue = {
		Forming = { "[whisper]Something vast is... [wave]remembering itself[/].[/]", "[slow]The air [hot]hums[/] with an old, enormous light.[/]" },
		Awake = { "[slow]A star[/] [beat] remembers what it was.", "I was the light that taught your sky to [hot]shine[/]. [beat] Now I am only its [shake]ending[/].", "[big]Come, small fires.[/] [beat] [slow]Burn with me.[/]" },
		Phase2 = { "You are brighter than I [hot]expected[/].", "Then let me show you [slow]what light does[/] when it is [shake]angry[/]." },
		Phase3 = { "[big]THE SKY FALLS[/] [beat] when I do.", "[glitch]Every star I ever lit -- I take them BACK.[/]" },
		Defeat = { "[whisper]I was never... [beat] meant to... [beat] [wave]shine[/]...[/]", "[slow]Thank you. [beat] The dark is [hot]gentle[/].[/]", "[wave]Look up tonight. [beat] [hot]One fewer[/].[/]" },
		Escape = { "[slow]The dawn will [hot]not[/] come for me.[/]", "[wave]I fade... [beat] to [slow]return[/].[/]" },
		Enrage = { "[shake]You are a [hot]spark[/]. [beat] Why will you [slow]not go out[/]?[/]", "[glitch]EVERYTHING I TOUCH BURNS.[/]", "[big]I CANNOT. STOP. SHINING.[/]" },
		Break = { "[big]My core![/] [beat] [shake]Cracks![/]", "[slow]So that is what [hot]pain[/] is.[/]", "[shake]Light... [beat] leaking...[/]" },
		Hit = { "[slow]Dim.[/]", "[wave]A [hot]spark[/] against the sun.[/]", "[shake]Gravity is [slow]patient[/].[/]", "[slow]Fall toward me.[/]", "I have [hot]watched empires[/] smaller than you.", "[wave]Be a good fire.[/] [beat] [hot]Go out.[/]", "[slow]I am so sorry.[/]", "[glitch]Fall. [beat] Fall. [beat] Fall.[/]", "[whisper]It is almost over.[/]", "[big]Shine![/] [beat] [slow]For as long as you can.[/]" },
		Stagger = { "[slow]Rise, little fire.[/] [beat] {name}. [beat] [hot]Rise[/].", "[wave]{name}... [beat] [slow]I knew a thousand like you.[/][/]", "[whisper]Do not be [hot]afraid[/], {name}.[/]", "[slow]Even {name} will dim.[/] [beat] [hot]Even I.[/]", "{name}. [beat] [slow]Light your own way back.[/]" },
		Idle = { "[whisper]Every star you have ever wished upon... [beat] is [hot]me[/].[/]", "[slow]Do you know [hot]how cold[/] the dark is?[/]", "[wave]I miss the [hot]others[/].[/]", "[slow]Stay. [beat] [hot]Just a little longer.[/][/]" },
		Ultimate = {
			Starfall = { "[big]STARFALL.[/] [beat] [slow]Run.[/]", "[shake]Every star I ever lit -- falls.[/]" },
			Supernova = { "[big]SUPERNOVA.[/]", "[slow]Find the dark. [beat] Hide in the [hot]dark[/].[/]" },
			EventHorizon = { "[big]EVENT HORIZON.[/]", "[wave]Nothing leaves. [beat] Not even light.[/]" },
			AnnihilationBeam = { "[big]ANNIHILATION.[/]", "[shake]One line of light. [beat] Let it find you.[/]" },
			LastLight = { "[big][shake]LAST LIGHT.[/][/]", "[glitch]If I end -- [beat] so does EVERYTHING.[/]" },
		},
		Attack = {
			Slam = { "[big]FALL.[/]", "[slow]A star lands.[/]" },
			Volley = { "[wave]Sparks, [hot]falling[/].[/]", "[slow]Make a wish.[/]" },
			Fissure = { "[slow]A [hot]crack[/] in the [wave]sky[/].[/]", "[big]The ground... [beat] [hot]opens[/].[/]" },
			Cage = { "[slow]A [hot]constellation[/] closes.[/]", "[wave]Do not step outside the stars.[/]" },
			Starburst = { "[big]RADIATE.[/]", "[wave]Every ray, a [hot]memory[/].[/]" },
			Rings = { "[wave]Orbits.[/]", "[slow]Everything circles [hot]something[/].[/]" },
			Lances = { "[slow]A line of [hot]starlight[/].[/]", "[big]Stand [shake]aside[/].[/]" },
			Summon = { "[wave]Come, my [hot]embers[/].[/]", "[slow]Little [hot]suns[/], [beat] attend.[/]" },
			Meteors = { "[big]THE SKY FALLS![/]", "[wave]Every wish [slow]must land[/] somewhere.[/]" },
			GravityWell = { "[slow]Everything falls toward the [hot]light[/].[/]", "[wave]Come closer.[/]" },
		},
	},
})
Astraeon.Combos = {
	{ After = "Volley", Then = "Fissure", Chance = 0.45, MinPhase = 1 },
	{ After = "Slam", Then = "Starburst", Chance = 0.45, MinPhase = 2 },
	{ After = "Cage", Then = "Meteors", Chance = 0.5, MinPhase = 3 },
	{ After = "Rings", Then = "Lances", Chance = 0.5, MinPhase = 2 },
	{ After = "Meteors", Then = "GravityWell", Chance = 0.45, MinPhase = 3 },
}
-- Ultimates for the other bosses (see Astraeon's for the rules): announced, never rolled, queued at phase changes,
-- on a timer from phase 3 and once as a last stand.
SanctuaryConfig.RiftBoss.Ultimates = {
	VoidCollapse = { Kind = "GravityWell", Params = { Radius = 52, Core = 20, PullSeconds = 4.5, Strength = 44, TelegraphSeconds = 1.6 } },
	Spearfall = { Kind = "Lances", Params = { Count = 12, HalfWidth = 0.05, Range = 100, TelegraphSeconds = 3 } },
	Oblivion = { Chain = { "VoidCollapse", "Spearfall" } },
}
SanctuaryConfig.RiftBoss.PhaseUltimates = { [3] = "VoidCollapse" }
SanctuaryConfig.RiftBoss.UltimateRoster = { "VoidCollapse", "Spearfall" }
SanctuaryConfig.RiftBoss.UltimateEvery = 45
SanctuaryConfig.RiftBoss.FinalStand = "Oblivion"

HollowChoir.Ultimates = {
	Crescendo = { Kind = "Rings", Params = { Count = 6, FirstRadius = 12, Gap = 12, Width = 5, StepSeconds = 0.45, TelegraphSeconds = 2.6 } },
	Requiem = { Kind = "Dissonance", Params = { Zones = 4, ZoneRadius = 12, TelegraphSeconds = 5 } },
	Finale = { Chain = { "Crescendo", "Requiem" } },
}
HollowChoir.PhaseUltimates = { [3] = "Crescendo" }
HollowChoir.UltimateRoster = { "Crescendo", "Requiem" }
HollowChoir.UltimateEvery = 45
HollowChoir.FinalStand = "Finale"

CinderRegent.Ultimates = {
	Eruption = { Kind = "Meteors", Params = { Count = 20, StepSeconds = 0.17, RadiusScale = 0.75, TelegraphSeconds = 2.4, Element = "Fire" } },
	Cataclysm = { Kind = "Fissure", Params = { Count = 9, FirstDistance = 10, Gap = 8, StepSeconds = 0.08, RadiusScale = 0.6, TelegraphSeconds = 2.6, Element = "Fire" } },
	Ragnarok = { Chain = { "Eruption", "Cataclysm" } },
}
CinderRegent.PhaseUltimates = { [3] = "Eruption" }
CinderRegent.UltimateRoster = { "Eruption", "Cataclysm" }
CinderRegent.UltimateEvery = 42
CinderRegent.FinalStand = "Ragnarok"

StormSeraph.Ultimates = {
	Judgment = { Kind = "Lances", Params = { Count = 14, HalfWidth = 0.05, Range = 100, TelegraphSeconds = 3 } },
	Tempest = { Kind = "Meteors", Params = { Count = 18, StepSeconds = 0.16, RadiusScale = 0.65, TelegraphSeconds = 2.4, Element = "Storm" } },
	Wrath = { Chain = { "Tempest", "Judgment" } },
}
StormSeraph.PhaseUltimates = { [3] = "Tempest" }
StormSeraph.UltimateRoster = { "Judgment", "Tempest" }
StormSeraph.UltimateEvery = 40
StormSeraph.FinalStand = "Wrath"

Rimeheart.Ultimates = {
	Whiteout = { Kind = "Cage", Params = { Count = 12, Distance = 20, RadiusScale = 0.6, TelegraphSeconds = 2.8, Element = "Frost" } },
	AbsoluteZero = { Kind = "GravityWell", Params = { Radius = 56, Core = 22, PullSeconds = 4.5, Strength = 40, TelegraphSeconds = 1.6 } },
	DeepWinter = { Chain = { "Whiteout", "AbsoluteZero" } },
}
Rimeheart.PhaseUltimates = { [3] = "Whiteout" }
Rimeheart.UltimateRoster = { "Whiteout", "AbsoluteZero" }
Rimeheart.UltimateEvery = 45
Rimeheart.FinalStand = "DeepWinter"

UmbralKnight.Ultimates = {
	Duel = { Kind = "Sweep", Params = { Seconds = 6, Speed = 1.4, HalfWidth = 0.22, Range = 90, TelegraphSeconds = 1.8 } },
	LastCut = { Kind = "Starburst", Params = { Rings = 3, Points = 6, FirstDistance = 14, Gap = 16, StepSeconds = 0.4, RadiusScale = 0.5, TelegraphSeconds = 2.2, Element = "Void" } },
	Execution = { Chain = { "Duel", "LastCut" } },
}
UmbralKnight.PhaseUltimates = { [3] = "Duel" }
UmbralKnight.UltimateRoster = { "Duel", "LastCut" }
UmbralKnight.UltimateEvery = 40
UmbralKnight.FinalStand = "Execution"
-- How each boss walks (studs per second) and how close it likes to stand to whoever it is fighting.
SanctuaryConfig.RiftBoss.WalkSpeed, SanctuaryConfig.RiftBoss.StandOff = 10, 24
HollowChoir.WalkSpeed, HollowChoir.StandOff = 7, 26
CinderRegent.WalkSpeed, CinderRegent.StandOff = 7, 20
StormSeraph.WalkSpeed, StormSeraph.StandOff = 9, 24
Rimeheart.WalkSpeed, Rimeheart.StandOff = 6, 20
UmbralKnight.WalkSpeed, UmbralKnight.StandOff = 15, 14
Astraeon.WalkSpeed, Astraeon.StandOff = 8, 32
-- Each boss's own soundtrack: kind -> uploaded audio id (the fight layer plays it, Music.Id below).
-- BOSS-MUSIC-BEGIN (rewritten by tools/assetgen/upload_boss_music.py)
SanctuaryConfig.BossMusic = {
	Astraeon = 122693395660359,
	Choir = 99711693083649,
	Knight = 132821136179443,
	Regent = 113802436441958,
	Rime = 72121734420253,
	Seraph = 120342418849966,
	Warden = 138383890408892,
}
-- BOSS-MUSIC-END
for _, boss in { SanctuaryConfig.RiftBoss, HollowChoir, CinderRegent, StormSeraph, Rimeheart, UmbralKnight, Astraeon } do
	local track = SanctuaryConfig.BossMusic[boss.Kind]
	if track ~= nil and boss.Music ~= nil then
		boss.Music.Id = track
		boss.Music.Pitch = 1 -- the track is already in tune
	end
end
SanctuaryConfig.RiftBosses = table.freeze({ SanctuaryConfig.RiftBoss, HollowChoir, CinderRegent, StormSeraph, Rimeheart, UmbralKnight, Astraeon })

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
Layout.WORLD_RADIUS = 880
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
		Id = "AstraIsle",
		Name = "The Starforge Dais",
		Center = { X = 240, Y = 30, Z = 730 },
		Radius = 80,
		Top = "Marble",
		Under = "Rock",
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
