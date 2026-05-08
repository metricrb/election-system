--!strict

--[[
	@class ElectionClient
	@within ElectionSystem

	Client-side election system. Handles UI, vote submission, and event listening.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("ElectionSystemShared")
local Types = require(SharedFolder:WaitForChild("Types"))
local ElectionUI = require(script.Parent:WaitForChild("ElectionUI"):WaitForChild("ElectionUI"))

local ElectionClient = {}
local mountedUi: any = nil
local remoteFolder: Folder? = nil
local initialized = false

--[[
	@method init
	@within ElectionClient

	Initializes the client election system.
]]
function ElectionClient.init()
	if initialized then
		return
	end
	initialized = true

	remoteFolder = ReplicatedStorage:WaitForChild("ElectionSystemRemotes") :: Folder
	mountedUi = ElectionUI.mount()

	-- Listen for phase changes
	local phaseChangedEvent = remoteFolder:WaitForChild("PhaseChanged") :: RemoteEvent
	phaseChangedEvent.OnClientEvent:Connect(function(newPhase)
		print("[ElectionClient] Phase changed:", newPhase)
		ElectionClient.onPhaseChanged(newPhase)
	end)

	-- Listen for ballot open
	local ballotOpenedEvent = remoteFolder:WaitForChild("BallotOpened") :: RemoteEvent
	ballotOpenedEvent.OnClientEvent:Connect(function()
		print("[ElectionClient] Ballot opened")
		ElectionClient.onBallotOpened()
	end)

	-- Listen for results
	local resultsEvent = remoteFolder:WaitForChild("ResultsPublished") :: RemoteEvent
	resultsEvent.OnClientEvent:Connect(function(results)
		print("[ElectionClient] Results received")
		ElectionClient.onResultsReceived(results)
	end)

	-- Listen for already voted
	local alreadyVotedEvent = remoteFolder:WaitForChild("AlreadyVoted") :: RemoteEvent
	alreadyVotedEvent.OnClientEvent:Connect(function()
		print("[ElectionClient] Already voted notification")
		ElectionClient.onAlreadyVoted()
	end)

	-- Listen for ineligible
	local ineligibleEvent = remoteFolder:WaitForChild("IneligibleResult") :: RemoteEvent
	ineligibleEvent.OnClientEvent:Connect(function(reason)
		print("[ElectionClient] Ineligible:", reason)
		ElectionClient.onIneligible(reason)
	end)

	-- Listen for alt detection
	local altDetectedEvent = remoteFolder:WaitForChild("AltDetectedClient") :: RemoteEvent
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
	if mountedUi then
		mountedUi:setPhase(phase)
	end
end

--[[
	@method onBallotOpened
	@within ElectionClient
]]
function ElectionClient.onBallotOpened()
	if mountedUi then
		mountedUi:showBallot()
	end
end

--[[
	@method onResultsReceived
	@within ElectionClient
	@param results ElectionResult
]]
function ElectionClient.onResultsReceived(results: Types.ElectionResult)
	if mountedUi then
		mountedUi:showResults(results)
	end
end

--[[
	@method onAlreadyVoted
	@within ElectionClient
]]
function ElectionClient.onAlreadyVoted()
	if mountedUi then
		mountedUi:showAlreadyVoted()
	end
end

--[[
	@method onIneligible
	@within ElectionClient
	@param reason string
]]
function ElectionClient.onIneligible(reason: string)
	if mountedUi then
		mountedUi:showIneligible(reason)
	end
end

--[[
	@method onAltDetected
	@within ElectionClient
]]
function ElectionClient.onAltDetected()
	if mountedUi then
		mountedUi:showKick()
	end
end

--[[
	@method submitVote
	@within ElectionClient
	@param ballot Ballot
	@return boolean
]]
function ElectionClient.submitVote(ballot: Types.Ballot): boolean
	if not remoteFolder then
		return false
	end

	local submitVoteFunc = remoteFolder:FindFirstChild("SubmitVote")
	if not submitVoteFunc or not submitVoteFunc:IsA("RemoteFunction") then
		return false
	end

	local success = submitVoteFunc:InvokeServer(ballot)
	return success == true
end

return ElectionClient
