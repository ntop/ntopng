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

function DefaultTemplate:describeConfig(script, hooks_conf)
  return ''
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

function ThresholdCrossTemplate:describeConfig(script, hooks_conf)
  local alert_consts = require("alert_consts")
  local granularities_order = {"min", "5mins", "hour", "day"}
  local items = {}

  -- E.g. "> 50 Sec (Minute), > 300 Sec (Hourly)"
  for _, granularity in ipairs(granularities_order) do
    local hook = hooks_conf[granularity]
    local granularity = alert_consts.alerts_granularities[granularity]

    if granularity and hook and hook.script_conf.threshold then
      local unit = ""
      local op = ternary(hook.script_conf.operator == "gt", ">", "<")

      if(script.gui and script.gui.i18n_field_unit) then
        unit = " " .. i18n(script.gui.i18n_field_unit)
      end

      items[#items + 1] = string.format("%s %s%s (%s)", op,
        hook.script_conf.threshold, unit, i18n(granularity.i18n_title) or granularity.i18n_title)
    end
  end

  return table.concat(items, ", ")
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

function ItemsList:describeConfig(script, hooks_conf)
  if((not hooks_conf.all) or (not hooks_conf.all.script_conf)) then
    return '' -- disabled, nothing to show
  end

  local items = hooks_conf.all.script_conf.items or {}

  return table.concat(items, ", ")
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

function ElephantFlowsTemplate:describeConfig(script, hooks_conf)
  if not hooks_conf.all then
    return '' -- disabled, nothing to show
  end

  -- E.g. '> 1 GB (L2R), > 2 GB (R2L), except: Datatransfer, Git'
  local conf = hooks_conf.all.script_conf
  local msg = i18n("user_scripts.elephant_flows_descr", {
    l2r_bytes = bytesToSize(conf.l2r_bytes_value),
    r2l_bytes = bytesToSize(conf.r2l_bytes_value),
  })

  if not table.empty(conf.items) then
    msg = msg .. ". " .. i18n("user_scripts.exceptions", {exceptions = table.concat(conf.items, ', ')})
  end

  return(msg)
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

function LongLivedTemplate:describeConfig(script, hooks_conf)
  if not hooks_conf.all then
    return '' -- disabled, nothing to show
  end

  local conf = hooks_conf.all.script_conf
  local msg = i18n("user_scripts.long_lived_flows_descr", {
    duration = secondsToTime(conf.min_duration),
  })

  if(not table.empty(conf.items)) then
    msg = msg .. ". " .. i18n("user_scripts.exceptions", {exceptions = table.concat(conf.items, ', ')})
  end

  return(msg)
end

-- ##############################################

--
-- MUD template
--

local FlowMUDTemplate = {}

function FlowMUDTemplate:new()
  local obj = Template:new("flow_mud")

  setmetatable(obj, self)
  self.__index = self

  return obj
end

function FlowMUDTemplate:parseConfig(script, conf)
  if(tonumber(conf.max_recording) == nil) then
    return false, "bad max_recording value"
  end

  return http_lint.validateListItems(script, conf, "device_types")
end

function FlowMUDTemplate:describeConfig(script, hooks_conf)
  local discover = require("discover_utils")
  local mud_utils = require("mud_utils")

  if(not hooks_conf.all) then
    return '' -- disabled, nothing to show
  end

  local conf = hooks_conf.all.script_conf

  if(not conf.max_recording) then
    return ''
  end

  local enabled_on = {}

  for _, k in pairs(conf.device_types or {}) do
    enabled_on[#enabled_on + 1] = discover.devtype2string(discover.devtype2id(k))
  end

  local msg = i18n("user_scripts.stop_recording_after", {duration = mud_utils.formatMaxRecording(conf.max_recording)})

  if(#enabled_on > 0) then
    msg = msg .. ". " .. i18n("user_scripts.mud_enabled_on", {device_types = table.concat(enabled_on, ', ')})
  end

  return msg
end

-- ##############################################

-- Available templates
return {
  default 	  = DefaultTemplate:new(),

  threshold_cross = ThresholdCrossTemplate:new(),
  items_list   	  = ItemsList:new(),
  elephant_flows  = ElephantFlowsTemplate:new(),
  long_lived	  = LongLivedTemplate:new(),
  flow_mud        = FlowMUDTemplate:new(),
}
