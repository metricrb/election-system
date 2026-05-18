return function(_context, target: Player)
	local electionManager = require(script.Parent.Parent.ElectionManagerRequire)()
	return electionManager:invalidateVoteByUserId(target.UserId)
end
