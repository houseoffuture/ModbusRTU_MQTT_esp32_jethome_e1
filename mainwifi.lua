print("wifi init")

file.open("wifi.cfg", "r")
local str = file.readline()
local t={}
local sep = ","
for par in string.gmatch(str, "([^"..sep.."]+)") do
 table.insert(t, par)
 ssid = tostring(t[5])
 pass = tostring(t[6])
 pass = pass:gsub("\n", "")
 pass = pass:gsub("\r", "")
end
file.close()
print('Boot IP settings is: '..str)
print('SSID an PASS is: '..ssid.." / "..pass)

local static = string.match(t[4], "stat", 1)


if static ~= nil then
print("Set static address")
  cfg={}
  cfg.ip=t[1]
  cfg.netmask=t[2]
  cfg.gateway=t[3]
  cfg.dns=t[3]
  wifi.sta.setip(cfg)
end

wifi.start()
wifi.mode(wifi.STATIONAP)
station_cfg={}
station_cfg.ssid=ssid
station_cfg.pwd=pass
wifi.sta.config(station_cfg)
wifi.sta.sethostname("esp32_test")

wifi.sta.connect()



local function ev(event, info)
    print("event", event)
    if event == "got_ip" then
      print('GOTIP: '..info.ip)
      gpio.write(2,1)
      dofile('web.lua')
    end
end

wifi.sta.on("connected", ev)
wifi.sta.on("disconnected", ev)
wifi.sta.on("start", ev)
wifi.sta.on("stop", ev)
wifi.sta.on("got_ip", ev)
