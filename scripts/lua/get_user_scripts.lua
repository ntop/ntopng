--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local alert_consts = require("alert_consts")
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
      local label

      if(conf.enabled) then
        enabled_hooks[#enabled_hooks + 1] = hook
      end

      local granularity_info = alert_consts.alerts_granularities[hook]

      if(granularity_info) then
        label = i18n(granularity_info.i18n_title)
      end

      all_hooks[#all_hooks + 1] = {
        key = hook,
        label = label,
      }
    end

    if(script.edition == "community") then
       local plugin_file_path = string.sub(script.source_path, string.len(dirs.scriptdir) + 1)
       local plugin_path = string.sub(script.plugin.path, string.len(dirs.scriptdir) + 1)
       edit_url = string.format("%s/lua/code_viewer.lua?plugin_file_path=%s&plugin_path=%s", ntop.getHttpPrefix(), plugin_file_path, plugin_path)
    end

    local input_handler = script.gui.input_builder

    result[#result + 1] = {
      key = script_name,
      title = i18n(script.gui.i18n_title) or script.gui.i18n_title,
      description = i18n(script.gui.i18n_description) or script.gui.i18n_description,
      category_title = i18n(script.category.i18n_title),
      category_icon = script.category.icon,
      enabled_hooks = enabled_hooks,
      all_hooks = all_hooks,
      is_enabled = not table.empty(enabled_hooks),
      edit_url = edit_url,
      input_handler = input_handler,
      value_description = script.template:describeConfig(script, hooks)
    }
  end
end

-- ################################################

print(json.encode(result))
