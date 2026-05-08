--!strict

--[[
	@class ElectionClient
	@within ElectionSystem

	Client-side election system. Handles UI, vote submission, and event listening.
]]

local ElectionSystem = require(game:GetService("ServerScriptService").ElectionSystem)
local Types = ElectionSystem.Types

local ElectionClient = {}

--[[
	@method init
	@within ElectionClient

	Initializes the client election system.
]]
function ElectionClient.init()
	local remoteFolder = game:GetService("ReplicatedStorage"):WaitForChild("ElectionSystemRemotes")

	-- Listen for phase changes
	local phaseChangedEvent = remoteFolder:WaitForChild("PhaseChanged")
	phaseChangedEvent.OnClientEvent:Connect(function(newPhase)
		print("[ElectionClient] Phase changed:", newPhase)
		ElectionClient.onPhaseChanged(newPhase)
	end)

	-- Listen for ballot open
	local ballotOpenedEvent = remoteFolder:WaitForChild("BallotOpened")
	ballotOpenedEvent.OnClientEvent:Connect(function()
		print("[ElectionClient] Ballot opened")
		ElectionClient.onBallotOpened()
	end)

	-- Listen for results
	local resultsEvent = remoteFolder:WaitForChild("ResultsPublished")
	resultsEvent.OnClientEvent:Connect(function(results)
		print("[ElectionClient] Results received")
		ElectionClient.onResultsReceived(results)
	end)

	-- Listen for already voted
	local alreadyVotedEvent = remoteFolder:WaitForChild("AlreadyVoted")
	alreadyVotedEvent.OnClientEvent:Connect(function()
		print("[ElectionClient] Already voted notification")
		ElectionClient.onAlreadyVoted()
	end)

	-- Listen for ineligible
	local ineligibleEvent = remoteFolder:WaitForChild("IneligibleResult")
	ineligibleEvent.OnClientEvent:Connect(function(reason)
		print("[ElectionClient] Ineligible:", reason)
		ElectionClient.onIneligible(reason)
	end)

	-- Listen for alt detection
	local altDetectedEvent = remoteFolder:WaitForChild("AltDetectedClient")
	altDetectedEvent.OnClientEvent:Connect(function()
		print("[ElectionClient] Alt detected - showing kick screen")
		ElectionClient.onAltDetected()
	end)

	print("[ElectionClient] Initialized")
end

--[[
	@method onPhaseChanged
	@within ElectionClient
	@param phase ElectionPhase
]]
function ElectionClient.onPhaseChanged(phase: Types.ElectionPhase)
	-- TODO: Update UI based on phase
end

--[[
	@method onBallotOpened
	@within ElectionClient
]]
function ElectionClient.onBallotOpened()
	-- TODO: Show ballot UI
end

--[[
	@method onResultsReceived
	@within ElectionClient
	@param results ElectionResult
]]
function ElectionClient.onResultsReceived(results: Types.ElectionResult)
	-- TODO: Show results UI
end

--[[
	@method onAlreadyVoted
	@within ElectionClient
]]
function ElectionClient.onAlreadyVoted()
	-- TODO: Show "Already Voted" screen
end

--[[
	@method onIneligible
	@within ElectionClient
	@param reason string
]]
function ElectionClient.onIneligible(reason: string)
	-- TODO: Show ineligible screen with reason
end

--[[
	@method onAltDetected
	@within ElectionClient
]]
function ElectionClient.onAltDetected()
	-- TODO: Show kick screen with countdown
end

--[[
	@method submitVote
	@within ElectionClient
	@param ballot Ballot
	@return boolean
]]
function ElectionClient.submitVote(ballot: Types.Ballot): boolean
	local remoteFolder = game:GetService("ReplicatedStorage"):FindFirstChild("ElectionSystemRemotes")
	if not remoteFolder then return false end

	local submitVoteFunc = remoteFolder:FindFirstChild("SubmitVote")
	if not submitVoteFunc then return false end

	local success = submitVoteFunc:InvokeServer(ballot)
	return success
end

-- Auto-initialize when script loads
ElectionClient.init()

return ElectionClient
