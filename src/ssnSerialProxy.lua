local rs232 = require("luars232")
--require 'ul_serial'
local socket = require("socket")

local logger
if loggerGlobal then
  logger = loggerGlobal
else
  require "logging.console"
  logger = logging.console()
end

-- Meta class
ssnSerialProxy = {
    baud_rate = 57600,
    data_bits = 8,
    parity = 'n',
    stop_bits = 1, -- rs232.RS232_STOP_1,
    flow_control = 0,
    dtr = 0,
    rts = 0,
    p = 0,
    e = 0,
    led_blink = nil,
    rts_port = nil,
    rts_active = "1",
    rts_passive = "0",
    callBack = nil
}

-- Derived class method new

function ssnSerialProxy:new (o, port_name)
   o = o or {}
   setmetatable(o, self)
   self.__index = self
   self.port_name = port_name or "/dev/ttyUSB0"
   return o
end

function ssnSerialProxy:setRTS (rts_value)
  local cmd
  if (rs232) then
    if (self.p) then
      if (rts_value) then
        self.p:set_rts(rs232.RS232_RTS_ON)
      else
        self.p:set_rts(rs232.RS232_RTS_OFF)
      end
    end
  else
-- to do...
  end
    if (self.rts_port) then
      if (rts_value) then
        cmd = "echo "..self.rts_active.." > /sys/class/gpio/gpio"..self.rts_port.."/value"
        os.execute(cmd)
      else
        cmd = "echo "..self.rts_passive.." > /sys/class/gpio/gpio"..self.rts_port.."/value"
        os.execute(cmd)
      end
    end
end

