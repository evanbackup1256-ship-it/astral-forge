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
local leaveEnd=assert(source:find("\n%s+function GuildService:Disband%(",first))
local kickStart=assert(source:find("\tfunction GuildService:Kick(",leaveEnd,true))
local kickEnd=assert(source:find("\n%s+function GuildService:ContributeBank%(",kickStart))
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
local effectStart=assert(dashboard:find("React.useEffect(function()",1,true))+#"React.useEffect(function()"
local effectEnd=assert(dashboard:find("end,%s*{%s*props%.dispatch,%s*selected,%s*scope,%s*revision%s*}%s*%)",effectStart))
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
