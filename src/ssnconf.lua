-- load SSN configuration file in yaml format


local logger

if loggerGlobal then
  logger = loggerGlobal
else
  require "logging.console"
  logger = logging.console()
end

local function read_file(path)
    local open = io.open
    local file = open(path, "r") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

function loadSSNConf(file_name)
  local fileConfName
  if (file_name) then
    fileConfName = file_name
  else
    fileConfName = "ssn_conf.yaml"
  end
  
  local fileConfigData = read_file(fileConfName)
  if not fileConfigData then
    logger:error(string.format("can't open configuration file '%s'\n", fileConfName))
    return;
  end
  local yaml = require('yaml')
--  local ssnConf = yaml.load(fileConfigData)
  return yaml.load(fileConfigData)
end

