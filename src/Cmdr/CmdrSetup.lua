--!strict

local Settings = require(script.Parent.Parent.Settings)

local CmdrSetup = {}

local chartMode = "bar"

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

function CmdrSetup.register(electionManager)
	game:GetService("Players").PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			if not canRun(player) then
				return
			end

			if message == "!election_results" then
				print("[Cmdr] election_results", electionManager:getResults())
			elseif message == "!election_votes" then
				print("[Cmdr] election_votes", electionManager:getStore():getAllVotes())
			elseif message == "!election_reset confirm" then
				electionManager:getStore():clear()
				print("[Cmdr] election_reset complete")
			elseif message == "!election_chart pie" then
				chartMode = "pie"
				print("[Cmdr] chart mode set to pie")
			elseif message == "!election_chart bar" then
				chartMode = "bar"
				print("[Cmdr] chart mode set to bar")
			end
		end)
	end)
end

return CmdrSetup
