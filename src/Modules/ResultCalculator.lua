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

--[=[
	@class ResultCalculator
	@tag Elections & Results

	Coordinates all 14 voting methods and calculates election results from ballots.

	The ResultCalculator dispatches to method-specific implementation modules (FPTP, IRV, Score, etc.)
	based on the configured voting method in Settings. It also handles:
	- Ballot format validation (custom per voting method)
	- Result formatting into a standard ElectionResult structure
	- District-by-district vote counting for geographic elections

	## Voting Methods

	All 14 methods return winners and vote shares:
	- **FPTP** — First-past-the-post, single winner
	- **TwoRound** — Two-round runoff, single winner
	- **IRV** — Instant runoff voting, ranked choice
	- **Approval** — Approval voting
	- **Score** — Range/score voting
	- **STAR** — Score Then Automatic Runoff
	- **STV** — Single Transferable Vote, multi-winner
	- **PartyListPR** — Party-list proportional representation
	- **MMP** — Mixed-member proportional
	- **Parallel** — Parallel voting systems
	- **Condorcet** — Condorcet method
	- **Borda** — Borda count
	- **Cumulative** — Cumulative voting
	- **Sortition** — Random selection (for sortition-based elections)

	## Usage

	```lua
	-- Usually handled internally by ElectionManager.calculateResults()
	local ballots = store:getAllVotes()
	local result = ResultCalculator.calculate(Settings.votingMethod, ballots, store)
	print("Winner:", result.winner.name)
	print("Votes recorded:", result.votesRecorded)
	```
]=]

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

--[=[
	@function calculate
	@within ResultCalculator
	@param votingMethod string — The voting method to use (e.g., "FPTP", "IRV")
	@param ballots { Types.Ballot } — Array of all cast ballots
	@param store Store — The election store instance
	@return Types.ElectionResult — Complete election results with winners and vote shares

	Calculates election results using the specified voting method.

	Delegates to the method-specific module (e.g., FPTP.lua, IRV.lua) which implements
	the counting algorithm. Returns a standardized ElectionResult object.

	```lua
	local result = ResultCalculator.calculate("IRV", ballots, store)
	```
]=]

--[=[
	@function validateBallot
	@within ResultCalculator
	@param ballot Types.Ballot
	@return { valid: boolean, reason: string }

	Validates a ballot against the currently configured voting method's rules.

	Different voting methods have different ballot constraints:
	- FPTP: single selection
	- Ranked methods: no duplicate selections
	- Score: numeric ranges
	- Approval: binary choices

	Returns `{valid=true}` if the ballot is acceptable, otherwise an error reason.
]=]
function ResultCalculator.validateBallot(ballot: Types.Ballot): { valid: boolean, reason: string }
	local method = METHODS[Settings.votingMethod]
	if not method or not method.validateBallot then
		return { valid = true, reason = "OK" }
	end
	return method.validateBallot(ballot, Settings)
end

-- Vote-share values from method modules are mixed: some are raw counts / points before this step.
-- Exposed `voteShare` is **percentage of ballots** for counting methods (incl. FPTP / Approval / Cumulative),
-- Borda as % of points, Score/STAR unchanged (method-specific scale).
local function normalizedVoteShareForResult(
	votingMethod: string,
	share: { [string]: number },
	ballotsCast: number
): { [string]: number }
	if next(share) == nil then
		return share
	end
	if votingMethod == "Score" or votingMethod == "STAR" then
		return share
	end
	if votingMethod == "FPTP" or votingMethod == "Approval" or votingMethod == "Cumulative" then
		if ballotsCast > 0 then
			local out: { [string]: number } = {}
			for id, v in pairs(share) do
				out[id] = (v / ballotsCast) * 100
			end
			return out
		end
		return share
	end

	local sum = 0
	for _, v in pairs(share) do
		sum += v
	end
	if sum <= 0 then
		return share
	end

	if votingMethod == "Borda" then
		local out: { [string]: number } = {}
		for id, v in pairs(share) do
			out[id] = (v / sum) * 100
		end
		return out
	end

	if ballotsCast > 0 then
		local out: { [string]: number } = {}
		for id, v in pairs(share) do
			out[id] = (v / ballotsCast) * 100
		end
		return out
	end

	return share
end

function ResultCalculator.calculate(
	votingMethod: string,
	ballots: { Types.Ballot },
	store: Store,
	countContext: Types.ResultCountContext?
): Types.ElectionResult
	local method = METHODS[votingMethod]
	if not method then
		error("Unknown voting method: " .. votingMethod)
	end

	local winnerResult = method.calculateWinner(ballots, Settings, countContext)

	local eligibleVoters = #Settings.candidates
	local rh: any = winnerResult.roundHistory
	if type(rh) == "table" and type(rh.registeredVoters) == "number" and rh.registeredVoters > 0 then
		eligibleVoters = rh.registeredVoters
	end

	local share = normalizedVoteShareForResult(votingMethod, winnerResult.voteShare, #ballots)

	return {
		phase = "ResultsOut",
		votesRecorded = #ballots,
		eligibleVoters = eligibleVoters,
		winner = winnerResult.winner,
		voteShare = share,
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
		resultsByDistrict[district.districtId] = ResultCalculator.calculate(votingMethod, ballots, store, { districtId = district.districtId })
	end
	return resultsByDistrict
end

--[=[
	@function mergeCompleteDistrictResults
	@within ResultCalculator

	Ensures every district in `Settings.districts` has an entry (e.g. after Settings grew, or stale cached `districtResults`).
	Mutates `districtResults` in place.
]=]
function ResultCalculator.mergeCompleteDistrictResults(
	districtResults: { [string]: Types.ElectionResult },
	votingMethod: string,
	store: Store,
	nationalPhase: Types.ElectionPhase
): ()
	for _, d in ipairs(Settings.districts) do
		if not districtResults[d.districtId] then
			local dr = ResultCalculator.calculate(votingMethod, {}, store, { districtId = d.districtId })
			local mutable = dr :: any
			mutable.phase = nationalPhase
			districtResults[d.districtId] = dr
		end
	end
end

return ResultCalculator
