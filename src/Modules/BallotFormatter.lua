--!strict

local Types = require(script.Parent.Types)

--[[
	@class BallotFormatter
	@within ElectionSystem

	Converts election config to ballot template for UI rendering.
	Specifies input method (buttons, sliders, drag-to-rank) per voting method.
]]

local BallotFormatter = {}

--[[
	@function format
	@within BallotFormatter
	@param votingMethod string
	@param candidates { Types.Candidate }
	@param parties { Types.Party }
	@return Types.BallotTemplate
]]
function BallotFormatter.format(votingMethod: string, candidates: { Types.Candidate }, parties: { Types.Party }): Types.BallotTemplate
	if votingMethod == "FPTP" or votingMethod == "Approval" then
		return {
			votingMethod = votingMethod,
			candidates = candidates,
			parties = parties,
			maxSelections = if votingMethod == "FPTP" then 1 else #candidates,
			minSelections = 1,
			allowRanking = false,
			allowScoring = false,
			allowApproval = votingMethod == "Approval",
			dualBallot = false,
		}
	elseif votingMethod == "Score" or votingMethod == "STAR" or votingMethod == "Cumulative" then
		return {
			votingMethod = votingMethod,
			candidates = candidates,
			parties = parties,
			maxSelections = #candidates,
			minSelections = #candidates,
			allowRanking = false,
			allowScoring = true,
			allowApproval = false,
			scoreRange = { min = 0, max = 5 },
			dualBallot = false,
		}
	elseif votingMethod == "IRV" or votingMethod == "STV" or votingMethod == "Condorcet" or votingMethod == "Borda" then
		return {
			votingMethod = votingMethod,
			candidates = candidates,
			parties = parties,
			maxSelections = #candidates,
			minSelections = 1,
			allowRanking = true,
			allowScoring = false,
			allowApproval = false,
			dualBallot = false,
		}
	elseif votingMethod == "PartyListPR" then
		return {
			votingMethod = votingMethod,
			candidates = candidates,
			parties = parties,
			maxSelections = 1,
			minSelections = 1,
			allowRanking = false,
			allowScoring = false,
			allowApproval = false,
			dualBallot = false,
			partyBallot = parties,
		}
	elseif votingMethod == "MMP" or votingMethod == "Parallel" then
		return {
			votingMethod = votingMethod,
			candidates = candidates,
			parties = parties,
			maxSelections = 2,
			minSelections = 2,
			allowRanking = false,
			allowScoring = false,
			allowApproval = false,
			dualBallot = true,
			partyBallot = parties,
		}
	elseif votingMethod == "TwoRound" then
		return {
			votingMethod = votingMethod,
			candidates = candidates,
			parties = parties,
			maxSelections = 2,
			minSelections = 2,
			allowRanking = true,
			allowScoring = false,
			allowApproval = false,
			dualBallot = false,
		}
	else
		return {
			votingMethod = votingMethod,
			candidates = candidates,
			parties = parties,
			maxSelections = 1,
			minSelections = 1,
			allowRanking = false,
			allowScoring = false,
			allowApproval = false,
			dualBallot = false,
		}
	end
end

return BallotFormatter
