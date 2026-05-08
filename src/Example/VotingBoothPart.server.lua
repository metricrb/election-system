--!strict

--[[
	@within ElectionSystem.Example

	VotingBoothPart.server.lua
	Place this script in a Part to create a voting booth.
	Players can use a ProximityPrompt to start voting.
]]

local ElectionSystem = require(game:GetService("ServerScriptService").ElectionSystem)
local CollectionService = game:GetService("CollectionService")

local VotingBooth = {}

-- Find or create voting booth part
local function setupVotingBooth(part: Part)
	-- Tag the part
	if not CollectionService:HasTag(part, "VotingBooth") then
		CollectionService:AddTag(part, "VotingBooth")
	end

	-- Create ProximityPrompt if not present
	local existingPrompt = part:FindFirstChild("VotePrompt")
	if not existingPrompt then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "VotePrompt"
		prompt.ActionText = "Vote"
		prompt.MaxActivationDistance = 8
		prompt.Parent = part

		-- When triggered, check eligibility and open ballot
		prompt.Triggered:Connect(function(player)
			local eligibility = ElectionSystem:checkEligibility(player)

			if not eligibility.eligible then
				-- Send ineligible event to client
				local remote = game:GetService("ReplicatedStorage"):FindFirstChild("ElectionSystemRemotes")
				if remote then
					local ineligibleEvent = remote:FindFirstChild("IneligibleResult")
					if ineligibleEvent then
						ineligibleEvent:FireClient(player, eligibility.reason)
					end
				end
				return
			end

			-- Check if already voted
			if ElectionSystem:getStore():hasVoted(tostring(player.UserId)) then
				local remote = game:GetService("ReplicatedStorage"):FindFirstChild("ElectionSystemRemotes")
				if remote then
					local alreadyVotedEvent = remote:FindFirstChild("AlreadyVoted")
					if alreadyVotedEvent then
						alreadyVotedEvent:FireClient(player)
					end
				end
				return
			end

			-- Open ballot
			local remote = game:GetService("ReplicatedStorage"):FindFirstChild("ElectionSystemRemotes")
			if remote then
				local ballotOpenedEvent = remote:FindFirstChild("BallotOpened")
				if ballotOpenedEvent then
					ballotOpenedEvent:FireClient(player)
				end
			end
		end)
	end
end

-- Find voting booth parts in workspace
function VotingBooth.setup()
	for _, part in ipairs(workspace:FindPartBoundsInRadius(Vector3.new(0, 0, 0), 10000)) do
		if CollectionService:HasTag(part, "VotingBooth") then
			setupVotingBooth(part)
		end
	end

	-- Also set up any existing voting booths tagged via CollectionService
	local bootParts = CollectionService:GetTagged("VotingBooth")
	for _, part in ipairs(bootParts) do
		if part:IsA("BasePart") then
			setupVotingBooth(part)
		end
	end
end

-- Run setup
VotingBooth.setup()

return VotingBooth
