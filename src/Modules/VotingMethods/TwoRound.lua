--!strict

local Types = require(script.Parent.Parent.Types)
local RoundManager = require(script.Parent.Parent.RoundManager)

--[[
	@class TwoRound
	@within ElectionSystem

	Two-round (runoff) voting. If no candidate exceeds threshold in round 1,
	top two candidates advance to round 2.
]]

local TwoRound = {}

function TwoRound.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local threshold = config.runoffThreshold

	-- Round 1: Count votes
	local round1Votes = RoundManager.getRoundVotes(ballots)
	local totalVotes = #ballots

	-- Check if someone exceeded threshold
	for candidateId, votes in pairs(round1Votes) do
		local percentage = (votes / totalVotes) * 100
		if percentage >= threshold then
			-- Round 1 winner
			return {
				winner = { candidateId = candidateId } :: any,
				voteShare = round1Votes,
			}
		end
	end

	-- Round 2: Top two candidates only
	local topTwo: { { candidateId: string, votes: number } } = {}
	for candidateId, votes in pairs(round1Votes) do
		table.insert(topTwo, { candidateId = candidateId, votes = votes })
	end
	table.sort(topTwo, function(a, b) return a.votes > b.votes end)

	if #topTwo < 2 then
		return {
			winner = { candidateId = topTwo[1].candidateId } :: any,
			voteShare = round1Votes,
		}
	end

	-- Eliminate all but top 2
	local round2Ballots = ballots
	for i = 3, #topTwo do
		round2Ballots = RoundManager.eliminateCandidate(topTwo[i].candidateId, round2Ballots)
	end

	local round2Votes = RoundManager.getRoundVotes(round2Ballots)
	local winnerId: string?
	local maxVotes = 0

	for candidateId, votes in pairs(round2Votes) do
		if votes > maxVotes then
			maxVotes = votes
			winnerId = candidateId
		end
	end

	return {
		winner = { candidateId = winnerId or topTwo[1].candidateId } :: any,
		voteShare = round2Votes,
	}
end

function TwoRound.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	if #ballot < 2 then
		return { valid = false, reason = "Two-round requires ranking at least 2 candidates" }
	end

	for _, entry in ipairs(ballot) do
		if not entry.rank then
			return { valid = false, reason = "All candidates must be ranked" }
		end
	end

	return { valid = true, reason = "Valid ballot" }
end

return TwoRound
