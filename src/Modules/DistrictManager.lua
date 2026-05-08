--!strict

local Types = require(script.Parent.Types)
local Settings = require(script.Parent.Parent.Settings)

--[[
	@class DistrictManager
	@within ElectionSystem

	Routes votes by electoral district. Supports single-member, multi-member, at-large, federal.
]]

local DistrictManager = {}

function DistrictManager.getDistrict(player: Player): Types.District?
	if #Settings.districts == 0 then
		return nil
	end
	local explicitDistrictId = player:GetAttribute("DistrictId")
	if type(explicitDistrictId) == "string" then
		for _, district in ipairs(Settings.districts) do
			if district.districtId == explicitDistrictId then
				return district
			end
		end
	end

	local userBucket = (player.UserId % #Settings.districts) + 1
	return Settings.districts[userBucket]
end

function DistrictManager.getDistrictVotes(districtId: string, votes: { Types.VoteRecord }): { Types.VoteRecord }
	local filtered: { Types.VoteRecord } = {}
	for _, vote in ipairs(votes) do
		if vote.districtId == districtId then
			table.insert(filtered, vote)
		end
	end
	return filtered
end

return DistrictManager
