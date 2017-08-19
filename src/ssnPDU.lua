
require("crc16")
require("compat53")

local yaml = require('yaml')

local logger
if loggerGlobal then
  logger = loggerGlobal
  logger:debug("Use global logger")
else
  require "logging.console"
  logger = logging.console()
  logger:debug("Use local logger")
end

--local outErr = io.stderr
--local out = io.stdout

local cSSNSTART = "===ssn1" -- #ssn packet template

-- Meta class
ssnPDU = {
        destObj = 0,
        srcObj = 0,
        msgType = 0,
        msgID = 0, -- message ID (from external system)
        msgData = nil,
--        msgChannel = msgChannel # 0 - serial, 1 - TCP
--        socket = msgSocket # client socket (for TCP channel) or None
--        msgSerial = msgSerial
        msgTimestamp = 0
}
--print (string.format("%X",ccitt_16('===ssn100010003020033{"ssn":{"v":1,"cmd":"getowilist", "data": {"g":1}}}')))

function ssnPDU:new (o, destObj, srcObj, msgType, msgData)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  self.msgTimestamp = os.time()
  if destObj then
    self.destObj = destObj
  end
  if srcObj then
    self.srcObj = srcObj
  end
  if msgType then
    self.msgType = msgType
  end
  if msgData then
    self.msgData = msgData
  end
  return o
end

function ssnPDU:setMsgData(msgData)
   self.msgData = msgData
end

function ssnPDU:setDestObj(destObj)
   self.destObj = destObj
end

function ssnPDU:setSrcObj(srcObj)
   self.srcObj = srcObj
end

function ssnPDU:setMsgType(msgType)
   self.msgType = msgType
end

function ssnPDU:setMsgID(msgID)
   self.msgID = msgID
end

-- ==============================================
function ssnPDU:getSSNPDU()
  local buf = nil
  
  if self.msgData then
    local crc = ccitt_16(self.msgData)
    buf = string.format("%s%04x%04x%02x%04x%s%04x",cSSNSTART,self.destObj,
            self.srcObj, self.msgType, #self.msgData, self.msgData, crc)
  end
  
   return buf
end

-- ==============================================
--    # scan text buffer and try to parse SSN message format:
function ssnPDU:processBuffer(buf)

  --  local buf = nil
  local bufTail = ""
  local nResult = false     -- # success or not result
  local pduPos1
  local pduPos2
  local currentPos
  local pduDataPos

  logger:debug(string.format("buf = %s\n", buf))
  if buf then

    pduPos1, pduPos2 = string.find(buf,cSSNSTART)

    if (pduPos1) then
      currentPos = pduPos2
      logger:debug("pduPos1 = %d, pduPos2 = %d", pduPos1, pduPos2)

      if ((pduPos2 >= 0) and (#buf-pduPos2)>=14) then
        logger:debug(string.format("SSN PDU detected \n"))

        --    # process SSN PDU
        --    #/* -- SSN serial protocol description -----------------------------------------
        --    # *
        --    # * Format: "===ssn1DDDDSSSSTTLLLL...CCCC"
        --    # *
        --    # * ===ssn1 - start packet (protocol version 1)
        --    # * DDDD - destination object (2 byte: hex chars - 0-9, A-F)
        --    # * SSSS - source object (2 byte: hex chars - 0-9, A-F)
        --    # * TT - message type (1 byte: hex chars - 0-9, A-F)
        --    # * LLLL - packet length (2 byte: hex chars - 0-9, A-F)
        --    # * ... data
        --    # * CCCC - CRC16 (2 byte: hex chars - 0-9, A-F)
        --    # *
        --    # * data sending in ascii format
        --    # * timeout = 2 sec
        --    # *
        --    # * */
        local destObj; local srcObj; local  msgType; local packetLen
        destObj, srcObj, msgType, packetLen = string.unpack ('<c4c4c2c4', string.sub(buf, (pduPos2+1), pduPos2+14))
        destObj = tonumber(destObj, 16)
        srcObj = tonumber(srcObj, 16)
        msgType = tonumber(msgType, 16)
        packetLen = tonumber(packetLen, 16)
        pduDataPos = pduPos2 + 14
        if (destObj and srcObj and msgType and packetLen and pduDataPos and ((pduDataPos+packetLen+4) <= #buf)) then
          logger:debug(string.format("destObj = %X, srcObj = %X, msgType = %X, packetLen = %d, pduDataPos = %d\n", destObj, srcObj,
            msgType, packetLen, pduDataPos))
          local pduData =  string.sub(buf,(pduDataPos+1),pduDataPos+packetLen)
          -- logger:debug(string.format("pduData: %s\n", pduData))
          local pduCRC = string.unpack('<c4', buf, (pduDataPos+packetLen+1))
          local calcCRC = ccitt_16(pduData)
          logger:debug(string.format("pduCRC = %s, calcCRC = %X\n", pduCRC, calcCRC))
          pduCRC = tonumber(pduCRC, 16)
          if (calcCRC == pduCRC) then
            self.destObj=destObj
            self.srcObj=srcObj
            self.msgType=msgType
            self.msgID=None
            self.msgData=pduData
            currentPos = pduDataPos+packetLen+5
            nResult = true
            bufTail = string.sub(buf,currentPos)
          else
            logger:warn(string.format("CRC Error! dest[%d] src[%d] msg[%s]\n", destObj,srcObj,pduData))
            currentPos = pduDataPos+packetLen+5
          end
        else
          --        currentPos = pduPos2 + 14
--          bufTail = string.sub(buf,pduPos1)
          bufTail = ""
          --        outErr:write(string.format("Error processing SSN PDU: %s",buf))
        end
      else
        bufTail = string.sub(buf,pduPos1)
      end
      currentPos = pduPos2
    end
  end
  return bufTail, nResult
end

-- =============================================================
-- helper SSN functions

