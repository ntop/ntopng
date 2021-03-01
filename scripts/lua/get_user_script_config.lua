--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")

sendHTTPContentTypeHeader('application/json')

local subdir = _GET["script_subdir"] or "host"
local factory = _GET["factory"]
local script_key = _GET["script_key"]

local script_type = user_scripts.getScriptType(subdir)

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
   config_set = user_scripts.getFactoryConfig()
else
   config_set = user_scripts.getConfigset()
end

-- ################################################


interface.select(getSystemInterfaceId())

local script = user_scripts.loadModule(getSystemInterfaceId(), script_type, subdir, script_key)

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

if (script.is_alert) then
  result.metadata.is_alert = script.is_alert
end

-- Getting filter configurations
local filter_conf = config_set["filters"]
if not filter_conf then
   goto try_filter_default_conf
end

if not filter_conf[subdir] then
   goto try_filter_default_conf
end

if not filter_conf[subdir][script_key] then
   goto try_filter_default_conf
end

if not filter_conf[subdir][script_key]["filter"] then
   goto try_filter_default_conf
end
result.filters = filter_conf[subdir][script_key]["filter"]

if table.len(result.filters) > 0 then
   goto skip_filter_conf
end
-------------------------------
::try_filter_default_conf::
-- No configuration found, trying to check if there is a default filter configured
result.filters = user_scripts.getDefaultFilters(interface.getId(), subdir, script_key)

::skip_filter_conf:: 
-------------------------------
local hooks_config = user_scripts.getScriptConfig(config_set, script, subdir)

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
