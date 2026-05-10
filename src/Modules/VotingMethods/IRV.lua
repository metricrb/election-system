--!strict

local Types = require(script.Parent.Parent.Types)
local RoundManager = require(script.Parent.Parent.RoundManager)

--[=[
	@class IRV

	Instant Runoff Voting (ranked choice). Iteratively eliminates lowest-vote candidate
	until someone reaches majority (>50%).
]=]

local IRV = {}

function IRV.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local currentBallots = ballots
	local totalVotes = #ballots
	local majority = math.ceil(totalVotes / 2)
	local roundHistory: { any } = {}

	while true do
		local votes = RoundManager.getRoundVotes(currentBallots)
		table.insert(roundHistory, votes)

		-- Check for majority
		for candidateId, voteCount in pairs(votes) do
			if voteCount >= majority then
				return {
					winner = { candidateId = candidateId } :: any,
					voteShare = votes,
					roundHistory = roundHistory,
				}
			end
		end

		-- Eliminate loser
		if #currentBallots == 0 then break end

		local loser = RoundManager.getLoser(votes)
		currentBallots = RoundManager.eliminateCandidate(loser, currentBallots)

		-- Check if only one candidate left
		local remaining: { [string]: boolean } = {}
		for _, ballot in ipairs(currentBallots) do
			if #ballot > 0 then
				remaining[ballot[1].candidateId] = true
			end
		end

		if #(function() local t = {} for k in pairs(remaining) do table.insert(t, k) end return t end)() <= 1 then
			local lastCandidate = next(remaining)
			return {
				winner = { candidateId = lastCandidate or loser } :: any,
				voteShare = votes,
				roundHistory = roundHistory,
			}
		end
	end

	return {
		winner = config.candidates[1],
		voteShare = {},
		roundHistory = roundHistory,
	}
end

function IRV.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	if #ballot < 1 then
		return { valid = false, reason = "IRV requires at least one ranked candidate" }
	end

	local rankedSet: { [number]: boolean } = {}
	for _, entry in ipairs(ballot) do
		if not entry.rank then
			return { valid = false, reason = "All ranked candidates must have distinct ranks" }
		end
		if rankedSet[entry.rank] then
			return { valid = false, reason = "Duplicate rank" }
		end
		rankedSet[entry.rank] = true
	end

	return { valid = true, reason = "Valid ballot" }
end

return IRV
