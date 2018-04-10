require "logging.console"
require "ssnconf"
local yaml = require('yaml')
socket = require("socket")

-- global variables:
log_level = logging.DEBUG
loggerGlobal = logging.console()
ssnmqttClient = nil
ssnConf = nil
SerProxy1 = nil
ssnDB1 = nil

-- local chank variables:
local s
local tail = ""
local logger = loggerGlobal

-- ==================================================================
-- global function: check - serial or not interface for destination object
-- if serial - true
function isSerialIf(obj)
  local bRet = nil
  if (ssnConf) then
    for i, serDstObj in pairs(ssnConf.ssn.serial_if)
    do
      if (serDstObj == obj) then
        bRet = true
      end
    end
  end
  return bRet
end

-- ==================================================================
-- global function: get local proxy object number
function getProxyObj()
  local nRet = 0
  if (ssnConf) then
     nRet = ssnConf.ssn.proxy_obj
  end
  return nRet
end

-- ==================================================================
-- global function: get Telegram bot object and device number
function getTelegramObj()
  local nObj = 0
  local nDev = 0
  if (ssnConf) then
     nObj = ssnConf.ssn.tlg_obj
     nDev = ssnConf.ssn.tlg_dev
  end
  return nObj, nDev
end

-- ==================================================================
function sleep(s)
  socket.sleep(s)
end

-- ==================================================================
-- global function: route message to target object (if needed)
-- return true if local (on current proxy instance) processing
-- return false if performed routing to external object
function routeMsg(srcObj, dstObj, bufData, msgType)
  local bRet = true
  -- to do: process broadcast messages ...
  if ((getProxyObj() ~= dstObj) and (dstObj > 0) and not isSerialIf(dstObj)) then
    bRet = nil
    logger:debug("route to external object")
    if (dstObj == getTelegramObj()) then
      ssnmqttClient:sendTelegramMessage(bufData)
    end
  end
  return bRet
end

-- From http://lua-users.org/wiki/AlternativeGetOpt
-- getopt, POSIX style command line argument parser
-- param arg contains the command line arguments in a standard table.
-- param options is a string with the letters that expect string values.
-- returns a table where associated keys are true, nil, or a string value.
function getopt( arg, options )
  local tab = {}
  for k, v in ipairs(arg) do
    if string.sub( v, 1, 2) == "--" then
      local x = string.find( v, "=", 1, true )
      if x then tab[ string.sub( v, 3, x-1 ) ] = string.sub( v, x+1 )
      else      tab[ string.sub( v, 3 ) ] = true
      end
    elseif string.sub( v, 1, 1 ) == "-" then
      local y = 2
      local l = string.len(v)
      local jopt
      while ( y <= l ) do
        jopt = string.sub( v, y, y )
        if string.find( options, jopt, 1, true ) then
          if y < l then
            tab[ jopt ] = string.sub( v, y+1 )
            y = l
          else
            tab[ jopt ] = arg[ k + 1 ]
          end
        else
          tab[ jopt ] = true
        end
        y = y + 1
      end
    end
  end
  return tab
end

-- ********************************************** process SSN messages
-- input: JSON telemetry message (type=3)
-- return: table with telemetry data
local function parseTeledataMsg(srcObj, strJsonData)
  local bRes = false
  local jsonData = yaml.load(strJsonData)
  logger:debug("JsonTeledataMsg: = %s", yaml.dump(jsonData))
  
  if (jsonData) then
    bRes = true
    for i, logItem in pairs(jsonData.ssn.data.devs)
    do
      if (logItem) then
        publishSSNDataDevice(ssnmqttClient, jsonData.ssn.obj, logItem.dev, logItem.i, logItem.val, logItem.updtime, 0)
      end
    end
  end

  return bRes

end

-- input: JSON LOG message (type=6)
-- return: table with log data
local function parseLogMsg(srcObj, strJsonData)
  local bRes = false
  local jsonData = yaml.load(strJsonData)
  logger:debug("JsonLogMsg: = %s", yaml.dump(jsonData))
  if (jsonData) then
    bRes = true
    for i, logItem in pairs(jsonData.log)
    do
      if (logItem) then
        publishSSNDataDevice(ssnmqttClient, srcObj, logItem.d, logItem.c, logItem.v, logItem.t, logItem.a)
      end
    end
  end

  return bRes
end

-- ************************************************************

