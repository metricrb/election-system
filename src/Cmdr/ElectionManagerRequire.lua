--!strict

--[[
	Resolves `ServerScriptService.ElectionSystem` after sync/Rojo load.
	Cmdr commands run early; use WaitForChild instead of indexing `.ElectionSystem` directly.
]]

local ServerScriptService = game:GetService("ServerScriptService")

return function()
	local holder = ServerScriptService:WaitForChild("ElectionSystem", 30)
	if not holder then
		error("[ElectionSystem] ServerScriptService.ElectionSystem not found within 30s.")
	end
	if not holder:IsA("ModuleScript") then
		error("[ElectionSystem] ServerScriptService.ElectionSystem must be a ModuleScript.")
	end
	return require(holder :: ModuleScript)
end
