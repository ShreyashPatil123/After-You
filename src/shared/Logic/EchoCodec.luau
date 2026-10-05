--!strict
--[[
	Packs a recorded path into a buffer for one RemoteEvent send (MASTER_IMPLEMENTATION_PLAN §H).
	Layout:
	  u16 sampleCount, f32 sampleInterval, f32 quantum
	  per sample: i16 x, i16 y, i16 z, u8 yaw (0-255 => 0-2pi), u8 flags (bit0 flashlight on, bit1 running, bit2 crouching)
	  u16 actionCount
	  per action: u16 sampleIndex (1-based), u8 kind, u16 idLength, bytes id
	Positions are relative to the layout origin, quantised to `quantum` studs.
]]
export type Sample = { X: number, Y: number, Z: number, Yaw: number, Flags: number }
export type Action = { Index: number, Kind: number, Id: string }
export type Path = { Interval: number, Quantum: number, Samples: { Sample }, Actions: { Action } }

local EchoCodec = {}

EchoCodec.Flags = { Flashlight = 1, Running = 2, Crouching = 4 }
EchoCodec.ActionKind = { DoorOpen = 1, DoorClose = 2, Knock = 3, FlashOn = 4, FlashOff = 5, Pickup = 6 }

local TWO_PI = math.pi * 2
local SAMPLE_BYTES = 8

local function q(v: number, quantum: number): number
	return math.clamp(math.floor(v / quantum + 0.5), -32768, 32767)
end

function EchoCodec.Encode(path: Path): buffer
	local n = #path.Samples
	assert(n <= 65535, "too many samples")
	local size = 2 + 4 + 4 + n * SAMPLE_BYTES + 2
	for _, a in path.Actions do
		size += 2 + 1 + 2 + #a.Id
	end
	local b = buffer.create(size)
	local o = 0
	buffer.writeu16(b, o, n)
	o += 2
	buffer.writef32(b, o, path.Interval)
	o += 4
	buffer.writef32(b, o, path.Quantum)
	o += 4
	for _, s in path.Samples do
		buffer.writei16(b, o, q(s.X, path.Quantum))
		o += 2
		buffer.writei16(b, o, q(s.Y, path.Quantum))
		o += 2
		buffer.writei16(b, o, q(s.Z, path.Quantum))
		o += 2
		local yaw = s.Yaw % TWO_PI
		buffer.writeu8(b, o, math.floor(yaw / TWO_PI * 256) % 256)
		o += 1
		buffer.writeu8(b, o, s.Flags)
		o += 1
	end
	buffer.writeu16(b, o, #path.Actions)
	o += 2
	for _, a in path.Actions do
		buffer.writeu16(b, o, a.Index)
		o += 2
		buffer.writeu8(b, o, a.Kind)
		o += 1
		buffer.writeu16(b, o, #a.Id)
		o += 2
		buffer.writestring(b, o, a.Id)
		o += #a.Id
	end
	return b
end

function EchoCodec.Decode(b: buffer): Path
	local o = 0
	local n = buffer.readu16(b, o)
	o += 2
	local interval = buffer.readf32(b, o)
	o += 4
	local quantum = buffer.readf32(b, o)
	o += 4
	local samples = table.create(n)
	for i = 1, n do
		local x = buffer.readi16(b, o) * quantum
		o += 2
		local y = buffer.readi16(b, o) * quantum
		o += 2
		local z = buffer.readi16(b, o) * quantum
		o += 2
		local yaw = buffer.readu8(b, o) / 256 * TWO_PI
		o += 1
		local flags = buffer.readu8(b, o)
		o += 1
		samples[i] = { X = x, Y = y, Z = z, Yaw = yaw, Flags = flags }
	end
	local m = buffer.readu16(b, o)
	o += 2
	local actions = table.create(m)
	for i = 1, m do
		local idx = buffer.readu16(b, o)
		o += 2
		local kind = buffer.readu8(b, o)
		o += 1
		local len = buffer.readu16(b, o)
		o += 2
		local id = buffer.readstring(b, o, len)
		o += len
		actions[i] = { Index = idx, Kind = kind, Id = id }
	end
	return { Interval = interval, Quantum = quantum, Samples = samples, Actions = actions }
end

return EchoCodec