local function processBuffer(strBuf)
  local bRes
  logger:debug("processBuffer: %s", strBuf)
  if strBuf then
    tail, bRes = s:processBuffer(tail..strBuf)
    logger:debug ("PROCBUF: TAIL=%s, RES=%s",tail, tostring(bRes))
    if (bRes) then
      logger:debug ("ssnPDU: srcObj=%d, destObj=%d, msgType=%d, msgData=%s",s.srcObj, s.destObj, s.msgType, s.msgData)
      -- if route not needed local processing:
      if (routeMsg(s.srcObj, s.destObj, s.msgData, s.msgType)) then
        if (s.msgType == 6) then
          -- process LOG message
          logger:debug ("Process LOG message")
          if not pcall(parseLogMsg, s.srcObj, s.msgData) then
            --        if not parseLogMsg(s.srcObj, s.msgData) then
            logger:warn ("parseLogMsg -- Failure: payload=%s",s.msgData)
          end
        elseif (s.msgType == 2) then
          -- process JSON message
          logger:debug ("Process JSON message")

        elseif (s.msgType == 3) then
          -- process TELEMETRY message
          logger:debug ("Process TELEMETRY message")
          if not pcall(parseTeledataMsg, s.srcObj, s.msgData) then
            --        if not parseTeledataMsg(s.srcObj, s.msgData) then
            logger:warn ("parseTeledataMsg -- Failure: payload=%s",s.msgData)
          end
        else
          logger:debug("skip row data processing")
        end
      end
    end
    -- reset tail if it size grow so much:
    if (#tail > ssnConf.app.SerialBufferSize) then
      tail = ""
    end
  end
end

local function receiveSerialMsg (co)
--  logger:debug("wait receiveSerialMsg")
  local status, value, isValidData = coroutine.resume(co)
--  logger:debug("get receiveSerialMsg, status: %s", tostring(status))
  if isValidData then 
    logger:debug("receiveSerialMsg, send to row_data topic...")
    ssnmqttClient.client:publish("/ssn/acc/"..tostring(ssnmqttClient.account).."/raw_data",value, 0, false)
    --processBuffer(value)
  end
  return true -- to do
end

local function ssnRowDataProcess(payload)
  logger:debug("RowDataProcess: %s", payload)
  if not pcall(processBuffer, payload) then
    logger:warn ("RowDataProcess -> processBuffer -- Failure: payload=%s",payload)
  end
  --        processBuffer(payload)
end


local function ssnObjDataProcess(subTokensArray, payload)
  logger:debug("ObjDataProcess: %s, subTokensArray size = %d", payload, #subTokensArray)
  local obj = 0
  local tokenArraySize = #subTokensArray
  
  if (subTokensArray) then
    obj = tonumber(subTokensArray[1], 10)
    logger:debug("ObjDataProcess: obj=%d", obj)
    
    if (routeMsg(getProxyObj(), obj, payload, nil)) then
      subToken = subTokensArray[2]
      
      if (tokenArraySize == 2) then
        if (subToken == "commands") then
          SerProxy1:write(payload)
        end
        
      elseif (tokenArraySize == 3) then

        if ((subToken == "commands") and (subTokensArray[3]=="ini")) then
          ssnmqttClient:cmdIniSend(payload, obj)

        elseif ((subToken == "commands") and (subTokensArray[3]=="json")) then
          ssnmqttClient:cmdJsonSend(payload, obj)

        end
        
      elseif (tokenArraySize == 5) then
        if ((subToken == "device") and (subTokensArray[5]=="in")) then
          ssnmqttClient:cmdSDV(payload, obj, subTokensArray[3], subTokensArray[4])
          
        elseif ((subToken == "device") and (subTokensArray[5]=="out_json")) then
          local teleData = yaml.load(payload)
          logger:debug("JsonTeledataMsg: = %s", yaml.dump(teleData))
          if (ssnDB1) then 
            ssnDB1:saveTeledata(teleData, obj)
          end
        end
      end
    end
  end
end

local function ssnTlgDataProcess(subTokensArray, payload)
  logger:debug("TlgDataProcess: %s, subTokensArray size = %d", payload, #subTokensArray)
  local tokenArraySize = #subTokensArray
  if (subTokensArray) then
    if (tokenArraySize == 1) then
      if (subTokensArray[1]=="in") then
      -- to do: make Telegram bot module call

      elseif (subTokensArray[1]=="out") then
      -- to do: process message from Telegram bot
      end
    end
  end
end

local function ssnOnMessage(mid, topic, payload)
  logger:debug("MQTT message. Topic=%s : %s", topic, payload)
  local acc
  local rootToken
  local subTokensArray
  acc, rootToken, subTokensArray = parseTopic(topic)
  -- check for correct account
  if not acc then
    logger:debug ("Wrong topic [%s]. Skipping", topic)
    return
  end
  if (acc == ssnConf.ssn.ACCOUNT) then
    logger:debug ("Account=%d, rootToken = %s", acc, rootToken)
    if (rootToken == "raw_data") then
      ssnRowDataProcess(payload)
    elseif (rootToken == "obj") then
      ssnObjDataProcess(subTokensArray, payload)
    elseif (rootToken == "telegram") then
      ssnTlgDataProcess(subTokensArray, payload)
    end
  else
    logger:debug ("Wrong account [%d]. Skipping", acc)
  end
end


local function mainLoop (co)
  logger:debug("Start SerialMsg consumer")
  while true do
    if (ssnConf.app.SerialOn == 1) then
      local res = receiveSerialMsg(co)
    end
    ssnmqttClient.client:loop(0,1)
    sleep(0.1)

    --    os.execute("sleep 0.2")
    --    sleep(0.01)
  end
end

-- ******************************* local loop:
local function localLoop()
  logger:debug("Create local Loop coroutine")
  return coroutine.create(function ()
      sleep(0.1)
      coroutine.yield(nil, nil)
  end)
end  

local function main()

  -- process command line arguments:
  local opts = getopt( arg, "ldc" )
  if (opts.l) then
    if (opts.l == 'DEBUG') then
      log_level = logging.DEBUG
    elseif (opts.l == 'INFO') then
      log_level = logging.INFO
    elseif (opts.l == 'WARN') then
      log_level = logging.WARN
    elseif (opts.l == 'ERROR') then
      log_level = logging.ERROR
    end
  end

  loggerGlobal:setLevel (log_level)

  local file_conf_name = "ssn_conf.yaml"
  if (opts.c) then
    file_conf_name = opts.c
  end
  logger:debug("Using config file: %s", file_conf_name)

  ssnConf = loadSSNConf(file_conf_name)
  logger:debug("Application name: %s", ssnConf.app.name)

  require "ssnPDU"
  require "ssnmqtt"

  ssnmqttClient = ssnmqtt:new(nil, ssnConf.ssn.ACCOUNT, ssnConf.app.MQTT_HOST, ssnConf.app.MQTT_PORT, ssnConf.app.MQTT_BROKER_CLIENT_ID)
  ssnmqttClient.client:login_set(ssnConf.ssn.MQTT_BROKER_USER, ssnConf.ssn.MQTT_BROKER_PASS)

  if (ssnConf.app.DBLog == 1) then
    -- start DB logger:
    require('ssnDB')
    logger:info ("Database logger starting")

    ssnDB1 = ssnDB:new(nil, ssnmqttClient, ssnConf.db.db, ssnConf.db.user, ssnConf.db.pass,ssnConf.db.host, ssnConf.db.port)
    if not pcall(function() ssnDB1:init() end) then
       logger:warn ("Init DB -- Failure")
     end
    
--    ssnDB1:init()
    --    ssnDB1.mainLoopDB ()
  end

  ssnmqttClient:setCallBackOnConnect (ssnOnConnect)
  ssnmqttClient:setCallBackOnMessage (ssnOnMessage)
  ssnmqttClient:connect()

  -- configure Serial interface:
  if (ssnConf.app.SerialOn == 1) then
    -- start Serial proxy:
    require('ssnSerialProxy')
    SerProxy1 = ssnSerialProxy:new(nil, ssnConf.app.SerialPort)
    SerProxy1:setBaudRate (ssnConf.app.Serialbaudrate)
    SerProxy1:setLedBlink (ssnConf.app.LED_BLINK)
    SerProxy1:setUseRTSDTR (ssnConf.app.Serialrtscts)
    SerProxy1:setSerialFlowHW (ssnConf.app.SerialFlowHW)

    if SerProxy1:init() then
      logger:info ("Init Ok. Read loop starting")
      s = ssnPDU:new()
      SerProxy1:setCallBack(processBuffer)
      SerProxy1:setRtsConf (ssnConf.app.RTS_GPIO, ssnConf.app.RTS_ACTIVE, ssnConf.app.RTS_PASSIVE)

      mainLoop(SerProxy1:readLoop())
    else
      logger:error("serial init fail")
    end
  -- use local loop:  
  else
      mainLoop(localLoop())
  end
end


main()
