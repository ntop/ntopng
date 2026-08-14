--
-- (C) 2019-26 - ntop.org
--

local alert_consts = require("alert_consts")
local alerts_api = require("alerts_api")
local checks = require("checks")
local storage_utils = require("storage_utils")

-- #################################################################

local script = {
   -- Script category
   category = checks.check_categories.system,

   default_enabled = true,
   default_value = {
      -- "> 90%"
      operator = "gt",
      threshold = 90,
   },

   severity = alert_consts.get_printable_severities().error,
   hooks = {},

   gui = {
      i18n_title = "alerts_dashboard.disk_space_low",
      i18n_description = "alerts_dashboard.disk_space_low_descr",
      i18n_field_unit = checks.field_units.percentage,
      input_builder = "threshold_cross",
      field_max = 99,
      field_min = 1,
      field_operator = "gt",
   }
}

-- #################################################################

-- @brief Checks a single volume against the configured threshold, triggering
--        or releasing the alert identified by `subtype`
local function check_volume(params, threshold, subtype, mount, used_perc, avail_bytes)
   if used_perc == nil then
      return
   end

   local alert = alert_consts.alert_types.alert_disk_space_low.new(
      mount,
      used_perc,
      avail_bytes,
      threshold
   )

   alert:set_info(params)
   alert:set_subtype(subtype)

   local entity_info = alerts_api.systemEntity()

   if used_perc > threshold then
      alert:trigger(entity_info, nil, params.cur_alerts)
   else
      alert:release(entity_info, nil, params.cur_alerts)
   end
end

-- #################################################################

local function check_disk_space_low(params)
   -- Windows does not support the `df` command used to compute storage info
   if ntop.isWindows() then
      return
   end

   -- Read the cached storage info (refreshed hourly)
   local storage_info = storage_utils.storageInfo(false --[[ do not refresh cache ]])

   if not storage_info then
      return
   end

   local threshold = tonumber(params.check_config.threshold)

   check_volume(params, threshold, "system", storage_info.volume_mount,
      storage_info.volume_used_perc, storage_info.volume_avail)

   if storage_info.pcap_volume_used_perc ~= nil then
      check_volume(params, threshold, "pcap", storage_info.pcap_volume_mount,
         storage_info.pcap_volume_used_perc, storage_info.pcap_volume_avail)
   end
end

-- #################################################################

script.hooks.min = check_disk_space_low

-- #################################################################

return script
