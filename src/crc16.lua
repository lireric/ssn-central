--local bit = require ("bit")
local bit32 = require ("bit32")

local POLY = 0x1021

function ccitt_16(str)
  local function hash(crc, byte)
    for i = 0, 7 do
      local lsb = bit32.extract(byte, 7 - i) -- Take the lsb
      local msb = bit32.extract(crc, 15, 1) -- msb
      crc = bit32.lshift(crc, 1) -- Remove the lsb of crc
      if bit32.bxor(lsb, msb) == 1 then crc = bit32.bxor(crc, POLY) end
    end
    return crc
  end

  local crc = 0xffff
  for i = 1, #str do
      crc = hash(crc, string.byte(str, i))
  end

  return bit32.extract(crc, 0, 16)
end
