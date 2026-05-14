--!strict

-- VotingBoothPart.server.lua — place this script in a Part to create a voting booth.
-- Players can use a ProximityPrompt to start voting.

local ServerScriptService = game:GetService("ServerScriptService")
local electionHolder = ServerScriptService:WaitForChild("ElectionSystem", 30)
assert(electionHolder and electionHolder:IsA("ModuleScript"), "[VotingBooth] ElectionSystem module missing.")
local ElectionSystem = require(electionHolder :: ModuleScript)
local DiscordNotifier = require((electionHolder :: Instance):WaitForChild("Modules"):WaitForChild("DiscordNotifier"))
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VotingBooth = {}
local REMOTE_FOLDER_NAME = "ElectionSystemRemotes"
local BOOTH_TAG = "VotingBooth"
local initializedRemotes = false

local function getRemotesFolder(): Folder?
	local remotes = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
	if remotes and remotes:IsA("Folder") then
		return remotes
	end

	-- Ensure core module initialization happened before players use a booth.
	if not initializedRemotes then
		initializedRemotes = true
		ElectionSystem.init()
	end

	local awaited = ReplicatedStorage:WaitForChild(REMOTE_FOLDER_NAME, 3)
	if awaited and awaited:IsA("Folder") then
		return awaited
	end

	warn("[VotingBooth] ElectionSystemRemotes folder not found.")
	return nil
end

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
		prompt.Parent = part
	end
	-- 0 = no hold (tap E once). Non-zero breaks Studio MCP / automation that sends a short key press.
	prompt.HoldDuration = 0

	prompt.Triggered:Connect(function(player)
		local remotes = getRemotesFolder()
		if not remotes then
			return
		end

		local phase = ElectionSystem:getPhase()
		if phase ~= "Open" then
			local closedMsg = "Voting is currently closed. Current phase: " .. tostring(phase)
			local ineligibleEvent = remotes:FindFirstChild("IneligibleResult")
			if ineligibleEvent and ineligibleEvent:IsA("RemoteEvent") then
				ineligibleEvent:FireClient(player, closedMsg)
			end
			return
		end

		local eligibility = ElectionSystem:checkEligibility(player)
		if not eligibility.eligible then
			DiscordNotifier.notifyVoteDenied(player, "ineligible", eligibility.reason)
			local ineligibleEvent = remotes:FindFirstChild("IneligibleResult")
			if ineligibleEvent and ineligibleEvent:IsA("RemoteEvent") then
				ineligibleEvent:FireClient(player, tostring(eligibility.reason))
			end
			return
		end

		ElectionSystem:hydrateVoteFromDataStore(player)
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
