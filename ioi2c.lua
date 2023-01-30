local ioi2c = {}

busid = 0  -- I2C Bus ID. Always zero
sda= 5     -- GPIO2 pin mapping is 4
scl= 4     -- GPIO0 pin mapping is 3
-- Seting up the I2C bus.
i2c.setup(busid,sda,scl,i2c.SLOW)

local function byte2bin(n)
local t = {}
  for i=7,0,-1 do
    t[#t+1] = math.floor(n / 2^i)
    n = n % 2^i
  end
  return t
end

function ioi2c.read()
     i2c.start(busid)
     i2c.address(busid, 0x22 , i2c.RECEIVER)
     bdata = i2c.read(busid,2)  -- Reads one byte
     i2c.stop(busid)
     idata = string.byte(bdata,1,1)
     inputs = byte2bin(idata)
     odata = string.byte(bdata,2,2)
     outputs = bit.bnot(odata)
     outputs = byte2bin(outputs)
     return inputs,outputs
end


function ioi2c.write(bitmask)
     i2c.start(busid)
     i2c.address(busid, 0x22 , i2c.RECEIVER)
     rdio = i2c.read(busid,2)
     b = string.byte(rdio,2, 2)
     for out ,val in ipairs(bitmask) do
       if val ~= '' then
         if val == 1 then b = bit.clear(b,out-1) end
         if val == 0 then b = bit.set(b,out-1) end
       end
     end
     i2c.start(busid)
     i2c.address(busid, 0x22, i2c.TRANSMITTER)
     i2c.write(busid,255,b)
     i2c.stop(busid)
     return b
end

function ioi2c.led(color)
     c = 255
     if color == "red" then c = 254 end
     if color == "green" then c = 253 end
     i2c.start(busid)
     i2c.address(busid, 0x20, i2c.TRANSMITTER)
     i2c.write(busid,c,255)
     i2c.stop(busid)
end

function ioi2c.userbutton()
     i2c.start(busid)
     i2c.address(busid, 0x20 , i2c.RECEIVER)
     bdata = i2c.read(busid,1)
     bdata = string.byte(bdata)
     ub = bit.isclear(bdata, 2)
     return ub
end

return ioi2c
