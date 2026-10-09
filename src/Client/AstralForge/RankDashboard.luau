--!nocheck
-- Ranks: grouped categories, podium, your-standing card and scaled rows.
local React=require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Math=require(game.ReplicatedStorage.AstralForge.Shared.OmegaMath)
local Social=require(game.ReplicatedStorage.AstralForge.Shared.SocialProgression)(Math)
local ui=require(script.Parent.UiCore)("ui")
local theme=require(script.Parent.CoreKit)("theme")
local compact=require(script.Parent.CoreKit)("format").compactNumber
local useViewport=require(script.Parent.MotionKit)("motion").useViewport
local Art=require(script.Parent.ArtKit)("Icon")
local Scaffold=require(script.Parent.LayoutKit)("pageScaffold").PageScaffold
local P=theme.Palette
local e=React.createElement
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")

local GROUPS={
	{id="Economy",label="ECONOMY",icon="Flux"},
	{id="Progression",label="PROGRESSION",icon="Rebirth"},
	{id="Activity",label="ACTIVITY",icon="Forge"},
	{id="Collection",label="COLLECTION",icon="Crate"},
	{id="Sky",label="SKY",icon="StarGrid"},
	{id="Social",label="GUILDS",icon="Guild"},
}
local GUILD_META={id="Guilds",short="GUILDS",label="Guild Halls",icon="Guild",accent=P.violet,group="Social",description="Guild activity earned by banking and building together."}
local PODIUM_ORDER={2,1,3}
local PODIUM_LIFT={[1]=1,[2]=0.74,[3]=0.56}
local MEDAL={[1]=Color3.fromRGB(255,196,92),[2]=Color3.fromRGB(196,212,230),[3]=Color3.fromRGB(214,146,98)}

local function share(value,top)
	if not Math.Gt(top,0) then return 0 end
	local ratio=Math.ToNumber(Math.Div(value,top))
	if ratio~=ratio then return 0 end
	return math.clamp(ratio,0,1)
end

local function matchesRank(row,query)
	local needle=string.lower(query):match("^%s*(.-)%s*$")
	return needle=="" or string.find(string.lower(tostring(row.Name or "").." "..tostring(row.Tag or "").." "..tostring(row.UserId or row.Id or "")),needle,1,true)~=nil
end

local function bar(ratio,color,position,size)
	return e("frame",{BackgroundColor3=Color3.fromRGB(20,24,38),BackgroundTransparency=0.2,BorderSizePixel=0,Position=position,Size=size},{
		Corner=e("uicorner",{CornerRadius=UDim.new(1,0)}),
		Fill=e("frame",{BackgroundColor3=color,BorderSizePixel=0,Size=UDim2.fromScale(math.max(ratio,0.015),1)},{
			Corner=e("uicorner",{CornerRadius=UDim.new(1,0)}),
		}),
	})
end

local function chip(props)
	return e(ui.Button,{
		text=props.text,icon=props.icon,color=props.accent,
		outline=not props.active,highlight=props.active,
		position=props.position,size=props.size,disabled=props.disabled,
		reducedMotion=props.reducedMotion,onClick=props.onClick,
	})
end

