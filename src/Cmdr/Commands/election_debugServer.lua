return function(context)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local folder = ReplicatedStorage:WaitForChild("ElectionSystemRemotes", 10)
	if not folder then
		return "ElectionSystemRemotes folder missing."
	end
	local ev = folder:WaitForChild("DebugElectionToggle", 5)
	if not ev or not ev:IsA("RemoteEvent") then
		return "DebugElectionToggle remote missing."
	end
	local executor = context.Executor
	if not executor then
		return "No executor."
	end
	(ev :: RemoteEvent):FireClient(executor)
	return "Toggled election debug UI for you."
end
