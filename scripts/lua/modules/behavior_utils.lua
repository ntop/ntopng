--
-- (C) 2020-21 - ntop.org
--

local rest_utils = require("rest_utils")

local behavior_utils = {}
local redis_key = "changed_behavior_alert_setup"

-- ##############################################

local behavior_table = {
   asn = {
      page_path = "/lua/as_details.lua",
      timeseries_id = "asn",
      schema_id = "asn",
      page = "historical",
   },
   network = {
      page_path = "/lua/network_details.lua",
      timeseries_id = "network",
      schema_id = "subnet",
      page = "historical",
   },
   l7 = {
      page_path = "/lua/if_stats.lua",
      schema_id = "iface",
      page = "historical",
      type_of_behavior = "ndpi",
   }
}

-- ##############################################

function behavior_utils.get_behavior_timeseries_utils(family_key)
   return behavior_table[family_key]
end

function behavior_utils.change_behavior_alert_status()
   -- Set the redis key for the restart
   ntop.setCache(redis_key, true)
   rest_utils.answer(rest_utils.consts.success.ok, res)
end

-- ##############################################

function behavior_utils.restart_required()
    if ntop.getCache(redis_key) == '' then
        return false
    end

    return true
end

-- ##############################################

function behavior_utils.reset()
    if ntop.getCache(redis_key) ~= '' then
        ntop.delCache(redis_key)
    end
end


return behavior_utils