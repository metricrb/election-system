--!strict

local Signal = require(script.Parent.Parent.Signal)
local Types = require(script.Parent.Types)
local Settings = require(script.Parent.Parent.Settings)
local Store = require(script.Parent.Store)

--[[
	@class AltDetector
	@within ElectionSystem

	Detects suspicious accounts post-vote. Supports three heuristics:
	- "age": flag if account age < minAccountAgeDays
	- "rapid": flag if vote within X seconds of previous vote
	- "both": flag if either condition met

	Outcomes:
	- KickWithScreen: fires event, client shows countdown, BanAPI called
	- InvalidateVote: silently removes vote from results, logs flag
	- Disabled: no action
]]

local AltDetector = {}

export type AltDetector = {
	detect: (store: Store, userId: string, player: Player) -> Types.AltFlagResult,
	AltDetected: Signal.Signal<string>,
}

local AltDetected = Signal.new()

--[[
	@function detect
	@within AltDetector
	@param store Store
	@param userId string
	@param player Player
	@return AltFlagResult

	Analyzes player account for suspicious behavior based on configured heuristic.
]]
function AltDetector.detect(store: Store, userId: string, player: Player): Types.AltFlagResult
	if not Settings.altDetection.enabled then
		return {
			flagged = false,
			reason = "Alt detection disabled",
			shouldKick = false,
			shouldInvalidate = false,
		}
	end

	local heuristic = Settings.altDetection.heuristic
	local flagged = false
	local reason = ""

	-- Check account age heuristic
	if heuristic == "age" or heuristic == "both" then
		if player.AccountAge < Settings.eligibility.minAccountAgeDays then
			flagged = true
			reason = "Account age below minimum (" .. tostring(player.AccountAge) .. " days)"
		end
	end

	-- Check rapid voting heuristic
	if heuristic == "rapid" or heuristic == "both" then
		local voteRecord = store:getVoteRecord(userId)
		if voteRecord then
			local timeSinceLastVote = os.time() - voteRecord.timestamp
			if timeSinceLastVote < Settings.altDetection.rapidVoteThresholdSeconds then
				flagged = true
				reason = "Rapid voting detected (" .. tostring(timeSinceLastVote) .. "s since last vote)"
			end
		end
	end

	if not flagged then
		store:logAltDetection(userId, false)
		return {
			flagged = false,
			reason = "No suspicious activity detected",
			shouldKick = false,
			shouldInvalidate = false,
		}
	end

	-- Account flagged - log and determine action
	store:logAltDetection(userId, true)
	AltDetected:fire(userId)

	return {
		flagged = true,
		reason = reason,
		shouldKick = Settings.altDetection.onDetect == "KickWithScreen",
		shouldInvalidate = Settings.altDetection.onDetect == "InvalidateVote",
	}
end

return AltDetector
