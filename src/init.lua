--!strict

-- Duplicate of the Rojo entry `init.module.lua`; kept for non-Rojo requires.
-- API docs are generated from `init.module.lua`.

local Players = game:GetService("Players")
local Settings = require(script.Settings)
local Signal = require(script.Signal)
local Types = require(script.shared.Types)
local Store = require(script.Modules.Store)
local TimestampManager = require(script.Modules.TimestampManager)
local EligibilityChecker = require(script.Modules.EligibilityChecker)
local AltDetector = require(script.Modules.AltDetector)
local BallotFormatter = require(script.Modules.BallotFormatter)
local ResultCalculator = require(script.Modules.ResultCalculator)
local Network = require(script.Modules.Network)
local Data = require(script.Modules.Data)
local RoundManager = require(script.Modules.RoundManager)
local SeatAllocator = require(script.Modules.SeatAllocator)
local DistrictManager = require(script.Modules.DistrictManager)
local CoalitionSystem = require(script.Modules.CoalitionSystem)
local CmdrSetup = require(script.Cmdr.CmdrSetup)
local DiscordNotifier = require(script.Modules.DiscordNotifier)

local ElectionManager = {}
ElectionManager.__index = ElectionManager

-- Module exports
ElectionManager.Signal = Signal
ElectionManager.Types = Types
ElectionManager.Store = Store
ElectionManager.TimestampManager = TimestampManager
ElectionManager.EligibilityChecker = EligibilityChecker
ElectionManager.AltDetector = AltDetector
ElectionManager.BallotFormatter = BallotFormatter
ElectionManager.ResultCalculator = ResultCalculator
ElectionManager.Network = Network
ElectionManager.Data = Data
ElectionManager.Settings = Settings

-- State
local store = Store.new()
local timestampManager = TimestampManager.new()
local phaseChanged = Signal.new()

local function hydrateVoteFromData(player: Player): ()
	Data.loadProfile(player.UserId)
	local record = Data.getVoteRecord(player.UserId)
	if record then
		store:seedVoteFromData(tostring(player.UserId), record)
	end
end

function ElectionManager:hydrateVoteFromDataStore(player: Player): ()
	hydrateVoteFromData(player)
end

--[=[
	@function init
	@within ElectionManager

	Initializes the election system (called automatically on first require).
]=]
function ElectionManager.init()
	Network.init()
	Data.init()

	for _, existing in Players:GetPlayers() do
		task.spawn(hydrateVoteFromData, existing)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(hydrateVoteFromData, player)
	end)

	local submitVoteRemote = Network.getRemote("SubmitVote")
	if submitVoteRemote and submitVoteRemote:IsA("RemoteFunction") then
		submitVoteRemote.OnServerInvoke = function(player: Player, ballot: Types.Ballot)
			return ElectionManager:recordVote(player, ballot)
		end
	end

	local requestStateRemote = Network.getRemote("RequestState")
	if requestStateRemote and requestStateRemote:IsA("RemoteFunction") then
		requestStateRemote.OnServerInvoke = function(player: Player)
			hydrateVoteFromData(player)
			return ElectionManager:exportState()
		end
	end

	CmdrSetup.register(ElectionManager)

	local requestConfigRemote = Network.getRemote("RequestElectionConfig")
	if requestConfigRemote and requestConfigRemote:IsA("RemoteFunction") then
		--[[ Client-visible election UI config only.
			Never include `discord`, `cmdr`, eligibility internals, datastore keys, or other secrets here. ]]
		requestConfigRemote.OnServerInvoke = function()
			return {
				votingMethod = Settings.votingMethod,
				governmentType = Settings.governmentType,
				seatSystem = Settings.seatSystem,
				seats = Settings.seats,
				threshold = Settings.threshold,
				seatAllocationMethod = Settings.seatAllocationMethod,
				ui = Settings.ui,
				parties = Settings.parties,
				candidates = Settings.candidates,
			}
		end
	end

	local phaseChangedRemote = Network.getRemote("PhaseChanged")
	if phaseChangedRemote and phaseChangedRemote:IsA("RemoteEvent") then
		timestampManager.PhaseChanged:connect(function(newPhase: Types.ElectionPhase)
			phaseChangedRemote:FireAllClients(newPhase)
		end)
		timestampManager.PhaseChanged:connect(function(newPhase: Types.ElectionPhase)
			DiscordNotifier.notifyElectionPhase(newPhase)
		end)
	end

	print("[ElectionSystem] Initialized")
	return ElectionManager
end

