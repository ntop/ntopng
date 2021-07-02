--
-- (C) 2020-21 - ntop.org
--

local rest_utils = require("rest_utils")

local behavior_utils = {}
local redis_key = "changed_behavior_alert_setup"
local behavior_maps_key = "ntopng.prefs.is_behaviour_analysis_enabled"

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

local maps_utils = {}


-- ##############################################

local function areMapsEnabled()
  return(ntop.isEnterpriseL() and ntop.isAdministrator() and (ntop.getPref(behavior_maps_key) == "1"))
end

-- ##############################################

-- Returns two bools value, one for service map and the other for periodicity map
function behavior_utils.mapsAvailable()
  local service_map_available = false
  local periodic_map_available = false  

  if areMapsEnabled() then
    local service_map = interface.serviceMap()
    local periodicity_map = interface.periodicityMap()

    if service_map and (table.len(service_map) > 0) then
      service_map_available = true
    end

    if periodicity_map and (table.len(periodicity_map) > 0) then
      periodic_map_available = true
    end
  end

  return service_map_available, periodic_map_available
end

-- ##############################################

return behavior_utils