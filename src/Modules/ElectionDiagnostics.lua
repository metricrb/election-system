--!strict

--[[
	Prefixed prints for MCP / Studio verification. Reads `Settings.testRunId` when set,
	otherwise `countryId`.
]]

local Settings = require(script.Parent.Parent.Settings)

local ElectionDiagnostics = {}

local function tag(): string
	local tr = (Settings :: any).testRunId
	if type(tr) == "string" and tr ~= "" then
		return tr
	end
	return Settings.countryId
end

function ElectionDiagnostics.log(message: string)
	print("[ElectionSystem:" .. tag() .. "] " .. message)
end

return ElectionDiagnostics
