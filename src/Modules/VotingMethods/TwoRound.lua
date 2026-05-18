--!strict

local Types = require(script.Parent.Parent.Types)
local RoundManager = require(script.Parent.Parent.RoundManager)

--[=[
	@class TwoRound

	Classic: top vote share in round 1 vs `runoffThreshold` (% of votes cast); otherwise top two → round 2.

	RegisteredRoll: single-member district style with a registered voter roll:
	- **Round 1:** elected if **absolute majority** of valid votes cast **and** votes ≥ **25%** of registered voters.
	- **Round 2:** candidates who received **≥ 12.5%** of registered voters in round 1;
	  if **none** did, the **two** leading candidates from round 1 stand;
	  if **only one** reached 12.5%, that candidate faces the **second-placed** candidate from round 1.
	  Round 2 is decided by **relative majority** (plurality) among remaining candidates — simulated via
	  first preference among qualifiers on each ranked ballot.
]=]

local TwoRound = {}

local function getRegisteredVoters(config: Types.ElectionConfig, countContext: Types.ResultCountContext?): number?
	-- Registered-roll thresholds are per district; a pooled national tally has no single roll.
	if #config.districts > 0 and (not countContext or not countContext.districtId) then
		return nil
	end
	if countContext and countContext.districtId and config.registeredVotersByDistrict then
		local n = config.registeredVotersByDistrict[countContext.districtId]
		if type(n) == "number" and n > 0 then
			return n
		end
	end
	if config.registeredVoters and config.registeredVoters > 0 then
		return config.registeredVoters
	end
	return nil
end

local function absoluteMajority(votes: number, totalValidVotes: number): boolean
	if totalValidVotes == 0 then
		return false
	end
	return votes * 2 > totalValidVotes
end

-- Registered-roll round-2 qualifiers (simplified counting rules)
local function registeredRollRound2QualifierIds(
	ordered: { { candidateId: string, votes: number } },
	registered: number
): { [string]: boolean }
	local threshold125 = 0.125 * registered
	local at125: { string } = {}
	for _, row in ipairs(ordered) do
		if row.votes >= threshold125 then
			table.insert(at125, row.candidateId)
		end
	end

	local ids: { string } = {}
	if #at125 == 0 then
		for i = 1, math.min(2, #ordered) do
			table.insert(ids, ordered[i].candidateId)
		end
	elseif #at125 == 1 then
		table.insert(ids, at125[1])
		for _, row in ipairs(ordered) do
			if row.candidateId ~= at125[1] then
				table.insert(ids, row.candidateId)
				break
			end
		end
	else
		for _, id in ipairs(at125) do
			table.insert(ids, id)
		end
	end

	local set: { [string]: boolean } = {}
	for _, id in ipairs(ids) do
		set[id] = true
	end
	return set
end

local function eliminateNonQualifiers(ballots: { Types.Ballot }, config: Types.ElectionConfig, qualify: { [string]: boolean }): { Types.Ballot }
	local b = ballots
	for _, c in ipairs(config.candidates) do
		if not qualify[c.candidateId] then
			b = RoundManager.eliminateCandidate(c.candidateId, b)
		end
	end
	return b
end

local function registeredRollTwoRound(ballots: { Types.Ballot }, config: Types.ElectionConfig, registered: number): Types.WinnerResult
	local round1Votes = RoundManager.getRoundVotes(ballots)
	local totalVotes = #ballots

	for candidateId, votes in pairs(round1Votes) do
		if absoluteMajority(votes, totalVotes) and votes >= 0.25 * registered then
			return {
				winner = { candidateId = candidateId } :: any,
				voteShare = round1Votes,
				roundHistory = {
					style = "RegisteredRoll",
					registeredVoters = registered,
					round = 1,
					decidedInRound1 = true,
					round1VoteShare = round1Votes,
				},
			}
		end
	end

	local ordered: { { candidateId: string, votes: number } } = {}
	for candidateId, votes in pairs(round1Votes) do
		table.insert(ordered, { candidateId = candidateId, votes = votes })
	end
	table.sort(ordered, function(a, b)
		return a.votes > b.votes
	end)

	local qualify = registeredRollRound2QualifierIds(ordered, registered)
	local round2Ballots = eliminateNonQualifiers(ballots, config, qualify)
	local round2Votes = RoundManager.getRoundVotes(round2Ballots)

	local winnerId: string?
	local maxV = -1
	for candidateId, v in pairs(round2Votes) do
		if v > maxV then
			maxV = v
			winnerId = candidateId
		end
	end

	if not winnerId and #ordered > 0 then
		winnerId = ordered[1].candidateId
	end

	local qualifierIds: { string } = {}
	for id, q in pairs(qualify) do
		if q then
			table.insert(qualifierIds, id)
		end
	end

	return {
		winner = { candidateId = winnerId or "" } :: any,
		voteShare = round2Votes,
		roundHistory = {
			style = "RegisteredRoll",
			registeredVoters = registered,
			decidedInRound1 = false,
			round1VoteShare = round1Votes,
			round2VoteShare = round2Votes,
			round2QualifierIds = qualifierIds,
		},
	}
end

local function classicTwoRound(ballots: { Types.Ballot }, config: Types.ElectionConfig): Types.WinnerResult
	local threshold = config.runoffThreshold
	local round1Votes = RoundManager.getRoundVotes(ballots)
	local totalVotes = #ballots

	for candidateId, votes in pairs(round1Votes) do
		local percentage = if totalVotes > 0 then (votes / totalVotes) * 100 else 0
		if percentage >= threshold then
			return {
				winner = { candidateId = candidateId } :: any,
				voteShare = round1Votes,
			}
		end
	end

	local topTwo: { { candidateId: string, votes: number } } = {}
	for candidateId, votes in pairs(round1Votes) do
		table.insert(topTwo, { candidateId = candidateId, votes = votes })
	end
	table.sort(topTwo, function(a, b)
		return a.votes > b.votes
	end)

	if #topTwo == 0 then
		local fallback = config.candidates[1]
		return {
			winner = if fallback then ({ candidateId = fallback.candidateId } :: any) else ({ candidateId = "" } :: any),
			voteShare = round1Votes,
		}
	end

	if #topTwo < 2 then
		return {
			winner = { candidateId = topTwo[1].candidateId } :: any,
			voteShare = round1Votes,
		}
	end

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

function TwoRound.calculateWinner(
	ballots: { Types.Ballot },
	config: Types.ElectionConfig,
	countContext: Types.ResultCountContext?
): Types.WinnerResult
	local style = config.twoRoundStyle
	if style == "RegisteredRoll" then
		local registered = getRegisteredVoters(config, countContext)
		if registered then
			return registeredRollTwoRound(ballots, config, registered)
		end
	end
	return classicTwoRound(ballots, config)
end

function TwoRound.validateBallot(ballot: Types.Ballot, config: Types.ElectionConfig): { valid: boolean, reason: string }
	-- Registered-roll first round is a single vote (one candidate). Classic two-round uses full rankings.
	if config.twoRoundStyle == "RegisteredRoll" then
		if #ballot < 1 or not ballot[1] or not ballot[1].candidateId then
			return { valid = false, reason = "Select one candidate" }
		end
		return { valid = true, reason = "Valid ballot" }
	end

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