function ssnSerialProxy:setRtsConf (rts_port, rts_active, rts_passive)
  -- all values are string!
  if (rts_port and #rts_port > 0) then
      self.rts_port = rts_port
  else
    self.rts_port = nil
  end
  self.rts_active = rts_active
  self.rts_passive = rts_passive
  
  local cmd
  if (self.rts_port) then
    cmd = "echo "..self.rts_port.." > /sys/class/gpio/export"
    logger:info("Configuring rts port: %s", cmd)
    os.execute(cmd)
--    os.execute("sleep 0.5")
    sleep(0.5)
    cmd = "echo out > /sys/class/gpio/gpio"..self.rts_port.."/direction"
    logger:info("Configuring rts port: %s", cmd)
    os.execute(cmd)
  end
end

function ssnSerialProxy:setLedBlink (led_blink)
  if (led_blink and #led_blink > 0) then
   self.led_blink = led_blink
  else
    self.led_blink = nil
  end
end

function ssnSerialProxy:setSerialFlowHW (value) -- not use!
  if (not value or value == 'False') then
    if (rs232) then
      self.flow_control = rs232.RS232_FLOW_OFF
    else
      self.flow_control = 0
    end
    logger:info("SerialFlowHW: FLOW_OFF (%s)", value)
else
  if (rs232) then
    self.flow_control = rs232.RS232_FLOW_HW
  else
    self.flow_control = 1
  end
  logger:info("SerialFlowHW: FLOW_HW (%s)", value)
end
end

function ssnSerialProxy:setUseRTSDTR (value)
  if (value) then
    self.dtr = 1
    self.rts = 1
  else
    self.dtr = 0
    self.rts = 0
  end
end

function ssnSerialProxy:setBaudRate (baud_rate)
  if (rs232) then
    if (baud_rate == 57600) then
      self.baud_rate = rs232.RS232_BAUD_57600
    elseif (baud_rate == 115200) then
      self.baud_rate = rs232.RS232_BAUD_115200
    elseif (baud_rate == 460800) then
      self.baud_rate = rs232.RS232_BAUD_460800
    elseif (baud_rate == 38400) then
      self.baud_rate = rs232.RS232_BAUD_38400
    elseif (baud_rate == 19200) then
      self.baud_rate = rs232.RS232_BAUD_19200
    elseif (baud_rate == 9600) then
      self.baud_rate = rs232.RS232_BAUD_9600
    else
      self.baud_rate = rs232.RS232_BAUD_57600
      logger:warn("Wrong baud rate! Set default BaudRate = 57600")
    end
  else
    logger:info("Set BaudRate = %d", baud_rate)
    self.baud_rate = baud_rate
  end
end

function ssnSerialProxy:setCallBack (callBackFunc)
   self.callBack = callBackFunc
end

function ssnSerialProxy:init()
  -- open port
  if (rs232) then
    logger:info("Using luars232 lib")
    local e, p = rs232.open(self.port_name)
    if e ~= rs232.RS232_ERR_NOERROR then
      -- handle error
      logger:error(string.format("can't open serial port '%s', error: '%s'\n",
        self.port_name, rs232.error_tostring(e)))
      return nil
    end

    self.p = p
    self.e = e
--    self.baud_rate = rs232.RS232_BAUD_57600
    self.data_bits = rs232.RS232_DATA_8
    self.parity = rs232.RS232_PARITY_NONE
    self.stop_bits = rs232.RS232_STOP_1
--    self.flow_control = rs232.RS232_FLOW_HW
--    self.dtr = rs232.RS232_DTR_OFF
--    self.rts = rs232.RS232_RTS_OFF

    -- set port settings
    assert(p:set_baud_rate(self.baud_rate) == rs232.RS232_ERR_NOERROR)
    assert(p:set_data_bits(self.data_bits) == rs232.RS232_ERR_NOERROR)
    assert(p:set_parity(self.parity) == rs232.RS232_ERR_NOERROR)
    assert(p:set_stop_bits(self.stop_bits) == rs232.RS232_ERR_NOERROR)
    assert(p:set_flow_control(self.flow_control)  == rs232.RS232_ERR_NOERROR)
    assert(p:set_dtr(self.dtr) == rs232.RS232_ERR_NOERROR)
    assert(p:set_rts(self.rts) == rs232.RS232_ERR_NOERROR)
    
    logger:info(string.format("Port parameters: %s", tostring(p)))
    
  else
    logger:info("Using ul_serial lib")
    io.Serial:getPorts()
    ports = io.Serial.ports

    logger:debug("\nAvailable ports: %d", #ports)
    for i,portName in ipairs(ports) do
      logger:debug("\t"..i.." : "..portName)
    end

    local p = io.Serial:open({port=self.port_name, baud=self.baud_rate, bits=self.data_bits, stops=self.stop_bits, parity=self.parity})
    p:config{DTR=self.dtr,RTS=self.rts}
    self.p = p
  end

  local cmd = "stty -F "..self.port_name.." raw"
  os.execute(cmd)

  logger:info(string.format("OK, port %s open", self.port_name))
  return true
end

function ssnSerialProxy:ledOn()
  if (self.led_blink) then
    local cmd = "echo 1 > /sys/class/leds/"..self.led_blink.."/brightness"
    os.execute(cmd)
  end
end

function ssnSerialProxy:ledOff()
    if (self.led_blink) then
      local cmd = "echo 1 > /sys/class/leds/"..self.led_blink.."/brightness"
      os.execute(cmd)
    end
end

function ssnSerialProxy:sendCallBack (buff_all)
  --  if self.callBack then
  --    self.callBack(buff_all)
  --  end
  logger:debug("sendCallBack")
  coroutine.yield(buff_all)
end

function ssnSerialProxy:write(buf)
  local timeout = 500 -- in miliseconds -- not use?
  --  local err
  local len
  self:setRTS(true)
  self:ledOn()

  if (rs232) then
    sleep(0.01)
    err, len = self.p:write(buf, timeout)
    if (err == rs232.RS232_ERR_NOERROR) then
      logger:debug(string.format("serial write: '%s' *** LEN: %d\n", tostring(buf), len))
    else
      logger:warn(string.format("serial write error: '%s' *** LEN: %d\n", tostring(buf), len))
    end
    --  self.p:flush()
    sleep(0.05)
  else
    self.p:write(buf)
    self.p:drainTX()
    logger:debug(string.format("\nserial write: '%s'", tostring(buf)))
  end
  --  sleep(0.05)
  self:ledOff()
  self:setRTS(nil)
end

function ssnSerialProxy:readLoop()
  local read_len = 32 -- maximum bytes
  local timeout = 200 -- 400 milliseconds -- maximum RX timeout (in 100-microsecond units)
  logger:debug("Create readLoop coroutine")
  return coroutine.create(function ()
    while true do
      --      self:setRTS(nil)
      local isValidData = nil
      local data_read
      local size = read_len
      local tout
      local buff_all = ""
      --      self:ledOn() -- flash the led (on)
      if (rs232) then
        local t = socket.gettime()*5000
        local err
        -- try to get data from serial port. If we receive data, then get it all:
        while ((size == read_len) or (socket.gettime()*5000 < (t + timeout))) do
          --        self:ledOn() -- flash the led (on)
          -- read with timeout
          err, data_read, size = self.p:read(read_len, timeout)

          if (err == rs232.RS232_ERR_NOERROR) then
            if data_read then
              buff_all = buff_all..data_read
              isValidData = true
              --            logger:debug(string.format("serial read: '%s' *** LEN: %d\n", tostring(buff_all), size))
            end
            --          logger:debug(string.format("232-read: data_read='%s' *** LEN: %d Max_LEN: %d", tostring(data_read), size, read_len))
          end

          --        logger:debug(string.format("232-read status: err='%s' *** LEN: %d", tostring(err), size))
        end

      else
        sleep(0.1)
        local avail = self.p:availRX()
        if avail > 0 then
          read_len = avail
          logger:debug(string.format("serial bytes available: %d", avail))
          -- read with timeout
          tout = self.p:waitRX(read_len, timeout)

          --      if tout > 0 then
          data_read = self.p:read()
          if data_read then
            size = #data_read
            isValidData = true
            logger:debug(string.format("serial read: '%s' *** LEN: %d\n", tostring(data_read), size))
          end
          --      end
          --      self:ledOff() -- flash the led (off)
        end
      end
      coroutine.yield(data_read, isValidData)
    end
  end)
end
  
