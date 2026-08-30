--!strict
-- Minimal synchronous event emitter (RBXScriptSignal-alike) used for
-- decoupling modules within a single VM (server-server or client-client).
-- This is NOT for client/server communication -- use Net.lua / RemoteEvents
-- for that. Kept dependency-free so the project does not require pulling
-- in a third-party package just to get a Signal type.

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = typeof(setmetatable(
	{} :: {
		_listeners: { (T...) -> () },
	},
	Signal
))

function Signal.new<T...>(): Signal<T...>
	return setmetatable({
		_listeners = {},
	}, Signal) :: any
end

function Signal.Connect<T...>(self: Signal<T...>, callback: (T...) -> ()): Connection
	local listeners = (self :: any)._listeners
	table.insert(listeners, callback)

	local connection = {
		Connected = true,
	}

	function connection.Disconnect(selfConn)
		if not selfConn.Connected then
			return
		end
		selfConn.Connected = false
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end

	return connection :: Connection
end

function Signal.Fire<T...>(self: Signal<T...>, ...: T...)
	-- Copy so a listener disconnecting mid-fire cannot mutate the array
	-- we're iterating.
	local listeners = table.clone((self :: any)._listeners)
	for _, callback in listeners do
		local ok, err = pcall(callback, ...)
		if not ok then
			warn("[Signal] listener error:", err)
		end
	end
end

return Signal
