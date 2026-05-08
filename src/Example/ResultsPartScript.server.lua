--!strict

--[[
	@within ElectionSystem.Example

	ResultsPartScript.server.lua
	Place this script in a Part to display live election results on a SurfaceGui.
]]

local ElectionSystem = require(game:GetService("ServerScriptService").ElectionSystem)
local CollectionService = game:GetService("CollectionService")

local ResultsPart = {}

-- Setup results display
function ResultsPart.setup()
	-- Find all ResultsPart tagged parts
	local parts = CollectionService:GetTagged("ResultsPart")

	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then
			setupResultsDisplay(part)
		end
	end
end

function setupResultsDisplay(part: Part)
	-- Create SurfaceGui
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
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

		-- Clear container
		resultsContainer:ClearAllChildren()

		-- Display vote counts per candidate
		local y = 0
		for candidateId, voteShare in pairs(results.voteShare) do
			local entryLabel = Instance.new("TextLabel")
			entryLabel.Size = UDim2.new(1, 0, 0.15, 0)
			entryLabel.Position = UDim2.new(0, 0, y, 0)
			entryLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			entryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			entryLabel.TextSize = 14
			entryLabel.Font = Enum.Font.Gotham
			entryLabel.Text = candidateId .. ": " .. string.format("%.1f%%", voteShare)
			entryLabel.BorderSizePixel = 0
			entryLabel.Parent = resultsContainer

			y = y + 0.15
		end
	end

	-- Listen for results updates
	local remote = game:GetService("ReplicatedStorage"):WaitForChild("ElectionSystemRemotes")
	local resultsEvent = remote:WaitForChild("ResultsPublished")
	resultsEvent.OnServerEvent:Connect(updateResults)

	-- Initial update
	updateResults()
end

-- Run setup
ResultsPart.setup()

return ResultsPart