local function AvatarView(props)
	local ref=React.useRef(nil)
	local scene=React.useRef(nil)
	local status,setStatus=React.useState("Loading avatar…")
	local revision,retry=React.useState(0)
	local angle,turn=React.useState(0)
	local previousAngle=React.useRef(0)
	React.useEffect(function()
		local viewport=ref.current
		if viewport==nil then return end
		local alive=true
		local world=Instance.new("WorldModel")
		world.Parent=viewport
		local camera=Instance.new("Camera")
		camera.FieldOfView=34
		camera.Parent=viewport
		viewport.CurrentCamera=camera
		setStatus("Loading avatar…")
		local timeout=task.delay(12,function()
			if alive and scene.current==nil then setStatus("Avatar taking too long. Retry.") end
		end)
		task.spawn(function()
			local ok,model=pcall(function() return Players:CreateHumanoidModelFromUserIdAsync(props.userId) end)
			if not alive then if ok then model:Destroy() end;return end
			if not ok then
				warn(`Ranks avatar {props.userId}: {model}`)
				setStatus("Avatar unavailable. Retry.")
				return
			end
			for _,item in model:GetDescendants() do
				if item:IsA("LuaSourceContainer") then item:Destroy()
				elseif item:IsA("BasePart") then item.Anchored=item.Name=="HumanoidRootPart";item.CanCollide=false end
			end
			model:PivotTo(CFrame.new())
			model.Parent=world
			task.wait()
			if not alive then model:Destroy();return end
			local bounds,size=model:GetBoundingBox()
			scene.current={camera=camera,target=bounds.Position,size=size}
			setStatus(nil)
		end)
		return function()
			alive=false
			task.cancel(timeout)
			scene.current=nil
			viewport.CurrentCamera=nil
			world:Destroy()
			camera:Destroy()
		end
	end,{props.userId,revision})
	React.useEffect(function()
		local viewport=ref.current
		local current=scene.current
		if current==nil or viewport==nil then return end
		local tween
		local function fit(animate)
			if tween then tween:Cancel() end
			local aspect=math.max(viewport.AbsoluteSize.X,1)/math.max(viewport.AbsoluteSize.Y,1)
			local size=current.size
			local distance=(math.max(size.Y,size.X/math.max(aspect,0.1))*0.56)/math.tan(math.rad(current.camera.FieldOfView/2))+size.Z/2
			local yaw=math.rad(angle)
			local eye=current.target+Vector3.new(math.sin(yaw)*distance,distance*0.08,-math.cos(yaw)*distance)
			local target=CFrame.lookAt(eye,current.target)
			if animate and not props.reducedMotion then
				tween=TweenService:Create(current.camera,TweenInfo.new(0.4,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{CFrame=target})
				tween:Play()
			else current.camera.CFrame=target end
		end
		fit(previousAngle.current~=angle)
		previousAngle.current=angle
		local connection=viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() fit(false) end)
		return function() connection:Disconnect();if tween then tween:Cancel() end end
	end,{status,angle,props.reducedMotion})
	return e("frame",{Name="RankAvatar",Size=props.size,Position=props.position,BackgroundTransparency=1},{
		View=e("viewportframe",{
			Name="AvatarViewport",ref=ref,Size=UDim2.new(1,0,1,-54),BackgroundTransparency=1,
			Ambient=Color3.fromRGB(180,185,205),LightColor=Color3.fromRGB(255,235,215),LightDirection=Vector3.new(-1,-1,-2),
		}),
		Status=status and e(ui.Text,{value=status,size=11,color=P.creamSoft,wrap=true,align=Enum.TextXAlignment.Center,position=UDim2.fromOffset(0,8),sizeConstraint=UDim2.new(1,0,1,-62)}),
		Turn=e(ui.Button,{
			text=if status and status~="Loading avatar…" then "RETRY" else "TURN",
			icon=if status then "Refresh" else "Crew",color=props.accent,outline=true,
			size=UDim2.new(1,0,0,48),position=UDim2.new(0,0,1,-48),
			disabled=status=="Loading avatar…",reducedMotion=props.reducedMotion,
			onClick=function()
				if status then retry(function(v) return v+1 end)
				else turn(function(v) return if v==0 then 30 elseif v==30 then -30 else 0 end) end
			end,
		}),
	})
end

local function mark(row,guildBoard,accent,size,position)
	if guildBoard then
		return e("frame",{BackgroundColor3=accent,BackgroundTransparency=0.7,BorderSizePixel=0,AnchorPoint=Vector2.new(0.5,0),Position=position,Size=UDim2.fromOffset(size,size)},{
			Corner=e("uicorner",{CornerRadius=UDim.new(0,math.floor(size*0.28))}),
			Stroke=e("uistroke",{Color=accent,Transparency=0.2,Thickness=1.5}),
			Tag=e(ui.Text,{value=string.upper(tostring(row.Tag or "?")),size=math.max(11,math.floor(size*0.3)),weight=Enum.FontWeight.Bold,align=Enum.TextXAlignment.Center,sizeConstraint=UDim2.fromScale(1,1)}),
		})
	end
	return e(Art.PlayerMark,{userId=row.UserId,accent=accent,size=size,position=position,anchorPoint=Vector2.new(0.5,0)})
