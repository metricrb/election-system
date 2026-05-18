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
DistrictManager.setStore(store)
local timestampManager = TimestampManager.new()
local phaseChanged = Signal.new()

local liveResultsRefreshToken = 0
local LIVE_RESULTS_DEBOUNCE_SEC = 0.45

local function scheduleLiveResultsRecalculate()
	liveResultsRefreshToken += 1
	local token = liveResultsRefreshToken
	task.delay(LIVE_RESULTS_DEBOUNCE_SEC, function()
		if token ~= liveResultsRefreshToken then
			return
		end
		pcall(function()
			ElectionManager:calculateResults(false)
		end)
	end)
end

local function hydrateVoteFromData(player: Player): ()
	Data.loadProfile(player.UserId)
	local uid = tostring(player.UserId)
	local record = Data.getVoteRecord(player.UserId)
	if record then
		store:seedVoteFromData(uid, record)
	else
		local gRec = Data.getGlobalVoteRecordForUser(player.UserId)
		if gRec then
			local gid = if type(gRec.userId) == "string" then gRec.userId else uid
			store:seedVoteFromData(gid, gRec)
		end
	end
end

local function syncPersistedVotesIntoStore(): ()
	if Settings.clearPlayerVoteOnJoin then
		return
	end
	for _, player in Players:GetPlayers() do
		hydrateVoteFromData(player)
	end
	for _, rec in ipairs(Data.getAllPersistedVoteRecordsFromLoadedProfiles()) do
		if type(rec.userId) == "string" then
			store:seedVoteFromData(rec.userId, rec)
		end
	end
end

local function getVoteRecordsForTally(): { Types.VoteRecord }
	syncPersistedVotesIntoStore()
	local byUser: { [string]: Types.VoteRecord } = {}
	if Settings.globalVoteLedger.enabled then
		for _, rec in ipairs(Data.getAllGlobalVoteRecords()) do
			if type(rec.userId) == "string" then
				byUser[rec.userId] = rec
			end
		end
	end
	for _, rec in ipairs(store:getAllVotes()) do
		if type(rec.userId) == "string" and byUser[rec.userId] == nil then
			byUser[rec.userId] = rec
		end
	end
	local out: { Types.VoteRecord } = {}
	for _, rec in pairs(byUser) do
		table.insert(out, rec)
	end
	return out
end

function ElectionManager:hydrateVoteFromDataStore(player: Player): ()
	hydrateVoteFromData(player)
end

function ElectionManager:syncPersistedVotesIntoStore(): ()
	syncPersistedVotesIntoStore()
end

function ElectionManager:getMergedVoteRecords(): { Types.VoteRecord }
	return getVoteRecordsForTally()
end

function ElectionManager:resetAllVoteDataForCmd(): ()
	store:clear()
	Data.clearGlobalVoteLedger()
	for _, p in Players:GetPlayers() do
		Data.clearVoteRecord(p.UserId)
	end
end

function ElectionManager:invalidateVoteByUserId(userId: number): string
	if type(userId) ~= "number" or userId < 1 then
		return "Invalid UserId."
	end
	local uidStr = tostring(userId)
	store:removeVote(uidStr)
	Data.removeGlobalVoteRecord(userId)
	Data.clearVoteRecord(userId)
	DistrictManager.clearAssignmentForUser(uidStr)
	local online = Players:GetPlayerByUserId(userId)
	if online then
		DistrictManager.syncDistrictAttribute(online)
		local stateUpdated = Network.getRemote("ElectionStateUpdated")
		if stateUpdated and stateUpdated:IsA("RemoteEvent") then
			stateUpdated:FireClient(online, ElectionManager:exportState())
		end
	end
	pcall(function()
		ElectionManager:calculateResults(false)
	end)
	return ("Invalidated vote for UserId %d (session, profile, global ledger)."):format(userId)
end

