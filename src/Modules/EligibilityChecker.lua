--!strict

local Types = require(script.Parent.Types)
local Settings = require(script.Parent.Parent.Settings)
local Diagnostics = require(script.Parent.ElectionDiagnostics)

--[=[
	@class EligibilityChecker
	@tag Validation & Detection

	Validates voter eligibility based on configured rules.

	Checks are performed in order, and the first failing check is returned:
	1. **Banned Usernames** — Case-insensitive username blacklist
	2. **Banned Groups** — Membership in disqualifying groups (any rank > 0)
	3. **Minimum Group Rank** — Must have at least the configured rank in a specific group
	4. **Minimum Account Age** — Account must be at least N days old

	All checks must pass for a player to be eligible. Configuration is in Settings.eligibility.

	## Usage

	```lua
	local eligibility = ElectionManager:checkEligibility(player)
	if eligibility.eligible then
		print("Player can vote!")
	else
		print("Ineligible:", eligibility.reason)
	end
	```

	## Configuration

	In Settings.lua:
	```lua
	eligibility = {
		minGroupRank = { groupId = 12345, minRank = 1 },  -- optional
		minAccountAgeDays = 30,  -- optional
		bannedGroupIds = { 999, 1000 },
		bannedUsernames = { "BadActor", "BadActor2" },
	}
	```
]=]

local EligibilityChecker = {}

--[=[
	@function check
	@within EligibilityChecker
	@param player Player
	@return EligibilityResult

	Checks if a player is eligible to vote.

	Returns an EligibilityResult with:
	- `eligible` (boolean) — true if all checks pass
	- `reason` (string) — Human-readable explanation of any failure

	```lua
	local result = EligibilityChecker.check(player)
	if not result.eligible then
		player:Kick(result.reason)
	end
	```
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
