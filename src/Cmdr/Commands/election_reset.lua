return {
	Name = "election_reset";
	Description = "Clear all vote records and cached election state.";
	Group = "ElectionAdmin";
	Args = {
		{
			Type = "string";
			Name = "confirm";
			Description = "Must be 'confirm'";
		},
	};
}
