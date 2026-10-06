--!nocheck
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Math = require(game.ReplicatedStorage.AstralForge.Shared.OmegaMath)
local Model = require(script.Parent.PlanningModel)(Math)
local ui = require(script.Parent.UiCore)("ui")
local theme = require(script.Parent.CoreKit)("theme")
local compact = require(script.Parent.CoreKit)("format").compactNumber
local useViewport = require(script.Parent.MotionKit)("motion").useViewport
local PageScaffold = require(script.Parent.LayoutKit)("pageScaffold").PageScaffold
local GamepadNavigationService = require(script.Parent.CoreKit)("GamepadNavigationService")
local MotionSettingsContext = require(script.Parent.MotionKit)("motion").MotionSettingsContext
local P = theme.Palette
local Views = {}

-- A ref closes the same-frame double-submit window; generations ignore late replies.
local function useAction(dispatch)
	local busy, setBusy = React.useState(false)
	local status, setStatus = React.useState("")
	local guard = React.useRef({busy=false, generation=0, alive=true})
	React.useEffect(function()
		guard.current.alive = true
		return function() guard.current.alive=false; guard.current.generation+=1 end
	end, {})
	local function run(action, payload)
		local latch = guard.current
		if latch.busy or not latch.alive then return end
		latch.busy=true; latch.generation+=1
		local generation=latch.generation
		setBusy(true); setStatus("Working…")
		local function finish(reply)
			if not latch.alive or latch.generation ~= generation or not latch.busy then return end
			latch.busy=false; setBusy(false)
			setStatus(if reply and reply.ok then (reply.message or "Done.") else (reply and (reply.error or reply.message) or "No response. Try again."))
		end
		task.delay(12,function() finish(nil) end)
		local ok, problem=pcall(dispatch,action,payload or {},finish)
		if not ok then finish({ok=false,message=tostring(problem)}) end
	end
	return busy,status,run,setStatus
end

local function copy(value, y, height, size, color, heavy)
	return React.createElement(ui.Text,{value=value,position=UDim2.fromOffset(0,y),sizeConstraint=UDim2.new(1,0,0,height),size=size or 14,color=color or P.creamSoft,wrap=true,fit=heavy == true,minSize=14,weight=if heavy then Enum.FontWeight.Heavy else Enum.FontWeight.Medium})
end
local function panel(accent, children)
	return React.createElement(ui.Panel,{size=UDim2.fromScale(1,1),accent=accent,padding=16,background=P.panelRaised,clips=true},children)
end
local function button(text,y,action,disabled,accent)
	return React.createElement(ui.Button,{text=text,position=UDim2.fromOffset(0,y),size=UDim2.new(1,0,0,48),onClick=action,disabled=disabled,color=accent or P.cyan,highlight=not disabled})
end
local function section(id,height,element) return {id=id,height=height,element=element} end
local function meter(value,y,accent)
	return React.createElement(ui.Meter,{value=value,position=UDim2.fromOffset(0,y),size=UDim2.new(1,0,0,10),color=accent,reducedMotion=true})
