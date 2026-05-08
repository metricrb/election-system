--!strict

local Types = require(script.Parent.Types)
local Settings = require(script.Parent.Parent.Settings)
local Store = require(script.Parent.Store)
local DistrictManager = require(script.Parent.DistrictManager)

-- Load all voting methods
local FPTP = require(script.Parent.VotingMethods.FPTP)
local TwoRound = require(script.Parent.VotingMethods.TwoRound)
local IRV = require(script.Parent.VotingMethods.IRV)
local Approval = require(script.Parent.VotingMethods.Approval)
local Score = require(script.Parent.VotingMethods.Score)
local STAR = require(script.Parent.VotingMethods.STAR)
local STV = require(script.Parent.VotingMethods.STV)
local PartyListPR = require(script.Parent.VotingMethods.PartyListPR)
local MMP = require(script.Parent.VotingMethods.MMP)
local Parallel = require(script.Parent.VotingMethods.Parallel)
local Condorcet = require(script.Parent.VotingMethods.Condorcet)
local Borda = require(script.Parent.VotingMethods.Borda)
local Cumulative = require(script.Parent.VotingMethods.Cumulative)
local Sortition = require(script.Parent.VotingMethods.Sortition)

--[[
	@class ResultCalculator
	@within ElectionSystem

	Orchestrates voting method execution and result formatting.
]]

local ResultCalculator = {}

local METHODS: { [string]: any } = {
	FPTP = FPTP,
	TwoRound = TwoRound,
	IRV = IRV,
	Approval = Approval,
	Score = Score,
	STAR = STAR,
	STV = STV,
	PartyListPR = PartyListPR,
	MMP = MMP,
	Parallel = Parallel,
	Condorcet = Condorcet,
	Borda = Borda,
	Cumulative = Cumulative,
	Sortition = Sortition,
}

--[[
	@function calculate
	@within ResultCalculator
	@param votingMethod string
	@param ballots { Types.Ballot }
	@param store Store
	@return Types.ElectionResult

	Calculates election results using the specified voting method.
]]
--[[
	@function validateBallot
	@within ResultCalculator

	Uses the active Settings.votingMethod implementation's validateBallot when present.
]]
function ResultCalculator.validateBallot(ballot: Types.Ballot): { valid: boolean, reason: string }
	local method = METHODS[Settings.votingMethod]
	if not method or not method.validateBallot then
		return { valid = true, reason = "OK" }
	end
	return method.validateBallot(ballot, Settings)
end

function ResultCalculator.calculate(votingMethod: string, ballots: { Types.Ballot }, store: Store): Types.ElectionResult
	local method = METHODS[votingMethod]
	if not method then
		error("Unknown voting method: " .. votingMethod)
	end

	local winnerResult = method.calculateWinner(ballots, Settings)

	return {
		phase = "ResultsOut",
		votesRecorded = #ballots,
		eligibleVoters = #Settings.candidates,
		winner = winnerResult.winner,
		voteShare = winnerResult.voteShare,
		seats = nil,
		coalition = nil,
		roundHistory = winnerResult.roundHistory,
		calculatedAt = os.time(),
	}
end

function ResultCalculator.calculateByDistrict(votingMethod: string, voteRecords: { Types.VoteRecord }, store: Store): { [string]: Types.ElectionResult }
	local resultsByDistrict: { [string]: Types.ElectionResult } = {}
	for _, district in ipairs(Settings.districts) do
		local districtVotes = DistrictManager.getDistrictVotes(district.districtId, voteRecords)
		local ballots: { Types.Ballot } = {}
		for _, vote in ipairs(districtVotes) do
			table.insert(ballots, vote.ballot)
		end
		resultsByDistrict[district.districtId] = ResultCalculator.calculate(votingMethod, ballots, store)
	end
	return resultsByDistrict
end

return ResultCalculator
