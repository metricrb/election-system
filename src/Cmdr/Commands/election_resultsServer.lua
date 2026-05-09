return function(context)
	local electionManager = require(script.Parent.Parent.ElectionManagerRequire)()
	local results = electionManager:getResults()
	if not results then
		return "No results available yet."
	end
	context:Reply("Election results fetched. See output for full table.")
	print("[Cmdr] election_results", results)
	return "Results printed."
end
