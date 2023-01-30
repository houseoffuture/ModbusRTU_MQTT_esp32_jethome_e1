local mb = require('lmodbus')
local convert = require('convert')
local io = require("ioi2c")
gpio.config({gpio={36},dir=gpio.IN, pull=gpio.PULL_UP })
local trID = 1
local numByte = 9
local trans = 0
local function modbusconf ()
  file.open("modbus.cfg", "r")
  str = file.readline()
  mbt={}
  sep = ","
  for par in string.gmatch(str, "([^"..sep.."]+)") do
   table.insert(mbt, par)
  end
  file.close()
  pooldelay = tonumber(mbt[5])
  devTimeout = tonumber(mbt[6])
  if pooldelay == nil then pooldelay = 5000 end
  if devTimeout == nil then devTimeout = 500 end
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
  protocol = prot[2]
  if prot[6] == nil then prot[6] = '' end
  if prot[7] == nil then prot[7] = '' end
  file.close()

  mqttip = prot[3]
  mqttport = prot[4]
  mqttid = prot[5]
  mqttlogin = prot[6]
  mqttpass = prot[7]
end

protocolconf ()
modbusconf ()

local m = mqtt.Client(mqttid, 20, mqttlogin, mqttpass)

function handle_mqtt_error(client, reason) 
  print("Try reconnect...")
  tmr.create():alarm(10 * 1000, tmr.ALARM_SINGLE, mqtt_connect)
end

