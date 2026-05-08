--!strict

--[[
	Dark theme tokens aligned with Roblox Election UI design (Figma / shadcn dark palette).
	@within ElectionSystem
]]

local Theme = {}

Theme.Background = Color3.fromRGB(10, 14, 26)
Theme.Card = Color3.fromRGB(20, 24, 36)
Theme.Border = Color3.fromRGB(30, 41, 59)
Theme.Foreground = Color3.fromRGB(232, 237, 245)
Theme.Muted = Color3.fromRGB(30, 41, 59)
Theme.MutedForeground = Color3.fromRGB(148, 163, 184)
Theme.Primary = Color3.fromRGB(59, 130, 246)
Theme.PrimaryMuted = Color3.fromRGB(59, 130, 246)
Theme.Destructive = Color3.fromRGB(239, 68, 68)
Theme.Success = Color3.fromRGB(16, 185, 129)
Theme.Warning = Color3.fromRGB(245, 158, 11)
Theme.Backdrop = Color3.new(0, 0, 0)

function Theme.accentFromSettings(accent: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(accent.r, accent.g, accent.b)
end

return Theme
