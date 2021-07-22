--
-- (C) 2020-21 - ntop.org
--

local rest_utils = require("rest_utils")
local json = require("dkjson")
local callback_utils = require("callback_utils")

local behavior_utils = {}
local redis_key = "changed_behavior_learning_setup"
local behavior_maps_key = "ntopng.prefs.is_behaviour_analysis_enabled"
local behavior_mac_ip_mapping = "ntopng.cache.mac_ip_mapping"
local mac_ip_table = {}
local SEC_BEFORE_EXPIRE = 420 -- 7 mins

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

function behavior_utils.change_behavior_learning_status()
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

function behavior_utils.mapMacIp(hostname, hoststats)
    if not mac_ip_table[hoststats["mac"]] then
        mac_ip_table[hoststats["mac"]] = {}
    end

    mac_ip_table[hoststats["mac"]][#mac_ip_table[hoststats["mac"]] + 1] = hostname
end

-- ##############################################

function behavior_utils.updateMacs()
    mac_ip_table = {}
    callback_utils.foreachLocalHost(interface.getName(), behavior_utils.mapMacIp)
    ntop.setCache(behavior_mac_ip_mapping, json.encode(mac_ip_table), SEC_BEFORE_EXPIRE)
    return mac_ip_table 
end

-- ##############################################

function behavior_utils.getMacs()
    mac_ip_table = ntop.getCache(behavior_mac_ip_mapping)

    if not isEmptyString(mac_ip_table) then
        return json.decode(mac_ip_table)
    end

    return {}
end

-- ##############################################

-- Returns two bools value, one for service map and the other for periodicity map
function behavior_utils.mapsAvailable()
    local service_map_available = false
    local periodic_map_available = false  

    if areMapsEnabled() then
        local service_map = interface.serviceMap(nil, 0, 0, false, 0, '') or {}
        local periodicity_map = interface.periodicityMap(nil, 0, 0, false, 0, '') or {}

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