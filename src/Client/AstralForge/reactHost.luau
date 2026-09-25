local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local reactModules = require(script.Parent.reactModules)
local notePage = require(script.Parent.vendorHost).notePage
local ClientLog = require(script.Parent.log).ClientLog
local Palette = require(script.Parent.theme).Palette

local PageHostContext = React.createContext({
	page = "",
	retry = function() end,
})

local function onPageRender(id, _phase, actualDuration)
	if type(actualDuration) ~= "number" or actualDuration < 20 then
		return nil
	end
	ClientLog:warnEvery(`react-slow-{id}`, 10, "React", `{id} commit took {math.floor(actualDuration)}ms`)
end

local PagePending = React.PureComponent:extend("PagePending")
function PagePending:render()
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, React.createElement("textlabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "Loading",
		TextColor3 = Palette.cream,
		TextSize = 16,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	}))
end

local function CrashNotice(props)
	local host = React.useContext(PageHostContext)
	local transparency, setTransparency = React.useBinding(1)
	local pressed, setPressed = React.useState(false)
	React.useDebugValue(props.message)
	reactModules.useMountEffect(function()
		setTransparency(0)
	end)
	reactModules.useTimeout(function()
		setPressed(false)
	end, if pressed then 0.45 else nil)
	local retry = React.useCallback(function()
		setPressed(true)
		if props.onRetry ~= nil then
			props.onRetry()
		else
			host.retry()
		end
	end, { host, props.onRetry })
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, React.createElement("textlabel", {
		Size = UDim2.new(1, -32, 0, 48),
		Position = UDim2.new(0.5, 0, 0.5, -36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = "This screen hit an error. You can open it again.",
		TextColor3 = Palette.cream,
		TextTransparency = transparency,
		TextSize = 16,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	}), React.createElement("textbutton", {
		Size = UDim2.fromOffset(140, 36),
		Position = UDim2.new(0.5, 0, 0.5, 28),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = if pressed then Palette.panelSoft else Palette.cyan,
		AutoButtonColor = false,
		Text = "TRY AGAIN",
		TextColor3 = Palette.ink,
		TextSize = 14,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		Event = {
			Activated = retry,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	})))
end

local PageErrorBoundary = React.Component:extend("PageErrorBoundary")
function PageErrorBoundary:init()
	self.state = {
		failed = false,
		message = "",
	}
end
function PageErrorBoundary.getDerivedStateFromError(err)
	return {
		failed = true,
		message = tostring(err),
	}
end
function PageErrorBoundary:componentDidCatch(err)
	ClientLog:warnEvery("react-page", 5, "React", tostring(err))
end
function PageErrorBoundary:render()
	if self.state.failed then
		return React.createElement(CrashNotice, {
			message = self.state.message,
			onRetry = function()
				self:setState({
					failed = false,
					message = "",
				})
			end,
		})
	end
	return self.props.children
end

local PageFrame = React.memo(React.forwardRef(function(props, ref)
	local page = props.page
	if page == nil then
		page = ""
	end
	local retryCount, bumpRetry = React.useReducer(function(count)
		return count + 1
	end, 0)
	local seenPage = React.useRef(page)
	local previousPage = reactModules.usePrevious(page)
	React.useDebugValue(if previousPage ~= nil and previousPage ~= "" then `{previousPage} -> {page}` else page)
	React.useLayoutEffect(function()
		seenPage.current = page
		return function()
			seenPage.current = ""
		end
	end, { page })
	-- notePage's debounce keeps one timer. A throttled Heartbeat (maxWait) overwrites
	-- that timer without disconnecting it, so rapid page switches leaked connections.
	React.useEffect(function()
		if page == "" then
			return nil
		end
		notePage(page)
		local pending = true
		local trailing = task.delay(0.12, function()
			pending = false
			notePage(page)
		end)
		return function()
			if pending then
				task.cancel(trailing)
			end
		end
	end, { page })
	React.useImperativeHandle(ref, function()
		return {
			retry = bumpRetry,
			page = function()
				return seenPage.current
			end,
		}
	end, { bumpRetry })
	local contextValue = React.useMemo(function()
		return {
			page = page,
			retry = bumpRetry,
		}
	end, { page, bumpRetry })
	local child = React.useMemo(function()
		local only = React.Children.only(props.children)
		if not React.isValidElement(only) then
			return only
		end
		return React.cloneElement(only, {
			key = `{page}:{retryCount}`,
		})
	end, { props.children, page, retryCount })
	return React.createElement(PageHostContext.Provider, {
		value = contextValue,
	}, React.createElement(React.Suspense, {
		fallback = React.createElement(PagePending),
	}, React.createElement(PageErrorBoundary, {
		key = `{page}:{retryCount}`,
	}, React.createElement(React.Profiler, {
		id = if page ~= "" then page else "Game",
		onRender = onPageRender,
	}, child))))
end))

return {
	PageFrame = PageFrame,
	PageErrorBoundary = PageErrorBoundary,
	PagePending = PagePending,
}
