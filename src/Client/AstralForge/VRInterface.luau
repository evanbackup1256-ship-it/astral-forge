--!nocheck
-- Interactive world panel; Roblox owns headset tracking and native laser input.
local VRService = game:GetService("VRService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")
local VRInterface = { Width = 1440, Height = 960 }

function VRInterface.mount(playerGui, screen, changed, forcePreview)
	local host = { active = false, disposed = false, connections = {} }
	local surface = Instance.new("SurfaceGui")
	surface.Name = "AstralForgeVR"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = Vector2.new(VRInterface.Width, VRInterface.Height)
	surface.AlwaysOnTop = true
	surface.LightInfluence = 0
	surface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	surface.Enabled = false
	surface.ResetOnSpawn = false
	surface.Parent = playerGui
	local part = Instance.new("Part")
	part.Name = "AstralForgeVRPanel"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.Transparency = 1
	part.CastShadow = false
	part.Size = Vector3.new(6, 4, 0.05)
	part.Parent = Workspace
	surface.Adornee = part
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 1, -64)
	content.Position = UDim2.fromOffset(0, 0)
	content.BackgroundColor3 = Color3.fromRGB(14, 11, 20)
	content.BorderSizePixel = 0
	content.ClipsDescendants = true
	content.Parent = surface
	host.container = content
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 1
	overlay.ZIndex = 1000
	overlay.Parent = surface
	host.overlay = overlay
	local header = Instance.new("TextButton")
	header.Name = "VRRecenter"
	header.Size = UDim2.new(1, 0, 0, 64)
	header.Position = UDim2.new(0, 0, 1, -64)
	header.BackgroundColor3 = Color3.fromRGB(27, 23, 39)
	header.TextColor3 = Color3.fromRGB(230, 239, 255)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 23
	header.Text = "ASTRAL FORGE  ·  RECENTER PANEL  ·  L3 recenter / R3 show or hide"
	header.Selectable = true
	header.Parent = surface
	local previousLaser, previousModels = VRService.LaserPointer, VRService.ControllerModels
	local basePosition = nil
	function host.recenter()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local head = camera:GetRenderCFrame()
		local scale = math.max(0.1, camera.HeadScale)
		local position = head.Position + head.LookVector * 6 * scale
		part.Size = Vector3.new(6, 4, 0.05) * scale
		local up = if math.abs(head.LookVector.Y) > 0.95 then head.UpVector else Vector3.yAxis
		part.CFrame = CFrame.lookAt(position, head.Position, up)
		basePosition = camera.CFrame.Position
	end
	local function action(name, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if name == "AFVRRecenter" then
			host.recenter()
		else
			surface.Enabled = not surface.Enabled
		end
		return Enum.ContextActionResult.Sink
	end
	local function sync()
		local active = VRService.VREnabled or forcePreview == true
		if active == host.active then
			return
		end
		host.active = active
		surface.Enabled = active
		screen.Enabled = not active
		Workspace:SetAttribute("AstralForgeVRCanvasWidth", if active then VRInterface.Width else nil)
		Workspace:SetAttribute("AstralForgeVRCanvasHeight", if active then VRInterface.Height - 64 else nil)
		if active then
			pcall(function()
				VRService.LaserPointer = Enum.VRLaserPointerMode.DualPointer
				VRService.ControllerModels = Enum.VRControllerModelMode.Transparent
			end)
			host.recenter()
			ContextActionService:BindActionAtPriority("AFVRRecenter", action, false, 3000, Enum.KeyCode.ButtonL3)
			ContextActionService:BindActionAtPriority("AFVRToggle", action, false, 3000, Enum.KeyCode.ButtonR3)
		else
			ContextActionService:UnbindAction("AFVRRecenter")
			ContextActionService:UnbindAction("AFVRToggle")
			pcall(function()
				VRService.LaserPointer = previousLaser
				VRService.ControllerModels = previousModels
			end)
		end
		if changed then
			changed(host)
		end
	end
	table.insert(host.connections, header.Activated:Connect(host.recenter))
	table.insert(host.connections, VRService:GetPropertyChangedSignal("VREnabled"):Connect(sync))
	table.insert(
		host.connections,
		RunService.RenderStepped:Connect(function()
			if not host.active then
				return
			end
			local camera = Workspace.CurrentCamera
			if not camera or not basePosition then
				return
			end
			-- Follow locomotion only. A head turn leaves the panel comfortably in place.
			local delta = camera.CFrame.Position - basePosition
			part.CFrame += delta
			basePosition = camera.CFrame.Position
		end)
	)
	function host.dispose()
		if host.disposed then
			return
		end
		host.disposed = true
		for _, connection in host.connections do
			connection:Disconnect()
		end
		ContextActionService:UnbindAction("AFVRRecenter")
		ContextActionService:UnbindAction("AFVRToggle")
		Workspace:SetAttribute("AstralForgeVRCanvasWidth", nil)
		Workspace:SetAttribute("AstralForgeVRCanvasHeight", nil)
		pcall(function()
			VRService.LaserPointer = previousLaser
			VRService.ControllerModels = previousModels
		end)
		surface:Destroy()
		part:Destroy()
		if screen.Parent then
			screen.Enabled = true
		end
	end
	sync()
	return host
end
return VRInterface
