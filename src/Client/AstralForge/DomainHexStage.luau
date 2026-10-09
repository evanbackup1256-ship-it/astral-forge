--!nocheck
local React=require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ui=require(script.Parent.UiCore)("ui")
local motion=require(script.Parent.MotionKit)("motion")
local theme=require(script.Parent.CoreKit)("theme")
local Icon=require(script.Parent.ArtKit)("Icon").Icon
local Audio=require(script.Parent.AudioKit)("audio").Audio
local P=theme.Palette
local h=React.createElement

local function hexLayout(layout,zoom)
	local positions={}
	for id,slot in layout.slot do
		positions[id]=Vector2.new(((layout.widest-slot.count)*48+(slot.index-1)*96+(slot.tier%2)*48+64)*zoom,(slot.tier*120+64)*zoom)
	end
	return positions,Vector2.new(((layout.widest+1)*96+32)*zoom,(layout.tierCount*120+32)*zoom)
end

local function Hex(props)
	local radius=props.radius
	local children={}
	for index=1,18 do
		local y=((index-0.5)/18*2-1)*radius
		local halfWidth=radius*math.sqrt(3)/2*math.min(1,2*(1-math.abs(y)/radius))
		children["fill"..index]=h("frame",{
			Size=UDim2.fromOffset(halfWidth*2,radius*2/18+1),
			Position=UDim2.fromOffset(radius,y+radius),AnchorPoint=Vector2.new(0.5,0.5),
			BackgroundColor3=props.fill,BackgroundTransparency=props.transparency or 0,
			BorderSizePixel=0,ZIndex=props.zIndex,
		})
	end
	for index=0,5 do
		local a=Vector2.new(math.sin(index*math.pi/3),-math.cos(index*math.pi/3))*radius
		local b=Vector2.new(math.sin((index+1)*math.pi/3),-math.cos((index+1)*math.pi/3))*radius
		local delta=b-a
		children["edge"..index]=h("frame",{
			Size=UDim2.fromOffset(delta.Magnitude+1,1.5),Position=UDim2.fromOffset(radius+(a.X+b.X)/2,radius+(a.Y+b.Y)/2),
			AnchorPoint=Vector2.new(0.5,0.5),Rotation=math.deg(math.atan2(delta.Y,delta.X)),
			BackgroundColor3=props.accent,BackgroundTransparency=props.outlineTransparency or 0.35,
			BorderSizePixel=0,ZIndex=props.zIndex+1,
		})
	end
	children.Content=h("frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=props.zIndex+2},props.children)
	return h("frame",{Size=UDim2.fromOffset(radius*2,radius*2),Position=props.position,AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,ZIndex=props.zIndex},children)
end

local function HexNode(props)
	local hovered,setHovered=React.useState(false)
	local amount=motion.useFlipperSpring(if hovered or props.selected then 1 else 0,props.softMotion,520,40)
	local accent=if props.owned then P.mint elseif props.available then props.style.accent else P.muted
	local flash=motion.useFlash(if props.bound then props.boundToken else 0,props.softMotion,0.55)
	return h("frame",{
		Name=props.node.Id,Size=UDim2.fromOffset(92*props.zoom,108*props.zoom),
		Position=UDim2.fromOffset(props.center.X,props.center.Y),AnchorPoint=Vector2.new(0.5,0.35),
		BackgroundTransparency=1,ZIndex=if props.selected then 715 else 710,
	},{
		Face=h(Hex,{radius=36*props.zoom,position=UDim2.new(0.5,0,0,36*props.zoom),
			fill=flash:map(function(v)return (if props.owned then theme.darken(P.mint,0.78) else P.panel):Lerp(accent,v*0.2)end),
			accent=accent,outlineTransparency=if props.selected then 0 else if props.owned then 0.15 else 0.5,zIndex=710,
			children=h("frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1},{
				Scale=h("uiscale",{Scale=amount:map(function(v)return 1+v*0.035 end)}),
				Icon=h(Icon,{kind=if props.owned then "Check" else if props.available then props.style.icon else "Lock",color=accent,accent=accent,size=24*props.zoom,spin=false,position=UDim2.fromScale(0.5,0.5),anchorPoint=Vector2.new(0.5,0.5)}),
			})}),
		Hit=h("textbutton",{
			Name="SelectNode",Size=UDim2.fromOffset(72*props.zoom,72*props.zoom),Position=UDim2.fromScale(0.5,0),AnchorPoint=Vector2.new(0.5,0),
			Text="",BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false,Selectable=true,SelectionOrder=props.order,ZIndex=716,
			Event={
				Activated=function()Audio:play("tabSwitch");props.onSelect(props.node.Id)end,
				MouseEnter=function()setHovered(true);Audio:play("navHover")end,
				MouseLeave=function()setHovered(false)end,
				SelectionGained=function()setHovered(true);props.onSelect(props.node.Id)end,
				SelectionLost=function()setHovered(false)end,
			},
		}),
		Label=h(ui.Text,{value=props.node.Name,size=11,color=if props.selected then P.cream else P.creamSoft,weight=Enum.FontWeight.Bold,
			position=UDim2.fromOffset(0,74*props.zoom),sizeConstraint=UDim2.new(1,0,0,32*props.zoom),align=Enum.TextXAlignment.Center,wrap=true,fit=true,minSize=9,zIndex=717}),
	})
