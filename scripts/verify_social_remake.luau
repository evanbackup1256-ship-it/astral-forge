local Math=require("../src/Shared/AstralForge/Shared/OmegaMath")
local Social=require("../src/Shared/AstralForge/Shared/SocialProgression")(Math)
local Request=require("../src/Client/AstralForge/ActionRequest")
for _,actor in {"Leader","Officer","Member"} do
	for _,target in {"Leader","Officer","Member"} do
		assert(Social.canManage({Role=actor},{Role=target},"Role")== (actor=="Leader" and target~="Leader"))
		assert(Social.canManage({Role=actor},{Role=target},"Kick")== ((actor=="Leader" and target~="Leader") or (actor=="Officer" and target=="Member")))
	end
end
local members={ ["1"]={Role="Leader",JoinedAt=1},["9"]={Role="Member",JoinedAt=2},["5"]={Role="Officer",JoinedAt=4},["3"]={Role="Officer",JoinedAt=4}}
assert(Social.successor(members,"1")=="3","officer first, stable ID tie")
members["3"].JoinedAt=5;assert(Social.successor(members,"1")=="5","oldest officer succeeds")
assert(Social.successor({["1"]=members["1"]},"1")==nil)
local hall=Social.hall({Upgrades={a=5,b=7,c=0/0,d=math.huge}})
assert(hall.Level==3 and hall.Points==12 and hall.Remaining==3 and hall.Progress==0.4)
local ranked=Social.rank({{UserId=8,Value="1e1000"},{UserId=2,Value="2e1000"},{UserId=4,Value="1e1000"},{UserId=8,Value=999},{UserId=5,Value=0/0},{UserId=6,Value=-1}})
assert(#ranked==3 and ranked[1].UserId==2 and ranked[2].UserId==4 and ranked[3].UserId==8,"Omega sort, stable tie, dedup, invalid score rejection")
local jobs,callbacks={},{}
local request=Request(function(_,_,callback) table.insert(callbacks,callback) end,function(_,callback) table.insert(jobs,callback) end,function() end)
assert(request.run("test",{}));assert(not request.run("test",{}))
callbacks[1]({ok=false,error="Denied"});assert(not request.busy and request.status=="Denied")
assert(request.run("test",{}));jobs[#jobs]();assert(not request.busy)
callbacks[2]({ok=true});assert(request.status:find("No response",1,true),"late callbacks cannot overwrite timeout")
assert(request.run("test",{}));request.dispose();callbacks[3]({ok=true});assert(not request.busy and not request.run("test",{}))
local throwing=Request(function() error("transport") end,function() end,function() end)
throwing.run("test",{});assert(not throwing.busy and throwing.status:find("Connection",1,true))
print("[TEST] social remake: role policy, deterministic succession, hall progression, Omega ranking, dedup, request latch/timeout/disposal passed")

-- Run the real guild service methods against a memory-only transaction fixture.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local source=fs.readFile("src/Server/AstralForge/Services/CoreServices.luau"):gsub("\r\n","\n")
local first=assert(source:find("\tfunction GuildService:Leave(",1,true))
local leaveEnd=assert(source:find("\n\tfunction GuildService:Disband(",first,true))
local kickStart=assert(source:find("\tfunction GuildService:Kick(",leaveEnd,true))
local kickEnd=assert(source:find("\n\tfunction GuildService:ContributeBank(",kickStart,true))
local factory=luau.load("return function(Social,emptyBonuses) local GuildService={} "..source:sub(first,leaveEnd-1)..source:sub(kickStart,kickEnd-1).." return GuildService end")()
local methods=factory(Social,function() return {} end)
local document={Members={ ["1"]={Role="Leader",JoinedAt=1},["2"]={Role="Officer",JoinedAt=2},["3"]={Role="Member",JoinedAt=3}},OwnerUserId=1}
local service=setmetatable({_update=function(_,_,transform)
	local nextDoc=transform(document)
	return nextDoc~=nil,"Denied",nextDoc
end},{__index=methods})
assert(not service:Kick({UserId=2},{Guild={Id="test"}},1),"officers cannot remove leader")
assert(not service:SetRole({UserId=2},{Guild={Id="test"}},3,"Officer"),"officers cannot promote")
assert(not service:SetRole({UserId=1},{Guild={Id="test"}},1,"Member"),"leader cannot demote self")
assert(service:SetRole({UserId=1},{Guild={Id="test"}},3,"Officer"))
assert(document.Members["3"].Role=="Officer")
local profile={Guild={Id="test"},GuildBonuses={Production=1}}
assert(service:Leave({UserId=1},profile))
assert(document.OwnerUserId==2 and document.Members["2"].Role=="Leader" and document.Members["1"]==nil)
assert(profile.Guild.Id=="" and profile.GuildBonuses.Production==nil)
assert(not service:Leave({UserId=9},{Guild={Id="test"}}),"stale non-member cannot report a successful leave")
print("[TEST] actual guild service fixtures: permission denial, role change, succession, membership cleanup passed")

-- Exercise the real ranks effect with controlled replies and timers.
local dashboard=fs.readFile("src/Client/AstralForge/RankDashboard.luau"):gsub("\r\n","\n")
local refreshStart=assert(dashboard:find("local localId=",1,true))
local effectStart=assert(dashboard:find("React.useEffect(function()",refreshStart,true))+#"React.useEffect(function()"
local effectEnd=assert(dashboard:find("end,{props.dispatch,selected,scope,revision})",effectStart,true))
local effectBody=dashboard:sub(effectStart,effectEnd-1)
for _,guildBoard in {false,true} do
	local scheduled,replies,actions={}, {}, {}
	local result={rows={}}
	local writes=0
	local environment={
		guildBoard=guildBoard,scope="Global",selected=if guildBoard then "Guilds" else "Flux",Social=Social,
		helpers={scoreCounts=function(_,value) return Math.Gt(value,0) end},
		props={dispatch=function(action,_,reply) table.insert(actions,action);table.insert(replies,reply) end},
		setResult=function(value) writes+=1;result=if type(value)=="function" then value(result) else value end,
		task={delay=function(seconds,callback) local job={seconds=seconds,callback=callback};table.insert(scheduled,job);return job end,cancel=function(job) job.cancelled=true end},
	}
	setmetatable(environment,{__index=_G})
	local cleanup=luau.load("return function() "..effectBody.." end",{environment=environment})()()
	assert(#actions==1 and actions[1]==(if guildBoard then "GetGuildLeaderboard" else "GetLeaderboard"))
	local rows=if guildBoard then {{Id="g",Activity=4,Name="Hall"}} else {{UserId=1,Value="1e1000"},{UserId=2,Value=0}}
	replies[1]({ok=true,Leaderboard=rows,GuildLeaderboard=rows})
	assert(#result.rows==1 and not result.loading)
	local refreshJob=scheduled[#scheduled];assert(refreshJob.seconds==30);refreshJob.callback()
	assert(#replies==2 and result.loading)
	local timeout=scheduled[#scheduled-1];assert(timeout.seconds==12);timeout.callback()
	assert(not result.loading and #result.rows==1 and result.status:find("unavailable",1,true),"refresh failure must retain previous rankings")
	local before=writes;replies[2]({ok=true,Leaderboard={}});assert(writes==before,"late callback cannot overwrite failed refresh")
	cleanup();scheduled[#scheduled].callback();assert(#replies==2,"unmounted ranks cannot keep polling")
end
print("[TEST] actual ranks refresh: player/guild queries, zero-score filtering, timeout retention, stale replies, polling cleanup passed")

local matchStart=assert(dashboard:find("local function matchesRank(",1,true))
local matchEnd=assert(dashboard:find("local function bar(",matchStart,true))
local matches=luau.load(dashboard:sub(matchStart,matchEnd-1).."\nreturn matchesRank")()
assert(matches({Name="Pilot [One]",UserId=123},"  PILOT  "))
assert(matches({Name="Pilot [One]"},"[One]"),"search treats pattern characters literally")
assert(matches({Name="Hall",Tag="STAR",Id="guild-9"},"star"))
assert(matches({UserId=123},"123"))
assert(not matches({Name="Pilot"},"unknown"))
local chipStart=assert(dashboard:find("local function chip(",1,true))
local chipEnd=assert(dashboard:find("local function AvatarView(",chipStart,true))
local chip=dashboard:sub(chipStart,chipEnd-1)
assert(chip:find("e(ui.Button",1,true) and not chip:find('e("textbutton"',1,true),"rank filters use shared button chrome, motion and SFX")
assert(dashboard:find('Search=e(ui.SearchField',1,true),"ranks reuse the shared search control")

local avatarStart=assert(dashboard:find("local function AvatarView(",1,true))
local loadStart=assert(dashboard:find("React.useEffect(function()",avatarStart,true))+#"React.useEffect(function()"
local loadEnd=assert(dashboard:find("end,{props.userId,revision})",loadStart,true))
local loadBody=dashboard:sub(loadStart,loadEnd-1)
for _,scenario in {"success","late","failure","late-joints"} do
	local jobs={}
	local viewport={}
	local status
	local warned=false
	local created={}
	local model={destroyed=false,descendants={}}
	function model:Destroy() self.destroyed=true end
	function model:GetDescendants() return self.descendants end
	function model:PivotTo() end
	function model:GetBoundingBox() return {Position="center"},"bounds" end
	local scriptItem={destroyed=false}
	function scriptItem:IsA(class) return class=="LuaSourceContainer" end
	function scriptItem:Destroy() self.destroyed=true end
	local part={Name="HumanoidRootPart"}
	function part:IsA(class) return class=="BasePart" end
	local limb={Name="Head"}
	function limb:IsA(class) return class=="BasePart" end
	model.descendants={scriptItem,part,limb}
	local worker
	local scene={current=nil}
	local environment={
		ref={current=viewport},scene=scene,props={userId=123},
		setStatus=function(value) status=value end,
		Instance={new=function(class)
			local object={class=class,destroyed=false}
			function object:Destroy() self.destroyed=true end
			table.insert(created,object);return object
		end},
		CFrame={new=function() return {} end},
		Players={CreateHumanoidModelFromUserIdAsync=function(_,id)
			assert(id==123);coroutine.yield()
			if scenario=="failure" then error("asset denied") end
			return model
		end},
		task={
			delay=function(_,callback) local job={callback=callback};table.insert(jobs,job);return job end,
			cancel=function(job) job.cancelled=true end,
			spawn=function(callback) worker=coroutine.create(callback);assert(coroutine.resume(worker)) end,
			wait=function() coroutine.yield() end,
		},
		warn=function() warned=true end,
	}
	setmetatable(environment,{__index=_G})
	local cleanup=luau.load("return function() "..loadBody.." end",{environment=environment})()()
	jobs[1].callback()
	assert(status=="Avatar taking too long. Retry.","slow avatar has an explicit retry state")
	if scenario=="late" then cleanup() end
	assert(coroutine.resume(worker))
	if scenario=="late-joints" then cleanup() end
	if coroutine.status(worker)=="suspended" then assert(coroutine.resume(worker)) end
	if scenario=="success" then
		assert(status==nil and scene.current.target=="center")
		assert(model.Parent==created[1] and part.Anchored and limb.Anchored==false and part.CanCollide==false and scriptItem.destroyed,"avatar is presentation-only and accessory welds can settle")
	elseif scenario=="late" or scenario=="late-joints" then
		assert(model.destroyed and scene.current==nil,"late avatar completion is destroyed after unmount or retry")
	else assert(warned and status=="Avatar unavailable. Retry.","avatar failure is visible and logged") end
	if scenario~="late" and scenario~="late-joints" then cleanup() end
	assert(jobs[1].cancelled and created[1].destroyed and created[2].destroyed and viewport.CurrentCamera==nil,"camera, world and deadline cleaned up")
end
print("[TEST] ranks: literal search, shared buttons, real avatar loader success/failure/timeout/stale completion/disposal passed")
local roblox=require("@lune/roblox")
local cameraStart=assert(dashboard:find("React.useEffect(function()",loadEnd,true))+#"React.useEffect(function()"
local cameraEnd=assert(dashboard:find("end,{status,angle,props.reducedMotion})",cameraStart,true))
for _,reducedMotion in {false,true} do
	local camera={FieldOfView=34,CFrame=roblox.CFrame.new()}
	local viewport={AbsoluteSize=roblox.Vector2.new(272,176)}
	local resize
	local disconnected=false
	function viewport:GetPropertyChangedSignal(property)
		assert(property=="AbsoluteSize")
		return {Connect=function(_,callback) resize=callback;return {Disconnect=function() disconnected=true end} end}
	end
	local tween
	local environment={
		ref={current=viewport},scene={current={camera=camera,target=roblox.Vector3.zero,size=roblox.Vector3.new(4,7,2)}},
		angle=30,previousAngle={current=0},props={reducedMotion=reducedMotion},
		Vector3=roblox.Vector3,CFrame=roblox.CFrame,
		Enum={EasingStyle={Quart="Quart"},EasingDirection={Out="Out"}},
		TweenInfo={new=function(seconds) assert(seconds==0.4);return {} end},
		TweenService={Create=function(_,target,_,goal)
			tween={cancelled=false}
			function tween:Play() target.CFrame=goal.CFrame end
			function tween:Cancel() self.cancelled=true end
			return tween
		end},
	}
	setmetatable(environment,{__index=_G})
	local cleanup=luau.load("return function() "..dashboard:sub(cameraStart,cameraEnd-1).." end",{environment=environment})()()
	assert((tween==nil)==reducedMotion,"turns animate only when reduced motion is off")
	assert(camera.CFrame.Position.X>0,"turn changes the viewing angle")
	local before=camera.CFrame.Position.Magnitude
	viewport.AbsoluteSize=roblox.Vector2.new(90,176);resize()
	assert(camera.CFrame.Position.Magnitude>before,"narrow previews fit the full model rather than cropping it")
	cleanup()
	assert(disconnected and (not tween or tween.cancelled),"camera resize and animation resources are disposed")
end
print("[TEST] actual ranks camera: animated/reduced-motion turns, aspect fitting, tween cancellation and resize cleanup passed")
