local function modbusconf ()
  file.open("modbus.cfg", "r")
  str = file.readline()
  mbt={}
  sep = ","
  for par in string.gmatch(str, "([^"..sep.."]+)") do
   table.insert(mbt, par)
  end
  file.close()
  --Setup serial port---------------------
  parity = mbt[3]
  stopbits = mbt[4]
  
  if parity == "NONE" then prt = uart.PARITY_NONE
  elseif parity == "ODD" then prt = uart.PARITY_ODD
  elseif parity == "EVEN" then prt = uart.PARITY_EVEN
  else prt = uart.PARITY_NONE
  end

  if stopbits == '1' then stb = uart.STOPBITS_1
  elseif stopbits == '1_5' then stb = uart.STOPBITS_1_5
  elseif stopbits == '2' then stb = uart.STOPBITS_2
  else stb = uart.STOPBITS_1
  end
  
  uart.setup(2,
             tonumber(mbt[1]),
             tonumber(mbt[2]),
             prt,
             stb,
             {tx=33, rx=34})
             uart.start(2)
  print(uart.getconfig(2))
  ------------------------
end  

local function ethconf ()
  file.open("eth.cfg", "r")
  str = file.readline()
  et={}
  sep = ","
  for par in string.gmatch(str, "([^"..sep.."]+)") do
   table.insert(et, par)
  end
  file.close()
  ck = string.match(et[4], "dhc", 1)
  if ck then
  dhcp = 'checked'
  else 
  dhcp = ''
  end
end  

local function wificonf ()
  file.open("wifi.cfg", "r")
  wstr = file.readline()
  wt={}
  wsep = ","
  for par in string.gmatch(wstr, "([^"..wsep.."]+)") do
   table.insert(wt, par)
  end
  file.close()
  wck = string.match(wt[4], "dhc", 1)
  if wck then
  wifidhcp = 'checked'
  else 
  wifidhcp = ''
  end
end

local function protocolconf ()
  file.open("protocol.cfg", "r")
  pstr = file.readline()
  pstr = pstr:gsub("\n", "")
  pstr = pstr:gsub("\r", "")
  prot={}
  psep = ","
  for par in string.gmatch(pstr, "([^"..psep.."]+)") do
   table.insert(prot, par)
  end

  if prot[1] == nil then prot[1] = '' end
  if prot[2] == nil then prot[2] = '' end
  if prot[3] == nil then prot[3] = '' end
  if prot[4] == nil then prot[4] = '' end
  if prot[5] == nil then prot[5] = '' end
  if prot[6] == nil then prot[6] = '' end
  if prot[7] == nil then prot[7] = '' end
  interface = prot[1]
  protocol = prot[2]
  print("Protocol is : "..protocol)
  file.close()
end

modbusconf ()
ethconf ()
wificonf ()
protocolconf ()

--Create Server
sv=net.createServer(net.TCP)
-------------------------------------------------------------------------------
function receiver(sck, data)
sck:on("sent", function(sck) sck:close() end)

s, e, get = string.find(data, "GET /??(.*) HTTP/1", 1)
s,e, impfilename =  string.find(data,'filename="(.*).csv"',1) 

isget = data:match('GET')
--ispost = data:match('POST')


if impfilename then
  cnt = 0
  lines = {}
   for line in data:gmatch('([^\n]+)') do 
        address,
        command,
        register,
        datatype = line:match("(%d+);(.*);(%d+);(.*)")
     if address then
     dataline =  address..','..command..','..register..','..datatype..'\n'
     table.insert(lines,dataline)
     
     print(dataline)
     cnt = cnt + 1 
     end
   --end
   --imp:close()
  end  
 
  if cnt > 0 then
    file.open("import.csv","w+")
    for numline, tabline in ipairs(lines) do
      file.write(tabline)
    end
    file.close()

    sck:send('<script> alert("Upload complite! Reboot device!") </script>')
    
  else
    sck:send('<script> alert("No data to upload!") </script>')
  end
end

