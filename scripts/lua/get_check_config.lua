--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local checks = require("checks")
local alert_consts = require("alert_consts")
local alert_exclusions = require "alert_exclusions"

sendHTTPContentTypeHeader('application/json')

local subdir = _GET["check_subdir"] or "host"
local factory = _GET["factory"]
local script_key = _GET["script_key"]

local script_type = checks.getScriptType(subdir)

if(script_type == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad subdir: " .. subdir)
  return
end

if(script_key == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing script_key parameter")
  return
end

local config_set
if factory and factory == "true" then
   config_set = checks.getFactoryConfig()
else
   config_set = checks.getConfigset()
end

-- ################################################

local script = checks.loadModule(getSystemInterfaceId(), script_type, subdir, script_key)

if(script == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown user script: " .. script_key)
  return
end

local result = {
  hooks = {},
  gui = {},
  metadata = {},
  filters = {}
}

if(script.gui) then
  local known_fields = {i18n_title=1, i18n_description=1, i18n_field_unit=1, input_builder=1}

  for field, val in pairs(script.gui) do
    if not known_fields[field] then
      result.gui[field] = val
    end
  end

  if(script.gui.i18n_field_unit) then
    result.gui.fields_unit = i18n(script.gui.i18n_field_unit)
  end

  result.gui.input_builder = script.gui.input_builder
end

if (script.default_value) then
  result.metadata.default_value = script.default_value
end

-- Getting filter configurations

if script.alert_id and (subdir == "flow" or subdir == "host") then
   result.filters = { current_filters = {}}
   local current_filters
   if subdir == "flow" then
      current_filters = alert_exclusions.flow_alerts_get_excluded_hosts(script.alert_id)
   else
      current_filters = alert_exclusions.host_alerts_get_excluded_hosts(script.alert_id)
   end

   for current_ip, _ in pairs(current_filters or {}) do
      result.filters.current_filters[#result.filters.current_filters + 1] = {ip = current_ip}
   end
else
   local filter_conf = config_set["filters"]
   if filter_conf and filter_conf[subdir] and filter_conf[subdir][script_key] and filter_conf[subdir][script_key]["filter"] then
      result.filters = filter_conf[subdir][script_key]["filter"]
   end

   if not result.filters or table.len(result.filters) == 0 then
      -- No configuration found, trying to check if there is a default filter configured
      result.filters = checks.getDefaultFilters(interface.getId(), subdir, script_key)
   end
end

-------------------------------

local hooks_config = checks.getScriptConfig(config_set, script, subdir)

-- script.template:render(hooks_config)

for hook, config in pairs(hooks_config) do
  local granularity_info = alert_consts.alerts_granularities[hook]
  local label = nil

  if(granularity_info) then
    label = i18n(granularity_info.i18n_title)
  end

  result.hooks[hook] = table.merge(config, {
    label = label or "",
  })
end

-- ################################################

print(json.encode(result))
