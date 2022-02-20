--
-- (C) 2019-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local alerts_api = require("alerts_api")
local checks = require("checks")
local alert_consts = require("alert_consts")

local script

-- #################################################################

local function check_ids_ips_log(params)
   local alert_consts = require "alert_consts"
   local info = params.entity_info
   local drop_host_pool_utils = require "drop_host_pool_utils"

   -- Emit an alert for each host added to the jailed hosts pool
   local num_pending = ntop.llenCache(drop_host_pool_utils.ids_ips_jail_add_key)
   for i = 1, num_pending do
      local added_host = ntop.lpopCache(drop_host_pool_utils.ids_ips_jail_add_key)

      if not added_host then
	 goto continue
       end

      local alert = alert_consts.alert_types.alert_ids_ips_jail_add.new(
	 added_host,
	 os.time()
      )

      alert:set_score_notice()
      alert:set_subtype(added_host)
      alert:set_granularity(params.granularity)

      alert:store(params.alert_entity, nil, params.cur_alerts)

      ::continue::
   end

   -- Emit an alert for each host added to the jailed hosts pool
   local num_pending = ntop.llenCache(drop_host_pool_utils.ids_ips_jail_remove_key)
   for i = 1, num_pending do
      local removed_host = ntop.lpopCache(drop_host_pool_utils.ids_ips_jail_remove_key)

      if not removed_host then
	 goto continue
      end

      local alert = alert_consts.alert_types.alert_ids_ips_jail_remove.new(
	 removed_host,
	 os.time()
      )

      alert:set_score_notice()
      alert:set_subtype(removed_host)
      alert:set_granularity(params.granularity)

      alert:store(params.alert_entity, nil, params.cur_alerts)

      ::continue::
   end
end

-- #################################################################

script = {
   -- Script category
   category = checks.check_categories.ids_ips,

   default_enabled = false,

   hooks = {
      min = check_ids_ips_log,
   },

   gui = {
      i18n_title = "show_alerts.ids_ips_log",
      i18n_description = "show_alerts.ids_ips_log_descr",
   }
}

-- #################################################################

return script