if (isget == 'GET' and get ~= nil) then
    mbgetparam = {}
    getparam = {}
    wgetparam = {}
    pgetparam = {}
    
    for param in get:gmatch('([^&]+)') do
      s, e, key = string.find(param,"(.*)=",1)
      s, e, val = string.find(param,"=(.*)",1)

      if key == 'baudrate' then mbgetparam[1] = val end
      if key == 'databit' then mbgetparam[2] = val end
      if key == 'parity' then mbgetparam[3] = val end
      if key == 'stopbits' then mbgetparam[4] = val end
      if key == 'pooldelay' then mbgetparam[5] = val end
      if key == 'timeout' then mbgetparam[6] = val end
      
      if key == 'interface' then pgetparam[1] = val end
      if key == 'protocol' then pgetparam[2] = val end
      if key == 'mqttip' then pgetparam[3] = val end
      if key == 'mqttport' then pgetparam[4] = val end
      if key == 'mqttid' then pgetparam[5] = val end
      if key == 'mqttlogin' then pgetparam[6] = val end
      if key == 'mqttpass' then pgetparam[7] = val end
      
      if key == 'ip' then getparam[1] = val end
      if key == 'netmask' then getparam[2] = val end
      if key == 'gw' then getparam[3] = val end
      if key == 'dhcp' then getparam[4] = 'dhcp' end

      if key == 'wifiip' then wgetparam[1] = val end
      if key == 'wifinetmask' then wgetparam[2] = val end
      if key == 'wifigw' then wgetparam[3] = val end
      if key == 'wifidhcp' then wgetparam[4] = 'dhcp' end
      if key == 'ssid' then wgetparam[5] = val end
      if key == 'pass' then wgetparam[6] = val end

      if key == 'restart' and val == '1' then node.restart() end
    end

  if mbgetparam[1] ~= nil then
  cfgtowrite = mbgetparam[1]..','..mbgetparam[2]..','..mbgetparam[3]..','..mbgetparam[4]..','..mbgetparam[5]..','..mbgetparam[6]
  file.open("modbus.cfg","w+")   
  file.write(cfgtowrite)
  print("Set new Modbus settings: "..cfgtowrite)
  file.close()
  end  
  
  if getparam[1] ~= nil then
  if getparam[4] == nil then getparam[4] = 'static' end
  cfgtowrite = getparam[1]..','..getparam[2]..','..getparam[3]..','..getparam[4]..'\r\n'
  file.open("eth.cfg","w+")   
  file.write(cfgtowrite)
  print("Set new ETH settings: "..cfgtowrite)
  file.close()
  end
  
  if wgetparam[1] ~= nil then
  if wgetparam[4] == nil then wgetparam[4] = 'static' end
  wcfgtowrite = wgetparam[1]..','..wgetparam[2]..','..wgetparam[3]..','..wgetparam[4]..','..wgetparam[5]..','..wgetparam[6]..'\r\n'
  file.open("wifi.cfg","w+")   
  file.write(wcfgtowrite)
  print("Set new WIFI settings: "..wcfgtowrite)
  file.close()
  end
  
  if pgetparam[2] ~= nil then
  if pgetparam[6] == nil then pgetparam[6] = '' end
  if pgetparam[7] == nil then pgetparam[7] = '' end
  pcfgtowrite = pgetparam[1]..','..pgetparam[2]..','..pgetparam[3]..','..pgetparam[4]..','..pgetparam[5]..','..pgetparam[6]..','..pgetparam[7]..'\r\n'
  file.open("protocol.cfg","w+")   
  file.write(pcfgtowrite)
  print("Set new protocol settings: "..pcfgtowrite)
  file.close()
  end 

end


--WEB interface selects------------------------
  if interface == 'e' then
    s00 = 'selected' s01 = ''
  else 
    s00 = '' s01 = 'selected'
  end  

  if parity == 'NONE' then
    spNONE = 'selected' spODD = '' spEVEN = ""
  elseif parity == 'ODD' then
    spNONE = '' spODD = 'selected' spEVEN = ""
  elseif parity == 'EVEN' then
    spNONE = '' spODD = '' spEVEN = "selected"
  end

  if stopbits == '1' then
    sp1 = 'selected' sp15 = '' sp2 = ""
  elseif stopbits == '1_5' then
    sp1 = '' sp15 = 'selected' sp2 = ""
  elseif stopbits == '2' then
    sp1 = '' sp15 = '' sp2 = "selected"
  end
