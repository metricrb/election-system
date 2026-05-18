--!strict

-- ResultsPartScript.server.lua — place this script in a Part to display live election results on a SurfaceGui.
-- Chart style follows Cmdr `election_chart` (bar | pie), same data as `election_results`.
-- The board refreshes when `resultsCache` updates: votes trigger a debounced server-side recount
-- (`calculateResults(false)`), so counts stay live without pushing the full-screen results view to every client.

local ServerScriptService = game:GetService("ServerScriptService")
local electionModule = ServerScriptService:WaitForChild("ElectionSystem", 30)
assert(electionModule:IsA("ModuleScript"), "[ResultsPart] ElectionSystem module missing.")
local ElectionSystem = require(electionModule :: ModuleScript)
local CmdrSetup = require((electionModule :: ModuleScript):WaitForChild("Cmdr"):WaitForChild("CmdrSetup"))
local ResultsPresentation = require((electionModule :: ModuleScript):WaitForChild("Modules"):WaitForChild("ResultsPresentation"))
local CollectionService = game:GetService("CollectionService")

type Party = {
	partyId: string,
	name: string,
	decalId: number,
	colour: { r: number, g: number, b: number },
	description: string,
}
type VoteShareRow = {
	candidateId: string,
	label: string,
	pct: number,
	partyId: string?,
}

local ResultsPart = {}
local RESULTS_TAG = "ResultsPart"

local FALLBACK_COLORS = {
	Color3.fromRGB(220, 70, 70),
	Color3.fromRGB(70, 120, 220),
	Color3.fromRGB(90, 180, 90),
	Color3.fromRGB(220, 180, 60),
	Color3.fromRGB(180, 90, 200),
	Color3.fromRGB(80, 200, 200),
}

