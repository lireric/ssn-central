rs232 = require("luars232")
--rs232 = require("rs232") -- https://luarocks.org/modules/moteus/rs232 -- https://github.com/moteus/librs232

local logger
if loggerGlobal then
  logger = loggerGlobal
else
  require "logging.console"
  logger = logging.console()
end

-- Meta class
ssnSerialProxy = {
  baud_rate = rs232.RS232_BAUD_57600,
  data_bits = rs232.RS232_DATA_8,
  parity = rs232.RS232_PARITY_NONE,
  stop_bits = rs232.RS232_STOP_1,
  flow_control = rs232.RS232_FLOW_HW,
  dtr = rs232.RS232_DTR_OFF,
  rts = rs232.RS232_RTS_OFF,
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
  if (self.p) then
    if (rts_value) then
      self.p:set_rts(rs232.RS232_RTS_ON)
    else
      self.p:set_rts(rs232.RS232_RTS_OFF)
    end
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

function ssnSerialProxy:setSerialFlowHW (value)
  if (not value or value == 'False') then
    self.flow_control = rs232.RS232_FLOW_OFF
    logger:info("SerialFlowHW: FLOW_OFF (%s)", value)
  else
    self.flow_control = rs232.RS232_FLOW_HW
    logger:info("SerialFlowHW: FLOW_HW (%s)", value)
  end
end

function ssnSerialProxy:setUseRTSDTR (value)
  if (value) then
    self.dtr = rs232.RS232_DTR_ON
    self.rts = rs232.RS232_RTS_ON
  else
    self.dtr = rs232.RS232_DTR_OFF
    self.rts = rs232.RS232_RTS_OFF
  end
end

function ssnSerialProxy:setBaudRate (baud_rate)
  logger:info("Set BaudRate = %d", baud_rate)
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
end

function ssnSerialProxy:setCallBack (callBackFunc)
   self.callBack = callBackFunc
end

function ssnSerialProxy:init()
  -- open port
  local e, p = rs232.open(self.port_name)
  if e ~= rs232.RS232_ERR_NOERROR then
    -- handle error
    logger:error(string.format("can't open serial port '%s', error: '%s'\n",
      self.port_name, rs232.error_tostring(e)))
    return nil
  end

  self.p = p
  self.e = e
  -- set port settings
  assert(p:set_baud_rate(self.baud_rate) == rs232.RS232_ERR_NOERROR)
  assert(p:set_data_bits(self.data_bits) == rs232.RS232_ERR_NOERROR)
  assert(p:set_parity(self.parity) == rs232.RS232_ERR_NOERROR)
  assert(p:set_stop_bits(self.stop_bits) == rs232.RS232_ERR_NOERROR)
  assert(p:set_flow_control(self.flow_control)  == rs232.RS232_ERR_NOERROR)
  assert(p:set_dtr(self.dtr) == rs232.RS232_ERR_NOERROR)
  assert(p:set_rts(self.rts) == rs232.RS232_ERR_NOERROR)

  logger:info(string.format("OK, port open with values '%s'\n", tostring(p)))
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
  local timeout = 200 -- in miliseconds
  local err
  local len
  self:setRTS(true)
  self:ledOn()
  err, len = self.p:write(buf, timeout)
  if (err == rs232.RS232_ERR_NOERROR) then
    logger:debug(string.format("serial write: '%s' *** LEN: %d\n", tostring(buf), len))
  else
    logger:warn(string.format("serial write error: '%s' *** LEN: %d\n", tostring(buf), len))
  end
  sleep(0.05)
  self:ledOff()
  self:setRTS(nil)
end

function ssnSerialProxy:readLoop()
  local read_len = 32 -- maximum 32 bytes
  local timeout = 200 -- in miliseconds
  logger:debug("Create readLoop coroutine")
  return coroutine.create(function ()
    while true do
      self:setRTS(nil)
      local buff_all = ""
      local isValidData = nil
      local err
      local data_read
      local size = read_len
      -- try to get data from serial port. If we receive data, then get it all:
      while (size == read_len) do
        self:ledOn() -- flash the led (on)
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
      self:ledOff() -- flash the led (off)

      coroutine.yield(buff_all, isValidData)
    end
  end)
end
  
