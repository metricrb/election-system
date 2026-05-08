--!strict

--[[
	@class ElectionSystem (ElectionManager)
	@within ElectionSystem

	Root module for the universal Roblox election system.
	Initialize and configure via src/Settings.lua before using.
]]

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

--[[
	@function init
	@within ElectionManager

	Initializes the election system (called automatically on first require).
]]
function ElectionManager.init()
	Network.init()
	print("[ElectionSystem] Initialized")
	return ElectionManager
end

--[[
	@method getPhase
	@within ElectionManager
	@return ElectionPhase

	Returns the current election phase.
]]
function ElectionManager:getPhase(): Types.ElectionPhase
	return timestampManager:getPhase()
end

--[[
	@method getCountdown
	@within ElectionManager
	@return number

	Returns seconds until next phase transition.
]]
function ElectionManager:getCountdown(): number
	return timestampManager:getCountdown()
end

--[[
	@method getStore
	@within ElectionManager
	@return Store

	Returns the election store instance.
]]
function ElectionManager:getStore(): any
	return store
end

--[[
	@method getResults
	@within ElectionManager
	@return ElectionResult?

	Returns cached election results if available.
]]
function ElectionManager:getResults(): Types.ElectionResult?
	return store:getResultsCache()
end

--[[
	@method calculateResults
	@within ElectionManager
	@return ElectionResult

	Calculates election results from recorded votes.
]]
function ElectionManager:calculateResults(): Types.ElectionResult
	local ballots = store:getAllVotes()
	local result = ResultCalculator.calculate(Settings.votingMethod, ballots, store)
	store:setResultsCache(result)
	return result
end

--[[
	@method checkEligibility
	@within ElectionManager
	@param player Player
	@return EligibilityResult

	Checks if a player is eligible to vote.
]]
function ElectionManager:checkEligibility(player: Player): Types.EligibilityResult
	return EligibilityChecker.check(player)
end

--[[
	@method recordVote
	@within ElectionManager
	@param player Player
	@param ballot Ballot
	@return boolean

	Records a vote and returns success status.
]]
function ElectionManager:recordVote(player: Player, ballot: Types.Ballot): boolean
	-- Check eligibility
	local eligibility = EligibilityChecker.check(player)
	if not eligibility.eligible then
		return false
	end

	-- Check if already voted
	if store:hasVoted(tostring(player.UserId)) then
		return false
	end

	-- Record vote
	store:recordVote(tostring(player.UserId), ballot, timestampManager:getPhase() == "Open" and 1 or 0)

	-- Check for alts
	local altFlag = AltDetector.detect(store, tostring(player.UserId), player)
	if altFlag.flagged then
		if altFlag.shouldInvalidate then
			store:removeVote(tostring(player.UserId))
		end
	end

	return true
end

--[[
	@method exportState
	@within ElectionManager
	@return table

	Exports the current election state.
]]
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
