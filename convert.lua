local convert = {}

function convert.tofloat(x)
  -- Bits:
  -- 31: sign (s)
  -- 23-30: exponent (e)
  -- 0-22: mantissa (m)
  if x == 0 then return 0 end
  local s = nil
  local em = nil
  local twoTo31 = 0x80000000
  local twoTo23 = 0x800000
  if x < twoTo31 then
    s = 1
    em = x
  else
    s = -1
    em = x - twoTo31
  end
  local e = math.floor(em / twoTo23) - 127
  local m = (em % twoTo23) / twoTo23 + 1
  return s*(2^e)*m
end


function convert.float2hex (n)
    if n == 0.0 then return 0.0 end

    local sign = 0
    if n < 0.0 then
        sign = 0x80
        n = -n
    end

    local mant, expo = math.frexp(n)
    local hext = {}

    if mant ~= mant then
        hext[#hext+1] = string.char(0xFF, 0x88, 0x00, 0x00)

    elseif mant == math.huge or expo > 0x80 then
        if sign == 0 then
            hext[#hext+1] = string.char(0x7F, 0x80, 0x00, 0x00)
        else
            hext[#hext+1] = string.char(0xFF, 0x80, 0x00, 0x00)
        end

    elseif (mant == 0.0 and expo == 0) or expo < -0x7E then
        hext[#hext+1] = string.char(sign, 0x00, 0x00, 0x00)

    else
        expo = expo + 0x7E
        mant = (mant * 2.0 - 1.0) * math.ldexp(0.5, 24)
        hext[#hext+1] = string.char(sign + math.floor(expo / 0x2),
                                    (expo % 0x2) * 0x80 + math.floor(mant / 0x10000),
                                    math.floor(mant / 0x100) % 0x100,
                                    mant % 0x100)
    end

    return tonumber(string.gsub(table.concat(hext),"(.)",
                                function (c) return string.format("%02X%s",string.byte(c),"") end), 16)
end


return convert
