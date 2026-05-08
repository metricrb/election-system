--!strict

local Types = require(script.Parent.Parent.Types)

--[[
	@class Condorcet
	@within ElectionSystem

	Condorcet voting. Candidate who beats all others in head-to-head matchups wins.
	Uses ranked ballots to determine pairwise preferences.
]]

local Condorcet = {}

function Condorcet.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local numCandidates = #config.candidates
	local pairwiseVotes: { [string]: { [string]: number } } = {}

	-- Initialize pairwise matrix
	for _, c1 in ipairs(config.candidates) do
		pairwiseVotes[c1.candidateId] = {}
		for _, c2 in ipairs(config.candidates) do
			if c1.candidateId ~= c2.candidateId then
				pairwiseVotes[c1.candidateId][c2.candidateId] = 0
			end
		end
	end

	-- Count pairwise preferences
	for _, ballot in ipairs(ballots) do
		for i, entry1 in ipairs(ballot) do
			for j, entry2 in ipairs(ballot) do
				if i < j and entry1.rank and entry2.rank and entry1.rank < entry2.rank then
					pairwiseVotes[entry1.candidateId][entry2.candidateId] = pairwiseVotes[entry1.candidateId][entry2.candidateId] + 1
				end
			end
		end
	end

	-- Find Condorcet winner (beats all others)
	local winnerId: string?
	for _, candidate in ipairs(config.candidates) do
		local beatsAll = true
		for _, opponent in ipairs(config.candidates) do
			if candidate.candidateId ~= opponent.candidateId then
				if (pairwiseVotes[candidate.candidateId][opponent.candidateId] or 0) <= (pairwiseVotes[opponent.candidateId][candidate.candidateId] or 0) then
					beatsAll = false
					break
				end
			end
		end
		if beatsAll then
			winnerId = candidate.candidateId
			break
		end
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
		voteShare = {},
	}
end

function Condorcet.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	if #ballot ~= #config.candidates then
		return { valid = false, reason = "Condorcet requires ranking all candidates" }
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

return Condorcet
