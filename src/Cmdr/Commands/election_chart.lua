return {
	Name = "election_chart";
	Description = "Set results board chart mode.";
	Group = "ElectionAdmin";
	Args = {
		{
			Type = "string";
			Name = "mode";
			Description = "Chart mode: bar or pie";
		},
	};
}
