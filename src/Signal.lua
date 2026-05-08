--!strict

--[[
	@class Signal
	@within ElectionSystem

	Simple event/signal system used throughout the election system.
	Provides .Connect() and .Fire() interface for broadcasting events.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
	disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	fire: (self: Signal<T...>, T...) -> (),
	wait: (self: Signal<T...>) -> T...,
	destroyConnections: (self: Signal<T...>) -> (),
	_connections: { (T...) -> () },
}

--[[
	@function new
	@within Signal
	@return Signal

	Creates a new signal.
]]
function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({}, Signal) :: any
	self._connections = {}
	return self
end

--[[
	@method connect
	@within Signal
	@param callback function -- Callback to invoke when signal fires
	@return Connection

	Connects a callback to the signal. Returns a connection object with a disconnect method.
]]
function Signal:connect<T...>(callback: (T...) -> ()): Connection
	local connection: any = {}

	function connection:disconnect()
		if self.Connected then
			self.Connected = false
			local idx = table.find(self._signal._connections, callback)
			if idx then
				table.remove(self._signal._connections, idx)
			end
		end
	end

	connection.Connected = true
	connection._signal = self
	table.insert(self._connections, callback)

	return connection
end

--[[
	@method fire
	@within Signal
	@param ... any -- Arguments to pass to connected callbacks

	Fires the signal, invoking all connected callbacks with the provided arguments.
]]
function Signal:fire<T...>(...)
	for _, callback in ipairs(self._connections) do
		task.spawn(callback, ...)
	end
end

--[[
	@method wait
	@within Signal
	@return ... any -- Arguments passed to fire()

	Waits for the signal to fire and returns the arguments.
]]
function Signal:wait<T...>(): T...
	local event = self:connect(function(...)
		event:disconnect()
	end)

	local success, result = coroutine.resume(coroutine.create(function()
		return script.Parent -- placeholder yield
	end))

	return ...
end

--[[
	@method destroyConnections
	@within Signal

	Disconnects all connected callbacks.
]]
function Signal:destroyConnections()
	for _, callback in ipairs(self._connections) do
		callback = nil
	end
	table.clear(self._connections)
end

return Signal
