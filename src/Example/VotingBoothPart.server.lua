--!strict

--[[
	@within ElectionSystem.Example

	VotingBoothPart.server.lua
	Place this script in a Part to create a voting booth.
	Players can use a ProximityPrompt to start voting.
]]

local ElectionSystem = require(game:GetService("ServerScriptService").ElectionSystem)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VotingBooth = {}
local REMOTE_FOLDER_NAME = "ElectionSystemRemotes"
local BOOTH_TAG = "VotingBooth"

-- Find or create voting booth part
local function setupVotingBooth(part: Part)
	-- Tag the part
	if not CollectionService:HasTag(part, BOOTH_TAG) then
		CollectionService:AddTag(part, BOOTH_TAG)
	end

	-- Create ProximityPrompt if not present
	local existingPrompt = part:FindFirstChild("VotePrompt")
	local prompt = if existingPrompt and existingPrompt:IsA("ProximityPrompt") then existingPrompt else Instance.new("ProximityPrompt")
	if prompt.Parent == nil then
		prompt.Name = "VotePrompt"
		prompt.ActionText = "Vote"
		prompt.ObjectText = "Election Booth"
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0.25
		prompt.Parent = part
	end

	prompt.Triggered:Connect(function(player)
		local remotes = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
		if not remotes then
			return
		end

		local eligibility = ElectionSystem:checkEligibility(player)
		if not eligibility.eligible then
			local ineligibleEvent = remotes:FindFirstChild("IneligibleResult")
			if ineligibleEvent and ineligibleEvent:IsA("RemoteEvent") then
				ineligibleEvent:FireClient(player, eligibility.reason)
			end
			return
		end

		if ElectionSystem:getStore():hasVoted(tostring(player.UserId)) then
			local alreadyVotedEvent = remotes:FindFirstChild("AlreadyVoted")
			if alreadyVotedEvent and alreadyVotedEvent:IsA("RemoteEvent") then
				alreadyVotedEvent:FireClient(player)
			end
			return
		end

		local ballotOpenedEvent = remotes:FindFirstChild("BallotOpened")
		if ballotOpenedEvent and ballotOpenedEvent:IsA("RemoteEvent") then
			ballotOpenedEvent:FireClient(player)
		end
	end)
end

local function ensureDefaultBooth(): Part
	local existing = workspace:FindFirstChild("VotingBoothPart")
	if existing and existing:IsA("Part") then
		return existing
	end

	local part = Instance.new("Part")
	part.Name = "VotingBoothPart"
	part.Size = Vector3.new(8, 1, 8)
	part.Anchored = true
	part.Position = Vector3.new(0, 4, 0)
	part.Color = Color3.fromRGB(46, 125, 50)
	part.Parent = workspace
	return part
end

-- Find voting booth parts in workspace
function VotingBooth.setup()
	local bootParts = CollectionService:GetTagged(BOOTH_TAG)
	if #bootParts == 0 then
		local fallback = ensureDefaultBooth()
		CollectionService:AddTag(fallback, BOOTH_TAG)
		bootParts = CollectionService:GetTagged(BOOTH_TAG)
	end

	for _, part in ipairs(bootParts) do
		if part:IsA("BasePart") then
			setupVotingBooth(part :: Part)
		end
	end

	CollectionService:GetInstanceAddedSignal(BOOTH_TAG):Connect(function(instance)
		if instance:IsA("BasePart") then
			setupVotingBooth(instance :: Part)
		end
	end)
end

-- Run setup
VotingBooth.setup()

return VotingBooth
