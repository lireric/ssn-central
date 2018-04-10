socket = require("socket")

local logger
if loggerGlobal then
  logger = loggerGlobal
else
  require "logging.console"
  logger = logging.console()
end

-- Meta class
ssnDB = {
  ssnmqttClient = nil,
  user = "",
  pass = "",
  db = "ssn",
  host = "localhost",
  port = 5432,
  driver = nil,
  con = nil, -- database connection
  env = nil,
  callBack = nil
}

-- Derived class method new

function ssnDB:new (o, ssnmqttClient, db, user, pass, host, port)
   o = o or {}
   setmetatable(o, self)
   self.__index = self
   self.ssnmqttClient = ssnmqttClient
   self.db = db
   self.user = user
   self.pass = pass
   self.host = host or "localhost"
   self.port = port or 5432
   return o
end


local function executeSQL(sqlStr, con)
  logger:debug("saveTeledata: %s",sqlStr)
  con:execute(sqlStr)
end

-- **************** Store teledata json into DB:
function ssnDB:saveTeledata(teleData, obj)
  --  td_account smallint, -- Account
  --  td_object smallint, -- Object
  --  td_device smallint NOT NULL, -- Device
  --  td_channel smallint NOT NULL DEFAULT 0, -- Channel of device (default=0)
  --  td_dev_ts integer, -- Timestamp from device (unix format)
  --  td_store_ts integer NOT NULL, -- Timestamp of storing in DB (unix format)
  --  td_dev_value integer NOT NULL, -- Value of device
  --  td_action smallint NOT NULL DEFAULT 0, -- Action number if value of device is changed by action or 0 if value changed by external factors.

  if (self.con) then
    local sqlStr = string.format([[
    INSERT INTO ssn_teledata (td_account, td_object, td_device, td_channel, td_dev_ts, td_store_ts, td_dev_value, td_action)
    VALUES ('%d', '%d', '%d', '%d', '%d', '%d', '%d', '%d')]], self.ssnmqttClient.account, obj, teleData.d, teleData.c, teleData.t, teleData.pub_ts, teleData.v, teleData.a)

    --    local res = assert (self.con:execute(sqlStr))
    local res
    local err
    res, err = pcall(executeSQL, sqlStr, self.con)
    if not res then
      logger:warn ("executeSQL -- Failure: sqlStr=%s, Error: %s",sqlStr, err)
      -- try to DB connect restore:
      if not pcall(function() ssnDB1:init() end) then
        logger:warn ("Init DB -- Failure")
      else
        logger:warn ("Init DB -- Restored")
      end
    end
  end
end

-- ********************************************** Database logger functions:
-- Callback function special for database logger:
function ssnDB:ssnOnConnectDB(success, rc, str)
  logger:info("connected (ssnOnConnectDB): %s, %d, %s", tostring(success), rc, str)
  if not success then
    logger:error("Failed to connect: %d : %s\n", rc, str)
    return
  end
end

-- ************************************************

function ssnDB:ssnOnMessageDB(mid, topic, payload)
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
    if (rootToken == "obj") then
      if (subTokensArray) then
        local obj = tonumber(subTokensArray[1], 10)
        logger:debug("ObjDataProcess: obj=%d", obj)
        local teleData = yaml.load(payload)
        logger:debug("JsonTeledataMsg: = %s", yaml.dump(teleData))
        self.saveTeledata(teleData)
      end
    end
  else
    logger:debug ("Wrong account [%d]. Skipping", acc)
  end
end

-- ==================================================================
function sleep(s)
  socket.sleep(s)
end

-- ***************************** loop for stand alone case:
function ssnDB:mainLoopDB ()
  logger:debug("Start mainLoopDB")
    self.ssnmqttClient:setCallBackOnConnect (self.ssnOnConnectDB)
    self.ssnmqttClient:setCallBackOnMessage (self.ssnOnMessageDB)
    self.ssnmqttClient:connect()

  while true do
    self.ssnmqttClient.client:loop(0,1)
    sleep(0.2)
  end
end

-- **********************************************

function ssnDB:init()
    local subscribeStr = "/ssn/acc/"..tostring(ssnmqttClient.account).."/obj/+/device/+/+/out_json"
    logger:debug("DB logger, subscribing to %s", subscribeStr)
--    self.ssnmqttClient.client:subscribe(subscribeStr, 0)

    -- load driver
    self.driver = require "luasql.postgres"
    -- create environment object
    self.env = assert (self.driver.postgres())
    -- connect to data source
    --local con = assert (env:connect("ssndb",username[,password[,hostname[,port]]]]))
    self.con = assert (self.env:connect(self.db, self.user, self.pass, self.host, self.port))
    

end

