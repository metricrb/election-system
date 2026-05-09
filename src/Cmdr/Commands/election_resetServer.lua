return function(_context, confirm)
	if string.lower(confirm) ~= "confirm" then
		return "Use: election_reset confirm"
	end
	return "confirm"
end
