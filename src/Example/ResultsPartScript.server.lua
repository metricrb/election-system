--!strict

--[[
	@within ElectionSystem.Example

	ResultsPartScript.server.lua
	Place this script in a Part to display live election results on a SurfaceGui.
]]

local ElectionSystem = require(game:GetService("ServerScriptService").ElectionSystem)
local CollectionService = game:GetService("CollectionService")
local CmdrSetup = require(game:GetService("ServerScriptService").ElectionSystem.Cmdr.CmdrSetup)

local ResultsPart = {}
local RESULTS_TAG = "ResultsPart"

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

	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then
			setupResultsDisplay(part :: Part)
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

	-- Create SurfaceGui
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "ElectionResultsSurface"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 35
	surfaceGui.AlwaysOnTop = true
	surfaceGui.Parent = part

	-- Create main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = surfaceGui

	-- Create title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.1, 0)
	titleLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 24
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = ElectionSystem.Settings.ui.electionTitle
	titleLabel.BorderSizePixel = 0
	titleLabel.Parent = mainFrame

	-- Create results container
	local resultsContainer = Instance.new("Frame")
	resultsContainer.Size = UDim2.new(1, 0, 0.9, 0)
	resultsContainer.Position = UDim2.new(0, 0, 0.1, 0)
	resultsContainer.BackgroundTransparency = 1
	resultsContainer.Parent = mainFrame

	-- Update results when they change
	local function updateResults()
		resultsContainer:ClearAllChildren()
		local results = ElectionSystem:getResults()
		if not results then
			-- Show "Calculating..." placeholder
			local placeholderLabel = Instance.new("TextLabel")
			placeholderLabel.Size = UDim2.new(1, 0, 1, 0)
			placeholderLabel.BackgroundTransparency = 1
			placeholderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			placeholderLabel.TextSize = 18
			placeholderLabel.Text = "Calculating results..."
			placeholderLabel.Parent = resultsContainer
			return
		end

		-- Display vote counts per candidate
		local y = 0
		local mode = CmdrSetup.getChartMode()
		for candidateId, voteShare in pairs(results.voteShare) do
			local entryLabel = Instance.new("TextLabel")
			entryLabel.Size = UDim2.new(1, 0, 0.15, 0)
			entryLabel.Position = UDim2.new(0, 0, y, 0)
			entryLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			entryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			entryLabel.TextSize = 14
			entryLabel.Font = Enum.Font.Gotham
			entryLabel.Text = string.format("[%s] %s: %.1f%%", mode, candidateId, voteShare)
			entryLabel.BorderSizePixel = 0
			entryLabel.Parent = resultsContainer

			y = y + 0.15
		end
	end

	local store = ElectionSystem:getStore()
	store.dataChanged:connect(function(key)
		if key == "resultsCache" then
			updateResults()
		end
	end)

	-- Initial update
	updateResults()
end

-- Run setup
ResultsPart.setup()

return ResultsPart
