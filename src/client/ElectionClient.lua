--!strict

--[=[
	@class ElectionClient

	Client-side election system. Handles UI, vote submission, and event listening.

	Election display config is loaded from the server (`Settings.lua` via `RequestElectionConfig`);
	the client does not duplicate election data locally.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("ElectionSystemShared")
local Types = require(SharedFolder:WaitForChild("Types"))
local ElectionUI = require(script.Parent:WaitForChild("UI"):WaitForChild("ElectionUI"))

local ElectionClient = {}
local mountedUi: any = nil
local remoteFolder: Folder? = nil
local initialized = false
local lastSubmitOk: boolean? = nil

local ElectionDebug: any = nil
do
	local debugModule = script.Parent:FindFirstChild("ElectionDebug")
	if debugModule then
		ElectionDebug = require(debugModule)
	end
end

local function normalizeCountdown(value: any): number
	if type(value) == "number" then
		return value
	end
	if type(value) == "table" then
		local nested = value.countdown or value[1]
		if type(nested) == "number" then
			return nested
		end
		return tonumber(nested) or 0
	end
	return tonumber(value) or 0
end

local function fetchElectionConfigFromServer(): any
	local folder = ReplicatedStorage:WaitForChild("ElectionSystemRemotes") :: Folder
	local rf = folder:WaitForChild("RequestElectionConfig") :: RemoteFunction

	for _ = 1, 50 do
		local ok, data = pcall(function()
			return rf:InvokeServer()
		end)
		if ok and type(data) == "table" and data.ui and type(data.candidates) == "table" then
			return data
		end
		task.wait(0.15)
	end

	warn(
		"[ElectionClient] Could not load election config from server (is ElectionSystem running?). "
			.. "UI will be empty until `RequestElectionConfig` succeeds; retry in Studio after server starts."
	)
	return {
		votingMethod = "MMP",
		governmentType = "Parliamentary",
		seats = 0,
		seatAllocationMethod = "DHondt",
		ui = {
			placeholderAvatarId = "",
			accentColour = { r = 100, g = 149, b = 237 },
			electionTitle = "Election",
		},
		parties = {} :: { Types.Party },
		candidates = {} :: { Types.Candidate },
	}
end

--[=[
	@method init
	@within ElectionClient

	Initializes the client election system.
]=]
function ElectionClient.init()
	if initialized then
		return
	end
	initialized = true

	remoteFolder = ReplicatedStorage:WaitForChild("ElectionSystemRemotes") :: Folder

	local electionConfig = fetchElectionConfigFromServer()

	mountedUi = ElectionUI.mount(electionConfig, {
		submitVote = function(ballot: Types.Ballot)
			return ElectionClient.submitVote(ballot)
		end,
	})

	if ElectionDebug then
		ElectionDebug.init(remoteFolder :: Folder, function()
			return lastSubmitOk
		end)
	end

	-- Listen for phase changes
	local phaseChangedEvent = remoteFolder:WaitForChild("PhaseChanged") :: RemoteEvent
	phaseChangedEvent.OnClientEvent:Connect(function(newPhase)
		print("[ElectionClient] Phase changed:", newPhase)
		ElectionClient.onPhaseChanged(newPhase)
	end)

	local stateUpdatedEvent = remoteFolder:WaitForChild("ElectionStateUpdated") :: RemoteEvent
	stateUpdatedEvent.OnClientEvent:Connect(function(state)
		if mountedUi and state then
			if state.phase then
				mountedUi:setPhase(state.phase)
			end
			mountedUi:setCountdown(normalizeCountdown(state.countdown))
		end
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

	task.spawn(function()
		while initialized and remoteFolder do
			local requestStateFunc = remoteFolder:FindFirstChild("RequestState")
			if requestStateFunc and requestStateFunc:IsA("RemoteFunction") then
				local ok, state = pcall(function()
					return requestStateFunc:InvokeServer()
				end)
				if ok and state and mountedUi then
					if state.phase then
						mountedUi:setPhase(state.phase)
					end
					mountedUi:setCountdown(normalizeCountdown(state.countdown))
				end
			end
			task.wait(1)
		end
	end)
end

--[=[
	@method onPhaseChanged
	@within ElectionClient
	@param phase ElectionPhase
]=]
function ElectionClient.onPhaseChanged(phase: Types.ElectionPhase)
	if mountedUi then
		mountedUi:setPhase(phase)
	end
end

--[=[
	@method onBallotOpened
	@within ElectionClient
]=]
function ElectionClient.onBallotOpened()
	if mountedUi then
		if mountedUi.isBallotOpen and mountedUi:isBallotOpen() then
			return
		end
		mountedUi:showBallot()
	end
	-- Header phase/countdown can be stale if RequestState has not run yet; sync from server when ballot opens.
	local folder = remoteFolder
	if folder and mountedUi then
		local rf = folder:FindFirstChild("RequestState")
		if rf and rf:IsA("RemoteFunction") then
			local ok, state = pcall(function()
				return rf:InvokeServer()
			end)
			if ok and type(state) == "table" then
				if state.phase then
					mountedUi:setPhase(state.phase)
				end
				mountedUi:setCountdown(normalizeCountdown(state.countdown))
			end
		end
	end
end

--[=[
	@method onResultsReceived
	@within ElectionClient
	@param results ElectionResult
]=]
function ElectionClient.onResultsReceived(results: Types.ElectionResult)
	if mountedUi then
		mountedUi:showResults(results)
	end
end

--[=[
	@method onAlreadyVoted
	@within ElectionClient
]=]
function ElectionClient.onAlreadyVoted()
	if mountedUi then
		mountedUi:showAlreadyVoted()
	end
end

--[=[
	@method onIneligible
	@within ElectionClient
	@param reason string
]=]
function ElectionClient.onIneligible(reason: string)
	if mountedUi then
		mountedUi:showIneligible(reason)
	end
end

--[=[
	@method onAltDetected
	@within ElectionClient
]=]
function ElectionClient.onAltDetected()
	if mountedUi then
		mountedUi:showKick()
	end
end

--[=[
	@method submitVote
	@within ElectionClient
	@param ballot Ballot
	@return boolean
]=]
function ElectionClient.submitVote(ballot: Types.Ballot): boolean
	if not remoteFolder then
		lastSubmitOk = false
		return false
	end

	local submitVoteFunc = remoteFolder:FindFirstChild("SubmitVote")
	if not submitVoteFunc or not submitVoteFunc:IsA("RemoteFunction") then
		lastSubmitOk = false
		return false
	end

	local success = submitVoteFunc:InvokeServer(ballot)
	lastSubmitOk = success == true
	if success ~= true then
		warn("[ElectionClient] SubmitVote failed (server returned false or non-boolean).")
	end
	return success == true
end

return ElectionClient