end

return function(helpers)
	local boardList=table.clone(helpers.boards)
	table.insert(boardList,GUILD_META)
	local function boardsIn(group)
		local found={}
		for _,board in boardList do if board.group==group then table.insert(found,board) end end
		return found
	end
	local function groupOf(id)
		for _,board in boardList do if board.id==id then return board.group end end
		return "Economy"
	end
	return function(props)
		local viewport=useViewport()
		local hostRef=React.useRef(nil)
		local measuredWidth,setMeasuredWidth=React.useState(viewport.width)
		React.useEffect(function()
			local host=hostRef.current
			if host==nil then return end
			local function resize() setMeasuredWidth(host.AbsoluteSize.X) end
			resize()
			local connection=host:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
			return function() connection:Disconnect() end
		end,{})
		local narrow=measuredWidth<620
		local reducedMotion=props.reducedMotion
		local selected,setSelected=React.useState("Flux")
		local scope,setScope=React.useState("Global")
		local revision,reload=React.useState(0)
		local query,setQuery=React.useState("")
		local mineOnly,setMineOnly=React.useState(false)
		local result,setResult=React.useState({rows={},loading=true,status="Loading rankings…"})
		local guildBoard=selected=="Guilds"
		local meta=if guildBoard then GUILD_META else helpers.metaFor(selected)
		local group=groupOf(selected)
		local localId=game.Players.LocalPlayer.UserId
		React.useEffect(function()
			local alive=true
			local pending=false
			local serial=0
			local timer
			local function refresh()
				if not alive or pending then return end
				pending=true;serial+=1
				local request=serial
				setResult(function(previous) return {rows=previous.rows,loading=true,status="Refreshing rankings…"} end)
				local function finish(reply)
					if not alive or not pending or serial~=request then return end
					pending=false;serial+=1
					if type(reply)~="table" or reply.ok~=true then
						setResult(function(previous) return {rows=previous.rows,loading=false,status=(type(reply)=="table" and (reply.error or reply.message)) or "Rankings unavailable. Retry below."} end)
						return
					end
					local entries=if guildBoard then reply.GuildLeaderboard or reply.Leaderboard else if scope=="Server" then helpers.serverEntries(reply.Players or {},selected) else reply.Leaderboard
					local rows=Social.rank(entries or {},guildBoard)
					if not guildBoard then
						local eligible={}
						for _,row in rows do if helpers.scoreCounts(selected,row.Value) then table.insert(eligible,row) end end
						rows=eligible
					end
					setResult({rows=rows,loading=false,status=`Updated · {#rows} entries · {if guildBoard then "Guild activity" else scope.." board"}`})
				end
				task.delay(12,function() finish(nil) end)
				local action=if guildBoard then "GetGuildLeaderboard" elseif scope=="Server" then "GetPlayers" else "GetLeaderboard"
				local ok=pcall(props.dispatch,action,if action=="GetPlayers" then {} else {Id=selected},finish)
				if not ok then finish({ok=false,error="Rankings connection interrupted."}) end
			end
			setResult({rows={},loading=true,status="Loading rankings…"})
			local function tick() refresh();timer=task.delay(30,tick) end
			tick()
			return function() alive=false;serial+=1;if timer then pcall(task.cancel,timer) end end
		end,{props.dispatch,selected,scope,revision})
		local rows=result.rows
		local guildId=(props.state.Guild or {}).Id
		local own=if guildBoard then (props.state.Guild or {}).Activity or 0 else helpers.ownValue(props.state,selected) or 0
		local function isMine(row) return if guildBoard then row.Id~=nil and row.Id==guildId else row.UserId==localId end
		local function valueText(value) return if guildBoard then `{compact(value)} activity` else helpers.formatValue(selected,value) end
		local personalIndex
		for index,row in rows do if isMine(row) then personalIndex=index;break end end
		local ahead=personalIndex and rows[personalIndex-1]
		local gap=ahead and Math.Max(0,Math.Sub(ahead.Value,own))
		local top=rows[1] and rows[1].Value or 0
		local sections={}
		local function text(value,x,y,w,h,size,color,extra)
			local props={value=value,position=UDim2.new(0,x,0,y),sizeConstraint=UDim2.new(w,if w==1 then -x else 0,0,h),size=size or 14,color=color or P.cream,wrap=true}
			if extra then for k,v in extra do props[k]=v end end
			return e(ui.Text,props)
		end
		local function section(id,height,children,accent)
			table.insert(sections,{id=id,height=height,element=e(ui.Panel,{size=UDim2.fromScale(1,1),padding=16,accent=accent or meta.accent},children)})
		end

		-- Standing card: your rank, your score and the climb to the next seat.
		local nextRatio=if ahead then share(own,ahead.Value) elseif personalIndex==1 then 1 else share(own,top)
		local standing=if personalIndex then `#{personalIndex}` else "—"
		section("rank-standing",narrow and 220 or 190,{
			Icon=e(Art.Icon,{kind=meta.icon or "Leaderboard",color=meta.accent,accent=meta.accent,size=28,spin=false,position=UDim2.fromOffset(0,2)}),
			Eyebrow=text(`RANKS · {string.upper(group)} · {if guildBoard then "GUILD HALLS" else string.upper(scope)}`,40,0,1,16,11,meta.accent,{weight=Enum.FontWeight.Bold}),
			Title=text(meta.label,40,16,1,28,22,P.cream,{weight=Enum.FontWeight.Bold}),
			About=text(meta.description,0,50,if narrow then 1 else 0.62,34,12,P.creamSoft),
			Seat=text(standing,0,if narrow then 92 else 50,1,40,34,if personalIndex==1 then MEDAL[1] else P.cream,{weight=Enum.FontWeight.Heavy,align=Enum.TextXAlignment.Right}),
			Score=text(`{if guildBoard then "Your hall" else "You"} · {valueText(own)}`,0,if narrow then 96 else 92,0.7,18,13,P.cream,{weight=Enum.FontWeight.SemiBold}),
			Climb=bar(nextRatio,if personalIndex==1 then MEDAL[1] else meta.accent,UDim2.fromOffset(0,if narrow then 124 else 118),UDim2.new(1,0,0,6)),
			Gap=text(if gap then `{compact(gap)} more to pass #{personalIndex-1} {ahead.Name or ""}` elseif personalIndex==1 then "You hold the top seat. Everyone else is chasing you." elseif personalIndex==nil and #rows>0 then `Outside the top {#rows}. Reach {valueText(rows[#rows].Value)} to enter the board.` else "No standings yet for this board.",0,if narrow then 136 else 130,1,18,11,P.creamSoft),
		})

		-- Category picker: group strip, then the boards inside the group.
		local groupKids={}
		local groupCols=if measuredWidth<480 then 2 elseif measuredWidth<1000 then 3 else 6
		for index,entry in GROUPS do
			local col=(index-1)%groupCols
			local row=math.floor((index-1)/groupCols)
			groupKids[entry.id]=chip({text=entry.label,icon=entry.icon,accent=if group==entry.id then meta.accent else P.muted,active=group==entry.id,
				position=UDim2.new(col/groupCols,2,0,row*56),size=UDim2.new(1/groupCols,-8,0,48),reducedMotion=reducedMotion,
				onClick=function() local first=boardsIn(entry.id)[1];if first then setSelected(first.id) end end})
		end
		local groupRows=math.ceil(#GROUPS/groupCols)
		local inGroup=boardsIn(group)
		local boardCols=math.min(#inGroup,if narrow then 2 else 4)
		for index,board in inGroup do
			local col=(index-1)%boardCols
			local row=math.floor((index-1)/boardCols)
			groupKids["board-"..board.id]=chip({text=board.short or board.label,icon=board.icon,accent=board.accent,active=selected==board.id,
				position=UDim2.new(col/boardCols,2,0,groupRows*56+14+row*56),size=UDim2.new(1/boardCols,-8,0,48),reducedMotion=reducedMotion,
				onClick=function() setSelected(board.id) end})
		end
		groupKids.Divider=e("frame",{BackgroundColor3=meta.accent,BackgroundTransparency=0.75,BorderSizePixel=0,Position=UDim2.fromOffset(0,groupRows*56+5),Size=UDim2.new(1,0,0,1)})
		section("rank-categories",groupRows*56+14+math.ceil(#inGroup/boardCols)*56+32,groupKids)

		-- Scope and refresh.
		local controls={Status=text(result.status or "Rankings unavailable.",0,0,1,18,11,P.creamSoft)}
		for index,id in {"Global","Server"} do
			controls[id]=chip({text=if id=="Global" then "GLOBAL" else "THIS SERVER",icon=if id=="Global" then "World" else "Command",accent=meta.accent,active=scope==id and not guildBoard,
				position=UDim2.new((index-1)/3,2,0,24),size=UDim2.new(1/3,-8,0,48),disabled=guildBoard,reducedMotion=reducedMotion,onClick=function() if not guildBoard then setScope(id) end end})
		end
		controls.Refresh=e(ui.Button,{text=if result.loading then "LOADING…" else "REFRESH",position=UDim2.new(2/3,2,0,24),size=UDim2.new(1/3,-8,0,48),disabled=result.loading,reducedMotion=reducedMotion,onClick=function() reload(function(v) return v+1 end) end,color=P.mint})
		section("rank-controls",110,controls)
		section("rank-find",154,{
			Search=e(ui.SearchField,{value=query,onChange=setQuery,placeholder=if guildBoard then "Find a guild or tag" else "Find a player or user ID",accent=meta.accent,reducedMotion=reducedMotion,size=UDim2.new(1,0,0,48)}),
			Mine=e(ui.Button,{text=if mineOnly then "SHOW EVERYONE" else "MY STANDING",icon="Crew",color=P.mint,outline=not mineOnly,reducedMotion=reducedMotion,position=UDim2.fromOffset(0,60),size=UDim2.new(1,0,0,48),onClick=function() setMineOnly(function(v) return not v end) end}),
		})

		if #rows==0 then
			section("rank-empty",120,{
				text(if result.loading then "Finding the current leaders…" else "No one has scored here yet",0,0,1,30,18),
				text("Try another category, switch scope or refresh. Boards sync every few seconds while you play.",0,36,1,40,12,P.creamSoft),
			})
		else
			-- Podium: second, first, third, with stepped plinths.
			local podium={}
			for slot,place in (if narrow then {1,2,3} else PODIUM_ORDER) do
				local row=rows[place]
				if row then
					local lift=PODIUM_LIFT[place]
					local color=MEDAL[place]
					local plinth=math.floor(64*lift)
					local seatHeight=if narrow then 230 else 352
					local infoX=if narrow then 0.5 else 0
					local infoWidth=if narrow then 0.5 else 1
					podium["seat"..place]=e("frame",{Name=`PodiumSeat{place}`,BackgroundTransparency=1,Position=if narrow then UDim2.fromOffset(0,(slot-1)*242) else UDim2.new((slot-1)/3,4,0,0),Size=UDim2.new(if narrow then 1 else 1/3,if narrow then 0 else -8,0,seatHeight)},{
						Avatar=not guildBoard and e(AvatarView,{userId=row.UserId,accent=color,reducedMotion=reducedMotion,position=UDim2.fromOffset(4,0),size=UDim2.new(if narrow then 0.46 else 1,-8,0,if narrow then 222 else 230)}),
						Mark=guildBoard and mark(row,true,color,70,if narrow then UDim2.new(0.23,0,0,58) else UDim2.new(0.5,0,0,90)),
						Name=text(`{row.Name or "Unknown"}{if isMine(row) then " · YOU" else ""}`,0,0,1,36,14,if isMine(row) then P.mint else P.cream,{weight=Enum.FontWeight.Bold,align=Enum.TextXAlignment.Center,fit=true,minSize=10,position=UDim2.new(infoX,0,0,if narrow then 34 else 236),sizeConstraint=UDim2.new(infoWidth,0,0,36)}),
						Value=text(valueText(row.Value),0,0,1,28,12,P.creamSoft,{align=Enum.TextXAlignment.Center,fit=true,minSize=9,position=UDim2.new(infoX,0,0,if narrow then 80 else 273),sizeConstraint=UDim2.new(infoWidth,0,0,28)}),
						Share=bar(share(row.Value,top),color,UDim2.new(infoX,8,0,if narrow then 118 else 307),UDim2.new(infoWidth,-16,0,4)),
						Plinth=e("frame",{BackgroundColor3=color,BackgroundTransparency=0.72,BorderSizePixel=0,AnchorPoint=Vector2.new(0,1),Position=UDim2.new(infoX,0,1,0),Size=UDim2.new(infoWidth,0,0,if narrow then plinth else 32)},{
							Corner=e("uicorner",{CornerRadius=UDim.new(0,8)}),
							Stroke=e("uistroke",{Color=color,Transparency=0.35,Thickness=1}),
							Shade=e("uigradient",{Rotation=90,Transparency=NumberSequence.new(0,0.65)}),
							Place=e(ui.Text,{value=tostring(place),size=if place==1 then 26 else 20,weight=Enum.FontWeight.Heavy,color=color,align=Enum.TextXAlignment.Center,sizeConstraint=UDim2.fromScale(1,1)}),
						}),
					})
				end
			end
			section("rank-podium",if narrow then math.min(#rows,3)*242+24 else 384,podium,MEDAL[1])

			-- Remaining rows: compact, with a share-of-leader bar.
			local shown=0
			for index=if query~="" or mineOnly then 1 else 4,#rows do
				local row=rows[index]
				local mine=isMine(row)
				if not matchesRank(row,query) or (mineOnly and not mine) then continue end
				shown+=1
				local accent=if mine then P.mint else meta.accent
				table.insert(sections,{id=`rank-row-{index}`,height=58,element=e("frame",{
					BackgroundColor3=if mine then Color3.fromRGB(22,48,44) else Color3.fromRGB(22,26,40),
					BackgroundTransparency=0.08,BorderSizePixel=0,Size=UDim2.fromScale(1,1),
				},{
					Corner=e("uicorner",{CornerRadius=UDim.new(0,12)}),
					Stroke=e("uistroke",{Color=accent,Transparency=if mine then 0.2 else 0.8,Thickness=1}),
					Place=e(ui.Text,{value=`{index}`,size=15,weight=Enum.FontWeight.Bold,color=P.muted,align=Enum.TextXAlignment.Center,position=UDim2.fromOffset(4,0),sizeConstraint=UDim2.new(0,36,1,0)}),
					Mark=mark(row,guildBoard,accent,34,UDim2.new(0,62,0.5,-17)),
					Name=e(ui.Text,{value=`{row.Name or "Unknown pilot"}{if mine then " · YOU" else ""}{if guildBoard and row.Tag then ` [{row.Tag}]` else ""}`,size=14,fit=true,minSize=9,weight=Enum.FontWeight.SemiBold,color=if mine then P.mint else P.cream,position=UDim2.fromOffset(90,9),sizeConstraint=UDim2.new(if narrow then 1 else 0.6,if narrow then -104 else -90,0,18)}),
					Value=e(ui.Text,{value=valueText(row.Value),size=13,fit=true,minSize=9,weight=Enum.FontWeight.Bold,color=P.cream,align=Enum.TextXAlignment.Right,position=if narrow then UDim2.fromOffset(90,29) else UDim2.new(0.6,0,0,9),sizeConstraint=UDim2.new(if narrow then 1 else 0.4,if narrow then -104 else -14,0,18)}),
					Share=bar(share(row.Value,top),accent,UDim2.new(0,90,0,if narrow then 51 else 36),UDim2.new(1,-104,0,4)),
				})})
			end
			if shown==0 and (query~="" or mineOnly) then
				section("rank-no-match",106,{
					text(if mineOnly and not personalIndex then "Your entry is outside this board." else "No matching entries.",0,0,1,28,16),
					text("Clear the search or show everyone. The podium remains the current top three.",0,34,1,40,12,P.creamSoft),
				})
			end
		end
		return e("frame",{Name="RankDashboard",ref=hostRef,Size=UDim2.fromScale(1,1),BackgroundTransparency=1},{
			Content=e(Scaffold,{sections=sections,gap=10,tailPad=80,scrollBarColor=meta.accent,scrollBarThickness=4}),
		})
	end
end
