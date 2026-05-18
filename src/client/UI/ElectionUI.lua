--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Types = require(ReplicatedStorage:WaitForChild("ElectionSystemShared"):WaitForChild("Types"))

export type ElectionConfig = {
	votingMethod: Types.VotingMethod,
	governmentType: Types.GovernmentType?,
	seatSystem: Types.SeatSystem?,
	ui: Types.UiConfig,
	seats: number,
	parties: { Types.Party },
	candidates: { Types.Candidate },
	districts: { Types.District }?,
}

local ElectionUI = {}

local function rgb(c: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(c.r, c.g, c.b)
end

--[[
	Ballot list rows show selection via accent stroke + tinted card background; keep in Fusion onBind/onChange sync.
]]
local function syncBallotChoiceRowAppearance(row: GuiObject, accentColor: Color3, selected: boolean)
	row.BackgroundColor3 = if selected then Theme.Card:Lerp(accentColor, 0.22) else Theme.Card
	local stroke = row:FindFirstChild("Sel")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = if selected then accentColor else Theme.Border
		stroke.Thickness = if selected then 2 else 1
		stroke.Transparency = if selected then 0.08 else 0.4
	end
end

local function findParty(parties: { Types.Party }, partyId: string): Types.Party?
	for _, p in ipairs(parties) do
		if p.partyId == partyId then
			return p
		end
	end
	return nil
end

local function formatCountdown(total: number): string
	total = math.max(0, math.floor(total))
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	local seconds = total % 60
	return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

--[[
	Phase can arrive as a plain string or a wrapped table from remotes / Fusion; UI always needs a display string.
	Never use tostring(table) — that produces "table: 0x..." in the UI.
]]
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
				local s = normalizePhase(v, d)
				if type(v) == "string" or s ~= "Scheduled" then
					return s
				end
			end
		end
		if t[1] ~= nil then
			return normalizePhase(t[1], d)
		end
		-- first matching known phase string anywhere in shallow values
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
	if type(raw) == "number" or type(raw) == "boolean" then
		return tostring(raw)
	end
	return "Scheduled"
end

local function badgeStyle(phase: string): (Color3, Color3)
	if phase == "Open" then
		return Theme.Success, Theme.Foreground
	elseif phase == "Closed" then
		return Theme.Warning, Color3.fromRGB(20, 20, 20)
	elseif phase == "Scheduled" then
		return Theme.MutedForeground, Theme.Foreground
	elseif phase == "ResultsOut" or phase == "Coalition" or phase == "Formed" then
		return Theme.Primary, Theme.Foreground
	end
	return Theme.Muted, Theme.Foreground
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

local function isDualBallot(method: string): boolean
	return method == "MMP" or method == "Parallel"
end

local function buildBallot(
	method: string,
	localId: string?,
	partyId: string?,
	approvalSet: { [string]: boolean }?
): Types.Ballot
	if method == "MMP" or method == "Parallel" then
		return {
			{ candidateId = localId :: string, rank = 1 },
			{ candidateId = partyId :: string, rank = 1 },
		}
	elseif method == "Approval" and approvalSet then
		local ballot: Types.Ballot = {}
		for id, on in pairs(approvalSet) do
			if on then
				table.insert(ballot, { candidateId = id, approved = true })
			end
		end
		return ballot
	else
		return {
			{ candidateId = localId :: string, rank = 1 },
		}
	end
end

function ElectionUI.mount(electionConfig: ElectionConfig?, callbacks: { submitVote: (Types.Ballot) -> boolean }?)
	local config: ElectionConfig = electionConfig :: any
	local submitVote = callbacks and callbacks.submitVote or function(_b: Types.Ballot)
		return false
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

	local districtsList = config.districts
	local ballotCandidates: { Types.Candidate }
	local playerDistrict: Types.District? = nil
	if districtsList and #districtsList > 0 then
		local cfgAny = config :: any
		playerDistrict = cfgAny.playerDistrict
		local explicit = Players.LocalPlayer:GetAttribute("DistrictId")
		if type(explicit) ~= "string" then
			explicit = Players.LocalPlayer:GetAttribute("ElectionDistrictId")
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
			warn("[ElectionUI] playerDistrict missing from server — ballot list not scoped to a real constituency.")
			playerDistrict = nil
			ballotCandidates = {}
		else
			local did = playerDistrict.districtId
			ballotCandidates = {}
			for _, c in ipairs(config.candidates) do
				if constituencyIdFromCandidate(c) == did then
					table.insert(ballotCandidates, c)
				end
			end
		end
	else
		ballotCandidates = table.clone(config.candidates)
	end

	local wardBannerHeight = if playerDistrict then 0.08 else 0
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local scope = Fusion.scoped(Fusion)
	local function New(className: string)
		return scope:New(className)
	end
	local Children = Fusion.Children

	local isOpen = false
	local currentView = ""
	local postSubmitAlreadyVoteGraceUntil = 0

	local mainView = scope:Value("Countdown" :: string)
	local ballotStep = scope:Value("Vote" :: string)
	local phaseConn = scope:Value("Scheduled" :: Types.ElectionPhase)
	local countdownSec = scope:Value(0)
	local ineligibleText = scope:Value("")
	local resultsSnapshot = scope:Value(nil :: any)

	local selectedLocal = scope:Value(nil :: string?)
	local selectedParty = scope:Value(nil :: string?)
	local selectedFptp = scope:Value(nil :: string?)
	local browseFilterParty = scope:Value("all" :: string)
	local browseQuery = scope:Value("")
	local browseSelected = scope:Value(nil :: Types.Candidate?)
	local refreshBrowserList: () -> ()

	local syncPanelVisibility: () -> ()

	local accent = Theme.accentFromSettings(config.ui.accentColour)
	local titleText = config.ui.electionTitle

	--[[
		Must render above studio/place "starting room" UI, Cmdr (1000), and other ScreenGuis.
		Re-parent on open so we win ties when DisplayOrder matches another gui.
	]]
	local MODAL_DISPLAY_ORDER = 1_000_000

	local screenGui = New("ScreenGui") {
		Name = "ElectionSystemUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Enabled = false,
		DisplayOrder = MODAL_DISPLAY_ORDER,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	}

	local backdrop = New("Frame") {
		Parent = screenGui,
		Name = "Backdrop",
		ZIndex = 1,
		BackgroundColor3 = Theme.Backdrop,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Active = false,
	}

	local outer = New("Frame") {
		Parent = screenGui,
		Name = "Outer",
		ZIndex = 2,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.88),
		BackgroundTransparency = 1,
	}

	local scale = New("UIScale") {
		Parent = outer,
		Name = "RootScale",
		Scale = 1,
	}

	local card = New("Frame") {
		Parent = outer,
		Name = "Card",
		BackgroundColor3 = Theme.Card,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 12),
			},
			New("UIStroke") {
				Color = Theme.Border,
				Thickness = 1,
				Transparency = 0.3,
			},
		},
	}

	local header = New("Frame") {
		Parent = card,
		Name = "Header",
		BackgroundColor3 = Theme.Muted,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.11, 0),
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 12),
			},
		},
	}

	-- Clip header bottom corners: mask with parent - actually use separate bottom clip or smaller radius on bottom - skip for simplicity

	local headerTitle = New("TextLabel") {
		Parent = header,
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.03, 0.12),
		Size = UDim2.fromScale(0.94, 0.38),
		Font = Enum.Font.GothamBold,
		Text = titleText,
		TextColor3 = Theme.Foreground,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}

	New("UIPadding") {
		Parent = headerTitle,
		PaddingLeft = UDim.new(0, 4),
	}

	local phaseBadgeFrame = New("Frame") {
		Parent = header,
		Name = "PhaseBadge",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.03, 0.55),
		Size = UDim2.fromScale(0.35, 0.32),
	}

	local phaseBadgeInner = New("Frame") {
		Parent = phaseBadgeFrame,
		Name = "Badge",
		BackgroundColor3 = Theme.MutedForeground,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 6),
			},
		},
	}

	local phaseBadgeText = New("TextLabel") {
		Parent = phaseBadgeInner,
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamMedium,
		Text = "Phase: Scheduled",
		TextColor3 = Theme.Foreground,
		TextScaled = true,
	}

	local countdownLabel = New("TextLabel") {
		Parent = header,
		Name = "Countdown",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.42, 0.55),
		Size = UDim2.fromScale(0.55, 0.32),
		Font = Enum.Font.Gotham,
		Text = "Time: " .. formatCountdown(0),
		TextColor3 = Theme.MutedForeground,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
	}

	local closeBtn = New("TextButton") {
		Parent = header,
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0.1, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Theme.Muted,
		BorderSizePixel = 0,
		Text = "X",
		TextColor3 = Theme.MutedForeground,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = true,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
		},
	}

	local bodyFrame = New("Frame") {
		Parent = card,
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.11),
		Size = UDim2.new(1, 0, 0.89, 0),
	}

	-- ——— Panels ———

	local countdownPanel = New("Frame") {
		Parent = bodyFrame,
		Name = "CountdownPanel",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = true,
	}

	local iconFrame = New("Frame") {
		Parent = countdownPanel,
		Name = "Icon",
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.85,
		Position = UDim2.fromScale(0.05, 0.06),
		Size = UDim2.fromOffset(44, 44),
		BorderSizePixel = 0,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
			New("TextLabel") {
				Name = "G",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "🗳",
				TextSize = 22,
			},
		},
	}

	local infoCard = New("Frame") {
		Parent = countdownPanel,
		Name = "Info",
		BackgroundColor3 = Theme.Muted,
		BackgroundTransparency = 0.5,
		Position = UDim2.fromScale(0.05, 0.22),
		Size = UDim2.fromScale(0.9, 0.5),
		BorderSizePixel = 0,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
			New("UIStroke") {
				Color = Theme.Border,
				Transparency = 0.5,
				Thickness = 1,
			},
		},
	}

	local infoText = New("TextLabel") {
		Parent = infoCard,
		Name = "Message",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.08),
		Size = UDim2.fromScale(0.92, 0.84),
		Font = Enum.Font.Gotham,
		Text = phaseMessage("Scheduled", 0),
		TextColor3 = Theme.Foreground,
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}

	New("TextButton") {
		Parent = countdownPanel,
		Name = "CloseFooter",
		Position = UDim2.fromScale(0.65, 0.82),
		Size = UDim2.fromScale(0.3, 0.1),
		BackgroundColor3 = Theme.Muted,
		Text = "Close",
		TextColor3 = Theme.Foreground,
		Font = Enum.Font.GothamMedium,
		TextScaled = true,
		AutoButtonColor = true,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
		},
	}

	-- Ballot: dual / FPTP + browse + confirm

	local ballotPanel = New("Frame") {
		Parent = bodyFrame,
		Name = "BallotPanel",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}

	local ballotVoteFrame = New("Frame") {
		Parent = ballotPanel,
		Name = "Vote",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = true,
	}

	local ballotBrowseFrame = New("Frame") {
		Parent = ballotPanel,
		Name = "Browse",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}

	local ballotConfirmFrame = New("Frame") {
		Parent = ballotPanel,
		Name = "Confirm",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}

	New("TextLabel") {
		Parent = ballotVoteFrame,
		Name = "WardBanner",
		BackgroundColor3 = Theme.Muted,
		BackgroundTransparency = 0.65,
		Position = UDim2.fromScale(0.03, 0.02),
		Size = UDim2.fromScale(0.94, wardBannerHeight),
		Visible = playerDistrict ~= nil,
		Font = Enum.Font.GothamMedium,
		Text = if playerDistrict
			then ("Your constituency: %s"):format(playerDistrict.name)
			else "",
		TextColor3 = Theme.Foreground,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		BorderSizePixel = 0,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
			New("UIPadding") {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			},
		},
	}

	-- Dual columns
	local dualGrid = New("Frame") {
		Parent = ballotVoteFrame,
		Name = "DualGrid",
		BackgroundTransparency = 1,
		Position = if playerDistrict then UDim2.fromScale(0, 0.11) else UDim2.fromScale(0, 0),
		Size = if playerDistrict then UDim2.new(1, 0, 0.71, 0) else UDim2.new(1, 0, 0.82, 0),
		Visible = isDualBallot(config.votingMethod),
	}

	local leftCol = New("ScrollingFrame") {
		Parent = dualGrid,
		Name = "Constituency",
		BackgroundColor3 = Theme.Muted,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.02, 0.05),
		Size = UDim2.fromScale(0.46, 0.9),
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(0, 0, 1, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		[Children] = {
			New("UIListLayout") {
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			New("UIPadding") {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			},
		},
	}

	local rightCol = New("ScrollingFrame") {
		Parent = dualGrid,
		Name = "Party",
		BackgroundColor3 = Theme.Muted,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.52, 0.05),
		Size = UDim2.fromScale(0.46, 0.9),
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		[Children] = {
			New("UIListLayout") {
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			New("UIPadding") {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			},
		},
	}

	New("TextLabel") {
		Parent = ballotVoteFrame,
		Name = "DualHint1",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.02, 0),
		Size = UDim2.fromScale(0.45, 0.05),
		Font = Enum.Font.GothamMedium,
		Text = "1  Constituency vote",
		TextColor3 = accent,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = isDualBallot(config.votingMethod),
	}

	New("TextLabel") {
		Parent = ballotVoteFrame,
		Name = "DualHint2",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.52, 0),
		Size = UDim2.fromScale(0.45, 0.05),
		Font = Enum.Font.GothamMedium,
		Text = "2  Party vote",
		TextColor3 = accent,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = isDualBallot(config.votingMethod),
	}

	local fptpScroll = New("ScrollingFrame") {
		Parent = ballotVoteFrame,
		Name = "FPTPList",
		BackgroundTransparency = 1,
		Position = if playerDistrict then UDim2.fromScale(0.03, 0.12) else UDim2.fromScale(0.03, 0.06),
		Size = if playerDistrict then UDim2.fromScale(0.94, 0.68) else UDim2.fromScale(0.94, 0.76),
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = not isDualBallot(config.votingMethod),
		[Children] = {
			New("UIListLayout") {
				Padding = UDim.new(0, 8),
			},
			New("UIPadding") {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			},
		},
	}

	local warningBox = New("Frame") {
		Parent = ballotVoteFrame,
		Name = "Warn",
		BackgroundColor3 = Theme.Destructive,
		BackgroundTransparency = 0.9,
		Position = UDim2.fromScale(0.03, 0.68),
		Size = UDim2.fromScale(0.94, 0.1),
		Visible = false,
		BorderSizePixel = 0,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 6),
			},
			New("TextLabel") {
				Name = "T",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Font = Enum.Font.Gotham,
				Text = "Please complete all required selections.",
				TextColor3 = Theme.Destructive,
				TextScaled = true,
			},
		},
	}

	local browseBtn = New("TextButton") {
		Parent = ballotVoteFrame,
		Name = "BrowseCandidates",
		Position = UDim2.fromScale(0.03, 0.8),
		Size = UDim2.fromScale(0.28, 0.09),
		BackgroundColor3 = Theme.Muted,
		Text = "Browse candidates",
		TextColor3 = Theme.Foreground,
		Font = Enum.Font.GothamMedium,
		TextScaled = true,
		AutoButtonColor = true,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
		},
	}

	local reviewBtn = New("TextButton") {
		Parent = ballotVoteFrame,
		Name = "Review",
		Position = UDim2.fromScale(0.55, 0.8),
		Size = UDim2.fromScale(0.42, 0.1),
		BackgroundColor3 = accent,
		Text = "Review ballot",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		AutoButtonColor = true,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
		},
	}

	-- Populate dual columns
	for _, cand in ipairs(ballotCandidates) do
		local pid = cand.partyId or ""
		local p = findParty(config.parties, pid)
		local partyName = if p then p.name else "—"
		local row = New("TextButton") {
			Parent = leftCol,
			Name = cand.candidateId,
			Size = UDim2.new(1, -16, 0, 52),
			BackgroundColor3 = Theme.Card,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			[Children] = {
				New("UICorner") {
					CornerRadius = UDim.new(0, 8),
				},
				New("UIStroke") {
					Name = "Sel",
					Thickness = 1,
					Color = Theme.Border,
					Transparency = 0.4,
				},
				New("Frame") {
					Name = "Swatch",
					Active = false,
					Selectable = false,
					Size = UDim2.fromOffset(4, 40),
					Position = UDim2.new(0, 6, 0.5, -20),
					BackgroundColor3 = if p then rgb(p.colour) else Theme.Border,
					BorderSizePixel = 0,
					[Children] = {
						New("UICorner") {
							CornerRadius = UDim.new(0, 2),
						},
					},
				},
				New("TextLabel") {
					Name = "N",
					Active = false,
					Selectable = false,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 20, 0, 4),
					Size = UDim2.new(1, -28, 0.55, 0),
					Font = Enum.Font.GothamMedium,
					Text = cand.name,
					TextColor3 = Theme.Foreground,
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
				New("TextLabel") {
					Name = "P",
					Active = false,
					Selectable = false,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 20, 0.5, -2),
					Size = UDim2.new(1, -28, 0.45, 0),
					Font = Enum.Font.Gotham,
					Text = partyName,
					TextColor3 = Theme.MutedForeground,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			},
		}
		scope:Observer(selectedLocal):onBind(function()
			local sel = Fusion.peek(selectedLocal)
			syncBallotChoiceRowAppearance(row, accent, sel == cand.candidateId)
		end)
		row.MouseButton1Click:Connect(function()
			selectedLocal:set(cand.candidateId)
		end)
	end

	for _, party in ipairs(config.parties) do
		local prow = New("TextButton") {
			Parent = rightCol,
			Name = party.partyId,
			Size = UDim2.new(1, -16, 0, 56),
			BackgroundColor3 = Theme.Card,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			[Children] = {
				New("UICorner") {
					CornerRadius = UDim.new(0, 8),
				},
				New("UIStroke") {
					Name = "Sel",
					Thickness = 1,
					Color = Theme.Border,
					Transparency = 0.4,
				},
				New("Frame") {
					Name = "Swatch",
					Active = false,
					Selectable = false,
					Size = UDim2.fromOffset(8, 36),
					Position = UDim2.new(0, 8, 0.5, -18),
					BackgroundColor3 = rgb(party.colour),
					BorderSizePixel = 0,
					[Children] = {
						New("UICorner") {
							CornerRadius = UDim.new(0, 4),
						},
					},
				},
				New("TextLabel") {
					Name = "N",
					Active = false,
					Selectable = false,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 28, 0, 8),
					Size = UDim2.new(1, -36, 0, 22),
					Font = Enum.Font.GothamMedium,
					Text = party.name,
					TextColor3 = Theme.Foreground,
					TextSize = 17,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
				New("TextLabel") {
					Name = "D",
					Active = false,
					Selectable = false,
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 28, 0, 30),
					Size = UDim2.new(1, -36, 0, 18),
					Font = Enum.Font.Gotham,
					Text = party.description,
					TextColor3 = Theme.MutedForeground,
					TextSize = 12,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				},
			},
		}
		scope:Observer(selectedParty):onBind(function()
			local sel = Fusion.peek(selectedParty)
			syncBallotChoiceRowAppearance(prow, accent, sel == party.partyId)
		end)
		prow.MouseButton1Click:Connect(function()
			selectedParty:set(party.partyId)
		end)
	end

	for _, cand in ipairs(ballotCandidates) do
		local pid = cand.partyId or ""
		local p = findParty(config.parties, pid)
		local partyName = if p then p.name else "—"
		local frow = New("TextButton") {
			Parent = fptpScroll,
			Name = cand.candidateId,
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = Theme.Card,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			[Children] = {
				New("UICorner") {
					CornerRadius = UDim.new(0, 8),
				},
				New("UIStroke") {
					Name = "Sel",
					Thickness = 1,
					Color = Theme.Border,
				},
				New("TextLabel") {
					Active = false,
					Selectable = false,
					BackgroundTransparency = 1,
					Position = UDim2.new(0.02, 0, 0, 6),
					Size = UDim2.new(0.96, 0, 0.5, 0),
					Font = Enum.Font.GothamMedium,
					Text = cand.name,
					TextColor3 = Theme.Foreground,
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
				New("TextLabel") {
					Active = false,
					Selectable = false,
					BackgroundTransparency = 1,
					Position = UDim2.new(0.02, 0, 0.52, 0),
					Size = UDim2.new(0.96, 0, 0.42, 0),
					Font = Enum.Font.Gotham,
					Text = partyName,
					TextColor3 = Theme.MutedForeground,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			},
		}
		scope:Observer(selectedFptp):onBind(function()
			local sel = Fusion.peek(selectedFptp)
			syncBallotChoiceRowAppearance(frow, accent, sel == cand.candidateId)
		end)
		frow.MouseButton1Click:Connect(function()
			selectedFptp:set(cand.candidateId)
		end)
	end

	-- Candidate browser (filter + list + detail)
	local browserFilterRow = New("Frame") {
		Parent = ballotBrowseFrame,
		Name = "Filters",
		Size = UDim2.new(1, 0, 0.14, 0),
		BackgroundTransparency = 1,
	}

	local filterScroll = New("ScrollingFrame") {
		Parent = browserFilterRow,
		Name = "PartyTabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.new(1, 0, 0.55, 0),
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(2, 0, 1, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		[Children] = {
			New("UIListLayout") {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
			},
		},
	}

	local allTab = New("TextButton") {
		Parent = filterScroll,
		Name = "all",
		Size = UDim2.fromOffset(100, 30),
		BackgroundColor3 = accent,
		Text = "All",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 6),
			},
		},
	}

	for _, party in ipairs(config.parties) do
		local tab = New("TextButton") {
			Parent = filterScroll,
			Name = party.partyId,
			Size = UDim2.fromOffset(120, 30),
			BackgroundColor3 = Theme.Muted,
			Text = party.name,
			TextColor3 = Theme.MutedForeground,
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			[Children] = {
				New("UICorner") {
					CornerRadius = UDim.new(0, 6),
				},
			},
		}
		tab.MouseButton1Click:Connect(function()
			browseFilterParty:set(party.partyId)
			for _, c in ipairs(filterScroll:GetChildren()) do
				if c:IsA("TextButton") then
					local on = (party.partyId == c.Name and c.Name ~= "all") or false
					c.BackgroundColor3 = if on then accent else Theme.Muted
					c.TextColor3 = if on then Color3.new(1, 1, 1) else Theme.MutedForeground
				end
			end
			allTab.BackgroundColor3 = Theme.Muted
			allTab.TextColor3 = Theme.MutedForeground
			refreshBrowserList()
		end)
	end

	allTab.MouseButton1Click:Connect(function()
		browseFilterParty:set("all")
		allTab.BackgroundColor3 = accent
		allTab.TextColor3 = Color3.new(1, 1, 1)
		for _, c in ipairs(filterScroll:GetChildren()) do
			if c:IsA("TextButton") and c ~= allTab then
				c.BackgroundColor3 = Theme.Muted
				c.TextColor3 = Theme.MutedForeground
			end
		end
		refreshBrowserList()
	end)

	local browserSplit = New("Frame") {
		Parent = ballotBrowseFrame,
		Name = "Split",
		Position = UDim2.fromScale(0, 0.14),
		Size = UDim2.new(1, 0, 0.68, 0),
		BackgroundTransparency = 1,
	}

	local browserList = New("ScrollingFrame") {
		Parent = browserSplit,
		Name = "List",
		BackgroundColor3 = Theme.Muted,
		BackgroundTransparency = 0.85,
		Size = UDim2.fromScale(0.58, 1),
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		[Children] = {
			New("UIListLayout") {
				Padding = UDim.new(0, 6),
			},
			New("UIPadding") {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 6),
			},
		},
	}

	local browserDetail = New("Frame") {
		Parent = browserSplit,
		Name = "Detail",
		Position = UDim2.fromScale(0.6, 0),
		Size = UDim2.fromScale(0.38, 1),
		BackgroundColor3 = Theme.Card,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
		},
	}

	local detailTitle = New("TextLabel") {
		Parent = browserDetail,
		Name = "Name",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.06, 0.05),
		Size = UDim2.fromScale(0.88, 0.12),
		Font = Enum.Font.GothamBold,
		Text = "Select a candidate",
		TextColor3 = Theme.Foreground,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}

	local detailParty = New("TextLabel") {
		Parent = browserDetail,
		Name = "Party",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.06, 0.16),
		Size = UDim2.fromScale(0.88, 0.07),
		Font = Enum.Font.Gotham,
		Text = "",
		TextColor3 = Theme.MutedForeground,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}

	local detailBio = New("TextLabel") {
		Parent = browserDetail,
		Name = "Bio",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.06, 0.28),
		Size = UDim2.fromScale(0.88, 0.55),
		Font = Enum.Font.Gotham,
		Text = "",
		TextColor3 = Theme.Foreground,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}

	refreshBrowserList = function()
		for _, c in ipairs(browserList:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		local filter = Fusion.peek(browseFilterParty)
		local q = string.lower(Fusion.peek(browseQuery))
		for _, cand in ipairs(ballotCandidates) do
			local p = cand.partyId
			if filter == "all" or p == filter then
				local pObj = if p then findParty(config.parties, p) else nil
				local pName = if pObj then pObj.name else ""
				local ok = q == ""
					or string.find(string.lower(cand.name), q, 1, true)
					or (pName ~= "" and string.find(string.lower(pName), q, 1, true))
				if ok then
					local btn = New("TextButton") {
						Parent = browserList,
						Size = UDim2.new(1, -12, 0, 48),
						BackgroundColor3 = Theme.Card,
						Text = "",
						AutoButtonColor = false,
						[Children] = {
							New("UICorner") {
								CornerRadius = UDim.new(0, 6),
							},
							New("TextLabel") {
								BackgroundTransparency = 1,
								Size = UDim2.new(0.55, 0, 1, 0),
								Position = UDim2.new(0.03, 0, 0, 0),
								Font = Enum.Font.GothamMedium,
								Text = cand.name,
								TextColor3 = Theme.Foreground,
								TextSize = 15,
								TextXAlignment = Enum.TextXAlignment.Left,
							},
						},
					}
					btn.MouseButton1Click:Connect(function()
						browseSelected:set(cand)
						detailTitle.Text = cand.name
						local pp = cand.partyId and findParty(config.parties, cand.partyId)
						detailParty.Text = if pp then pp.name else ""
						detailBio.Text = cand.bio
					end)
				end
			end
		end
	end

	refreshBrowserList()

	local bbBack = New("TextButton") {
		Parent = ballotBrowseFrame,
		Name = "Back",
		Position = UDim2.fromScale(0.04, 0.86),
		Size = UDim2.fromScale(0.25, 0.09),
		BackgroundColor3 = Theme.Muted,
		Text = "← Back to ballot",
		TextColor3 = Theme.Foreground,
		Font = Enum.Font.GothamMedium,
		TextScaled = true,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
		},
	}

	browseBtn.MouseButton1Click:Connect(function()
		ballotStep:set("Browse")
		ballotVoteFrame.Visible = false
		ballotBrowseFrame.Visible = true
		ballotConfirmFrame.Visible = false
		refreshBrowserList()
	end)

	bbBack.MouseButton1Click:Connect(function()
		ballotStep:set("Vote")
		ballotVoteFrame.Visible = true
		ballotBrowseFrame.Visible = false
		ballotConfirmFrame.Visible = false
	end)

	local function ballotIsValid(): boolean
		if #ballotCandidates == 0 then
			return false
		end
		if isDualBallot(config.votingMethod) then
			return Fusion.peek(selectedLocal) ~= nil and Fusion.peek(selectedParty) ~= nil
		end
		return Fusion.peek(selectedFptp) ~= nil
	end

	-- Confirm panel
	New("Frame") {
		Parent = ballotConfirmFrame,
		Name = "Icon",
		BackgroundColor3 = Theme.Warning,
		BackgroundTransparency = 0.8,
		Position = UDim2.fromScale(0.05, 0.05),
		Size = UDim2.fromOffset(40, 40),
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
		},
	}

	New("TextLabel") {
		Parent = ballotConfirmFrame,
		Name = "H",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.16, 0.05),
		Size = UDim2.fromScale(0.8, 0.08),
		Font = Enum.Font.GothamBold,
		Text = "Review your ballot",
		TextColor3 = Theme.Foreground,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}

	New("TextLabel") {
		Parent = ballotConfirmFrame,
		Name = "Sub",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.16, 0.12),
		Size = UDim2.fromScale(0.8, 0.05),
		Font = Enum.Font.Gotham,
		Text = "Please verify your selections before submitting.",
		TextColor3 = Theme.MutedForeground,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}

	local confirmBody = New("Frame") {
		Parent = ballotConfirmFrame,
		Name = "Box",
		Position = UDim2.fromScale(0.05, 0.22),
		Size = UDim2.fromScale(0.9, 0.45),
		BackgroundColor3 = Theme.Muted,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
		},
	}

	local confirmText = New("TextLabel") {
		Parent = confirmBody,
		Name = "Lines",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.04, 0.08),
		Size = UDim2.fromScale(0.92, 0.84),
		Font = Enum.Font.Gotham,
		Text = "",
		TextColor3 = Theme.Foreground,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}

	New("Frame") {
		Parent = ballotConfirmFrame,
		Name = "WarnBox",
		Position = UDim2.fromScale(0.05, 0.7),
		Size = UDim2.fromScale(0.9, 0.12),
		BackgroundColor3 = Theme.Warning,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
			New("TextLabel") {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Font = Enum.Font.Gotham,
				Text = "Once submitted, your vote cannot be changed.",
				TextColor3 = Theme.Foreground,
				TextScaled = true,
			},
		},
	}

	local backEditBtn = New("TextButton") {
		Parent = ballotConfirmFrame,
		Name = "Edit",
		Position = UDim2.fromScale(0.05, 0.86),
		Size = UDim2.fromScale(0.28, 0.09),
		BackgroundColor3 = Theme.Muted,
		Text = "← Edit",
		TextColor3 = Theme.Foreground,
		Font = Enum.Font.GothamMedium,
		TextScaled = true,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
		},
	}

	local submitBtn = New("TextButton") {
		Parent = ballotConfirmFrame,
		Name = "Submit",
		Position = UDim2.fromScale(0.55, 0.86),
		Size = UDim2.fromScale(0.4, 0.1),
		BackgroundColor3 = accent,
		Text = "Confirm & submit",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		[Children] = {
			New("UICorner") {
				CornerRadius = UDim.new(0, 8),
			},
		},
	}

	reviewBtn.MouseButton1Click:Connect(function()
		if not ballotIsValid() then
			warningBox.Visible = true
			return
		end
		warningBox.Visible = false
		ballotStep:set("Confirm")
		ballotVoteFrame.Visible = false
		ballotBrowseFrame.Visible = false
		ballotConfirmFrame.Visible = true

		if isDualBallot(config.votingMethod) then
			local cid = Fusion.peek(selectedLocal) :: string
			local pid = Fusion.peek(selectedParty) :: string
			local c = nil
			for _, x in ipairs(ballotCandidates) do
				if x.candidateId == cid then
					c = x
					break
				end
			end
			local pp = findParty(config.parties, pid)
			local gov = (config :: any).governmentType or ""
			confirmText.Text = string.format(
				"Constituency: %s\nParty: %s\n\n%s • %s",
				c and c.name or "?",
				pp and pp.name or "?",
				config.votingMethod,
				gov
			)
		else
			local cid = Fusion.peek(selectedFptp) :: string
			local c = nil
			for _, x in ipairs(ballotCandidates) do
				if x.candidateId == cid then
					c = x
					break
				end
			end
			local ward = if playerDistrict then ("\nConstituency: %s"):format(playerDistrict.name) else ""
			confirmText.Text = string.format("Your choice: %s%s", c and c.name or "?", ward)
		end
	end)

	backEditBtn.MouseButton1Click:Connect(function()
		ballotStep:set("Vote")
		ballotVoteFrame.Visible = true
		ballotConfirmFrame.Visible = false
	end)

	submitBtn.MouseButton1Click:Connect(function()
		local ballot: Types.Ballot
		if isDualBallot(config.votingMethod) then
			ballot = buildBallot(config.votingMethod, Fusion.peek(selectedLocal), Fusion.peek(selectedParty), nil)
		else
			ballot = buildBallot(config.votingMethod, Fusion.peek(selectedFptp), nil, nil)
		end
		local ok = submitVote(ballot)
		if ok then
			postSubmitAlreadyVoteGraceUntil = tick() + 3
			mainView:set("ThankYou")
			syncPanelVisibility()
		else
			confirmText.Text = (confirmText.Text :: string) .. "\n\nSubmission failed. Try again or contact an admin."
		end
	end)

	-- Simple status panels
	local function makeStatusPanel(name: string, title: string, messageText: string, accentColor: Color3): Frame
		local p = New("Frame") {
			Parent = bodyFrame,
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
		}
		New("Frame") {
			Name = "AccentBar",
			Parent = p,
			BackgroundColor3 = accentColor,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 0, 4),
		}
		New("TextLabel") {
			Parent = p,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.08, 0.06),
			Size = UDim2.fromScale(0.84, 0.12),
			Font = Enum.Font.GothamBold,
			Text = title,
			TextColor3 = Theme.Foreground,
			TextScaled = true,
			TextWrapped = true,
		}
		New("TextLabel") {
			Parent = p,
			Name = "Body",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.08, 0.22),
			Size = UDim2.fromScale(0.84, 0.68),
			Font = Enum.Font.Gotham,
			Text = messageText,
			TextColor3 = Theme.Foreground,
			TextSize = 18,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
		}
		return p
	end

	local thankPanel = makeStatusPanel(
		"ThankYou",
		"Vote submitted",
		"Your vote has been recorded. Thank you for participating.",
		Theme.Success
	)
	local alreadyPanel = makeStatusPanel(
		"Already",
		"Already voted",
		"You have already cast your vote in this election.",
		Theme.Warning
	)
	local kickPanel = makeStatusPanel(
		"Kick",
		"Alt account detected",
		"Multiple accounts detected. Vote manipulation is prohibited.",
		Theme.Destructive
	)
	local inelPanel = makeStatusPanel("Ineligible", "Not eligible", "", Theme.Destructive)

	local resultsPanel = New("Frame") {
		Parent = bodyFrame,
		Name = "Results",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}

	local resultsScroll = New("ScrollingFrame") {
		Parent = resultsPanel,
		Name = "Scroll",
		Position = UDim2.fromScale(0.03, 0.14),
		Size = UDim2.fromScale(0.94, 0.75),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		[Children] = {
			New("UIListLayout") {
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
		},
	}

	New("TextLabel") {
		Parent = resultsPanel,
		Name = "H",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.05, 0.02),
		Size = UDim2.fromScale(0.9, 0.08),
		Font = Enum.Font.GothamBold,
		Text = "Election results",
		TextColor3 = Theme.Foreground,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}

	local voteCountLabel = New("TextLabel") {
		Parent = resultsPanel,
		Name = "Sub",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.05, 0.088),
		Size = UDim2.fromScale(0.9, 0.04),
		Font = Enum.Font.Gotham,
		Text = "",
		TextColor3 = Theme.MutedForeground,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}

	syncPanelVisibility = function()
		local v = Fusion.peek(mainView)
		countdownPanel.Visible = v == "Countdown"
		ballotPanel.Visible = v == "Ballot"
		resultsPanel.Visible = v == "Results"
		thankPanel.Visible = v == "ThankYou"
		alreadyPanel.Visible = v == "AlreadyVoted"
		inelPanel.Visible = v == "Ineligible"
		kickPanel.Visible = v == "Kick"
	end

	local function getCountdownSeconds(): number
		local raw = Fusion.peek(countdownSec)
		if type(raw) == "table" then
			local t = raw :: { [any]: any }
			local inner = t.countdown or t[1]
			return if type(inner) == "number" then inner else tonumber(inner) or 0
		elseif type(raw) == "number" then
			return raw
		end
		return tonumber(raw) or 0
	end

	local function updatePrePromptCopy()
		if currentView == "Ineligible" or currentView == "Kick" then
			return
		end
		local ph = normalizePhase(Fusion.peek(phaseConn))
		infoText.Text = phaseMessage(ph, getCountdownSeconds())
	end

	local function updatePhaseUi()
		local ph = normalizePhase(Fusion.peek(phaseConn))
		phaseBadgeText.Text = "Phase: " .. ph
		local bg, fg = badgeStyle(ph)
		phaseBadgeInner.BackgroundColor3 = bg
		phaseBadgeText.TextColor3 = fg
		updatePrePromptCopy()
	end

	local function updateCountdownLabel()
		local secs = getCountdownSeconds()
		countdownLabel.Text = "Time: " .. formatCountdown(secs)
		if currentView == "Ineligible" or currentView == "Kick" then
			return
		end
		updatePrePromptCopy()
	end

	scope:Observer(phaseConn):onBind(updatePhaseUi)
	scope:Observer(countdownSec):onBind(updateCountdownLabel)

	local function resultLabelAndColor(id: string): (string, Color3)
		local p = findParty(config.parties, id)
		if p then
			return p.name, rgb(p.colour)
		end
		for _, c in ipairs(config.candidates) do
			if c.candidateId == id then
				local pr = c.partyId and findParty(config.parties, c.partyId)
				if pr then
					return c.name, rgb(pr.colour)
				end
				return c.name, accent
			end
		end
		return id, accent
	end

	local function renderResults(r: any)
		for _, c in ipairs(resultsScroll:GetChildren()) do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		if not r or not r.voteShare then
			return
		end
		local total = 0
		for _, n in pairs(r.voteShare) do
			total += n :: number
		end
		voteCountLabel.Text = string.format("%d votes recorded • %s", r.votesRecorded or total, config.votingMethod)
		local rows = {}
		for id, votes in pairs(r.voteShare) do
			table.insert(rows, { id = id, votes = votes :: number })
		end
		table.sort(rows, function(a, b)
			return a.votes > b.votes
		end)
		if rows[1] then
			local wId = rows[1].id
			local wLab = select(1, resultLabelAndColor(wId))
			New("Frame") {
				Parent = resultsScroll,
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, 72),
				BackgroundColor3 = accent,
				BackgroundTransparency = 0.88,
				BorderSizePixel = 0,
				[Children] = {
					New("UICorner") {
						CornerRadius = UDim.new(0, 10),
					},
					New("TextLabel") {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Font = Enum.Font.GothamBold,
						Text = "Leading: " .. wLab .. " (vote share)",
						TextColor3 = Theme.Foreground,
						TextSize = 18,
					},
				},
			}
		end
		for rank, row in ipairs(rows) do
			local id = row.id
			local label, col = resultLabelAndColor(id)
			local pct = if total > 0 then (row.votes / total) * 100 else 0
			local rowF = New("Frame") {
				Parent = resultsScroll,
				LayoutOrder = rank,
				Size = UDim2.new(1, 0, 0, 52),
				BackgroundColor3 = Theme.Muted,
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				[Children] = {
					New("UICorner") {
						CornerRadius = UDim.new(0, 8),
					},
				},
			}
			New("TextLabel") {
				Parent = rowF,
				BackgroundTransparency = 1,
				Size = UDim2.new(0.08, 0, 1, 0),
				Text = "#" .. tostring(rank),
				TextColor3 = Theme.MutedForeground,
				Font = Enum.Font.GothamMedium,
				TextSize = 16,
			}
			New("Frame") {
				Parent = rowF,
				Size = UDim2.fromOffset(10, 10),
				Position = UDim2.new(0.09, 0, 0.5, -5),
				BackgroundColor3 = col,
				BorderSizePixel = 0,
				[Children] = {
					New("UICorner") {
						CornerRadius = UDim.new(1, 0),
					},
				},
			}
			New("TextLabel") {
				Parent = rowF,
				BackgroundTransparency = 1,
				Position = UDim2.new(0.13, 0, 0, 6),
				Size = UDim2.new(0.45, 0, 0.55, 0),
				Font = Enum.Font.GothamMedium,
				Text = label,
				TextColor3 = Theme.Foreground,
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Left,
			}
			New("TextLabel") {
				Parent = rowF,
				BackgroundTransparency = 1,
				Position = UDim2.new(0.13, 0, 0.5, 0),
				Size = UDim2.new(0.45, 0, 0.45, 0),
				Font = Enum.Font.Gotham,
				Text = string.format("%.1f%% of votes cast", pct),
				TextColor3 = Theme.MutedForeground,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
			}
			New("TextLabel") {
				Parent = rowF,
				BackgroundTransparency = 1,
				Position = UDim2.new(0.7, 0, 0.2, 0),
				Size = UDim2.new(0.26, 0, 0.6, 0),
				Font = Enum.Font.GothamMedium,
				Text = string.format("%.1f%%", pct),
				TextColor3 = accent,
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Right,
			}
			local barBg = New("Frame") {
				Parent = rowF,
				Position = UDim2.new(0.13, 0, 0.86, 0),
				Size = UDim2.new(0.82, 0, 0.1, 0),
				BackgroundColor3 = Theme.Border,
				BorderSizePixel = 0,
				[Children] = {
					New("UICorner") {
						CornerRadius = UDim.new(0, 4),
					},
				},
			}
			New("Frame") {
				Parent = barBg,
				Size = UDim2.fromScale(pct / 100, 1),
				BackgroundColor3 = col,
				BorderSizePixel = 0,
				[Children] = {
					New("UICorner") {
						CornerRadius = UDim.new(0, 4),
					},
				},
			}
		end
	end

	scope:Observer(resultsSnapshot):onChange(function()
		renderResults(Fusion.peek(resultsSnapshot))
	end)

	local conn =
		workspace.CurrentCamera
		and workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			local v = cam.ViewportSize
			scale.Scale = math.clamp(math.min(v.X, v.Y) / 720, 0.55, 1.05)
		end)
	table.insert(scope, function()
		if conn then
			conn:Disconnect()
		end
	end)
	task.defer(function()
		local cam = workspace.CurrentCamera
		if cam then
			local v = cam.ViewportSize
			scale.Scale = math.clamp(math.min(v.X, v.Y) / 720, 0.55, 1.05)
		end
	end)

	local function openGui()
		isOpen = true
		screenGui.DisplayOrder = MODAL_DISPLAY_ORDER
		local parentGui = screenGui.Parent
		if parentGui then
			screenGui.Parent = nil
			screenGui.Parent = parentGui
		end
		screenGui.Enabled = true
	end

	local function closeUi()
		if isOpen then
			isOpen = false
			screenGui.Enabled = false
		end
		currentView = ""
	end

	local function show(target: string)
		openGui()
		currentView = target
		mainView:set(target)
		if target == "Ballot" then
			ballotStep:set("Vote")
			ballotVoteFrame.Visible = true
			ballotBrowseFrame.Visible = false
			ballotConfirmFrame.Visible = false
			warningBox.Visible = false
			reviewBtn.Text = "Review ballot"
		end
		syncPanelVisibility()
		updatePhaseUi()
		updateCountdownLabel()
	end

	closeBtn.MouseButton1Click:Connect(closeUi)
	local closeFooter = countdownPanel:FindFirstChild("CloseFooter")
	if closeFooter and closeFooter:IsA("TextButton") then
		closeFooter.MouseButton1Click:Connect(closeUi)
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

	return {
		setPhase = function(nextPhase: Types.ElectionPhase)
			local ph = normalizePhase(nextPhase)
			phaseConn:set(ph :: any)
			if not isOpen then
				return
			end
			-- While the player is casting a vote, do not replace the ballot with the pre-prompt (Countdown).
			if currentView == "Ballot" then
				if ph == "ResultsOut" or ph == "Coalition" or ph == "Formed" then
					show("Results")
				end
				return
			end
			-- Post-submit thank-you / already-voted confirmations should not be replaced by the polling Countdown panel.
			if currentView == "ThankYou" or currentView == "AlreadyVoted" then
				if ph == "ResultsOut" or ph == "Coalition" or ph == "Formed" then
					show("Results")
				end
				return
			end
			-- Blocked-vote messages (ineligible / alt): do not swap to Countdown "go to booth" or Results.
			if currentView == "Ineligible" or currentView == "Kick" then
				return
			end
			if ph == "ResultsOut" or ph == "Coalition" or ph == "Formed" then
				show("Results")
			else
				show("Countdown")
			end
		end,
		setCountdown = function(secondsLeft: any)
			local numericSeconds = secondsLeft
			if type(numericSeconds) == "table" then
				numericSeconds = numericSeconds.countdown or numericSeconds[1] or 0
			end
			if type(numericSeconds) ~= "number" then
				numericSeconds = tonumber(numericSeconds) or 0
			end
			countdownSec:set(math.max(0, math.floor(numericSeconds)))
		end,
		showBallot = function()
			selectedLocal:set(nil)
			selectedParty:set(nil)
			selectedFptp:set(nil)
			show("Ballot")
		end,
		isBallotOpen = function(): boolean
			return isOpen and currentView == "Ballot"
		end,
		showResults = function(results: any)
			resultsSnapshot:set(results)
			show("Results")
		end,
		showAlreadyVoted = function()
			if tick() < postSubmitAlreadyVoteGraceUntil then
				return
			end
			show("AlreadyVoted")
		end,
		showIneligible = function(reason: any)
			local msg = normalizeUserFacingString(reason, "You are not eligible to vote.")
			if msg == "" then
				msg = "You are not eligible to vote."
			end
			ineligibleText:set(msg)
			local bodyLbl = inelPanel:FindFirstChild("Body")
			if bodyLbl and bodyLbl:IsA("TextLabel") then
				bodyLbl.Text = msg
			end
			show("Ineligible")
		end,
		showKick = function()
			show("Kick")
		end,
		showThankYou = function()
			show("ThankYou")
		end,
		hide = function()
			closeUi()
		end,
		unmount = function()
			Fusion.doCleanup(scope)
			screenGui:Destroy()
		end,
	}
end

return ElectionUI
