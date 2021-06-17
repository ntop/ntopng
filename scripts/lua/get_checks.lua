--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local alert_consts = require("alert_consts")
local checks = require("checks")
local rest_utils = require "rest_utils"
local auth = require "auth"

if not auth.has_capability(auth.capabilities.checks) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local dirs = ntop.getDirs()

sendHTTPContentTypeHeader('application/json')

local subdir = _GET["check_subdir"]

if(subdir == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'check_subdir' parameter")
  return
end

local script_type = checks.getScriptType(subdir)

if(script_type == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad subdir: " .. subdir)
  return
end

local config_set = checks.getConfigset()

-- ################################################

local scripts = checks.load(getSystemInterfaceId(), script_type, subdir, {return_all = true})
local result = {}

for script_name, script in pairs(scripts.modules) do
   if script.gui and script.gui.i18n_title and script.gui.i18n_description then
    local hooks = checks.getScriptConfig(config_set, script, subdir)

    local enabled_hooks = {}
    local all_hooks = {}

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
      edit_url = checks.getScriptEditorUrl(script),
      input_handler = input_handler,
      value_description = script.template:describeConfig(hooks)
    }
  end
end

-- ################################################

print(json.encode(result))
