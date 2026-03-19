--
-- (C) 2019-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json        = require("dkjson")
local alert_consts = require("alert_consts")
local checks      = require("checks")
local rest_utils  = require "rest_utils"
local auth        = require "auth"

--
-- Returns the list of checks for a given subdir with their enable/disable status.
-- "all" is a meta-subdir that aggregates every available subdir.
--
-- Example:
--   curl -u admin:admin \
--     'http://localhost:3000/lua/rest/v2/get/checks/list.lua?check_subdir=host&ifid=0'
--

if not auth.has_capability(auth.capabilities.checks) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local subdir = _GET["check_subdir"]
local ifid   = tonumber(_GET["ifid"] or getSystemInterfaceId())
-- "all" | "enabled" | "disabled" — optional, defaults to "all"
local status = _GET["status"] or "all"

if subdir == nil then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

-- Resolve the list of subdirs to scan
local subdirs = {}
if subdir == "all" then
   for _, s in pairs(checks.listSubdirs()) do
      subdirs[#subdirs + 1] = s.id
   end
else
   subdirs[#subdirs + 1] = subdir
end

local config_set = checks.getConfigset()
local result     = {}

for _, cur_subdir in ipairs(subdirs) do
   local script_type = checks.getScriptType(cur_subdir)
   if script_type == nil then goto next_subdir end

   local scripts = checks.load(getSystemInterfaceId(), script_type, cur_subdir, { return_all = false })

   for script_name, script in pairs(scripts.modules) do
      if not (script.gui and script.gui.i18n_title and script.gui.i18n_description) then
         goto next_script
      end

      -- Skip interface-type mismatches
      if script.packet_interface_only == true and not interface.isPacketInterface() then
         goto next_script
      end
      if script.zmq_interface_only == true and not interface.isZMQInterface() then
         goto next_script
      end

      -- Enabled hooks
      local hooks_config  = checks.getScriptConfig(config_set, script, cur_subdir)
      local enabled_hooks = {}
      for hook, conf in pairs(hooks_config) do
         if conf.enabled then
            enabled_hooks[#enabled_hooks + 1] = hook
         end
      end

      -- Severity (icon + i18n key only — no translated string)
      local severity_key, severity_icon
      if cur_subdir == "flow" and script.alert_id then
         local sev_id = ntop.mapScoreToSeverity(ntop.getFlowAlertScore(script.alert_id))
         local sev    = alert_consts.alertSeverityById(sev_id)
         if sev then
            severity_key  = sev.i18n_title
            severity_icon = sev.icon
         end
      elseif script.severity then
         severity_key  = script.severity.i18n_title
         severity_icon = script.severity.icon
      end

      local is_enabled = not table.empty(enabled_hooks)

      -- Apply status filter
      if status == "enabled"  and not is_enabled then goto next_script end
      if status == "disabled" and     is_enabled then goto next_script end

      result[#result + 1] = {
         key           = script_name,
         subdir        = cur_subdir,
         title         = i18n(script.gui.i18n_title) or script_name,
         description   = i18n(script.gui.i18n_description) or "",
         category_key  = script.category and script.category.i18n_title or nil,
         category_icon = script.category and script.category.icon      or nil,
         severity_key  = severity_key,
         severity_icon = severity_icon,
         is_enabled    = is_enabled,
         enabled_hooks = enabled_hooks,
         is_editable   = (script.gui and not isEmptyString(script.gui.input_builder or "")) and true or false,
      }

      ::next_script::
   end

   ::next_subdir::
end

rest_utils.answer(rest_utils.consts.success.ok, result)
