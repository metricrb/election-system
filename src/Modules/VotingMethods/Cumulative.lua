--!strict

local Types = require(script.Parent.Parent.Types)

--[[
	@class Cumulative
	@within ElectionSystem

	Cumulative voting. Each voter distributes multiple votes among candidates.
	Can stack all votes on one candidate or spread them.
]]

local Cumulative = {}

function Cumulative.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local voteShare: { [string]: number } = {}

	for _, ballot in ipairs(ballots) do
		for _, entry in ipairs(ballot) do
			if entry.score then
				voteShare[entry.candidateId] = (voteShare[entry.candidateId] or 0) + entry.score
			end
		end
	end

	local maxVotes = 0
	local winnerId: string?
	for candidateId, votes in pairs(voteShare) do
		if votes > maxVotes then
			maxVotes = votes
			winnerId = candidateId
		end
	end

	local totalVotes = #ballots
	local sharePercentages: { [string]: number } = {}
	for candidateId, votes in pairs(voteShare) do
		sharePercentages[candidateId] = if totalVotes > 0 then (votes / totalVotes) * 100 else 0
	end

	local winner: Types.Candidate?
	for _, candidate in ipairs(config.candidates) do
		if candidate.candidateId == winnerId then
			winner = candidate
			break
		end
	end

	return {
		winner = winner or config.candidates[1],
		voteShare = sharePercentages,
	}
end

function Cumulative.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	local totalVotes = 0
	for _, entry in ipairs(ballot) do
		if entry.score then
			totalVotes = totalVotes + entry.score
		end
	end

	if totalVotes ~= #ballot then
		return { valid = false, reason = "Total votes must equal number of candidates" }
	end

	return { valid = true, reason = "Valid ballot" }
end

return Cumulative
