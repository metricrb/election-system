--!strict

local RankableBallot = require(script.Parent.RankableBallot)
local ScoredBallot = require(script.Parent.ScoredBallot)
local ApprovalBallot = require(script.Parent.ApprovalBallot)
local PartyListBallot = require(script.Parent.PartyListBallot)
local DualBallot = require(script.Parent.DualBallot)

local rankedMethods = {
	IRV = true,
	STV = true,
	Condorcet = true,
	Borda = true,
}

local scoredMethods = {
	Score = true,
	STAR = true,
	Cumulative = true,
}

return function(props)
	props = props or {}
	local method = props.votingMethod or "FPTP"
	if rankedMethods[method] then
		return RankableBallot(props)
	elseif scoredMethods[method] then
		return ScoredBallot(props)
	elseif method == "Approval" then
		return ApprovalBallot(props)
	elseif method == "PartyListPR" then
		return PartyListBallot(props)
	elseif method == "MMP" or method == "Parallel" then
		return DualBallot(props)
	end
	return ApprovalBallot(props)
end
