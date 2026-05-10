--!strict

local Types = require(script.Parent.Parent.Types)
local RoundManager = require(script.Parent.Parent.RoundManager)
local SeatAllocator = require(script.Parent.Parent.SeatAllocator)

--[=[
	@class STV

	Single Transferable Vote (Ireland, Australia Senate).
	Multi-seat system with ranked ballots.
	Candidates reaching quota elected; surplus votes transferred to next choices.
	Lowest candidate eliminated repeatedly until all seats filled.
]=]

local STV = {}

function STV.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local totalVotes = #ballots
	local quota = math.floor(totalVotes / (config.seats + 1)) + 1
	local elected: { Types.Candidate } = {}
	local eliminated: { [string]: boolean } = {}

	local currentBallots = ballots
	local roundHistory: { any } = {}

	while #elected < config.seats do
		local votes = RoundManager.getRoundVotes(currentBallots)
		table.insert(roundHistory, votes)

		-- Check for elected candidates
		for candidateId, voteCount in pairs(votes) do
			if voteCount >= quota and not eliminated[candidateId] then
				for _, candidate in ipairs(config.candidates) do
					if candidate.candidateId == candidateId then
						table.insert(elected, candidate)
						eliminated[candidateId] = true
						break
					end
				end
			end
		end

		if #elected >= config.seats then break end

		-- Eliminate lowest
		local loser = RoundManager.getLoser(votes)
		if not loser then break end
		eliminated[loser] = true
		currentBallots = RoundManager.eliminateCandidate(loser, currentBallots)

		if #currentBallots == 0 then break end
	end

	return {
		winner = if #elected == 1 then elected[1] else (if #elected > 0 then elected else config.candidates[1]),
		voteShare = {},
		roundHistory = roundHistory,
	}
end

function STV.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	if #ballot < config.seats then
		return { valid = false, reason = "STV requires ranking at least " .. tostring(config.seats) .. " candidates" }
	end

	local rankedSet: { [number]: boolean } = {}
	for _, entry in ipairs(ballot) do
		if not entry.rank then
			return { valid = false, reason = "All candidates must be ranked" }
		end
		if rankedSet[entry.rank] then
			return { valid = false, reason = "Duplicate rank" }
		end
		rankedSet[entry.rank] = true
	end

	return { valid = true, reason = "Valid ballot" }
end

return STV
