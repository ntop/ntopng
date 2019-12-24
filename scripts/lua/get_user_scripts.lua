--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")

local dirs = ntop.getDirs()

sendHTTPContentTypeHeader('application/json')

local confset_id = tonumber(_GET["confset_id"]) or user_scripts.DEFAULT_CONFIGSET_ID
local subdir = _GET["script_subdir"]

if(subdir == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'script_subdir' parameter")
  return
end

local script_type = user_scripts.getScriptType(subdir)

if(script_type == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad subdir: " .. subdir)
  return
end

if(confset_id == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'confset_id' paramter")
  return
end

local config_set = user_scripts.getConfigsets()[confset_id]

if(config_set == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown configset ID: " .. confset_id)
  return
end

-- ################################################

interface.select(getSystemInterfaceId())

local scripts = user_scripts.load(getSystemInterfaceId(), script_type, subdir)
local result = {}

for script_name, script in pairs(scripts.modules) do
  if script.gui and script.gui.i18n_title and script.gui.i18n_description then
    local hooks = user_scripts.getScriptConfig(config_set, script, subdir)
    local enabled_hooks = {}
    local all_hooks = {}
    local edit_url = nil

    for hook, conf in pairs(hooks) do
      if(conf.enabled) then
        enabled_hooks[#enabled_hooks + 1] = hook
      end

      all_hooks[#all_hooks + 1] = hook
    end

    if(script.edition == "community") then
      local path = string.sub(script.source_path, string.len(dirs.scriptdir)+1)
      edit_url = ntop.getHttpPrefix() .. '/lua/code_viewer.lua?lua_script_path='.. path
    end

    local input_handler = nil

    if(script.gui.input_builder == user_scripts.threshold_cross_input_builder) then -- TODO make generic
      input_handler = "threshold_cross"
    end

    result[#result + 1] = {
      key = script_name,
      title = i18n(script.gui.i18n_title) or script.gui.i18n_title,
      description = i18n(script.gui.i18n_description) or script.gui.i18n_description,
      enabled_hooks = enabled_hooks,
      all_hooks = all_hooks,
      is_enabled = not table.empty(enabled_hooks),
      edit_url = edit_url,
      input_handler = input_handler,
    }
  end
end

-- ################################################

print(json.encode(result))
