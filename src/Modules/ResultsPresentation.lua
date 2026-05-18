--!strict

--[=[
	@class ResultsPresentation

	Shared sorting and text formatting for election results (Cmdr + SurfaceGui board).
]=]

local Types = require(script.Parent.Types)
local Settings = require(script.Parent.Parent.Settings)
local Store = require(script.Parent.Store)
local ResultCalculator = require(script.Parent.ResultCalculator)

export type ResultRow = {
	candidateId: string,
	label: string,
	pct: number,
	partyId: string?,
}

local function candidateIndexById(candidates: { Types.Candidate }): { [string]: Types.Candidate }
	local map: { [string]: Types.Candidate } = {}
	for _, c in ipairs(candidates) do
		map[c.candidateId] = c
	end
	return map
end

local function constituencyIdFromCandidate(candidate: Types.Candidate): string?
	for _, tag in ipairs(candidate.policyTags) do
		local prefix = "constituency:"
		if string.sub(tag, 1, #prefix) == prefix then
			return string.sub(tag, #prefix + 1)
		end
	end
	return nil
end

local function candidateIdsForConstituency(candidates: { Types.Candidate }, districtId: string): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, c in ipairs(candidates) do
		if constituencyIdFromCandidate(c) == districtId then
			set[c.candidateId] = true
		end
	end
	return set
end

--[=[
	@function sortedRows
	@within ResultsPresentation
	Returns vote-share rows sorted by percentage descending.
]=]
function sortedRows(results: Types.ElectionResult, candidates: { Types.Candidate }): { ResultRow }
	local byId = candidateIndexById(candidates)
	local rows: { ResultRow } = {}
	for candidateId, pct in pairs(results.voteShare) do
		local cand = byId[candidateId]
		table.insert(rows, {
			candidateId = candidateId,
			label = if cand then cand.name else candidateId,
			pct = pct,
			partyId = cand and cand.partyId or nil,
		})
	end
	table.sort(rows, function(a, b)
		if a.pct ~= b.pct then
			return a.pct > b.pct
		end
		return a.label < b.label
	end)
	return rows
end

--[=[
	@function sortedRowsForConstituency
	@within ResultsPresentation

	Like `sortedRows`, but only candidates standing in the given constituency (policy tag `constituency:<districtId>`).
]=]
function sortedRowsForConstituency(
	results: Types.ElectionResult,
	candidates: { Types.Candidate },
	districtId: string
): { ResultRow }
	local allow = candidateIdsForConstituency(candidates, districtId)
	local byId = candidateIndexById(candidates)
	local rows: { ResultRow } = {}
	for candidateId, pct in pairs(results.voteShare) do
		if allow[candidateId] then
			local cand = byId[candidateId]
			table.insert(rows, {
				candidateId = candidateId,
				label = if cand then cand.name else candidateId,
				pct = pct,
				partyId = cand and cand.partyId or nil,
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.pct ~= b.pct then
			return a.pct > b.pct
		end
		return a.label < b.label
	end)
	return rows
end

--[=[
	@function constituencyMetaLine
	@within ResultsPresentation

	Human-readable line: ballots cast; registered roll shown only as legal context (not as % denominator).
]=]
function constituencyMetaLine(districtDisplayName: string, results: Types.ElectionResult): string
	local rh: any = results.roundHistory
	local rollNote = ""
	if type(rh) == "table" and type(rh.registeredVoters) == "number" and rh.registeredVoters > 0 then
		rollNote = string.format(" · %d registered on roll (thresholds only)", rh.registeredVoters)
	elseif results.eligibleVoters ~= results.votesRecorded and results.eligibleVoters > 0 then
		rollNote = string.format(" · %d reference roll (not vote-share denominator)", results.eligibleVoters)
	end
	return string.format(
		"%s · Phase %s · %d ballots cast — shares are %% of votes cast%s",
		districtDisplayName,
		results.phase,
		results.votesRecorded,
		rollNote
	)
end

-- Synthetic zero-ballot result for a constituency; matches `ResultCalculator.calculate` shape for that district.
local function placeholderDistrictResult(districtId: string, nationalPhase: Types.ElectionPhase): Types.ElectionResult
	local dr = ResultCalculator.calculate(Settings.votingMethod, {}, Store.new(), { districtId = districtId })
	local mutable = dr :: any
	mutable.phase = nationalPhase
	return dr
end

--[=[
	@function formatText
	@within ResultsPresentation
	Multi-line summary for Cmdr or logs.
]=]
function formatText(results: Types.ElectionResult, candidates: { Types.Candidate }): string
	local lines = {}
	local drAny = (results :: any).districtResults :: { [string]: Types.ElectionResult }?
	if drAny and next(drAny) ~= nil then
		table.insert(lines, string.format(
			"National aggregate — Phase: %s | All districts votes recorded: %d (not a legal constituency tally)",
			results.phase,
			results.votesRecorded
		))
		table.insert(lines, "--- By constituency ---")
		for _, d in ipairs(Settings.districts) do
			local dr = drAny[d.districtId] or placeholderDistrictResult(d.districtId, results.phase)
			table.insert(lines, constituencyMetaLine(d.name, dr))
			local sub = sortedRowsForConstituency(dr, candidates, d.districtId)
			if #sub == 0 then
				table.insert(lines, "  (no votes yet)")
			else
				for rank, row in ipairs(sub) do
					table.insert(lines, string.format("  %d. %s — %.1f%%", rank, row.label, row.pct))
				end
			end
		end
		for districtId, dr in pairs(drAny) do
			local known = false
			for _, d in ipairs(Settings.districts) do
				if d.districtId == districtId then
					known = true
					break
				end
			end
			if not known then
				table.insert(lines, constituencyMetaLine(districtId, dr))
				local sub = sortedRowsForConstituency(dr, candidates, districtId)
				for rank, row in ipairs(sub) do
					table.insert(lines, string.format("  %d. %s — %.1f%%", rank, row.label, row.pct))
				end
			end
		end
		return table.concat(lines, "\n")
	end

	local rows = sortedRows(results, candidates)
	table.insert(
		lines,
		string.format("Phase: %s | Ballots cast: %d", results.phase, results.votesRecorded)
	)
	local rhTop: any = results.roundHistory
	if type(rhTop) == "table" and type(rhTop.registeredVoters) == "number" and rhTop.registeredVoters > 0 then
		table.insert(
			lines,
			string.format(
				"Registered on roll: %d (legal thresholds only — not used as vote-share denominator)",
				rhTop.registeredVoters
			)
		)
	elseif results.eligibleVoters > 0 and results.eligibleVoters ~= results.votesRecorded then
		table.insert(
			lines,
			string.format(
				"Config/reference electorate: %d (percentages below are of ballots cast)",
				results.eligibleVoters
			)
		)
	end
	if #rows == 0 then
		table.insert(lines, "(No vote share entries)")
	else
		for rank, row in ipairs(rows) do
			table.insert(lines, string.format("%d. %s — %.1f%%", rank, row.label, row.pct))
		end
	end
	return table.concat(lines, "\n")
end

return {
	sortedRows = sortedRows,
	sortedRowsForConstituency = sortedRowsForConstituency,
	constituencyMetaLine = constituencyMetaLine,
	formatText = formatText,
	placeholderDistrictResult = placeholderDistrictResult,
}
