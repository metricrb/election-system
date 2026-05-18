--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(script.Parent.Parent.Settings)
local Signal = require(script.Parent.Parent.Signal)
local Cmdr = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Cmdr"))

local CmdrSetup = {}

local chartMode = "bar"
local chartModeChanged = Signal.new()

local function canRun(player: Player): boolean
	local cfg = Settings.cmdr
	if cfg.adminGroupId <= 0 then
		return true
	end
	return player:GetRankInGroup(cfg.adminGroupId) >= cfg.adminMinRank
end

function CmdrSetup.getChartMode(): string
	return chartMode
end

function CmdrSetup.connectChartModeChanged(callback: () -> ())
	return chartModeChanged:connect(callback)
end

function CmdrSetup.register(electionManager)
	Cmdr.Registry:RegisterDefaultCommands()

	local commandsFolder = script:FindFirstChild("Commands")
	if not commandsFolder then
		local electionSystem = game:GetService("ServerScriptService"):WaitForChild("ElectionSystem", 5)
		local cmdrFolder = electionSystem and electionSystem:FindFirstChild("Cmdr")
		commandsFolder = cmdrFolder and cmdrFolder:FindFirstChild("Commands")
	end

	if commandsFolder then
		Cmdr.Registry:RegisterCommandsIn(commandsFolder)
	else
		warn("[CmdrSetup] Commands folder not found; custom election commands were not registered.")
	end

	Cmdr.Registry:RegisterHook("BeforeRun", function(context)
		if context.Group ~= "ElectionAdmin" then
			return
		end

		local executor = context.Executor
		if not executor or not canRun(executor) then
			return "You are not allowed to run election admin commands."
		end
	end)

	Cmdr.Registry:RegisterHook("AfterRun", function(context)
		if context.Name == "election_chart" then
			-- Cmdr ArgumentContext uses :GetValue(), not .Value; Response is the server return (normalized mode).
			local newMode: string? = nil
			local resp = context.Response
			if type(resp) == "string" then
				local r = string.lower(resp :: string)
				if r == "bar" or r == "pie" then
					newMode = r
				end
			end
			if not newMode then
				local arg1 = context:GetArgument(1)
				if arg1 then
					local v = arg1:GetValue()
					if type(v) == "string" then
						local r = string.lower(v)
						if r == "bar" or r == "pie" then
							newMode = r
						end
					end
				end
			end
			if not newMode and type(context.RawArguments) == "table" and context.RawArguments[1] then
				local r = string.lower(tostring(context.RawArguments[1]))
				if r == "bar" or r == "pie" then
					newMode = r
				end
			end
			if newMode then
				chartMode = newMode
				chartModeChanged:fire()
			end
		elseif context.Name == "election_reset" then
			electionManager:resetAllVoteDataForCmd()
		end
	end)
end

return CmdrSetup
