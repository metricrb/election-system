return function(_context, mode)
	local normalized = string.lower(mode)
	if normalized ~= "bar" and normalized ~= "pie" then
		return "Mode must be 'bar' or 'pie'."
	end
	return normalized
end