--[=[
	@function init
	@within ElectionManager

	Initializes the election system (called automatically on first require).
]=]
function ElectionManager.init()
	Network.init()
	Data.init()
	DistrictManager.init()

	for _, existing in Players:GetPlayers() do
		task.spawn(function()
			hydrateVoteFromData(existing)
			DistrictManager.syncDistrictAttribute(existing)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			hydrateVoteFromData(player)
			DistrictManager.syncDistrictAttribute(player)
		end)
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
			DistrictManager.syncDistrictAttribute(player)
			local state = ElectionManager:exportState()
			;(state :: any).playerDistrict = DistrictManager.getDistrict(player)
			return state
		end
	end

	CmdrSetup.register(ElectionManager)

	local requestConfigRemote = Network.getRemote("RequestElectionConfig")
	if requestConfigRemote and requestConfigRemote:IsA("RemoteFunction") then
		--[[ Client-visible election UI config only.
			Never include `discord`, `cmdr`, eligibility internals, datastore keys, or other secrets here. ]]
		requestConfigRemote.OnServerInvoke = function(player: Player)
			local playerDistrict = DistrictManager.getDistrict(player)
			DistrictManager.syncDistrictAttribute(player)
			return {
				votingMethod = Settings.votingMethod,
				governmentType = Settings.governmentType,
				seatSystem = Settings.seatSystem,
				seats = Settings.seats,
				threshold = Settings.threshold,
				seatAllocationMethod = Settings.seatAllocationMethod,
				twoRoundStyle = Settings.twoRoundStyle,
				ui = Settings.ui,
				parties = Settings.parties,
				candidates = Settings.candidates,
				districts = Settings.districts,
				allowVoteReplacement = Settings.allowVoteReplacement,
				playerDistrict = playerDistrict,
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

	store.dataChanged:connect(function(key)
		if key == "voteRecords" then
			scheduleLiveResultsRecalculate()
		end
	end)

	task.defer(function()
		pcall(function()
			ElectionManager:calculateResults(false)
		end)
	end)

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
function ElectionManager:calculateResults(publishToClients: boolean?): Types.ElectionResult
	local voteRecords = getVoteRecordsForTally()
	local ballots: { Types.Ballot } = {}
	for _, rec in pairs(voteRecords) do
		table.insert(ballots, rec.ballot)
	end
	local result = ResultCalculator.calculate(Settings.votingMethod, ballots, store)
	if #Settings.districts > 0 then
		local districtResults = ResultCalculator.calculateByDistrict(Settings.votingMethod, voteRecords, store)
		ResultCalculator.mergeCompleteDistrictResults(districtResults, Settings.votingMethod, store, result.phase)
		local mutableResult = result :: any
		mutableResult.districtResults = districtResults
	end
	store:setResultsCache(result)
	local shouldPublish = if publishToClients == nil then true else publishToClients
	if shouldPublish then
		local resultsPublished = Network.getRemote("ResultsPublished")
		if resultsPublished and resultsPublished:IsA("RemoteEvent") then
			resultsPublished:FireAllClients(result)
		end
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
	local priorVoteRecord = store:getVoteRecord(uid)
	if store:hasVoted(uid) and not Settings.allowVoteReplacement then
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
	if not DistrictManager.isBallotAllowedForDistrict(ballot, district) then
		local reason = "Candidate is not standing in your constituency."
		DiscordNotifier.notifyVoteDenied(player, "invalid_ballot", reason)
		return false
	end
	local districtId = if district then district.districtId else nil

	-- Record vote
	store:recordVote(uid, ballot, timestampManager:getPhase() == "Open" and 1 or 0, districtId)
	local voteRecord = store:getVoteRecord(uid)
	if not voteRecord then
		return false
	end
	if Settings.globalVoteLedger.enabled then
		if not Data.tryInsertGlobalVoteRecord(player.UserId, voteRecord) then
			store:removeVote(uid)
			DiscordNotifier.notifyVoteDenied(
				player,
				"duplicate_vote",
				"Could not save vote to the global election tally."
			)
			return false
		end
	end
	Data.setVoteRecord(player.UserId, voteRecord)

	-- Check for alts (rapid uses priorVoteRecord, not the ballot just written)
	local altFlag = AltDetector.detect(store, uid, player, priorVoteRecord)
	if altFlag.flagged then
		if altFlag.shouldInvalidate then
			warn("[ElectionSystem] Vote invalidated (alt detection): " .. altFlag.reason)
			store:removeVote(uid)
			Data.removeGlobalVoteRecord(player.UserId)
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
