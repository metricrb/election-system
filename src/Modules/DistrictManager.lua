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
	-- TODO: implement district assignment logic
	return Settings.districts[1]
end

function DistrictManager.getDistrictVotes(districtId: string): { Types.VoteRecord }
	-- TODO: filter votes by district
	return {}
end

return DistrictManager
