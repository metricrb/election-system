--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local New = Fusion.New

return function(props)
	props = props or {}
	return New("Frame") {
		Name = "ScoredBallot",
		BackgroundColor3 = props.backgroundColor3 or Color3.fromRGB(35, 35, 40),
		BorderSizePixel = 0,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position or UDim2.fromScale(0, 0),
		Visible = if props.visible == nil then true else props.visible,
		[Fusion.Children] = {
			New("TextLabel") {
				Name = "Label",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Font = Enum.Font.GothamSemibold,
				Text = props.text or "ScoredBallot",
				TextColor3 = Color3.fromRGB(245, 245, 245),
				TextScaled = true,
			},
		},
	}
end
