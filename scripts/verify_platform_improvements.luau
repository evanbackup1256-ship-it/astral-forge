--!nocheck
local Math=require("../src/Shared/AstralForge/Shared/OmegaMath")
local Plan=require("../src/Client/AstralForge/PlanningModel")(Math)
local Schema=require("../src/Shared/AstralForge/Shared/AdminCommandSchema")
local Soundtrack=require("../src/Client/AstralForge/AudioKit")("soundtrack")
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local audioSource=fs.readFile("src/Client/AstralForge/AudioKit.luau")
assert(audioSource:match("ContentProvider:PreloadAsync%(%s*{%s*deck%.sound%s*}"),"warm the actual Sound instance, not just asset-ID strings")
assert(audioSource:find("deck.loadVersion == version",1,true),"late preload callbacks must not fail a newer track")

local loadout,problem=Plan.toggleLoadout({Loadout={"Flux","Strike"},LoadoutSlots=3},"Fortune")
assert(not problem and #loadout==3 and loadout[1]=="Flux" and loadout[2]=="Strike","equipping must retain existing channels")
assert(Plan.toggleLoadout({Loadout=loadout,LoadoutSlots=3},"Vault")==nil,"full loadout must reject a fourth channel")
assert(Plan.toggleLoadout({Loadout={"Flux"},LoadoutSlots=3},"Flux")==nil,"last channel cannot be removed")
local removed=Plan.toggleLoadout({Loadout=loadout,LoadoutSlots=3},"Strike")
assert(#removed==2 and removed[2]=="Fortune")
local rank=Plan.nextRank({Cash="1e1000",Stardust=5,Continuum={Rank=9,FluxCost="2e1000",StardustCost=12}}, {Continuum={MilestoneEvery=10,MilestoneScale=2}})
assert(math.abs(rank.fluxProgress-0.5)<0.001 and rank.dust==7 and rank.milestone and rank.production==2.32)
local protocol=Plan.protocol({Fragments=100,Protocols={P=2}},{Id="P",BaseCost=4,CostScale=2,MaxLevel=2})
assert(protocol.capped and not protocol.ready)
local rounded=Plan.protocol({Fragments=5,Protocols={P=1}},{Id="P",BaseCost=4,CostScale=1.42,MaxLevel=10})
assert(rounded.cost==6 and not rounded.ready,"protocol preview must use the server's nearest-integer cost")
assert(Plan.shift({Anomaly={Ready=true,Charge=100,Target=100}},{}).action=="StabilizeAnomaly")
assert(Plan.shift({Anomaly={Directives={{Id="x",Name="Ready",Progress=3,Target=3}}}},{}).action=="ClaimAnomalyDirective")

local shuffle=Soundtrack.newShuffle(function(a,b) return b end)
local seen,current={},nil
for _=1,Soundtrack.count() do
	local index=shuffle:next(current,{},0)
	assert(index and not seen[index],"every track must play once per bag")
	seen[index]=true;current=index
end
local boundary=shuffle:next(current,{},0)
assert(boundary~=current,"bag boundary must not repeat")
local failed={} for index=1,Soundtrack.count() do failed[index]=100 end
assert(Soundtrack.newShuffle():next(nil,failed,100)==nil,"all failed tracks must back off")
assert(Soundtrack.newShuffle():next(nil,failed,100+Soundtrack.RETRY_SECONDS)~=nil)
local surviving=Soundtrack.newShuffle(function(a,b) return b end)
local unavailable={} for index=2,Soundtrack.count() do unavailable[index]=100 end
assert(surviving:next(nil,unavailable,100)==1)
assert(surviving:next(1,unavailable,100)==nil)
assert(surviving:next(1,unavailable,100+Soundtrack.RETRY_SECONDS)~=nil,"a deferred current track must not prevent recovered tracks from re-entering the bag")
assert(Schema.validate("SetCores",{},0,"")==0)
assert(Schema.validate("GrantRebirths",{},0,"")==nil)
assert(Schema.validate("GrantRebirths",{},1.5,"")==nil)
assert(Schema.validate("Blind",{World=true},121,"")==nil)
assert(Schema.validate("GlobalBan",{Moderation=true},0/0,"")==nil)
assert(Schema.canonical("  setcores ",{SetCores={}})=="SetCores")

-- Execute the actual registry, isolated from networking/persistence; never touch a live profile.
local source=fs.readFile("src/Server/AstralForge/Services/AdminService.luau"):gsub("\r\n","\n")
local registry=source:match("local profileHandlers = {}(.-)\n%s+function AdminService:Execute")
assert(registry,"profile executor registry missing")
local factory=luau.load("return function(OmegaMath,ProfileBagMath,GameConfig,Economy) local profileHandlers={} "..registry.." return profileHandlers end")()
local bag=require("../src/Server/AstralForge/Modules/ProfileBagMath")
local handlers=factory(Math,bag,{Continuum={MaxRank=100}},{Capacity=function() return 500 end})
local profile={Cash=12,RunCash=12,LifetimeCash=12,Cores=8,Vault=10,Stardust=10,Rebirths=10}
assert(handlers.GrantFlux(profile,100,"").ok and profile.Cash==112 and profile.LifetimeCash==112)
assert(handlers.SetCores(profile,0,"").ok and profile.Cores==0)
handlers.SetVault(profile,700,"");assert(profile.Vault==500)
handlers.TaxHalf(profile,1,"");assert(profile.Cash==56)
handlers.ResetMachines(profile,1,"");assert(profile.Machines.StellarCore==1)
local catalog=source:match("local COMMANDS = table.freeze%(%s*(%b{})%s*%)")
local commands=luau.load("return "..catalog)()
local count=0
for id,definition in commands do
	count+=1
	assert(handlers[id] or definition.World or definition.Moderation,"missing executor: "..id)
	assert(Schema.describe(id,definition).Summary~="")
end
print(`[TEST] platform improvements: loadouts, Omega budgets, milestone benefits, shuffle, input rules, {count} admin commands + real executor fixtures`)
