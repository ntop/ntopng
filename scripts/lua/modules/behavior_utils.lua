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
   },
   network = {
      page_path = "/lua/network_details.lua",
      timeseries_id = "network",
      schema_id = "subnet",
   }
}

-- ##############################################

function behavior_utils.get_behavior_timeseries_utils(family_key)
   return behavior_table[family_key]
end

-- ##############################################

return behavior_utils