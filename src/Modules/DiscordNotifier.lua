--!strict

--[=[
	@class DiscordNotifier
	@tag Server Integration

	Posts admin-only Discord webhook messages (server-side). Configure in `Settings.discord`.

	Requires HttpService HTTP requests enabled in Game Settings.

	See Discord webhook payload reference: developers/docs/resources/webhook (Discord API docs).
]=]

local HttpService = game:GetService("HttpService")

local Settings = require(script.Parent.Parent.Settings)
local Types = require(script.Parent.Types)

local DiscordNotifier = {}

local MAX_DESC = 1800

local function settings(): Types.DiscordWebhookConfig
	return Settings.discord
end

local function configured(): boolean
	local cfg = settings()
	if not cfg or not cfg.enabled then
		return false
	end
	local url = cfg.webhookUrl
	if type(url) ~= "string" or url == "" then
		return false
	end
	return string.match(url, "^https://discord%.com/api/webhooks/%d+/[^%s?#]+$") ~= nil
		or string.match(url, "^https://discordapp%.com/api/webhooks/%d+/[^%s?#]+$") ~= nil
end

local function trimDescription(s: string): string
	if #s <= MAX_DESC then
		return s
	end
	return string.sub(s, 1, MAX_DESC - 3) .. "..."
end

local function formatBallot(ballot: Types.Ballot): string
	local parts = {}
	for _, e in ipairs(ballot) do
		local seg = e.candidateId
		if e.rank ~= nil then
			seg ..= (" rank=%s"):format(tostring(e.rank))
		end
		if e.score ~= nil then
			seg ..= (" score=%s"):format(tostring(e.score))
		end
		if e.approved ~= nil then
			seg ..= (" approved=%s"):format(tostring(e.approved))
		end
		table.insert(parts, seg)
	end
	return table.concat(parts, "; ")
end

local function post(title: string, description: string, color: number)
	if not configured() then
		return
	end
	local cfg = settings()
	local body = {
		username = (cfg.botUsername ~= "" and cfg.botUsername) or nil,
		embeds = {
			{
				title = title,
				description = trimDescription(description),
				color = color,
			},
		},
	}
	local ok, err = pcall(function()
		HttpService:PostAsync(
			cfg.webhookUrl,
			HttpService:JSONEncode(body),
			Enum.HttpContentType.ApplicationJson,
			false
		)
	end)
	if not ok then
		warn("[DiscordNotifier] Webhook post failed: " .. tostring(err))
	end
end

function DiscordNotifier.notifyVoteRecorded(player: Player, ballot: Types.Ballot, districtId: string?)
	local cfg = settings()
	if not cfg or not cfg.notifyVoteRecorded then
		return
	end
	local dist = districtId and (" | district=%s"):format(districtId) or ""
	post(
		"Vote recorded",
		table.concat({
			("**Election:** %s"):format(Settings.countryId),
			("**Player:** %s (`%s`)"):format(player.Name, tostring(player.UserId)),
			("**Method:** %s"):format(Settings.votingMethod),
			("**Ballot:** %s"):format(formatBallot(ballot)),
		}, "\n") .. dist,
		0x2ecc71
	)
end

function DiscordNotifier.notifyVoteDenied(player: Player, kind: string, detail: string)
	local cfg = settings()
	if not cfg or not cfg.notifyVoteDenied then
		return
	end
	post(
		"Vote denied",
		table.concat({
			("**Election:** %s"):format(Settings.countryId),
			("**Player:** %s (`%s`)"):format(player.Name, tostring(player.UserId)),
			("**Reason:** %s"):format(kind),
			trimDescription(detail),
		}, "\n"),
		0xe74c3c
	)
end

function DiscordNotifier.notifyAltDetection(player: Player, altReason: string, outcome: "invalidated" | "kick")
	local cfg = settings()
	if not cfg or not cfg.notifyAltFlag then
		return
	end
	post(
		"Alt detection",
		table.concat({
			("**Election:** %s"):format(Settings.countryId),
			("**Player:** %s (`%s`)"):format(player.Name, tostring(player.UserId)),
			("**Signal:** %s"):format(trimDescription(altReason)),
			("**Outcome:** %s"):format(outcome),
		}, "\n"),
		0xf1c40f
	)
end

function DiscordNotifier.notifyElectionPhase(newPhase: Types.ElectionPhase)
	local cfg = settings()
	if not cfg or not cfg.notifyPhaseChanges then
		return
	end
	post(
		"Election phase",
		table.concat({
			("**Election:** %s"):format(Settings.countryId),
			("**Phase:** %s"):format(newPhase),
		}, "\n"),
		0x3498db
	)
end

return DiscordNotifier