--[=[
	@method getPhase
	@within ElectionManager
	@return ElectionPhase

	Returns the current election phase.
]=]
function ElectionManager:getPhase(): Types.ElectionPhase
	return timestampManager:getPhase()
end

--[=[
	@method getCountdown
	@within ElectionManager
	@return number

	Returns seconds until next phase transition.
]=]
function ElectionManager:getCountdown(): number
	return timestampManager:getCountdown()
end

--[=[
	@method getStore
	@within ElectionManager
	@return Store

	Returns the election store instance.
]=]
function ElectionManager:getStore(): any
	return store
end

--[=[
	@method getResults
	@within ElectionManager
	@return ElectionResult?

	Returns cached election results if available.
]=]
function ElectionManager:getResults(): Types.ElectionResult?
	return store:getResultsCache()
end

--[=[
	@method calculateResults
	@within ElectionManager
	@return ElectionResult

	Calculates election results from recorded votes.
]=]
function ElectionManager:calculateResults(): Types.ElectionResult
	local ballots = store:getAllVotes()
	local result = ResultCalculator.calculate(Settings.votingMethod, ballots, store)
	if #Settings.districts > 0 then
		local districtResults = ResultCalculator.calculateByDistrict(Settings.votingMethod, ballots, store)
		local mutableResult = result :: any
		mutableResult.districtResults = districtResults
	end
	store:setResultsCache(result)
	local resultsPublished = Network.getRemote("ResultsPublished")
	if resultsPublished and resultsPublished:IsA("RemoteEvent") then
		resultsPublished:FireAllClients(result)
	end
	return result
end

--[=[
	@method checkEligibility
	@within ElectionManager
	@param player Player
	@return EligibilityResult

	Checks if a player is eligible to vote.
]=]
function ElectionManager:checkEligibility(player: Player): Types.EligibilityResult
	return EligibilityChecker.check(player)
end

--[=[
	@method recordVote
	@within ElectionManager
	@param player Player
	@param ballot Ballot
	@return boolean

	Records a vote and returns success status.
]=]
function ElectionManager:recordVote(player: Player, ballot: Types.Ballot): boolean
	-- Check eligibility
	local eligibility = EligibilityChecker.check(player)
	if not eligibility.eligible then
		DiscordNotifier.notifyVoteDenied(player, "ineligible", eligibility.reason)
		return false
	end

	hydrateVoteFromData(player)

	local uid = tostring(player.UserId)
	if store:hasVoted(uid) then
		DiscordNotifier.notifyVoteDenied(player, "duplicate_vote", "Player already has a recorded vote.")
		return false
	end

	local ballotCheck = ResultCalculator.validateBallot(ballot)
	if not ballotCheck.valid then
		DiscordNotifier.notifyVoteDenied(player, "invalid_ballot", ballotCheck.reason)
		warn("[ElectionSystem] Invalid ballot: " .. ballotCheck.reason)
		return false
	end

	local district = DistrictManager.getDistrict(player)
	local districtId = if district then district.districtId else nil

	local priorVoteRecord = store:getVoteRecord(uid)

	-- Record vote
	store:recordVote(uid, ballot, timestampManager:getPhase() == "Open" and 1 or 0, districtId)
	local voteRecord = store:getVoteRecord(uid)
	if voteRecord then
		Data.setVoteRecord(player.UserId, voteRecord)
	end

	-- Check for alts (rapid uses priorVoteRecord, not the ballot just written)
	local altFlag = AltDetector.detect(store, uid, player, priorVoteRecord)
	if altFlag.flagged then
		if altFlag.shouldInvalidate then
			warn("[ElectionSystem] Vote invalidated (alt detection): " .. altFlag.reason)
			store:removeVote(uid)
			DiscordNotifier.notifyAltDetection(player, altFlag.reason, "invalidated")
		elseif altFlag.shouldKick then
			DiscordNotifier.notifyAltDetection(player, altFlag.reason, "kick")
		end
	else
		DiscordNotifier.notifyVoteRecorded(player, ballot, districtId)
	end

	local stateUpdated = Network.getRemote("ElectionStateUpdated")
	if stateUpdated and stateUpdated:IsA("RemoteEvent") then
		stateUpdated:FireAllClients(self:exportState())
	end

	return true
end

--[=[
	@method exportState
	@within ElectionManager
	@return table

	Exports the current election state.
]=]
function ElectionManager:exportState(): any
	return {
		phase = timestampManager:getPhase(),
		countdown = timestampManager:getCountdown(),
		votes = store:getAllVotes(),
		results = store:getResultsCache(),
	}
end

-- Auto-initialize
ElectionManager.init()

return ElectionManager
