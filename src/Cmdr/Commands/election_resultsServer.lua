return function(_context)
	local electionRoot = script.Parent.Parent.Parent
	local ResultsPresentation = require(electionRoot.Modules.ResultsPresentation)
	local electionManager = require(script.Parent.Parent.ElectionManagerRequire)()
	-- Recalculate from DataStore-backed profiles + in-memory store (not stale session-only cache).
	local results = electionManager:calculateResults(false)
	local text = ResultsPresentation.formatText(results, electionManager.Settings.candidates)
	print("[Cmdr] election_results\n" .. text)
	return text
end