function mqtt_connect()
m:lwt(mqttid..'/LWT', 'Offline' ,0 ,1)
m:connect(mqttip, mqttport, 0, function(client)

function subsctopic(top)
  client:subscribe(top, 0)
end

function senttopic(top,topdata,topqos,topretain)
  client:publish(top, topdata, topqos, topretain)
end

----------------------------------------------------------------------
function ioreadjson()
  inputs, outputs = io.read()
  inputs = table.concat(inputs,',',3,8)
  outputs = table.concat(outputs,',',4,8)
  inputs = string.reverse(inputs)
  outputs = string.reverse(outputs)
  statusio = '{"inputs":['..inputs..'],"outputs":['..outputs..']}'
  return statusio
end

function ioint()
  function intreset()
    tmr.create():alarm(100, tmr.ALARM_SINGLE,function()
    statusio = ioreadjson() 
    senttopic(mqttid..'/IO/status', statusio, 0, 0) 
    io.led('green')
    gpio.trig(36,gpio.INTR_LOW,int)
    end)
  end
  function int()
   statusio = ioreadjson()
   senttopic(mqttid..'/IO/status', statusio, 0, 0)
   io.led('red')
   intreset()
   gpio.trig(36,nil)
  end
  gpio.trig(36,gpio.INTR_LOW,int)
end  


----------------------------------------------------------------------

m:on("connect", function(client) print ("Connected to broker") end)
m:on("offline", function(client)
print('Offline event')
m:close()
handle_mqtt_error()
end)
m:on("connect", ioint() )
m:on("connect", subsctopic(mqttid.."/IO/write") )
m:on("connect", subsctopic(mqttid.."/IO/read") )
m:on("connect", subsctopic(mqttid.."/CMD"))
m:on("connect", senttopic(mqttid.."/LWT", "Online", 0, 1) )
m:on("connect", senttopic(mqttid.."/IO/status", ioreadjson(), 0, 0) )

-----------------------------------------------------------------------
m:on("message", function(client, topic, mqttdata) 
--recieve from mqtt
print(topic .. " >>> data is: "..mqttdata )

if topic == mqttid..'/IO/read' then
  statusio = ioreadjson()
  senttopic(mqttid..'/IO/status', statusio,0,0) 
  io.led('green')
end
  
if topic == mqttid..'/IO/write' then
  bitmask = {'','','','',''}
  s, e, wObject = string.find(mqttdata,'{(.*)}',1)
  if wObject then
     for out in wObject:gmatch('([^,]+)') do
        s, e, key = string.find(out,'R(.*)":',1)
        s, e, val = string.find(out,':(.*)',1)
        if tonumber(key) then bitmask[tonumber(key)] = tonumber(val) end
     end
   end 
    io.write(bitmask)
end 

end)
-----------------------------------------------------------------------


local function importcsv()
print('Load Modbus pool data...')
   pooltab = {}
   csv = file.open("import.csv","r")
   if csv then
     --for line in string.match(csv, "([^\n]+)") do
     repeat
     line = csv:readline()
      if line then
        line = line:gsub("\n", "")
        line = line:gsub("\r", "")
        trans = trans + 1  
        local address,
        command,
        register,
        datatype = line:match("(%d+),(.*),(%d+),(.*)")
        pooltab[trans] = { tonumber(address), command, tonumber(register), datatype}
        print(address,command,register,datatype)
       end  
      until line == nil
    end
 csv:close()
 return(pooltab)
end


local transactions = importcsv()


local xact = {
 type = 'RTU', 
 func = 'READ_HOLDING_REGISTERS', 
 server_addr = 0, 
 start_addr = 0,
 word_count = 0,
 words = {}
 }


local function serial_write(msg)
  uart.write(2, msg)
end

local function REQ(tr)
  io.led()
  xact.server_addr = transactions[tr][1]
  xact.func = transactions[tr][2]
  xact.start_addr = transactions[tr][3]
  if transactions[tr][4] == 'int' then
    xact.word_count = 1
  elseif transactions[tr][4] == 'float' then
    xact.word_count = 2
  end  
  --xact.word_count = transactions[tr][4]
  if transactions[tr]['words'] ~= nil then
    xact['words'] = transactions[tr]['words']
  end
  gpio.write(2,0)
  req = mb.build_request(xact)  
  serial_write(req)
  reqHEX = ''
  Rbt = {}
  for i = 1, #req do 
    Rby = string.format("%02x",string.byte(req,i))
    reqHEX = reqHEX..Rby..''
    table.insert(Rbt, Rby)
  end
  print('----------------------')
  print('Request HEX : '..reqHEX)
end

local function checkType()
  if xact.word_count == 2 then
    numByte = 9
  elseif xact.word_count == 1 then
    numByte = 7
  end
end

local function nexttransact()
  trID = trID + 1
  if transactions[trID] == nil then trID = 1 end
end

local function clearbuffer()
  uart.on(2,"data", 1 , function(data) end)
  --uart.on("data")
  print('RX buffer clear...')
  loop:start()
end

---------------------------------------------------  
local function recieve(nb)
  nexttransact()
  timeout = tmr.create()
  loop:stop()
  timeout:register(devTimeout, tmr.ALARM_SINGLE, function()
      io.led('green')
      print('Response timeout...')
      --uart.on("data")
      clearbuffer()
    end)
  timeout:start()



  uart.on(2,"data", nb , function(data)
    timeout:unregister()
    resp = data
    gpio.write(2,1)
    ok, err = mb.parse_response(xact, resp)
    if ok ~= true then
     --nexttransact()
      print(err)
     --uart.on("data")
      loop:stop()
      clearbuffer()
    end
  

  ret = ''
  bt = {}
  for i = 1, nb do 
    by = string.format("%02x",string.byte(data,i))
    ret = ret..by..''
    table.insert(bt, by)
  end
  io.led('green')
  print('Response HEX : '..ret)
  if xact.word_count == 2 then
    pdu = table.concat(bt,'',4,7)
    pdu = tonumber(pdu,16)
    pdu = convert.tofloat(pdu)

  elseif xact.word_count == 1 then
    pdu = table.concat(bt,'',4,5)
    pdu = tonumber(pdu,16)
    
  end
  print('Value is: '..pdu)
  senttopic(mqttid..'/'..xact.server_addr..'/'..xact.start_addr, pdu,0,0) 
  uart.on("data")
  loop:start()
 end)

end


---------------------------------------------------  
  
if trans > 0 then
print('Modbus pool started...')
loop = tmr.create()
loop:register(pooldelay, tmr.ALARM_AUTO, function()
  REQ(trID)
  checkType()
  recieve(numByte)
  --print(math.ceil(node.heap() * 0.00097656))
 end)
loop:start()
else
print('Modbus pool data no found...')
end

end,handle_mqtt_error)
end
mqtt_connect()
