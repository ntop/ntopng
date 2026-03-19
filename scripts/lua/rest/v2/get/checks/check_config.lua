--
-- (C) 2019-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json             = require "dkjson"
local rest_utils       = require "rest_utils"
local checks           = require "checks"
local alert_consts     = require "alert_consts"
local alert_severities = require "alert_severities"
local auth             = require "auth"

--
-- Return configuration for a single check (hooks, severities, gui metadata).
-- Used by the Vue edit-check modal.
--
-- GET params:
--   check_subdir  string  — e.g. "host", "flow"
--   script_key    string  — check key name
--   factory       string  — "true" to return factory defaults
--

if not auth.has_capability(auth.capabilities.checks) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local subdir     = _GET["check_subdir"]
local script_key = _GET["script_key"]
local factory    = (_GET["factory"] == "true")

if not subdir or not script_key then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local script_type = checks.getScriptType(subdir)
if not script_type then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local script = checks.loadModule(getSystemInterfaceId(), script_type, subdir, script_key)
if not script then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

local configset    = factory and checks.getFactoryConfig() or checks.getConfigset()
local hooks_config = checks.getScriptConfig(configset, script, subdir)

-- Per-hook config
local hooks = {}
for hook, config in pairs(hooks_config) do
   local granularity_info = alert_consts.alerts_granularities[hook]
   hooks[hook] = table.merge(config, {
      label = (granularity_info and i18n(granularity_info.i18n_title)) or
              (hook ~= "all" and hook) or
              i18n("edit_check.hooks_config") or hook
   })
end

-- Severity options (only those used by alerts, sorted by id)
local severities = {}
for sev_key, sev in pairs(alert_severities) do
   if sev.used_by_alerts then
      severities[#severities + 1] = {
         id    = sev.severity_id,
         key   = sev_key,
         label = i18n(sev.i18n_title) or sev_key,
         icon  = sev.icon or "",
      }
   end
end
table.sort(severities, function(a, b) return a.id < b.id end)

-- GUI metadata
local gui = {}
if script.gui then
   gui.title         = i18n(script.gui.i18n_title) or script.gui.i18n_title or script_key
   gui.description   = i18n(script.gui.i18n_description) or script.gui.i18n_description or ""
   gui.input_builder = script.gui.input_builder or nil
   if script.category then
      gui.category_icon  = script.category.icon or ""
      gui.category_label = i18n(script.category.i18n_title) or script.category.i18n_title or ""
   end
   if script.gui.i18n_field_unit then
      gui.field_unit = i18n(script.gui.i18n_field_unit)
   end
   if script.gui.input_title then
      gui.input_title = i18n(script.gui.input_title) or script.gui.input_title
   end
   if script.gui.input_description then
      gui.input_description = i18n(script.gui.input_description) or script.gui.input_description
   end
end

-- Per-field metadata for multi_threshold_cross checks (translated titles + units)
local field_metadata = {}
if script.default_value then
   for field, meta in pairs(script.default_value) do
      if type(meta) == "table" then
         field_metadata[field] = {
            title         = (meta.i18n_title and (i18n(meta.i18n_title) or meta.i18n_title)) or field,
            fields_unit   = (meta.i18n_fields_unit and (i18n(meta.i18n_fields_unit) or meta.i18n_fields_unit)) or nil,
            field_min     = meta.field_min,
            field_max     = meta.field_max,
            field_operator = meta.field_operator,
         }
      end
   end
end

rest_utils.answer(rest_utils.consts.success.ok, {
   hooks          = hooks,
   severities     = severities,
   gui            = gui,
   default_value  = script.default_value,
   field_metadata = field_metadata,
})
