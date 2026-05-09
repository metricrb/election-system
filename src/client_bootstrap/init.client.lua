--!strict

print("[ElectionClientBootstrap] Starting...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local cmdrClient = ReplicatedStorage:WaitForChild("CmdrClient", 5)
if cmdrClient then
	local okCmdr, cmdr = pcall(require, cmdrClient)
	if okCmdr and cmdr then
		cmdr:SetActivationKeys({ Enum.KeyCode.LeftControl })
		print("[ElectionClientBootstrap] CmdrClient initialized.")
	else
		warn("[ElectionClientBootstrap] CmdrClient failed to load.")
	end
else
	warn("[ElectionClientBootstrap] CmdrClient not found in ReplicatedStorage.")
end

local ok, err = pcall(function()
	local clientModules = script.Parent:WaitForChild("ClientModules")
	local electionClientModule = clientModules:WaitForChild("ElectionClient")
	local ElectionClient = require(electionClientModule)
	ElectionClient.init()
end)

if ok then
	print("[ElectionClientBootstrap] Initialized successfully.")
else
	warn("[ElectionClientBootstrap] Failed to initialize:", err)
end
