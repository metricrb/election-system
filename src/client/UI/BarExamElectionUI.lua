--!strict
--[[
	Bar Exam–styled election UI (layout inspired by BarExamPortal / Figma shell).
	Same controller surface as `ElectionUI.mount` for `ElectionClient`.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedFolder = ReplicatedStorage:WaitForChild("ElectionSystemShared")
local Types = require(SharedFolder:WaitForChild("Types"))

local BarExamElectionUI = {}

local TRICOLOR_H = 4
local HEADER_H = 56
local MODAL_DISPLAY_ORDER = 1_000_000

local B = {
	ModalBackdropNavy = Color3.fromRGB(15, 23, 42),
	CreamPanel = Color3.fromRGB(250, 248, 244),
	PortalBorder = Color3.fromRGB(200, 190, 175),
	HeaderNavy = Color3.fromRGB(30, 41, 59),
	AccentBlue = Color3.fromRGB(0, 85, 164),
	AccentWhite = Color3.fromRGB(255, 255, 255),
	AccentRed = Color3.fromRGB(239, 51, 64),
	White = Color3.fromRGB(255, 255, 255),
	Gold = Color3.fromRGB(212, 175, 55),
	TextMuted = Color3.fromRGB(100, 100, 110),
	TextBody = Color3.fromRGB(40, 40, 48),
	OkGreen = Color3.fromRGB(16, 185, 129),
	BadRed = Color3.fromRGB(239, 68, 68),
}

type ElectionClientConfig = {
	votingMethod: Types.VotingMethod,
	governmentType: Types.GovernmentType,
	ui: Types.UiConfig,
	parties: { Types.Party },
	candidates: { Types.Candidate },
	districts: { Types.District },
	twoRoundStyle: Types.TwoRoundStyle?,
	playerDistrict: Types.District?,
}

local function pad(inst: GuiObject, l: number, r: number, t: number, b: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, l)
	p.PaddingRight = UDim.new(0, r)
	p.PaddingTop = UDim.new(0, t)
	p.PaddingBottom = UDim.new(0, b)
	p.Parent = inst
end

local function letterForIndex(i: number): string
	return string.char(string.byte("A") + i)
end

local function normalizePhase(raw: any, depth: number?): string
	local d = (depth or 0) + 1
	if d > 16 then
		return "Scheduled"
	end
	if type(raw) == "string" and raw ~= "" then
		local trimmed = string.match(raw, "^%s*(.-)%s*$") or raw
		if trimmed ~= "" then
			return trimmed
		end
	end
	if type(raw) == "table" then
		local t = raw :: { [any]: any }
		for _, key in ipairs({ "phase", "Phase", "value", "Value", "state", "State", "name" }) do
			local v = t[key]
			if v ~= nil then
				return normalizePhase(v, d)
			end
		end
		if t[1] ~= nil then
			return normalizePhase(t[1], d)
		end
		local known: { [string]: boolean } = {
			Scheduled = true,
			Open = true,
			Closed = true,
			ResultsOut = true,
			Coalition = true,
			Formed = true,
		}
		for _, v in pairs(t) do
			if type(v) == "string" and known[v] then
				return v
			end
		end
		for _, v in pairs(t) do
			if type(v) == "string" and v ~= "" then
				return v
			end
		end
		return "Scheduled"
	end
	return "Scheduled"
end

local function phaseMessage(phase: string, secondsRemaining: number): string
	if phase == "Scheduled" then
		if secondsRemaining <= 0 then
			return "Voting is open — use a voting booth to cast your ballot."
		end
		return "Voting will begin soon. Check back when the election opens."
	elseif phase == "Open" then
		return "Use a voting booth prompt to open your ballot."
	elseif phase == "Closed" then
		return "Voting is currently closed. Waiting for results."
	elseif phase == "ResultsOut" or phase == "Coalition" or phase == "Formed" then
		return "Election results are available."
	end
	return "—"
end

local function normalizeUserFacingString(value: any, fallback: string): string
	if type(value) == "string" then
		return value
	end
	if type(value) == "table" then
		local t = value :: { [any]: any }
		local inner = t.message or t.text or t.reason or t[1]
		if type(inner) == "string" then
			return inner
		end
	end
	local coerced = tostring(value)
	if coerced == "" or string.sub(coerced, 1, 6) == "table:" then
		return fallback
	end
	return coerced
end

local function isDualBallot(method: string): boolean
	return method == "MMP" or method == "Parallel"
end

local function constituencyIdFromCandidate(cand: Types.Candidate): string?
	for _, tag in ipairs(cand.policyTags) do
		local prefix = "constituency:"
		if string.sub(tag, 1, #prefix) == prefix then
			return string.sub(tag, #prefix + 1)
		end
	end
	return nil
end

local function partyNameForId(parties: { Types.Party }, partyId: string?): string
	if not partyId or partyId == "" then
		return "—"
	end
	for _, p in ipairs(parties) do
		if p.partyId == partyId then
			return p.name
		end
	end
	return "—"
end

local function candidateBallotLabel(c: Types.Candidate, parties: { Types.Party }): string
	return c.name .. " — " .. partyNameForId(parties, c.partyId)
end

local function getBallotCandidatesAndDistrict(
	config: ElectionClientConfig,
	localPlayer: Player
): (Types.District?, { Types.Candidate })
	local districtsList = config.districts
	if not districtsList or #districtsList == 0 then
		return nil, table.clone(config.candidates)
	end

	local playerDistrict: Types.District? = nil
	local explicit = localPlayer:GetAttribute("DistrictId")
	if type(explicit) ~= "string" then
		explicit = localPlayer:GetAttribute("ElectionDistrictId")
	end
	if type(explicit) == "string" then
		for _, d in ipairs(districtsList) do
			if d.districtId == explicit then
				playerDistrict = d
				break
			end
		end
	end
	if not playerDistrict then
		playerDistrict = config.playerDistrict
	end
	if not playerDistrict then
		warn(
			"[BarExamElectionUI] playerDistrict missing — cannot match server constituency. Re-fetch config or rejoin."
		)
		return nil, {}
	end

	local did = playerDistrict.districtId
	local ballotCandidates: { Types.Candidate } = {}
	for _, c in ipairs(config.candidates) do
		if constituencyIdFromCandidate(c) == did then
			table.insert(ballotCandidates, c)
		end
	end
	-- Never fall back to the full candidate list for district elections (wrong ballot vs server validation).
	return playerDistrict, ballotCandidates
end

function BarExamElectionUI.mount(
	electionConfig: ElectionClientConfig?,
	callbacks: { submitVote: (Types.Ballot) -> boolean }?
)
	local config: ElectionClientConfig = electionConfig :: any
	local submitVote = callbacks and callbacks.submitVote or function(_b: Types.Ballot)
		return false
	end

	local localPlayer = Players.LocalPlayer
	local playerDistrict: Types.District? = nil
	local ballotCandidates: { Types.Candidate } = {}

	local phaseNow = "Scheduled"
	local countdownSec = 0
	local currentView = ""
	local isOpen = false
	local postSubmitAlreadyVoteGraceUntil = 0
	local resultsSnapshot: any = nil
	local ineligibleMsg = ""

	-- Ballot editor state
	local fptpChoice: string? = nil
	local approval: { [string]: boolean } = {}
	local scores: { [string]: number } = {}
	local ranks: { [string]: number } = {} -- candidateId -> rank
	local mmpStep = 0 -- 0 local cand, 1 party
	local mmpLocal: string? = nil
	local mmpParty: string? = nil
	local voted = false

	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ElectionBarExamUI"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = MODAL_DISPLAY_ORDER
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundColor3 = B.ModalBackdropNavy
	root.BorderSizePixel = 0
	root.Parent = screenGui

	local card = Instance.new("Frame")
	card.Name = "Shell"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.Size = UDim2.new(0.94, 0, 0.92, 0)
	card.BackgroundColor3 = B.CreamPanel
	card.BorderSizePixel = 0
	card.Parent = root
	local cap = Instance.new("UISizeConstraint")
	cap.MinSize = Vector2.new(320, 400)
	cap.MaxSize = Vector2.new(920, 1000)
	cap.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = B.PortalBorder
	stroke.Thickness = 2
	stroke.Parent = card

	local tri = Instance.new("Frame")
	tri.Size = UDim2.new(1, 0, 0, TRICOLOR_H)
	tri.BackgroundTransparency = 1
	tri.BorderSizePixel = 0
	tri.Parent = card
	for i, color in ipairs({ B.AccentBlue, B.AccentWhite, B.AccentRed }) do
		local seg = Instance.new("Frame")
		seg.Size = UDim2.new(1 / 3, 0, 1, 0)
		seg.Position = UDim2.new((i - 1) / 3, 0, 0, 0)
		seg.BackgroundColor3 = color
		seg.BorderSizePixel = 0
		seg.Parent = tri
	end

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, HEADER_H)
	header.Position = UDim2.new(0, 0, 0, TRICOLOR_H)
	header.BackgroundColor3 = B.HeaderNavy
	header.BorderSizePixel = 0
	header.Parent = card
	pad(header, 18, 18, 10, 10)

	local titleMain = Instance.new("TextLabel")
	titleMain.BackgroundTransparency = 1
	titleMain.Size = UDim2.new(0.7, 0, 0, 22)
	titleMain.Position = UDim2.new(0, 0, 0, 4)
	titleMain.Font = Enum.Font.GothamBold
	titleMain.TextSize = 15
	titleMain.TextColor3 = B.White
	titleMain.TextXAlignment = Enum.TextXAlignment.Left
	titleMain.Text = config.ui.electionTitle
	titleMain.Parent = header

	local titleSub = Instance.new("TextLabel")
	titleSub.BackgroundTransparency = 1
	titleSub.Size = UDim2.new(0.7, 0, 0, 16)
	titleSub.Position = UDim2.new(0, 0, 0, 26)
	titleSub.Font = Enum.Font.GothamBold
	titleSub.TextSize = 10
	titleSub.TextColor3 = B.Gold
	titleSub.TextXAlignment = Enum.TextXAlignment.Left
	titleSub.Text = "National Election Portal"
	titleSub.Parent = header

	local closeHdr = Instance.new("TextButton")
	closeHdr.Name = "CloseHeader"
	closeHdr.Size = UDim2.new(0, 72, 0, 22)
	closeHdr.Position = UDim2.new(1, -72, 0, 14)
	closeHdr.BackgroundTransparency = 1
	closeHdr.Text = "Close"
	closeHdr.Font = Enum.Font.GothamMedium
	closeHdr.TextSize = 11
	closeHdr.TextColor3 = B.Gold
	closeHdr.Parent = header

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.new(0, 0, 0, TRICOLOR_H + HEADER_H)
	content.Size = UDim2.new(1, 0, 1, -(TRICOLOR_H + HEADER_H))
	content.Parent = card

	-- --- Countdown panel ---
	local countdownPanel = Instance.new("ScrollingFrame")
	countdownPanel.Name = "Countdown"
	countdownPanel.Size = UDim2.new(1, 0, 1, 0)
	countdownPanel.BackgroundTransparency = 1
	countdownPanel.ScrollBarThickness = 6
	countdownPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	countdownPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
	countdownPanel.BorderSizePixel = 0
	countdownPanel.Parent = content
	pad(countdownPanel, 20, 20, 16, 16)
	local cdLayout = Instance.new("UIListLayout")
	cdLayout.Padding = UDim.new(0, 10)
	cdLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cdLayout.Parent = countdownPanel

	local cdTitle = Instance.new("TextLabel")
	cdTitle.BackgroundTransparency = 1
	cdTitle.Size = UDim2.new(1, 0, 0, 26)
	cdTitle.LayoutOrder = 1
	cdTitle.Font = Enum.Font.GothamBold
	cdTitle.TextSize = 20
	cdTitle.TextColor3 = B.HeaderNavy
	cdTitle.TextXAlignment = Enum.TextXAlignment.Left
	cdTitle.Text = config.ui.electionTitle
	cdTitle.Parent = countdownPanel

	local cdSub = Instance.new("TextLabel")
	cdSub.BackgroundTransparency = 1
	cdSub.Size = UDim2.new(1, 0, 0, 20)
	cdSub.LayoutOrder = 2
	cdSub.Font = Enum.Font.Gotham
	cdSub.TextSize = 12
	cdSub.TextColor3 = B.TextMuted
	cdSub.TextXAlignment = Enum.TextXAlignment.Left
	cdSub.Text = config.votingMethod .. " · " .. config.governmentType
	cdSub.Parent = countdownPanel

	local wardLbl = Instance.new("TextLabel")
	wardLbl.BackgroundTransparency = 1
	wardLbl.Size = UDim2.new(1, 0, 0, 22)
	wardLbl.LayoutOrder = 3
	wardLbl.Visible = playerDistrict ~= nil
	wardLbl.Font = Enum.Font.GothamMedium
	wardLbl.TextSize = 12
	wardLbl.TextColor3 = B.HeaderNavy
	wardLbl.TextXAlignment = Enum.TextXAlignment.Left
	wardLbl.Text = if playerDistrict then ("Constituency: %s"):format(playerDistrict.name) else ""
	wardLbl.Parent = countdownPanel

	local function applyConstituencyFromAttributes()
		local pd, bc = getBallotCandidatesAndDistrict(config, localPlayer)
		playerDistrict = pd
		ballotCandidates = bc;
		(config :: any).playerDistrict = pd
		wardLbl.Visible = playerDistrict ~= nil
		wardLbl.Text = if playerDistrict then ("Constituency: %s"):format(playerDistrict.name) else ""
	end

	applyConstituencyFromAttributes()

	local infoBox = Instance.new("TextLabel")
	infoBox.BackgroundTransparency = 1
	infoBox.Size = UDim2.new(1, 0, 0, 120)
	infoBox.LayoutOrder = 4
	infoBox.Font = Enum.Font.Gotham
	infoBox.TextSize = 13
	infoBox.TextColor3 = B.TextBody
	infoBox.TextWrapped = true
	infoBox.TextXAlignment = Enum.TextXAlignment.Left
	infoBox.TextYAlignment = Enum.TextYAlignment.Top
	infoBox.Text = phaseMessage(phaseNow, countdownSec)
	infoBox.Parent = countdownPanel

	local cdTime = Instance.new("TextLabel")
	cdTime.BackgroundTransparency = 1
	cdTime.Size = UDim2.new(1, 0, 0, 22)
	cdTime.LayoutOrder = 5
	cdTime.Font = Enum.Font.GothamBold
	cdTime.TextSize = 14
	cdTime.TextColor3 = B.HeaderNavy
	cdTime.TextXAlignment = Enum.TextXAlignment.Left
	cdTime.Text = "—"
	cdTime.Parent = countdownPanel

	local openBallotBtn = Instance.new("TextButton")
	openBallotBtn.Name = "OpenBallot"
	openBallotBtn.LayoutOrder = 10
	openBallotBtn.Size = UDim2.new(1, 0, 0, 42)
	openBallotBtn.BackgroundColor3 = B.HeaderNavy
	openBallotBtn.TextColor3 = B.White
	openBallotBtn.Text = "Cast ballot"
	openBallotBtn.Font = Enum.Font.GothamBold
	openBallotBtn.TextSize = 14
	openBallotBtn.BorderSizePixel = 0
	openBallotBtn.Parent = countdownPanel
	local obc = Instance.new("UICorner")
	obc.CornerRadius = UDim.new(0, 6)
	obc.Parent = openBallotBtn

	-- --- Ballot ---
	local ballotPanel = Instance.new("Frame")
	ballotPanel.Name = "Ballot"
	ballotPanel.Visible = false
	ballotPanel.Size = UDim2.new(1, 0, 1, 0)
	ballotPanel.BackgroundTransparency = 1
	ballotPanel.Parent = content

	local ballotScroll = Instance.new("ScrollingFrame")
	ballotScroll.Name = "Body"
	ballotScroll.Position = UDim2.new(0, 0, 0, 0)
	ballotScroll.Size = UDim2.new(1, 0, 1, -52)
	ballotScroll.BackgroundTransparency = 1
	ballotScroll.ScrollBarThickness = 6
	ballotScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	ballotScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	ballotScroll.BorderSizePixel = 0
	ballotScroll.Parent = ballotPanel
	pad(ballotScroll, 16, 16, 10, 10)
	local ballotList = Instance.new("UIListLayout")
	ballotList.Padding = UDim.new(0, 8)
	ballotList.SortOrder = Enum.SortOrder.LayoutOrder
	ballotList.Parent = ballotScroll

	local ballotFooter = Instance.new("Frame")
	ballotFooter.Size = UDim2.new(1, 0, 0, 48)
	ballotFooter.Position = UDim2.new(0, 0, 1, -48)
	ballotFooter.BackgroundColor3 = B.White
	ballotFooter.BorderSizePixel = 0
	ballotFooter.Parent = ballotPanel
	local bfStroke = Instance.new("UIStroke")
	bfStroke.Color = B.PortalBorder
	bfStroke.Parent = ballotFooter

	local submitBtn = Instance.new("TextButton")
	submitBtn.Name = "SubmitVote"
	submitBtn.Size = UDim2.new(0, 120, 0, 34)
	submitBtn.Position = UDim2.new(1, -132, 0, 7)
	submitBtn.BackgroundColor3 = B.HeaderNavy
	submitBtn.TextColor3 = B.White
	submitBtn.Font = Enum.Font.GothamBold
	submitBtn.TextSize = 12
	submitBtn.Text = "Submit vote"
	submitBtn.BorderSizePixel = 0
	submitBtn.Parent = ballotFooter
	local sbc = Instance.new("UICorner")
	sbc.CornerRadius = UDim.new(0, 6)
	sbc.Parent = submitBtn

	local backBallotBtn = Instance.new("TextButton")
	backBallotBtn.Size = UDim2.new(0, 80, 0, 34)
	backBallotBtn.Position = UDim2.new(0, 12, 0, 7)
	backBallotBtn.BackgroundColor3 = B.White
	backBallotBtn.TextColor3 = B.HeaderNavy
	backBallotBtn.Text = "← Back"
	backBallotBtn.Font = Enum.Font.GothamBold
	backBallotBtn.TextSize = 11
	backBallotBtn.BorderSizePixel = 0
	backBallotBtn.Parent = ballotFooter
	local bbs = Instance.new("UIStroke")
	bbs.Color = B.PortalBorder
	bbs.Parent = backBallotBtn
	local bbc = Instance.new("UICorner")
	bbc.CornerRadius = UDim.new(0, 6)
	bbc.Parent = backBallotBtn

	local statusFooter = Instance.new("TextLabel")
	statusFooter.BackgroundTransparency = 1
	statusFooter.Size = UDim2.new(1, -220, 0, 34)
	statusFooter.Position = UDim2.new(0, 100, 0, 7)
	statusFooter.Font = Enum.Font.Gotham
	statusFooter.TextSize = 11
	statusFooter.TextColor3 = B.TextMuted
	statusFooter.Text = ""
	statusFooter.TextTruncate = Enum.TextTruncate.AtEnd
	statusFooter.Parent = ballotFooter

	-- Simple status panels (thank you / already / ineligible / kick)
	local function makeFullBleedPanel(name: string): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.Visible = false
		f.Size = UDim2.new(1, 0, 1, 0)
		f.BackgroundTransparency = 1
		f.Parent = content
		return f
	end

	local thankPanel = makeFullBleedPanel("ThankYou")
	local alreadyPanel = makeFullBleedPanel("AlreadyVoted")
	local inelPanel = makeFullBleedPanel("Ineligible")
	local kickPanel = makeFullBleedPanel("Kick")
	local resultsPanel = makeFullBleedPanel("Results")

	local showView: (string) -> ()

	local function makeCenterCard(parent: Frame, title: string, body: string, btnText: string?, onOk: (() -> ())?)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.new(1, 0, 1, 0)
		scroll.BackgroundTransparency = 1
		scroll.ScrollBarThickness = 6
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.BorderSizePixel = 0
		scroll.Parent = parent
		pad(scroll, 24, 24, 24, 24)
		local lay = Instance.new("UIListLayout")
		lay.Padding = UDim.new(0, 12)
		lay.SortOrder = Enum.SortOrder.LayoutOrder
		lay.Parent = scroll

		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, 28)
		t.LayoutOrder = 1
		t.Font = Enum.Font.GothamBold
		t.TextSize = 20
		t.TextColor3 = B.HeaderNavy
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = title
		t.Parent = scroll

		local b = Instance.new("TextLabel")
		b.BackgroundTransparency = 1
		b.Size = UDim2.new(1, 0, 0, 80)
		b.LayoutOrder = 2
		b.Font = Enum.Font.Gotham
		b.TextSize = 14
		b.TextColor3 = B.TextBody
		b.TextWrapped = true
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.TextYAlignment = Enum.TextYAlignment.Top
		b.Text = body
		b.Parent = scroll

		if btnText and onOk then
			local ok = Instance.new("TextButton")
			ok.LayoutOrder = 10
			ok.Size = UDim2.new(1, 0, 0, 40)
			ok.BackgroundColor3 = B.HeaderNavy
			ok.TextColor3 = B.White
			ok.Font = Enum.Font.GothamBold
			ok.TextSize = 13
			ok.Text = btnText
			ok.BorderSizePixel = 0
			ok.Parent = scroll
			local okc = Instance.new("UICorner")
			okc.CornerRadius = UDim.new(0, 6)
			okc.Parent = ok
			ok.MouseButton1Click:Connect(onOk)
		end
	end

	makeCenterCard(
		thankPanel,
		"Vote submitted",
		"Your vote has been recorded. Thank you for participating.",
		"Close",
		function()
			showView("Countdown")
		end
	)

	makeCenterCard(
		alreadyPanel,
		"Already voted",
		"You have already cast your vote in this election.",
		"Close",
		function()
			showView("Countdown")
		end
	)

	makeCenterCard(inelPanel, "Not eligible", "You are not eligible to vote.", "Close", function()
		showView("Countdown")
	end)

	makeCenterCard(
		kickPanel,
		"Alt account detected",
		"Multiple accounts detected. Vote manipulation is prohibited.",
		"Close",
		function()
			showView("Countdown")
		end
	)

	-- Results build lazily
	local resultsScroll = Instance.new("ScrollingFrame")
	resultsScroll.Name = "ResultsScroll"
	resultsScroll.Size = UDim2.new(1, 0, 1, 0)
	resultsScroll.BackgroundTransparency = 1
	resultsScroll.ScrollBarThickness = 6
	resultsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	resultsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	resultsScroll.BorderSizePixel = 0
	resultsScroll.Parent = resultsPanel
	pad(resultsScroll, 20, 20, 16, 16)
	local resLayout = Instance.new("UIListLayout")
	resLayout.Padding = UDim.new(0, 10)
	resLayout.SortOrder = Enum.SortOrder.LayoutOrder
	resLayout.Parent = resultsScroll

	local function updateCountdownUi()
		if countdownSec <= 0 then
			cdTime.Text = "Opens soon or is open — listen for booth prompts."
		else
			local m = math.floor(countdownSec / 60)
			local s = countdownSec % 60
			cdTime.Text = ("Time remaining: %d:%02d"):format(m, s)
		end
		infoBox.Text = phaseMessage(phaseNow, countdownSec)
		local districtMode = config.districts and #config.districts > 0
		local canInteract = (phaseNow == "Open") and not voted and (not districtMode or #ballotCandidates > 0)
		openBallotBtn.Visible = canInteract
		if not canInteract and phaseNow ~= "Open" then
			openBallotBtn.Visible = false
		end
	end

	local function clearBallotBody()
		for _, ch in ballotScroll:GetChildren() do
			if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
				ch:Destroy()
			end
		end
	end

	local function rankingCandidateList(): { Types.Candidate }
		local m = config.votingMethod :: string
		if m == "Borda" or m == "Condorcet" then
			return config.candidates
		end
		return ballotCandidates
	end

	local function buildBallot(): Types.Ballot?
		applyConstituencyFromAttributes()
		local m = config.votingMethod :: string
		if fptpChoice then
			local found = false
			for _, c in ipairs(ballotCandidates) do
				if c.candidateId == fptpChoice then
					found = true
					break
				end
			end
			if not found then
				fptpChoice = nil
			end
		end
		if mmpLocal then
			local foundLocal = false
			for _, c in ipairs(ballotCandidates) do
				if c.candidateId == mmpLocal then
					foundLocal = true
					break
				end
			end
			if not foundLocal then
				mmpLocal = nil
				mmpParty = nil
				mmpStep = 0
			end
		end
		if m == "Sortition" then
			statusFooter.Text = ""
			return {}
		end

		if isDualBallot(m) then
			if mmpStep == 0 or not mmpLocal then
				statusFooter.Text = "Select your local candidate."
				return nil
			end
			if not mmpParty then
				statusFooter.Text = "Select a party."
				return nil
			end
			statusFooter.Text = ""
			return {
				{ candidateId = mmpLocal :: string, rank = 1 },
				{ candidateId = mmpParty :: string, rank = 1 },
			}
		end

		if m == "PartyListPR" then
			if not fptpChoice then
				statusFooter.Text = "Select one party."
				return nil
			end
			statusFooter.Text = ""
			return { { candidateId = fptpChoice :: string, rank = 1 } }
		end

		if (m == "TwoRound" and config.twoRoundStyle == "RegisteredRoll") or m == "FPTP" then
			if not fptpChoice then
				statusFooter.Text = "Select one option."
				return nil
			end
			statusFooter.Text = ""
			return { { candidateId = fptpChoice :: string, rank = 1 } }
		end

		if m == "Approval" then
			local b: Types.Ballot = {}
			for _, c in ipairs(ballotCandidates) do
				table.insert(b, {
					candidateId = c.candidateId,
					approved = approval[c.candidateId] == true,
				})
			end
			if #b == 0 then
				return nil
			end
			statusFooter.Text = ""
			return b
		end

		if m == "Score" or m == "STAR" then
			local b: Types.Ballot = {}
			for _, c in ipairs(ballotCandidates) do
				local sc = scores[c.candidateId] or 0
				table.insert(b, { candidateId = c.candidateId, score = sc })
			end
			statusFooter.Text = ""
			return b
		end

		if m == "Cumulative" then
			local b: Types.Ballot = {}
			local sum = 0
			for _, c in ipairs(ballotCandidates) do
				local sc = scores[c.candidateId] or 0
				sum += sc
				table.insert(b, { candidateId = c.candidateId, score = sc })
			end
			if sum ~= #ballotCandidates then
				statusFooter.Text = ("Distribute exactly %d points (total now %d)."):format(#ballotCandidates, sum)
				return nil
			end
			statusFooter.Text = ""
			return b
		end

		if
			m == "IRV"
			or m == "STV"
			or m == "Borda"
			or m == "Condorcet"
			or (m == "TwoRound" and config.twoRoundStyle ~= "RegisteredRoll")
		then
			local list = rankingCandidateList()
			local entries: { Types.BallotEntry } = {}
			for _, c in ipairs(list) do
				local r = ranks[c.candidateId]
				if type(r) == "number" and r > 0 then
					table.insert(entries, { candidateId = c.candidateId, rank = r })
				end
			end
			table.sort(entries, function(aa, bb)
				return (aa.rank or 0) < (bb.rank or 0)
			end)

			if m == "TwoRound" and #entries < 2 then
				statusFooter.Text = "Rank at least two candidates."
				return nil
			end
			if m == "STV" and #entries < config.seats then
				statusFooter.Text = ("Rank at least %d candidates."):format(config.seats)
				return nil
			end
			if m == "IRV" and #entries < 1 then
				statusFooter.Text = "Rank at least one candidate."
				return nil
			end
			if (m == "Borda" or m == "Condorcet") and #entries ~= #list then
				statusFooter.Text = "Assign a unique rank to every candidate."
				return nil
			end

			local seen: { [number]: boolean } = {}
			for _, e in ipairs(entries) do
				local rr = e.rank or 0
				if seen[rr] then
					statusFooter.Text = "Duplicate ranks are not allowed."
					return nil
				end
				seen[rr] = true
			end

			statusFooter.Text = ""
			return entries
		end

		statusFooter.Text = ("Voting method %s is not supported in this skin — use default ElectionUI."):format(m)
		return nil
	end

	local function rebuildBallotUi(resetEditor: boolean?)
		clearBallotBody()
		local doReset = resetEditor ~= false
		if doReset then
			applyConstituencyFromAttributes()
		end
		if #config.districts > 0 and #ballotCandidates == 0 then
			local err = Instance.new("TextLabel")
			err.BackgroundTransparency = 1
			err.Size = UDim2.new(1, -24, 0, 140)
			err.Position = UDim2.new(0, 12, 0, 8)
			err.TextWrapped = true
			err.Font = Enum.Font.GothamMedium
			err.TextSize = 14
			err.TextColor3 = B.BadRed
			err.TextXAlignment = Enum.TextXAlignment.Left
			if playerDistrict then
				err.Text =
					"No candidates are tagged for your constituency in Settings, or the list failed to load. You cannot vote until this is fixed."
			else
				err.Text =
					"The server did not assign your constituency. Rejoin, or ensure the election system is running before opening the UI."
			end
			err.Parent = ballotScroll
			return
		end
		if doReset then
			mmpStep = 0
			mmpLocal = nil
			mmpParty = nil
			fptpChoice = nil
			table.clear(approval)
			table.clear(scores)
			table.clear(ranks)
			for _, c in ipairs(ballotCandidates) do
				approval[c.candidateId] = false
				scores[c.candidateId] = 0
			end
		end

		local m = config.votingMethod :: string
		local order = 1

		local hint = Instance.new("TextLabel")
		hint.BackgroundTransparency = 1
		hint.Size = UDim2.new(1, 0, 0, 40)
		hint.LayoutOrder = order
		order += 1
		hint.Font = Enum.Font.GothamBold
		hint.TextSize = 14
		hint.TextColor3 = B.HeaderNavy
		hint.TextWrapped = true
		hint.TextXAlignment = Enum.TextXAlignment.Left
		hint.Text = ("Method: %s — follow the instructions below."):format(m)
		hint.Parent = ballotScroll

		if playerDistrict then
			local w = Instance.new("TextLabel")
			w.BackgroundTransparency = 1
			w.Size = UDim2.new(1, 0, 0, 20)
			w.LayoutOrder = order
			order += 1
			w.Font = Enum.Font.GothamMedium
			w.TextSize = 12
			w.TextColor3 = B.HeaderNavy
			w.TextXAlignment = Enum.TextXAlignment.Left
			w.Text = ("Constituency: %s"):format(playerDistrict.name)
			w.Parent = ballotScroll
		end

		local function addMcOptions(list: { Types.Candidate }, picked: (string) -> (), isParty: boolean?)
			for idx, c in ipairs(list) do
				local id = c.candidateId
				local label = if isParty then c.name else candidateBallotLabel(c, config.parties)
				local optBtn = Instance.new("TextButton")
				optBtn.LayoutOrder = order
				order += 1
				optBtn.Size = UDim2.new(1, 0, 0, 0)
				optBtn.AutomaticSize = Enum.AutomaticSize.Y
				local sel = fptpChoice == id
				if isDualBallot(m) and mmpStep == 0 then
					sel = mmpLocal == id
				elseif isDualBallot(m) and mmpStep == 1 then
					sel = mmpParty == id
				end
				optBtn.BackgroundColor3 = if sel then B.HeaderNavy else B.White
				optBtn.BorderSizePixel = 0
				optBtn.AutoButtonColor = false
				optBtn.Text = ""
				optBtn.Parent = ballotScroll
				local st = Instance.new("UIStroke")
				st.Color = if sel then B.Gold else B.PortalBorder
				st.Thickness = if sel then 2 else 1
				st.Parent = optBtn
				local oc = Instance.new("UICorner")
				oc.CornerRadius = UDim.new(0, 6)
				oc.Parent = optBtn
				local inner = Instance.new("TextLabel")
				inner.BackgroundTransparency = 1
				inner.Size = UDim2.new(1, -16, 0, 0)
				inner.Position = UDim2.new(0, 8, 0, 8)
				inner.AutomaticSize = Enum.AutomaticSize.Y
				inner.Font = if sel then Enum.Font.GothamBold else Enum.Font.Gotham
				inner.TextSize = 12
				inner.TextColor3 = if sel then B.White else B.TextBody
				inner.TextWrapped = true
				inner.TextXAlignment = Enum.TextXAlignment.Left
				inner.Text = (if sel then "✓ " else "") .. letterForIndex(idx - 1) .. ". " .. label
				inner.Parent = optBtn
				optBtn.Activated:Connect(function()
					picked(id)
					rebuildBallotUi(false)
				end)
			end
		end

		if m == "Sortition" then
			hint.Text = "Sortition — submit to confirm participation (no choices)."
			return
		end

		if isDualBallot(m) then
			if mmpStep == 0 then
				hint.Text = "Step 1 of 2 — choose your constituency candidate."
				addMcOptions(ballotCandidates, function(id)
					mmpLocal = id
					mmpStep = 1
				end)
				return
			end
			hint.Text = "Step 2 of 2 — choose your party vote."
			local fake: { Types.Candidate } = {}
			for _, p in ipairs(config.parties) do
				table.insert(fake, {
					candidateId = p.partyId,
					userId = "0",
					name = p.name,
					bio = "",
					policyTags = {},
				} :: Types.Candidate)
			end
			addMcOptions(fake, function(id)
				mmpParty = id
			end, true)
			local prev = Instance.new("TextButton")
			prev.LayoutOrder = order
			order += 1
			prev.Size = UDim2.new(1, 0, 0, 32)
			prev.Text = "← Change local vote"
			prev.Font = Enum.Font.Gotham
			prev.TextSize = 11
			prev.BackgroundColor3 = B.White
			prev.TextColor3 = B.HeaderNavy
			prev.BorderSizePixel = 0
			prev.Parent = ballotScroll
			prev.MouseButton1Click:Connect(function()
				mmpStep = 0
				mmpParty = nil
				rebuildBallotUi(false)
			end)
			return
		end

		if m == "PartyListPR" then
			local fake: { Types.Candidate } = {}
			for _, p in ipairs(config.parties) do
				table.insert(fake, {
					candidateId = p.partyId,
					userId = "0",
					name = p.name,
					bio = p.description or "",
					policyTags = {},
				} :: Types.Candidate)
			end
			hint.Text = "Select one party list."
			addMcOptions(fake, function(id)
				fptpChoice = id
			end, true)
			return
		end

		if m == "FPTP" or m == "Sortition" or (m == "TwoRound" and config.twoRoundStyle == "RegisteredRoll") then
			hint.Text = "Select one candidate."
			addMcOptions(ballotCandidates, function(id)
				fptpChoice = id
			end)
			return
		end

		if m == "Approval" then
			hint.Text = "Toggle all candidates you approve of."
			for idx, c in ipairs(ballotCandidates) do
				local on = approval[c.candidateId] == true
				local row = Instance.new("TextButton")
				row.LayoutOrder = order
				order += 1
				row.Size = UDim2.new(1, 0, 0, 36)
				row.BackgroundColor3 = if on then B.HeaderNavy else B.White
				row.TextColor3 = if on then B.White else B.HeaderNavy
				row.Font = Enum.Font.GothamBold
				row.TextSize = 12
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.Text = ("  %s  %s"):format(if on then "☑" else "☐", candidateBallotLabel(c, config.parties))
				row.BorderSizePixel = 0
				row.Parent = ballotScroll
			row.Activated:Connect(function()
				approval[c.candidateId] = not on
				rebuildBallotUi(false)
			end)
			end
			return
		end

		if m == "Score" or m == "STAR" or m == "Cumulative" then
			hint.Text = if m == "Cumulative"
				then ("Allocate exactly %d points across candidates (scores below)."):format(#ballotCandidates)
				else "Score each candidate from 0–5."
			for _, c in ipairs(ballotCandidates) do
				local row = Instance.new("Frame")
				row.LayoutOrder = order
				order += 1
				row.Size = UDim2.new(1, 0, 0, 40)
				row.BackgroundTransparency = 1
				row.Parent = ballotScroll
				local nl = Instance.new("TextLabel")
				nl.Size = UDim2.new(0.55, 0, 1, 0)
				nl.BackgroundTransparency = 1
				nl.Font = Enum.Font.GothamMedium
				nl.TextSize = 12
				nl.TextColor3 = B.TextBody
				nl.TextXAlignment = Enum.TextXAlignment.Left
				nl.Text = candidateBallotLabel(c, config.parties)
				nl.Parent = row
				local val = Instance.new("TextLabel")
				val.Name = "Val"
				val.Size = UDim2.new(0.15, 0, 1, 0)
				val.Position = UDim2.new(0.55, 0, 0, 0)
				val.BackgroundTransparency = 1
				val.Text = tostring(scores[c.candidateId] or 0)
				val.Font = Enum.Font.GothamBold
				val.TextSize = 14
				val.TextColor3 = B.HeaderNavy
				val.Parent = row
				for i = 0, 5 do
					local b = Instance.new("TextButton")
					b.Size = UDim2.new(0, 28, 0, 28)
					b.Position = UDim2.new(0.72 + i * 0.045, 0, 0.15, 0)
					b.Text = tostring(i)
					b.Font = Enum.Font.GothamBold
					b.TextSize = 11
					b.BackgroundColor3 = B.White
					b.Parent = row
					b.MouseButton1Click:Connect(function()
						scores[c.candidateId] = i
						val.Text = tostring(i)
					end)
				end
			end
			return
		end

		-- Ranked methods
		hint.Text = "Enter a unique rank (1 = best) for each row. Leave blank to skip (where allowed)."
		local rlist = rankingCandidateList()
		for _, c in ipairs(rlist) do
			local row = Instance.new("Frame")
			row.LayoutOrder = order
			order += 1
			row.Size = UDim2.new(1, 0, 0, 36)
			row.BackgroundTransparency = 1
			row.Parent = ballotScroll
			local nl = Instance.new("TextLabel")
			nl.Size = UDim2.new(0.62, 0, 1, 0)
			nl.BackgroundTransparency = 1
			nl.Font = Enum.Font.Gotham
			nl.TextSize = 12
			nl.TextColor3 = B.TextBody
			nl.TextXAlignment = Enum.TextXAlignment.Left
			nl.Text = candidateBallotLabel(c, config.parties)
			nl.Parent = row
			local tb = Instance.new("TextBox")
			tb.Size = UDim2.new(0.3, 0, 0, 28)
			tb.Position = UDim2.new(0.68, 0, 0.1, 0)
			tb.BackgroundColor3 = B.White
			tb.TextColor3 = B.TextBody
			tb.Font = Enum.Font.GothamBold
			tb.TextSize = 14
			tb.ClearTextOnFocus = false
			tb.Text = if ranks[c.candidateId] then tostring(ranks[c.candidateId]) else ""
			tb.PlaceholderText = "rank"
			tb.Parent = row
			tb:GetPropertyChangedSignal("Text"):Connect(function()
				local n = tonumber(tb.Text)
				if n then
					ranks[c.candidateId] = math.floor(n)
				else
					ranks[c.candidateId] = nil :: any
				end
			end)
		end
	end

	local function rebuildResultsUi()
		for _, ch in resultsScroll:GetChildren() do
			if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
				ch:Destroy()
			end
		end
		local order = 1
		local h = Instance.new("TextLabel")
		h.BackgroundTransparency = 1
		h.Size = UDim2.new(1, 0, 0, 26)
		h.LayoutOrder = order
		order += 1
		h.Font = Enum.Font.GothamBold
		h.TextSize = 20
		h.TextColor3 = B.HeaderNavy
		h.TextXAlignment = Enum.TextXAlignment.Left
		h.Text = "Election results"
		h.Parent = resultsScroll

		if not resultsSnapshot then
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.new(1, 0, 0, 40)
			t.LayoutOrder = order
			t.Font = Enum.Font.Gotham
			t.TextSize = 13
			t.TextColor3 = B.TextMuted
			t.TextWrapped = true
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.Text = "No results data yet."
			t.Parent = resultsScroll
			return
		end

		local share = resultsSnapshot.voteShare
		if type(share) == "table" then
			for cid, pct in pairs(share) do
				local row = Instance.new("TextLabel")
				row.BackgroundTransparency = 1
				row.Size = UDim2.new(1, 0, 0, 22)
				row.LayoutOrder = order
				order += 1
				row.Font = Enum.Font.Gotham
				row.TextSize = 13
				row.TextColor3 = B.TextBody
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.Text = ("%s — %.1f%%"):format(tostring(cid), typeof(pct) == "number" and pct or 0)
				row.Parent = resultsScroll
			end
		end
	end

	local function openGui()
		isOpen = true
		screenGui.DisplayOrder = MODAL_DISPLAY_ORDER
		local p = screenGui.Parent
		if p then
			screenGui.Parent = nil
			screenGui.Parent = p
		end
		screenGui.Enabled = true
	end

	local function closeGui()
		isOpen = false
		screenGui.Enabled = false
		currentView = ""
	end

	showView = function(target: string)
		openGui()
		currentView = target
		countdownPanel.Visible = target == "Countdown"
		ballotPanel.Visible = target == "Ballot"
		thankPanel.Visible = target == "ThankYou"
		alreadyPanel.Visible = target == "AlreadyVoted"
		inelPanel.Visible = target == "Ineligible"
		kickPanel.Visible = target == "Kick"
		resultsPanel.Visible = target == "Results"

		titleMain.Text = if target == "Results" then "Results" else config.ui.electionTitle
		if target == "Ballot" then
			rebuildBallotUi()
		end
		if target == "Results" then
			rebuildResultsUi()
		end
		if target == "Countdown" then
			applyConstituencyFromAttributes()
			updateCountdownUi()
		end
	end

	closeHdr.MouseButton1Click:Connect(closeGui)
	openBallotBtn.MouseButton1Click:Connect(function()
		showView("Ballot")
	end)
	backBallotBtn.MouseButton1Click:Connect(function()
		showView("Countdown")
	end)
	submitBtn.MouseButton1Click:Connect(function()
		local b = buildBallot()
		if not b then
			return
		end
		local ok = submitVote(b)
		if ok then
			voted = true
			postSubmitAlreadyVoteGraceUntil = tick() + 3
			showView("ThankYou")
		end
	end)

	local function onDistrictAttributeChanged()
		applyConstituencyFromAttributes()
		mmpStep = 0
		mmpLocal = nil
		mmpParty = nil
		fptpChoice = nil
		table.clear(approval)
		table.clear(scores)
		table.clear(ranks)
		for _, c in ipairs(ballotCandidates) do
			approval[c.candidateId] = false
			scores[c.candidateId] = 0
		end
		updateCountdownUi()
		if currentView == "Ballot" then
			rebuildBallotUi(true)
		end
	end

	localPlayer:GetAttributeChangedSignal("ElectionDistrictId"):Connect(onDistrictAttributeChanged)
	localPlayer:GetAttributeChangedSignal("DistrictId"):Connect(onDistrictAttributeChanged)

	return {
		setPhase = function(nextPhase: Types.ElectionPhase)
			phaseNow = normalizePhase(nextPhase)
			if not isOpen then
				return
			end
			if currentView == "Ballot" then
				if phaseNow == "ResultsOut" or phaseNow == "Coalition" or phaseNow == "Formed" then
					showView("Results")
				end
				return
			end
			if currentView == "ThankYou" or currentView == "AlreadyVoted" then
				if phaseNow == "ResultsOut" or phaseNow == "Coalition" or phaseNow == "Formed" then
					showView("Results")
				end
				return
			end
			if currentView == "Ineligible" or currentView == "Kick" then
				return
			end
			if phaseNow == "ResultsOut" or phaseNow == "Coalition" or phaseNow == "Formed" then
				showView("Results")
			else
				showView("Countdown")
			end
		end,
		setCountdown = function(secondsLeft: any)
			local n = secondsLeft
			if type(n) == "table" then
				n = n.countdown or n[1] or 0
			end
			countdownSec = math.max(0, math.floor(tonumber(n) or 0))
			if isOpen and currentView == "Countdown" then
				updateCountdownUi()
			end
		end,
		showBallot = function()
			if voted then
				return
			end
			mmpStep = 0
			showView("Ballot")
		end,
		isBallotOpen = function(): boolean
			return isOpen and currentView == "Ballot"
		end,
		showResults = function(results: any)
			resultsSnapshot = results
			showView("Results")
		end,
		showAlreadyVoted = function()
			if tick() < postSubmitAlreadyVoteGraceUntil then
				return
			end
			showView("AlreadyVoted")
		end,
		showIneligible = function(reason: any)
			ineligibleMsg = normalizeUserFacingString(reason, "You are not eligible to vote.")
			local scroll = inelPanel:FindFirstChildWhichIsA("ScrollingFrame")
			if scroll then
				for _, ch in scroll:GetChildren() do
					if ch:IsA("TextLabel") and ch.LayoutOrder == 2 then
						ch.Text = ineligibleMsg
						break
					end
				end
			end
			showView("Ineligible")
		end,
		showKick = function()
			showView("Kick")
		end,
		showThankYou = function()
			voted = true
			postSubmitAlreadyVoteGraceUntil = tick() + 3
			showView("ThankYou")
		end,
		hide = function()
			closeGui()
		end,
	}
end

return BarExamElectionUI
