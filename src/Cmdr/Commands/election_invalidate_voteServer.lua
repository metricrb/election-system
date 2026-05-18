return function(_context, userId: number)
	local electionManager = require(script.Parent.Parent.ElectionManagerRequire)()
	return electionManager:invalidateVoteByUserId(userId)
end
