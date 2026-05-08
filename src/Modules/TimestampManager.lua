--!strict

local Signal = require(script.Parent.Parent.Signal)
local Types = require(script.Parent.Types)
local Settings = require(script.Parent.Parent.Settings)

--[[
	@class TimestampManager
	@within ElectionSystem

	Manages election phases based on the current time (os.time()).
	Broadcasts PhaseChanged signal when phase transitions occur.
]]

local TimestampManager = {}
TimestampManager.__index = TimestampManager

--[[
	@function new
	@within TimestampManager
	@return TimestampManager

	Creates a new TimestampManager instance.
]]
function TimestampManager.new(): any
	local self = setmetatable({}, TimestampManager) :: any
	self._lastPhaseTime = os.time()
	self.PhaseChanged = Signal.new()
	self._currentPhase = (self :: any):_derivePhase() :: Types.ElectionPhase

	-- Start heartbeat monitor
	task.spawn(function()
		while true do
			task.wait(1)
			local newPhase = self:_derivePhase()
			if newPhase ~= self._currentPhase then
				self._currentPhase = newPhase
				self.PhaseChanged:fire(newPhase)
			end
		end
	end)

	return self
end

--[[
	@method _derivePhase
	@within TimestampManager
	@private
	@return ElectionPhase

	Derives the current election phase from os.time().
]]
function TimestampManager:_derivePhase(): Types.ElectionPhase
	local now = os.time()
	local openAt = Settings.openAt
	local closeAt = Settings.closeAt

	if now < openAt then
		return "Scheduled"
	elseif now >= openAt and now < closeAt then
		return "Open"
	elseif now >= closeAt then
		-- TODO: determine if ResultsOut, Coalition, or Formed based on calculation state
		return "ResultsOut"
	end

	return "Scheduled"
end

--[[
	@method getPhase
	@within TimestampManager
	@return ElectionPhase

	Returns the current election phase.
]]
function TimestampManager:getPhase(): Types.ElectionPhase
	-- Always derive from wall clock so API/state are not up to one heartbeat behind.
	return self:_derivePhase()
end

--[[
	@method getCountdown
	@within TimestampManager
	@return number

	Returns seconds until the next phase transition.
	- If Scheduled: seconds until openAt
	- If Open: seconds until closeAt
	- If Closed: 0
]]
function TimestampManager:getCountdown(): number
	local now = os.time()
	local phase = self:getPhase()

	if phase == "Scheduled" then
		return math.max(0, Settings.openAt - now)
	elseif phase == "Open" then
		return math.max(0, Settings.closeAt - now)
	else
		return 0
	end
end

--[[
	@method isOpen
	@within TimestampManager
	@return boolean

	Returns true if election is currently open for voting.
]]
function TimestampManager:isOpen(): boolean
	return self:getPhase() == "Open"
end

--[[
	@method isClosed
	@within TimestampManager
	@return boolean

	Returns true if election is closed (voting has ended).
]]
function TimestampManager:isClosed(): boolean
	local phase = self:getPhase()
	return phase == "Closed" or phase == "ResultsOut" or phase == "Coalition" or phase == "Formed"
end

return TimestampManager
