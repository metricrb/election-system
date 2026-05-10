--!strict

local Types = require(script.Parent.Parent.Types)

--[=[
	@class Sortition

	Sortition/Random selection. Randomly selects N eligible players for office.
	No voting required.
]=]

local Sortition = {}

function Sortition.calculateWinner(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	if #config.candidates == 0 then
		return {
			winner = {},
			voteShare = {},
		}
	end

	-- Randomly select winners (number = config.seats)
	local numWinners = math.min(config.seats, #config.candidates)
	local winners: { Types.Candidate } = {}
	local selected: { [string]: boolean } = {}

	for _ = 1, numWinners do
		local candidateIdx = math.random(1, #config.candidates)
		while selected[config.candidates[candidateIdx].candidateId] do
			candidateIdx = math.random(1, #config.candidates)
		end
		table.insert(winners, config.candidates[candidateIdx])
		selected[config.candidates[candidateIdx].candidateId] = true
	end

	return {
		winner = if #winners == 1 then winners[1] else winners,
		voteShare = {},
	}
end

function Sortition.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	-- Sortition has no actual ballot - always valid
	return { valid = true, reason = "Sortition requires no ballot" }
end

return Sortition
