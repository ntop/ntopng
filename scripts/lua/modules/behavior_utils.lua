--
-- (C) 2020-21 - ntop.org
--

local behavior_utils = {}

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

-- ##############################################

return behavior_utils