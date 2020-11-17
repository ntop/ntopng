--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/system_config/?.lua;" .. package.path

local system_setup_ui_utils = require "system_setup_ui_utils"
require "lua_utils"
require "prefs_utils"
local tz_utils = require("tz_utils")
prefsSkipRedis(true)

local nf_config = require("nf_config"):create(true)
local now = os.time()

system_setup_ui_utils.process_apply_discard_config(nf_config)

local timezones = tz_utils.ListTimeZones()
local system_timezone = tz_utils.TimeZone()

local default_custom_date
local date_time_config = nf_config:getDateTimeConfig()

if date_time_config.custom_date then
   default_custom_date = makeTimeStamp(date_time_config.custom_date)
end

local warnings = {}

if table.len(_POST) > 0 then
   local changed = false

   if not isEmptyString(_POST["ntp_sync_enabled"]) then
      date_time_config.ntp_sync.enabled = ternary(_POST["ntp_sync_enabled"] == "1", true, false)
      changed = true
   end

   if not isEmptyString(_POST["timezone_name"]) then
      date_time_config.timezone = _POST["timezone_name"]
      changed = true
   end

   if _POST["custom_date_str"] ~= _POST["custom_date_str_orig"] and _POST["ntp_sync_enabled"] == "0" then
      date_time_config.custom_date = _POST["custom_date_str"]
      default_custom_date = makeTimeStamp(_POST["custom_date_str"])
      -- must save the time of the request: if one clicks apply after 10 minutes
      -- we must add ten minutes to the date_time_config.custom_date before actually applying!
      -- Also, always use UTC so there's no issue with timezones
      date_time_config.custom_date_set_req = os.time(os.date("!*t", now))
      changed = true
   end

   if changed then
      nf_config:setDateTimeConfig(date_time_config)
      nf_config:save()
   end
end

local print_page_body = function()
   local date_time_config = nf_config:getDateTimeConfig()

   local timezone_keys, timezone_values = {}, {}
   for k, v in ipairs(timezones) do
      timezone_keys[#timezone_keys + 1] = k
      timezone_values[#timezone_values + 1 ] = v
   end

   printPageSection(i18n("nedge.timezone"))
   prefsDropdownFieldPrefs(i18n("nedge.timezone"), i18n("nedge.timezone_descr"), "timezone_name", timezone_values, date_time_config.timezone or system_timezone, true)

   printPageSection(i18n("nedge.date_time"))

   local dateTimeElementsToSwitch = {"custom_date_str",}

   prefsToggleButton(subpage_active, {
      title = i18n("nedge.ntp_sync"),
      description = i18n("nedge.ntp_sync_descr"),
      content = "",
      field = "ntp_sync_enabled",
      default = ternary(date_time_config.ntp_sync.enabled, "1", "0"),
      to_switch = dateTimeElementsToSwitch,
      pref = "",
      redis_prefix = "",
      reverse_switch = true,
   })

   local showEnabled = ternary(date_time_config.ntp_sync.enabled, false, true)
   system_setup_ui_utils.prefsDateTimeFieldPrefs(i18n("nedge.custom_datetime"), i18n("nedge.custom_datetime_descr"), "custom_date_str",
					      ternary(default_custom_date, default_custom_date, now), showEnabled)

   printSaveButton()
end

system_setup_ui_utils.print_setup_page(print_page_body, nf_config, warnings)