end

local function DomainHexStage(props)
	local scrollRef=React.useRef(nil)
	local zoom,setZoom=React.useState(1)
	local positions,extent=hexLayout(props.layout,zoom)
	local selectedPath={}
	local function visit(id)
		if selectedPath[id]then return end
		selectedPath[id]=true
		local node=props.layout.byId[id]
		for _,parent in (node and node.Requires)or{}do visit(parent)end
	end
	if props.focusId then visit(props.focusId)end
	local children={}
	for order,node in props.tree do
		local center=positions[node.Id]
		local available=true
		for _,parent in node.Requires or{}do
			if not props.owned[parent]then available=false end
			local origin=positions[parent]
			if origin then
				local delta=center-origin
				local active=selectedPath[parent]and selectedPath[node.Id]
				children[parent.."->"..node.Id]=h("frame",{
					Size=UDim2.fromOffset(delta.Magnitude,if active then 2 else 1),
					Position=UDim2.fromOffset((origin.X+center.X)/2,(origin.Y+center.Y)/2),
					AnchorPoint=Vector2.new(0.5,0.5),Rotation=math.deg(math.atan2(delta.Y,delta.X)),
					BackgroundColor3=if active then P.cyan else if props.owned[parent]then P.mint else P.lineSoft,
					BackgroundTransparency=if active then 0.15 else 0.55,BorderSizePixel=0,ZIndex=707,
				})
			end
		end
		children[node.Id]=h(HexNode,{node=node,center=center,zoom=zoom,order=order,owned=props.owned[node.Id]==true,available=available,
			selected=props.focusId==node.Id,style=props.styleFor(node),softMotion=props.softMotion,onSelect=props.onSelect,
			bound=props.boundId==node.Id,boundToken=props.boundToken})
	end
	React.useEffect(function()
		local scroll=scrollRef.current
		local position=positions[props.focusId]
		if not scroll or not position then return end
		local viewport=scroll.AbsoluteSize
		scroll.CanvasPosition=Vector2.new(math.clamp(position.X-viewport.X/2,0,math.max(0,extent.X-viewport.X)),math.clamp(position.Y-viewport.Y/2,0,math.max(0,extent.Y-viewport.Y)))
	end,{props.focusId,zoom})
	local function fit()
		setZoom(math.clamp(props.size.X.Offset/(((props.layout.widest+1)*96)+32),0.85,1.25))
	end
	return h("frame",{Name="DomainHexGrid",Size=props.size,Position=props.position,BackgroundColor3=P.ink,BorderSizePixel=0,ClipsDescendants=true,ZIndex=705,
		ref=function(host)if host then host:SetAttribute("LayoutGuardIgnore",true);host:SetAttribute("NoMotion",true)end end},{
		Corner=h("uicorner",{CornerRadius=UDim.new(0,12)}),
		Scroll=h("scrollingframe",{ref=scrollRef,Size=UDim2.new(1,0,1,-60),CanvasSize=UDim2.fromOffset(extent.X,extent.Y),BackgroundTransparency=1,BorderSizePixel=0,
			ScrollBarThickness=3,ScrollBarImageColor3=P.cyan,ScrollingDirection=Enum.ScrollingDirection.XY,ZIndex=706},children),
		ZoomOut=h(ui.Button,{text="-",onClick=function()setZoom(math.max(0.85,zoom-0.15))end,size=UDim2.fromOffset(48,48),position=UDim2.new(0,8,1,-54),outline=true,color=P.cyan,reducedMotion=props.softMotion,zIndex=720}),
		Fit=h(ui.Button,{text="FIT",onClick=fit,size=UDim2.fromOffset(76,48),position=UDim2.new(0,64,1,-54),outline=true,color=P.cyan,reducedMotion=props.softMotion,zIndex=720}),
		ZoomIn=h(ui.Button,{text="+",onClick=function()setZoom(math.min(1.6,zoom+0.15))end,size=UDim2.fromOffset(48,48),position=UDim2.new(0,148,1,-54),outline=true,color=P.cyan,reducedMotion=props.softMotion,zIndex=720}),
	})
end

return {DomainHexStage=DomainHexStage,Hex=Hex,hexLayout=hexLayout}
