--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")

sendHTTPContentTypeHeader('application/json')

local stype = _GET["script_type"] or "traffic_element"
local subdir = _GET["script_subdir"] or "host"
local confset_id = tonumber(_GET["confset_id"] or user_scripts.DEFAULT_CONFIGSET_ID)
local script_key = _GET["script_key"]

local script_type = user_scripts.script_types[stype]

if(script_type == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad script_type: " .. stype)
  return
end

if(script_key == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing script_key parameter")
  return
end

local config_set = user_scripts.getConfigsets(subdir)[confset_id]

if(config_set == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown configset ID: " .. confset_id)
  return
end

-- ################################################


interface.select(getSystemInterfaceId())

local script = user_scripts.loadModule(getSystemInterfaceId(), script_type, subdir, script_key)

if(script == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Unkown user script: " .. script_key)
  return
end

local result = {
  hooks = {},
  gui = {},
}

if(script.gui) then
  local known_fields = {i18n_title=1, i18n_description=1, i18n_field_unit=1, input_builder=1, post_handler=1}

  for field, val in pairs(script.gui) do
    if not known_fields[field] then
      result.gui[field] = val
    end
  end

  if(script.gui.i18n_field_unit) then
    result.gui.fields_unit = i18n(script.gui.i18n_field_unit)
  end

  if(script.gui.input_builder == user_scripts.threshold_cross_input_builder) then -- TODO make generic
    result.gui.input_builder = "threshold_cross"
  end
end

local hooks_config = user_scripts.getConfigsetHooksConf(config_set, script, subdir)

for hook, config in pairs(hooks_config) do
  local granularity_info = alert_consts.alerts_granularities[hook]
  local label = nil

  if(granularity_info) then
    label = i18n(granularity_info.i18n_title)
  end

  result.hooks[hook] = table.merge(config, {
    label = label,
  })
end

-- ################################################

print(json.encode(result))
