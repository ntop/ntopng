--
-- (C) 2020 - ntop.org
--

local http_lint = require("http_lint")

-- ##############################################

local Template = {}

function Template:new(key)
  local obj = {
    key = key
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

-- @brief Validates and parses the given configuration.
-- @return (true,conf) if configuration is valid, (false,errmsg) otherwise
function Template:parseConfig(script, conf)
  traceError(TRACE_WARNING, TRACE_CONSOLE, "Template:parseConfig implementation is missing: " .. self.key)
  return true, conf
end

-- @brief Get a short string describing the current configuration
-- @return a descriptive string
function Template:describeConfig(hooks_conf)
  traceError(TRACE_WARNING, TRACE_CONSOLE, "Template:describeConfig implementation is missing: " .. self.key)
  return ""
end

-- ##############################################

local DefaultTemplate = {}

function DefaultTemplate:new()
  local obj = Template:new("default")

  setmetatable(obj, self)
  self.__index = self

  return obj
end

function DefaultTemplate:parseConfig(script, conf)
  return true, conf
end

function DefaultTemplate:describeConfig(hooks_conf)
  -- TODO
  return ""
end

-- ##############################################

--
-- Threshold cross template
--

local ThresholdCrossTemplate = {}

function ThresholdCrossTemplate:new()
  local obj = Template:new("threshold_cross")

  setmetatable(obj, self)
  self.__index = self

  return obj
end

function ThresholdCrossTemplate:parseConfig(script, conf)
  if(not http_lint.validateOperator(conf.operator)) then
    return false, "bad operator"
  end

  if(tonumber(conf.threshold) == nil) then
    return false, "bad threshold"
  end

  return true, conf
end

function ThresholdCrossTemplate:describeConfig(hooks_conf)
  -- TODO
  return ""
end

-- ##############################################

--
-- Items List
--

local ItemsList = {}

function ItemsList:new()
  local obj = Template:new("items_list")

  setmetatable(obj, self)
  self.__index = self

  return obj
end

function ItemsList:parseConfig(script, conf)
  return http_lint.validateListItems(script, conf)
end

function ItemsList:describeConfig(hooks_conf)
  -- TODO
  return ""
end

-- ##############################################

--
-- Elephant flows template
--

local ElephantFlowsTemplate = {}

function ElephantFlowsTemplate:new()
  local obj = Template:new("elephant_flows")

  setmetatable(obj, self)
  self.__index = self

  return obj
end

function ElephantFlowsTemplate:parseConfig(script, conf)
  if(tonumber(conf.l2r_bytes_value) == nil) then
    return false, "bad l2r_bytes_value value"
  end

  if(tonumber(conf.r2l_bytes_value) == nil) then
    return false, "bad r2l_bytes_value value"
  end

  return http_lint.validateListItems(script, conf)
end

function ThresholdCrossTemplate:describeConfig(hooks_conf)
  -- TODO
  return ""
end

-- ##############################################

--
-- Long lived template
--

local LongLivedTemplate = {}

function LongLivedTemplate:new()
  local obj = Template:new("long_lived")

  setmetatable(obj, self)
  self.__index = self

  return obj
end

function LongLivedTemplate:parseConfig(script, conf)
  if(tonumber(conf.min_duration) == nil) then
    return false, "bad min_duration value"
  end

  return http_lint.validateListItems(script, conf)
end

function LongLivedTemplate:describeConfig(hooks_conf)
  -- TODO
  return ""
end

-- ##############################################

-- Available templates
return {
  default 	  = DefaultTemplate:new(),

  threshold_cross = ThresholdCrossTemplate:new(),
  items_list 	  = ItemsList:new(),
  elephant_flows  = ElephantFlowsTemplate:new(),
  long_lived	  = LongLivedTemplate:new(),
}
