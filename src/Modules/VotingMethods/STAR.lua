--!strict

local Types = require(script.Parent.Parent.Types)

--[[
	@class STAR
	@within ElectionSystem

	STAR voting (Score Then Automatic Runoff).
	Phase 1: Each voter scores candidates 0-5.
	Phase 2: Top 2 highest-scoring candidates enter automatic runoff.
	Phase 3: Ballots compared: higher-scored candidate wins pairwise comparison.
]]

local STAR = {}

function STAR.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	-- Phase 1: Score each candidate
	local scoreSum: { [string]: number } = {}
	local scoreCount: { [string]: number } = {}

	for _, ballot in ipairs(ballots) do
		for _, entry in ipairs(ballot) do
			if entry.score then
				scoreSum[entry.candidateId] = (scoreSum[entry.candidateId] or 0) + entry.score
				scoreCount[entry.candidateId] = (scoreCount[entry.candidateId] or 0) + 1
			end
		end
	end

	-- Find average scores
	local averageScores: { { candidateId: string, average: number } } = {}
	for candidateId, sum in pairs(scoreSum) do
		local count = scoreCount[candidateId] or 1
		table.insert(averageScores, { candidateId = candidateId, average = sum / count })
	end
	table.sort(averageScores, function(a, b) return a.average > b.average end)

	if #averageScores < 2 then
		return {
			winner = { candidateId = averageScores[1].candidateId } :: any,
			voteShare = {},
		}
	end

	-- Phase 2: Top 2 enter runoff
	local finalist1 = averageScores[1].candidateId
	local finalist2 = averageScores[2].candidateId

	-- Phase 3: Automatic runoff - compare ballot preferences
	local finalist1Wins = 0
	local finalist2Wins = 0

	for _, ballot in ipairs(ballots) do
		local score1: number?
		local score2: number?

		for _, entry in ipairs(ballot) do
			if entry.candidateId == finalist1 and entry.score then
				score1 = entry.score
			elseif entry.candidateId == finalist2 and entry.score then
				score2 = entry.score
			end
		end

		if score1 and score2 then
			if score1 > score2 then
				finalist1Wins = finalist1Wins + 1
			elseif score2 > score1 then
				finalist2Wins = finalist2Wins + 1
			end
		end
	end

	local winner = if finalist1Wins > finalist2Wins then finalist1 else finalist2

	return {
		winner = { candidateId = winner } :: any,
		voteShare = {},
	}
end

function STAR.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	for _, entry in ipairs(ballot) do
		if not entry.score or entry.score < 0 or entry.score > 5 then
			return { valid = false, reason = "All candidates must have scores 0-5" }
		end
	end

	return { valid = true, reason = "Valid ballot" }
end

return STAR