local function colorForRow(row: VoteShareRow, parties: { Party }, rowIndex: number): Color3
	if row.partyId then
		for _, p in ipairs(parties) do
			if p.partyId == row.partyId then
				local c = p.colour
				return Color3.fromRGB(c.r, c.g, c.b)
			end
		end
	end
	return FALLBACK_COLORS[(rowIndex - 1) % #FALLBACK_COLORS + 1]
end

local function makeRowLabel(parent: Instance, text: string, textSize: number, heightPx: number, layoutOrder: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, heightPx)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextSize = textSize
	label.Font = Enum.Font.Gotham
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	if layoutOrder then
		label.LayoutOrder = layoutOrder
	end
	label.Parent = parent
	return label
end

local function populateBarChart(
	scroll: ScrollingFrame,
	rows: { VoteShareRow },
	parties: { Party },
	layoutOrderStart: number
): number
	local o = layoutOrderStart
	for index, row in ipairs(rows) do
		local rowFrame = Instance.new("Frame")
		rowFrame.LayoutOrder = o
		o += 1
		rowFrame.Size = UDim2.new(1, 0, 0, 52)
		rowFrame.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
		rowFrame.BorderSizePixel = 0
		rowFrame.Parent = scroll

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = rowFrame

		local col = colorForRow(row, parties, index)

		local rank = Instance.new("TextLabel")
		rank.Size = UDim2.new(0.06, 0, 1, 0)
		rank.Position = UDim2.new(0, 6, 0, 0)
		rank.BackgroundTransparency = 1
		rank.Text = "#" .. tostring(index)
		rank.TextColor3 = Color3.fromRGB(160, 160, 170)
		rank.TextSize = 14
		rank.Font = Enum.Font.GothamMedium
		rank.Parent = rowFrame

		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.fromOffset(10, 10)
		swatch.Position = UDim2.new(0.08, 0, 0.5, -5)
		swatch.BackgroundColor3 = col
		swatch.BorderSizePixel = 0
		swatch.Parent = rowFrame
		local swc = Instance.new("UICorner")
		swc.CornerRadius = UDim.new(1, 0)
		swc.Parent = swatch

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.5, -8, 0.55, 0)
		nameLbl.Position = UDim2.new(0.12, 0, 0.06, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = row.label
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.TextSize = 15
		nameLbl.Font = Enum.Font.GothamMedium
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Parent = rowFrame

		local pctLbl = Instance.new("TextLabel")
		pctLbl.Size = UDim2.new(0.22, 0, 0.55, 0)
		pctLbl.Position = UDim2.new(0.78, 0, 0.06, 0)
		pctLbl.BackgroundTransparency = 1
		pctLbl.Text = string.format("%.1f%%", row.pct)
		pctLbl.TextColor3 = Color3.fromRGB(120, 200, 255)
		pctLbl.TextSize = 15
		pctLbl.Font = Enum.Font.GothamMedium
		pctLbl.TextXAlignment = Enum.TextXAlignment.Right
		pctLbl.Parent = rowFrame

		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(0.86, -12, 0.14, 0)
		barBg.Position = UDim2.new(0.12, 0, 0.72, 0)
		barBg.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
		barBg.BorderSizePixel = 0
		barBg.Parent = rowFrame
		local barBgC = Instance.new("UICorner")
		barBgC.CornerRadius = UDim.new(0, 4)
		barBgC.Parent = barBg

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(math.clamp(row.pct / 100, 0, 1), 0, 1, 0)
		fill.BackgroundColor3 = col
		fill.BorderSizePixel = 0
		fill.Parent = barBg
		local fillC = Instance.new("UICorner")
		fillC.CornerRadius = UDim.new(0, 4)
		fillC.Parent = fill
	end
	return o
end

local function populatePieComposition(
	scroll: ScrollingFrame,
	rows: { VoteShareRow },
	parties: { Party },
	layoutOrderStart: number
): number
	local o = layoutOrderStart
	local strip = Instance.new("Frame")
	strip.LayoutOrder = o
	o += 1
	strip.Size = UDim2.new(1, 0, 0, 36)
	strip.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
	strip.BorderSizePixel = 0
	strip.ClipsDescendants = true
	strip.Parent = scroll
	local stripC = Instance.new("UICorner")
	stripC.CornerRadius = UDim.new(0, 6)
	stripC.Parent = strip

	local xScale = 0
	for index, row in ipairs(rows) do
		local w = math.clamp(row.pct / 100, 0, 1)
		if w > 0 then
			local seg = Instance.new("Frame")
			seg.Size = UDim2.new(w, 0, 1, 0)
			seg.Position = UDim2.new(xScale, 0, 0, 0)
			seg.BackgroundColor3 = colorForRow(row, parties, index)
			seg.BorderSizePixel = 0
			seg.Parent = strip
			xScale += w
		end
	end

	makeRowLabel(scroll, "Vote share (proportional strip — pie layout)", 13, 22, o)
	o += 1

	for index, row in ipairs(rows) do
		local rowFrame = Instance.new("Frame")
		rowFrame.LayoutOrder = o
		o += 1
		rowFrame.Size = UDim2.new(1, 0, 0, 28)
		rowFrame.BackgroundTransparency = 1
		rowFrame.Parent = scroll

		local sw = Instance.new("Frame")
		sw.Size = UDim2.fromOffset(12, 12)
		sw.Position = UDim2.new(0, 4, 0.5, -6)
		sw.BackgroundColor3 = colorForRow(row, parties, index)
		sw.BorderSizePixel = 0
		sw.Parent = rowFrame
		local swc = Instance.new("UICorner")
		swc.CornerRadius = UDim.new(1, 0)
		swc.Parent = sw

		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.new(1, -24, 1, 0)
		txt.Position = UDim2.new(0, 22, 0, 0)
		txt.BackgroundTransparency = 1
		txt.Font = Enum.Font.Gotham
		txt.TextSize = 14
		txt.TextColor3 = Color3.fromRGB(235, 235, 240)
		txt.TextXAlignment = Enum.TextXAlignment.Left
		txt.Text = string.format("%s  ·  %.1f%%", row.label, row.pct)
		txt.TextTruncate = Enum.TextTruncate.AtEnd
		txt.Parent = rowFrame
	end
	return o
end

-- Setup results display
function ResultsPart.setup()
	local parts = CollectionService:GetTagged(RESULTS_TAG)
	if #parts == 0 then
		local part = Instance.new("Part")
		part.Name = "ElectionResultsBoard"
		part.Size = Vector3.new(16, 10, 1)
		part.Anchored = true
		part.Position = Vector3.new(0, 8, -16)
		part.Parent = workspace
		CollectionService:AddTag(part, RESULTS_TAG)
		parts = CollectionService:GetTagged(RESULTS_TAG)
	end

	for _, p in ipairs(parts) do
		if p:IsA("BasePart") then
			setupResultsDisplay(p :: Part)
		end
	end

	CollectionService:GetInstanceAddedSignal(RESULTS_TAG):Connect(function(instance)
		if instance:IsA("BasePart") then
			setupResultsDisplay(instance :: Part)
		end
	end)
end

function setupResultsDisplay(part: Part)
	local existing = part:FindFirstChild("ElectionResultsSurface")
	if existing and existing:IsA("SurfaceGui") then
		existing:Destroy()
	end

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "ElectionResultsSurface"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 35
	surfaceGui.AlwaysOnTop = false
	surfaceGui.Parent = part

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = surfaceGui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.09, 0)
	titleLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 22
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = ElectionSystem.Settings.ui.electionTitle
	titleLabel.BorderSizePixel = 0
	titleLabel.Parent = mainFrame

	local modeLabel = Instance.new("TextLabel")
	modeLabel.Name = "ChartModeHint"
	modeLabel.Size = UDim2.new(1, 0, 0.045, 0)
	modeLabel.Position = UDim2.new(0, 0, 0.09, 0)
	modeLabel.BackgroundTransparency = 1
	modeLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
	modeLabel.TextSize = 14
	modeLabel.Font = Enum.Font.GothamMedium
	modeLabel.BorderSizePixel = 0
	modeLabel.Parent = mainFrame

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "ResultsScroll"
	scroll.Size = UDim2.new(1, -16, 0.84, 0)
	scroll.Position = UDim2.new(0, 8, 0.14, 0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = mainFrame

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = scroll

		local function updateResults()
		for _, child in scroll:GetChildren() do
			if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
				child:Destroy()
			end
		end

		local chartMode = CmdrSetup.getChartMode()
		local results = ElectionSystem:getResults()
		if not results then
			modeLabel.Text = string.format("Live results · chart: %s", chartMode)
			makeRowLabel(scroll, "Calculating results…", 18, 36, 1)
			return
		end

		local settings = ElectionSystem.Settings
		local candidates = settings.candidates
		local parties = settings.parties
		local districtResults = (results :: any).districtResults :: { [string]: any }?

		if districtResults and settings.districts and #settings.districts > 0 then
			modeLabel.Text = string.format(
				"Live results · %s · chart: %s (`election_chart %s`)",
				"by constituency",
				chartMode,
				chartMode
			)

			local layoutOrder = 0
			makeRowLabel(
				scroll,
				string.format("All constituencies · %d vote(s) cast (sum of local ballots)", results.votesRecorded or 0),
				13,
				28,
				layoutOrder
			)
			layoutOrder += 1

			for _, dist in ipairs(settings.districts) do
				local dr = districtResults[dist.districtId]
					or ResultsPresentation.placeholderDistrictResult(dist.districtId, results.phase)
				local meta = ResultsPresentation.constituencyMetaLine(dist.name, dr)
				makeRowLabel(scroll, meta, 12, 44, layoutOrder)
				layoutOrder += 1

				local rows = ResultsPresentation.sortedRowsForConstituency(dr, candidates, dist.districtId)
				if #rows == 0 then
					makeRowLabel(scroll, "  No votes in this constituency yet.", 14, 26, layoutOrder)
					layoutOrder += 1
				else
					if chartMode == "pie" then
						layoutOrder = populatePieComposition(scroll, rows :: any, parties, layoutOrder)
					else
						layoutOrder = populateBarChart(scroll, rows :: any, parties, layoutOrder)
					end
				end
				layoutOrder += 1
				makeRowLabel(scroll, " ", 10, 6, layoutOrder)
				layoutOrder += 1
			end
			return
		end

		modeLabel.Text = string.format(
			"Live results · Cmdr chart: %s (`election_chart %s`)",
			chartMode,
			chartMode
		)

		local rows = ResultsPresentation.sortedRows(results, candidates)
		if #rows == 0 then
			makeRowLabel(scroll, "No vote share data yet.", 16, 28, 1)
			return
		end

		local meta = Instance.new("TextLabel")
		meta.LayoutOrder = 0
		meta.Size = UDim2.new(1, 0, 0, 24)
		meta.BackgroundTransparency = 1
		meta.Font = Enum.Font.Gotham
		meta.TextSize = 13
		meta.TextColor3 = Color3.fromRGB(180, 180, 190)
		meta.TextXAlignment = Enum.TextXAlignment.Left
		meta.Text = string.format(
			"Phase %s · %d ballots cast · bars show %% of votes cast (eligible roll is separate / legal only)",
			results.phase,
			results.votesRecorded
		)
		meta.Parent = scroll

		local nextOrder = 1
		if chartMode == "pie" then
			populatePieComposition(scroll, rows, parties, nextOrder)
		else
			populateBarChart(scroll, rows, parties, nextOrder)
		end
	end

	local store = ElectionSystem:getStore()
	store.dataChanged:connect(function(key)
		if key == "resultsCache" then
			updateResults()
		end
	end)

	CmdrSetup.connectChartModeChanged(function()
		updateResults()
	end)

	updateResults()
end

ResultsPart.setup()

return ResultsPart
