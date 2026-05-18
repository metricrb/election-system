return function(_context)
	local electionManager = require(script.Parent.Parent.ElectionManagerRequire)()
	local votes = electionManager:getMergedVoteRecords()
	print("[Cmdr] election_votes", votes)
	return ("Printed %d vote records."):format(#votes)
end