end
local function pairedSections(sections,viewport)
	if viewport.width < 760 then return sections end
	local result={}
	local index=1
	while index<=#sections do
		local first,second=sections[index],sections[index+1]
		local pair=second and ((first.id=="rank-costs" and second.id=="rank-benefits")
			or (string.sub(first.id,1,10)=="directive-" and string.sub(second.id,1,10)=="directive-")
			or (string.sub(first.id,1,9)=="protocol-" and string.sub(second.id,1,9)=="protocol-"))
		if pair then
			local height=math.max(first.height,second.height)
			local children={}
			for column,item in {first,second} do
				children[column]=React.createElement("frame",{Size=UDim2.new(0.5,-6,1,0),Position=UDim2.new((column-1)*0.5,if column==1 then 0 else 6,0,0),BackgroundTransparency=1},item.element)
			end
			table.insert(result,section(first.id.."-pair",height,React.createElement("frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1},children)))
			index+=2
		else table.insert(result,first);index+=1 end
	end
	return result
end
local function scaffold(sections,viewport,props,name)
	local chrome=theme.chromeFor(viewport)
	sections=pairedSections(sections,viewport)
	local reducedMotion = props.reducedMotion
	local inheritedMotion = React.useContext(MotionSettingsContext)
	local softMotion = reducedMotion or inheritedMotion.soft == true
	local motion = table.clone(inheritedMotion)
	motion.soft = softMotion
	local root=React.useRef(nil)
	React.useEffect(function()
		local job=task.delay(0.15,function()
			if root.current and GamepadNavigationService.IsConsole() then GamepadNavigationService.FocusClaim(root.current) end
		end)
		return function() pcall(task.cancel,job) end
	end,{})
	return React.createElement("frame",{Name=name,ref=root,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ClipsDescendants = false},
		React.createElement(MotionSettingsContext.Provider,{value=motion,reducedMotion = softMotion},
			React.createElement(PageScaffold,{sections=sections,gap=12,tailPad=theme.scrollTail(chrome.stack,chrome.bottomSafe,40),scrollBarColor=P.cyan,scrollBarThickness=4})))
end

function Views.NextPlan(props)
	local viewport=useViewport()
	local state, config=props.state,props.config
	local rank=state.Continuum or {}
	local plan=Model.nextRank(state,config)
	local busy,status,run=useAction(props.dispatch)
	local function navigate(page) if props.navigate then props.navigate(page) end end
	local missing=if plan.capped then "Your Continuum rank is at its current limit." elseif plan.ready then "Both costs are covered. This upgrade raises permanent bonuses without resetting your machines." else `Still needed: {compact(plan.flux)} Flux + {compact(plan.dust)} Stardust.`
	local sections={
		section("next-plan",232,panel(P.pink,{
			copy("NEXT PLAN · PERMANENT PROGRESSION",0,22,12,P.pink,true),
			copy(`Continuum {plan.rank} → {plan.nextRank}`,30,38,24,P.cream,true),
			copy(missing,78,66,14),
			button(if busy then "UPGRADING…" elseif plan.capped then "RANK LIMIT" else "RAISE RANK",152,function() run("UpgradeContinuum",{}) end,busy or not plan.ready,P.pink),
		})),
		section("rank-costs",218,panel(P.cyan,{
			copy("YOUR UPGRADE BUDGET",0,24,13,P.cyan,true),
			copy(`Flux · {compact(state.Cash)} / {compact(rank.FluxCost or 0)}`,34,32,14),
			meter(plan.fluxProgress,72,P.cyan),
			copy(`Stardust · {compact(state.Stardust)} / {compact(rank.StardustCost or 0)}`,96,32,14),
			meter(plan.dustProgress,136,P.pink),
			copy(if plan.milestone then "Next rank includes the milestone production bonus." else `Production milestone: rank {plan.milestoneRank}.`,154,32,12,P.muted),
		})),
		section("rank-benefits",246,panel(P.mint,{
			copy("WHAT CHANGES AT YOUR NEXT RANK",0,24,13,P.mint,true),
			copy(`Production · {compact(rank.ProductionMultiplier or 1)}× → {compact(Math.Mul(rank.ProductionMultiplier or 1,plan.production))}×`,34,36),
			copy(`Vault capacity · {compact(rank.CapacityMultiplier or 1)}× → {compact(Math.Mul(rank.CapacityMultiplier or 1,plan.capacity))}×`,76,36),
			copy(`Strike power · {compact(rank.TapMultiplier or 1)}× → {compact(Math.Mul(rank.TapMultiplier or 1,plan.tap))}×`,118,36),
			copy(`Offline bonus · {string.format("%.2f",(rank.OfflineBonus or 0)*100)}% → {string.format("%.2f",plan.offline*100)}%`,160,36),
		})),
		section("rank-route",254,panel(P.mango,{
			copy("BUILD THE MISSING RESOURCES",0,24,13,P.mango,true),
			copy(if status ~= "" then status else "Collect earned rewards, bank a shift, or compare production upgrades. Choose the route that fills your shortfall.",32,64,14),
			button("OPEN SHIFT PLAN",106,function() navigate("Anomaly") end,false,P.pink),
			button("COMPARE WORKSHOP UPGRADES",166,function() navigate("Workshop") end,false,P.cyan),
		})),
	}
	return scaffold(sections,viewport,props,"ContinuumClaimActions")
end

function Views.ShiftPlan(props)
	local viewport=useViewport()
	local state,config=props.state,props.config
	local anomaly=state.Anomaly or {}
	local plan=Model.shift(state,config)
	local busy,status,run,setStatus=useAction(props.dispatch)
	local pane,setPane=React.useState("Directives")
	local sections={
		section("shift-next",240,panel(P.pink,{
			copy("SHIFT PLAN · DO THIS NEXT",0,22,12,P.pink,true),
			copy(plan.title,30,58,23,P.cream,true),
			copy(if status ~= "" then status else plan.body,96,58,14),
			button(if busy then "WORKING…" else (if plan.action == "PulseAnomaly" then "PULSE CHARGE" else "COLLECT REWARD"),160,function() run(plan.action,plan.payload) end,busy,P.pink),
		})),
		section("shift-meter",238,panel(P.mint,{
			copy(`CHARGE · {math.floor(plan.charge*100)}%`,0,24,14,P.mint,true),
			meter(plan.charge,34,P.pink),
			copy(`{compact(anomaly.Charge or 0)} / {compact(anomaly.Target or 0)} · Combo {anomaly.Combo or 0} / {anomaly.ComboMax or 20}`,56,42),
			copy(`{compact(anomaly.Fragments or 0)} fragments · {anomaly.Stabilizations or 0} shifts banked · Core tier {anomaly.CoreTier or 1}`,106,42),
			button("BANK COMPLETED SHIFT",158,function() run("StabilizeAnomaly",{}) end,busy or not anomaly.Ready,P.mint),
		})),
	}
	local compactTabs=viewport.width<760
	local tabs={copy("SHIFT WORKBENCH",0,24,13,P.cyan,true)}
	for index,id in {"Directives","Loadout","Milestones","Protocols"} do
		local columns=if compactTabs then 2 else 4
		local column=(index-1)%columns
		local row=math.floor((index-1)/columns)
		table.insert(tabs,React.createElement(ui.Button,{
			text=string.upper(id),size=UDim2.new(1/columns,-6,0,48),
			position=UDim2.new(column/columns,if column==0 then 0 else 6,0,34+row*56),
			color=if pane==id then P.cyan else P.panelSoft,textColor=if pane==id then P.ink else P.cream,
			onClick=function() setPane(id) end,
		}))
	end
	table.insert(sections,section("shift-workbench",if compactTabs then 174 else 118,panel(P.cyan,tabs)))
	local channels={}
	for id,definition in (config.Anomalies or {}).Channels or {} do table.insert(channels,{id=id,definition=definition}) end
	 table.sort(channels,function(a,b) return a.definition.Name < b.definition.Name end)
	local equipped={}
	for _,id in anomaly.Loadout or {anomaly.Channel or "Strike"} do equipped[id]=true end
	local used=0 for _ in equipped do used+=1 end
	local channelChildren={copy(`CHANNEL LOADOUT · {used} / {anomaly.LoadoutSlots or 1} slots`,0,26,13,P.cyan,true),copy("Mix boosts for your current goal. Unequip one to make room; at least one stays active.",34,58,14)}
	for index,channel in channels do
		local y=102+(index-1)*124
		table.insert(channelChildren,button((if equipped[channel.id] then "UNEQUIP · " else "EQUIP · ")..channel.definition.Name,y,function()
			local loadout,problem=Model.toggleLoadout(anomaly,channel.id)
			if loadout then run("SetAnomalyLoadout",{Loadout=loadout}) else setStatus(problem) end
		end,busy or (not equipped[channel.id] and used >= (anomaly.LoadoutSlots or 1)),channel.definition.Color))
		table.insert(channelChildren,copy(channel.definition.Description,y+56,46,13,P.muted))
	end
	if pane=="Loadout" then table.insert(sections,section("shift-loadout",134+#channels*124,panel(P.cyan,channelChildren))) end
	for index,job in plan.jobs do
		if pane~="Directives" then break end
		local progress=Model.ratio(job.Progress,job.Target)
		table.insert(sections,section("directive-"..job.Id,254,panel(job.Color or P.mango,{
			copy("DAILY DIRECTIVE",0,20,11,P.mango,true),copy(job.Name,26,42,19,P.cream,true),
			copy(job.Description or job.Kind,74,56,14),meter(progress,136,job.Color or P.mango),
			copy(`{compact(job.Progress)} / {compact(job.Target)} · {math.floor(progress*100)}%`,152,22,12),
			button(if progress>=1 then "CLAIM DIRECTIVE" else "DIRECTIVE IN PROGRESS",184,function() run("ClaimAnomalyDirective",{Id=job.Id}) end,busy or progress<1,job.Color or P.mango),
		})))
	end
	for index,milestone in plan.milestones do
		if pane~="Milestones" then break end
		if index > 3 then break end
		local ready=(anomaly.Stabilizations or 0)>=milestone.Required
		table.insert(sections,section(`milestone-{milestone.Tier}`,172,panel(P.mint,{
			copy(`SHIFT MILESTONE · TIER {milestone.Tier}`,0,26,13,P.mint,true),
			copy(`{anomaly.Stabilizations or 0} / {milestone.Required} completed shifts`,34,36,14),
			meter(Model.ratio(anomaly.Stabilizations,milestone.Required),80,P.mint),
			button(if ready then "CLAIM MILESTONE" else "KEEP BANKING SHIFTS",104,function() run("ClaimAnomalyMilestone",{Tier=milestone.Tier}) end,busy or not ready,P.mint),
		})))
	end
	for _,protocol in plan.protocols do
		if pane~="Protocols" then break end
		local definition=protocol.definition
		table.insert(sections,section("protocol-"..definition.Id,218,panel(definition.Color,{
			copy(`{definition.Name} · LV {compact(protocol.level)}`,0,42,18,P.cream,true),
			copy(definition.Description,50,54,14),
			copy(if protocol.capped then "Maximum level reached." else `Next level: {compact(protocol.cost)} fragments`,110,32,13,P.muted),
			button(if protocol.capped then "MAXED" else "BUY NEXT LEVEL",150,function() run("BuyAnomalyProtocol",{Id=definition.Id}) end,busy or not protocol.ready,definition.Color),
		})))
	end
	if pane=="Directives" and #plan.jobs==0 then
		table.insert(sections,section("directives-complete",110,panel(P.mint,{copy("All daily directives collected",0,34,20,P.cream,true),copy("Keep building charge or explore permanent protocols while the next daily set approaches.",42,42,14)})))
	end
	return scaffold(sections,viewport,props,"AnomalyClaimActions")
end
return Views
