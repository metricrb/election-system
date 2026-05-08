--!strict

local Types = require(script.Parent.Types)
local Store = require(script.Parent.Store)

--[[
	@class RoundManager
	@within ElectionSystem

	Manages multi-round voting systems (TwoRound, IRV).
	Handles candidate elimination, vote transfers, and round progression.
]]

local RoundManager = {}

--[[
	@function initRound
	@within RoundManager
	@param store Store
	@return number

	Initializes a new round and returns the round ID.
]]
function RoundManager.initRound(store: Store): number
	local currentRound = store:get("currentRound") or 0
	local newRound = currentRound + 1
	store:set("currentRound", newRound)
	return newRound
end

--[[
	@function getRoundVotes
	@within RoundManager
	@param ballots { Types.Ballot }
	@return { [string]: number }

	Returns vote counts for the current round (first valid preference per ballot).
]]
function RoundManager.getRoundVotes(ballots: { Types.Ballot }): { [string]: number }
	local votes: { [string]: number } = {}

	for _, ballot in ipairs(ballots) do
		if #ballot > 0 then
			local candidateId = ballot[1].candidateId
			votes[candidateId] = (votes[candidateId] or 0) + 1
		end
	end

	return votes
end

--[[
	@function eliminateCandidate
	@within RoundManager
	@param candidateId string
	@param ballots { Types.Ballot }
	@return { Types.Ballot }

	Removes a candidate from all ballots and returns updated ballots.
]]
function RoundManager.eliminateCandidate(candidateId: string, ballots: { Types.Ballot }): { Types.Ballot }
	local updatedBallots = {}

	for _, ballot in ipairs(ballots) do
		local newBallot: Types.Ballot = {}
		for _, entry in ipairs(ballot) do
			if entry.candidateId ~= candidateId then
				table.insert(newBallot, entry)
			end
		end
		table.insert(updatedBallots, newBallot)
	end

	return updatedBallots
end

--[[
	@function getLoser
	@within RoundManager
	@param votes { [string]: number }
	@return string

	Returns the candidate ID with the fewest votes (the loser to eliminate).
]]
function RoundManager.getLoser(votes: { [string]: number }): string
	local minVotes = math.huge
	local loserId: string?

	for candidateId, voteCount in pairs(votes) do
		if voteCount < minVotes then
			minVotes = voteCount
			loserId = candidateId
		end
	end

	return loserId or ""
end

return RoundManager
