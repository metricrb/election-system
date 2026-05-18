return {
	Name = "election_invalidate_vote";
	Description = "Remove a voter's ballot from this server, their profile, and the global tally.";
	Group = "ElectionAdmin";
	Args = {
		{
			Type = "integer";
			Name = "userId";
			Description = "Numeric Roblox UserId (works even if player is offline)";
		},
	};
}
