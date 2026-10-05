--!nonstrict
-- Fixed-capacity ring buffer. Index 1 = oldest retained item.
local RingBuffer = {}
RingBuffer.__index = RingBuffer

export type RingBuffer<T> = {
	Push: (self: RingBuffer<T>, item: T) -> (),
	Get: (self: RingBuffer<T>, i: number) -> T?,
	Size: (self: RingBuffer<T>) -> number,
	Capacity: number,
	Total: number, -- items ever pushed
}

function RingBuffer.new<T>(capacity: number): RingBuffer<T>
	assert(capacity >= 1, "capacity must be >= 1")
	local self = { _data = table.create(capacity), _head = 0, _count = 0, Capacity = capacity, Total = 0 }
	return (setmetatable(self, RingBuffer) :: any) :: RingBuffer<T>
end

function RingBuffer:Push(item)
	self._head = (self._head % self.Capacity) + 1
	self._data[self._head] = item
	if self._count < self.Capacity then
		self._count += 1
	end
	self.Total += 1
end

function RingBuffer:Size(): number
	return self._count
end

function RingBuffer:Get(i: number)
	if i < 1 or i > self._count then
		return nil
	end
	-- oldest index = head - count + 1 (wrapped)
	local idx = ((self._head - self._count + i - 1) % self.Capacity) + 1
	return self._data[idx]
end

return RingBuffer
