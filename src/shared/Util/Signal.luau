--!nonstrict
-- Minimal synchronous signal. Handlers run in connection order; a disconnected handler never runs again.
export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} :: { any } }, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(fn)
	local conn: any
	conn = {
		Connected = true,
		_fn = fn,
		Disconnect = function(c)
			if not c.Connected then
				return
			end
			c.Connected = false
			local list = self._handlers
			local i = table.find(list, c)
			if i then
				table.remove(list, i)
			end
		end,
	}
	table.insert(self._handlers, conn)
	return conn
end

function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Fire(...)
	-- Copy so handlers may disconnect during dispatch.
	local snapshot = table.clone(self._handlers)
	for _, c in snapshot do
		if c.Connected then
			c._fn(...)
		end
	end
end

function Signal:DisconnectAll()
	for _, c in table.clone(self._handlers) do
		c:Disconnect()
	end
end

return Signal