----------------------------------------------
  

if not impfilename then
     html = "HTTP/1.0 200 OK\r\nServer: NodeMCU\r\nContent-Type: text/html\r\n\r\n"

     html = html.."<html><title>Modbus2MQTT</title><body>"
     html = html.."<h1>Modbus2MQTT</h1>"
     html = html.."<style>"..
     [[label,
     input[type=text] {
     display: inline-block;
     vertical-align: middle;
     }
     label {
     width: 10%;
     margin-bottom: 5px;
     }
     input[type=text] {
     width: 30%;
     margin-bottom: 5px;
     }
     select {
     width: 5%;
     margin-bottom: 5px;
     margin-right: 5px;
     }]]
     html = html.."</style>"
    -- html = html.."<hr>"
      --html = html.."</style>"
    -- html = html.."<hr>"
     --html = html.."<p>Last Reboot: "..node.bootreason().."</p>"
     --html = html.."<p>Heap: "..node.heap().." byte</p>"
     html = html..'<div>'
     html = html..[[<button onclick="restart()"><b>Restart device</b></button>]]
     html = html..[[
     <script>
     function restart() {
      var xhr = new XMLHttpRequest();
      xhr.open('GET', '/?restart=1', true);
      xhr.send();
      if (xhr.status != 200) {
        console.log(xhr.status);
      } else {
        console.log(xhr.status);
      }
      
     }
     </script>
     ]]
     html = html..'</div>'

     html = html.."<b>Modbus settings: </b>"
     html = html..'<form action="/" method="get">'
     hhtml = html..'<div>'
     html = html..'<label for="baudrate"> Baudrate - </label>'
     html = html..'<input name="baudrate" id="baudrate" value='..mbt[1]..'>'
     html = html..'</div>'
     html = html..'<div>'
     html = html..'<label for="databit"> Data bit num. - </label>'
     html = html..'<input name="databit" id="databit" value='..mbt[2]..'>'
     html = html..'</div>'
     --[[html = html..'<div>'
     html = html..'<label for="parity"> Parity - </label>'
     html = html..'<input name="parity" id="parity" value='..mbt[3]..'>'
     html = html..'</div>']]
     html = html..'<div>'
     html = html..'<label for="parity">Parity - </label>'
     html = html..'<select size="1" name="parity">'
     html = html..'<option '..spNONE..' value="NONE">NONE</option>'
     html = html..'<option '..spODD..' value="ODD">ODD</option>'
     html = html..'<option '..spEVEN..' value="EVEN">EVEN</option>'
     html = html..'</select>'
     html = html..'</div>'
     --[[html = html..'<div>'
     html = html..'<label for="stopbits"> Stop bits - </label>'
     html = html..'<input name="stopbits" id="stopbits" value='..mbt[4]..'>'
     html = html..'</div>']]
     html = html..'<div>'
     html = html..'<label for="stopbits">Stopbits - </label>'
     html = html..'<select size="1" name="stopbits">'
     html = html..'<option '..sp1..' value="1">1</option>'
     html = html..'<option '..sp15..' value="1_5">1.5</option>'
     html = html..'<option '..sp2..' value="2">2</option>'
     html = html..'</select>'
     html = html..'</div>'
     html = html..'<div>'
     html = html..'<label for="pooldelay"> Pool delay, ms - </label>'
     html = html..'<input name="pooldelay" id="pooldelay" value='..mbt[5]..'>'
     html = html..'</div>'
      html = html..'<div>'
     html = html..'<label for="timeout"> Timeout, ms - </label>'
     html = html..'<input name="timeout" id="timeout" value='..mbt[6]..'>'
     html = html..'</div>'
     html = html..'<button type="submit">Save settings</button>'
     html = html..'</form>'


     html = html..'<div>'
     html = html..'<label><b> UPLOAD POOL DATA </b></label>'
     html = html..[[<form enctype="multipart/form-data" method="post">
                    <p><input type="file" name="f">
                    <input type="submit" value="UPLOAD"></p>
                    </form> ]]
     html = html..'</div>'
     
     
     html = html.."<b>Device settings: </b>"
     html = html..'<form action="/" method="get">'
     html = html..'<select size="1" name="interface">'
     html = html..'<option '..s00..' value="e">Ethernet</option>'
     html = html..'<option '..s01..' value="w">WIFI</option>'
     html = html..'</select>'
     html = html..'<select size="1" name="protocol">'
     html = html..'<option selected value="mqtt">MQTT</option>'
     html = html..'</select>'
     html = html..'<div>'
     html = html..'<label for="mqttip"> MQTT broker IP - </label>'
     html = html..'<input name="mqttip" id="mqttip" value='..prot[3]..'>'
     html = html..'</div>'
     html = html..'<div>'
     html = html..'<label for="mqttport"> MQTT broker port - </label>'
     html = html..'<input name="mqttport" id="mqttport" value='..prot[4]..'>'
     html = html..'</div>'
     html = html..'<div>'
     html = html..'<label for="mqttid"> MQTT device ID - </label>'
     html = html..'<input name="mqttid" id="mqttid" value='..prot[5]..'>'
     html = html..'</div>'
     html = html..'<label for="mqttlogin"> MQTT Login - </label>'
     html = html..'<input name="mqttlogin" id="mqttlogin" value='..prot[6]..'>'
     html = html..'</div>'
     html = html..'<div>'
     html = html..'<label for="mqttpass"> MQTT Password - </label>'
     html = html..'<input name="mqttpass" id="mqttpass" value='..prot[7]..'>'
     html = html..'</div>'
     html = html..'<button type="submit">Save settings</button>'
     html = html..'</form>'
     
     html = html.."<b>Ethernet settings: </b>"
     html = html..'<form action="/" method="get">'
     html = html..'<div>'
     html = html..'<label for="ip"> IP ADDRESS- </label>'
     html = html..'<input name="ip" id="ip" value='..et[1]..'>'
     html = html..'</div>'
     html = html..'<div>'
     html = html..'<label for="netmask"> NETMASK - </label>'
     html = html..'<input name="netmask" id="netmask" value='..et[2]..'>'
     html = html..'</div>'
     html = html..'<div>'
     html = html..'<label for="gw"> GATEWAY - </label>'
     html = html..'<input name="gw" id="gw" value='..et[3]..'>'
     html = html..'</div>'
     html = html..'<div>'
     html = html..'<input type="checkbox" id="dhcp" name="dhcp" '..dhcp..'>'
     html = html..'<label for="dhcp">DHCP</label>'
     html = html..'</div>'
     html = html..'<button>Save ETH settings</button>'
     html = html..'</form>'

     html = html.."<b>WIFI settings: </b>"
     html = html..'<form action="/" method="get">'
     html = html..'<div>'
     html = html..'<label for="wifiip"> IP ADDRESS- </label>'
     html = html..'<input name="wifiip" id="wifiip" value='..wt[1]..'>'
     html = html..'</div>'
     html = html..'<div>'
     html = html..'<label for="wifinetmask"> NETMASK - </label>'
     html = html..'<input name="wifinetmask" id="wifinetmask" value='..wt[2]..'>'
     html = html..'</div>'
     html = html..'<div>'
     html = html..'<label for="wifigw"> GATEWAY - </label>'
     html = html..'<input name="wifigw" id="wifigw" value='..wt[3]..'>'
     html = html..'</div>'
     html = html..'<div>'
     html = html..'<input type="checkbox" id="wifidhcp" name="wifidhcp" '..wifidhcp..'>'
     html = html..'<label for="wifidhcp">DHCP</label>'
     html = html..'</div>'
     html = html..'<div>'
     html = html..'<label for="ssid"> SSID - </label>'
     html = html..'<input name="ssid" id="ssid" value='..wt[5]..'>'
     html = html..'</div>'
     html = html..'<div>'
     html = html..'<label for="pass"> PASSWORD - </label>'
     html = html..'<input name="pass" id="pass" value='..wt[6]..'>'
     html = html..'</div>'
     html = html..'<button>Save WIFI settings</button>'
     html = html..'</form>'


     html = html.."</body></html>"
     sck:send(html)
     html = ''
  end
     
     
end 


if sv then
  sv:listen(80, function(conn)
    conn:on("receive", receiver)
  end)
  dofile('modbus.lua')
end
