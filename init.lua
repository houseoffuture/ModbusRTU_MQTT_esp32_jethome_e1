gpio.config({ gpio=4, dir=gpio.IN, pull=gpio.PULL_UP }, { gpio=2, dir=gpio.OUT })
def_pin = gpio.read(4)

print('Default settings pin is '..def_pin)

function devsettings ()
  file.open("protocol.cfg", "r")
  line = file.readline()
  line = line:gsub("\n", "")
  line = line:gsub("\r", "")
  settings={}
  sep = ","
  for set in string.gmatch(line, "([^"..sep.."]+)") do
   table.insert(settings, set)
  end
  interface = settings[1]
  file.close()
end
devsettings ()

if def_pin == 1 then
  if interface == 'e' then
    print("Switch to Ethernet...")
    dofile('main.lua')
  else
    print("Switch to WIFI...")
    dofile('mainwifi.lua')
  end
else
print("Write default IP 192.168.6.66 to int. Ethernet... Open jumper and reboot device!")
file.open("eth.cfg","w+")
set = '192.168.6.66,255.255.255.0,192.168.6.1,static'    
file.write(set)
file.close()
file.open("protocol.cfg","w+")
set = 'e,dalihub,,,,,'    
file.write(set)
file.close()
end

--RESTART WHILE
readRstTimer = tmr.create()
readRstTimer:register(500, tmr.ALARM_AUTO, function() 
fnbutton = gpio.read(0)
if fnbutton == 0 then node.restart() end
end)
readRstTimer:start()


