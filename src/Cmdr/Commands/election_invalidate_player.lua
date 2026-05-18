return {
	Name = "election_invalidate_player";
	Description = "Same as election_invalidate_vote, but pick a Player (must be in-game).";
	Group = "ElectionAdmin";
	Args = {
		{
			Type = "player";
			Name = "player";
			Description = "Target player";
		},
	};
}
