--!strict
-- Purpose: Build a distinct, disposable 3D preview for each score-only arcade game.
-- Owner: Astral Forge presentation. Dependencies: React, MotionKit, ArcadeViewportScene. Last-reviewed: 2026-10-07.

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactTypes = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts-js"].React)
local RunService = game:GetService("RunService")
local Motion = require(script.Parent.MotionKit)("motion")
local Scene = require(script.Parent.ArcadeViewportScene)
local CreateElement = React.createElement
type Element = ReactTypes.ReactElement<{}, string>

type Props = {
	kind: string,
	size: UDim2?,
	position: UDim2?,
	zIndex: number?,
	animate: boolean?,
}

local function ArcadeViewport(props: Props): Element
	local host: { current: ViewportFrame? } = React.useRef(nil)
	local softMotion = Motion.useMotionSettings().soft == true
	React.useEffect(function(): (() -> ())?
		local viewport = host.current
		if viewport == nil then
			return nil
		end
		local world = Instance.new("WorldModel")
		world.Name = "ArcadePreviewWorld"
		world.Parent = viewport
		local camera = Instance.new("Camera")
		camera.Name = "ArcadePreviewCamera"
		camera.FieldOfView = 34
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, 10), Vector3.zero)
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local scene = Scene.BuildScene(world, props.kind)
		local connection: RBXScriptConnection? = nil
		if props.animate == true and not softMotion then
			connection = RunService.RenderStepped:Connect(function(): ()
				local elapsed = os.clock()
				local yaw = math.sin(elapsed * 0.7) * 0.035
				local bob = math.sin(elapsed * 1.1) * 0.035
				scene:PivotTo(CFrame.new(0, bob, 0) * CFrame.Angles(0, yaw, 0))
			end)
		end
		return function(): ()
			if connection ~= nil then
				connection:Disconnect()
			end
			viewport.CurrentCamera = nil
			world:Destroy()
			camera:Destroy()
		end
	end, { props.kind, props.animate == true, softMotion })
	return CreateElement("viewportframe", {
		Name = "ArcadeViewport_" .. props.kind,
		ref = host,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Ambient = Color3.fromRGB(155, 170, 195),
		LightColor = Color3.fromRGB(255, 246, 225),
		LightDirection = Vector3.new(-0.5, -0.8, 1),
		ZIndex = props.zIndex or 2,
	})
end

return ArcadeViewport
