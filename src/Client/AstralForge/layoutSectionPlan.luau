--!strict
-- Pure layout section planners for Overview bands and Workspace chrome.
-- No Roblox / React — PageRouter / MainGame and Lune verify scripts share
-- these so section heights stay testable without Studio. Behavior mirrors
-- the prior inline math; callers inject chrome/theme constants.

local LayoutSectionPlan = {}

export type OverviewFlags = {
	stack: boolean,
	phone: boolean,
	landscapePhone: boolean,
	wideOverview: boolean,
	ultraOverview: boolean,
	rebirthVisible: boolean,
	domainVisible: boolean,
	countdownInPage: boolean,
	chromePanelGap: number,
	layoutPanelGap: number,
}

export type OverviewPlan = {
	heroH: number,
	rebirthH: number,
	domainH: number,
	notesH: number,
	opsH: number,
	metricCardH: number,
	metricsH: number,
	countdownH: number,
	sectionGap: number,
	topBandH: number,
	sectionCount: number,
	overviewTail: number,
	contentIntrinsic: number,
}

export type WorkspaceFlags = {
	keyboardCompact: boolean,
	stack: boolean,
	landscape: boolean,
	workspaceHeaderH: number,
	layoutWorkspaceHeaderHeight: number,
	tapTarget: number,
	showNextGoal: boolean,
}

export type WorkspacePlan = {
	headerHeight: number,
	unlockH: number,
}

function LayoutSectionPlan.planOverview(flags: OverviewFlags): OverviewPlan
	local stack = flags.stack == true
	local phone = flags.phone == true
	local landscapePhone = flags.landscapePhone == true
	local wideOverview = flags.wideOverview == true
	local ultraOverview = flags.ultraOverview == true
	local rebirthVisible = flags.rebirthVisible == true
	local domainVisible = flags.domainVisible == true
	local countdownInPage = flags.countdownInPage == true
	local chromePanelGap = tonumber(flags.chromePanelGap) or 10
	local layoutPanelGap = tonumber(flags.layoutPanelGap) or 14

	local heroH = if landscapePhone
		then 176
		elseif phone then 272
		elseif ultraOverview then 240
		elseif wideOverview then 232
		else 248
	local rebirthH = if rebirthVisible
		then (if phone then (if landscapePhone then 248 else 300) else (if ultraOverview then 220 else 208))
		else 0
	local domainH = if domainVisible
		then (if phone then (if landscapePhone then 268 else 320) else (if ultraOverview then 236 else 224))
		else 0
	local notesH = if stack
		then (if landscapePhone then 132 else 168)
		else (if ultraOverview then 152 else 140)
	-- Ops Pulse: phone uses a 2×2 claim grid so Collect stays above the fold.
	local opsH = if landscapePhone then 156 elseif stack then 196 else (if ultraOverview then 168 else 156)
	local metricCardH = if stack
		then (if landscapePhone then 64 else 86)
		elseif wideOverview then (if ultraOverview then 76 else 68)
		else 0
	local metricsH = if stack then metricCardH * 3 + 16 elseif wideOverview then heroH else 104
	local countdownH = if countdownInPage
		then (if stack then (if landscapePhone then 128 else 168) else (if ultraOverview then 152 else 140))
		else 0
	-- topBandH collapses hero+metrics into one row on wide PC; remaining sections still stack.
	local sectionGap = if stack
		then chromePanelGap
		elseif ultraOverview then 18
		elseif wideOverview then 16
		else layoutPanelGap
	local topBandH = if wideOverview then heroH else heroH + metricsH + sectionGap
	local sectionCount = 1
		+ 1
		+ 1
		+ (if countdownInPage then 1 else 0)
		+ (if rebirthVisible then 1 else 0)
		+ (if domainVisible then 1 else 0)
	local overviewTail = if landscapePhone then 48 elseif stack then 56 else (if ultraOverview then 48 else 40)
	local contentIntrinsic = topBandH
		+ notesH
		+ opsH
		+ countdownH
		+ rebirthH
		+ domainH
		+ sectionGap * math.max(0, sectionCount - 1)

	return {
		heroH = heroH,
		rebirthH = rebirthH,
		domainH = domainH,
		notesH = notesH,
		opsH = opsH,
		metricCardH = metricCardH,
		metricsH = metricsH,
		countdownH = countdownH,
		sectionGap = sectionGap,
		topBandH = topBandH,
		sectionCount = sectionCount,
		overviewTail = overviewTail,
		contentIntrinsic = contentIntrinsic,
	}
end

function LayoutSectionPlan.planWorkspace(flags: WorkspaceFlags): WorkspacePlan
	local keyboardCompact = flags.keyboardCompact == true
	local stack = flags.stack == true
	local landscape = flags.landscape == true
	local workspaceHeaderH = tonumber(flags.workspaceHeaderH) or 0
	local layoutWorkspaceHeaderHeight = tonumber(flags.layoutWorkspaceHeaderHeight) or 86
	local tapTarget = tonumber(flags.tapTarget) or 48
	local showNextGoal = flags.showNextGoal == true

	-- Phone stack uses MobileHeader for page chrome, so chrome.workspaceHeaderH is 0 and the
	-- Workspace title/collect strip must stay collapsed — otherwise we double-tax vertical
	-- space and first-screen CTAs fall below the fold. Keyboard-open with a zero plan header
	-- stays collapsed (MobileHeader + tab bar are already hidden in that mode).
	local headerHeight: number
	if keyboardCompact then
		headerHeight = if landscape or workspaceHeaderH <= 0 then 0 else tapTarget
	elseif stack then
		headerHeight = workspaceHeaderH
	else
		headerHeight = layoutWorkspaceHeaderHeight
	end

	-- Next-goal strip: skip on landscape and whenever the workspace header itself is gone.
	local unlockH = 0
	if not keyboardCompact and not landscape and headerHeight > 0 and showNextGoal then
		unlockH = 32
	end

	return {
		headerHeight = headerHeight,
		unlockH = unlockH,
	}
end

return table.freeze(LayoutSectionPlan)
