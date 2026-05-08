--!strict

local Signal = require(script.Parent.Parent.Signal)
local Types = require(script.Parent.Types)
local Settings = require(script.Parent.Parent.Settings)
local Store = require(script.Parent.Store)
local Diagnostics = require(script.Parent.ElectionDiagnostics)

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
	detect: (store: Store, userId: string, player: Player, priorVoteRecord: Types.VoteRecord?) -> Types.AltFlagResult,
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
function AltDetector.detect(
	store: Store,
	userId: string,
	player: Player,
	priorVoteRecord: Types.VoteRecord?
): Types.AltFlagResult
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

	-- Compare time since a *prior* ballot only — post-record checks read the new vote and delta is ~0s.
	if (heuristic == "rapid" or heuristic == "both") and priorVoteRecord then
		local timeSinceLastVote = os.time() - priorVoteRecord.timestamp
		if timeSinceLastVote < Settings.altDetection.rapidVoteThresholdSeconds then
			flagged = true
			reason = "Rapid voting detected (" .. tostring(timeSinceLastVote) .. "s since last vote)"
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

	local shouldKick = Settings.altDetection.onDetect == "KickWithScreen"
	local shouldInvalidate = Settings.altDetection.onDetect == "InvalidateVote"
	Diagnostics.log(
		("ALT FLAG userId=%s reason=%s onDetect=%s shouldKick=%s shouldInvalidate=%s (Ban/Kick UI is client; no Roblox BanService call in this package)"):format(
			userId,
			reason,
			tostring(Settings.altDetection.onDetect),
			tostring(shouldKick),
			tostring(shouldInvalidate)
		)
	)

	return {
		flagged = true,
		reason = reason,
		shouldKick = shouldKick,
		shouldInvalidate = shouldInvalidate,
	}
end

return AltDetector
