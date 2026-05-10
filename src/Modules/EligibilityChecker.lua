--!strict

local Types = require(script.Parent.Types)
local Settings = require(script.Parent.Parent.Settings)
local Diagnostics = require(script.Parent.ElectionDiagnostics)

--[=[
	@class EligibilityChecker

	Checks voter eligibility based on configured rules:
	- Banned usernames (case-insensitive)
	- Banned groups (any rank > 0)
	- Minimum group rank (if enabled)
	- Minimum account age (if enabled)

	First failing check returns its reason; all pass = eligible.
]=]

local EligibilityChecker = {}

--[=[
	@function check
	@within EligibilityChecker
	@param player Player
	@return EligibilityResult

	Checks if a player is eligible to vote. Returns result with eligible flag and reason string.
]=]
function EligibilityChecker.check(player: Player): Types.EligibilityResult
	local config = Settings.eligibility

	-- Check 1: Banned usernames (case-insensitive)
	for _, bannedName in ipairs(config.bannedUsernames) do
		if string.lower(player.Name) == string.lower(bannedName) then
			Diagnostics.log(
				("ELIGIBILITY deny user=%s reason=BANNED_USERNAME match=%s"):format(player.Name, bannedName)
			)
			return {
				eligible = false,
				reason = "Your username is on the banned list.",
			}
		end
	end

	-- Check 2: Banned groups (any membership rank > 0)
	for _, bannedGroupId in ipairs(config.bannedGroupIds) do
		local rank = player:GetRankInGroup(bannedGroupId)
		if rank > 0 then
			Diagnostics.log(
				("ELIGIBILITY deny user=%s reason=BANNED_GROUP groupId=%s rank=%s"):format(
					player.Name,
					tostring(bannedGroupId),
					tostring(rank)
				)
			)
			return {
				eligible = false,
				reason = "Your group membership disqualifies you from voting.",
			}
		end
	end

	-- Check 3: Minimum group rank (if enabled)
	if config.minGroupRank.groupId > 0 then
		local rank = player:GetRankInGroup(config.minGroupRank.groupId)
		if rank < config.minGroupRank.minRank then
			Diagnostics.log(
				("ELIGIBILITY deny user=%s reason=MIN_GROUP_RANK need=%s have=%s"):format(
					player.Name,
					tostring(config.minGroupRank.minRank),
					tostring(rank)
				)
			)
			return {
				eligible = false,
				reason = "You do not meet the minimum group rank requirement.",
			}
		end
	end

	-- Check 4: Minimum account age (if enabled)
	if config.minAccountAgeDays > 0 then
		local accountAgeDays = player.AccountAge
		if accountAgeDays < config.minAccountAgeDays then
			Diagnostics.log(
				("ELIGIBILITY deny user=%s reason=MIN_ACCOUNT_AGE needDays=%s haveDays=%s"):format(
					player.Name,
					tostring(config.minAccountAgeDays),
					tostring(accountAgeDays)
				)
			)
			return {
				eligible = false,
				reason = "Your account is too new. Minimum age: " .. tostring(config.minAccountAgeDays) .. " days.",
			}
		end
	end

	-- All checks passed
	return {
		eligible = true,
		reason = "Eligible to vote.",
	}
end

return EligibilityChecker
