--
-- (C) 2020 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"
local user_scripts = require("user_scripts")

local script

-- #################################################################

-- Name of the cache key, created from a fixed name + ifid
local NO_ACTIVITY_PLUGIN_CACHE_KEY = "ntopng.cache.user_scripts.no_activity_plugins_enabled.ifid"


local function check_interface_activity(params)

  -- Get total number of packets, flows and interface id
  local num_packets = params.entity_info.eth.packets
  local num_flows = params.entity_info.stats.flows
  local ifid = tonumber(params.entity_info.id)
  local tmp_if_table = interface.getIfNames()

  -- Getting the interface name from the list of interfaces
  local ifname = tmp_if_table[tostring(ifid)]

  -- Creating a string, used to put into the redis cache the number of packets and flows
  local new_counters = num_packets .. "_" .. num_flows

  local no_if_activity_type = alert_consts.alert_types.alert_no_if_activity.create(
      alert_severities.error,
      alert_consts.alerts_granularities.min
  )

  local redis_key = NO_ACTIVITY_PLUGIN_CACHE_KEY .. ifname
  
  -- Get from the cache the previous number of total packets received
  local previous_counters = ntop.getCache(redis_key)

  previous_packets, previous_flows = string.match(previous_counters, "(.*)_(.*)")

  -- Check if the previous number it's equal to the actual number of both, packets and flows
  -- this distinction is done due to the fact that exist packet based interfaces
  -- and flow based interfaces
  if(tonumber(previous_packets) == num_packets and tonumber(previous_flows) == num_flows) then
    alerts_api.trigger(params.alert_entity, no_if_activity_type, nil, params.cur_alerts)

  else -- One of the two or both stats were different, so the interface is still active
    alerts_api.release(params.alert_entity, no_if_activity_type, nil, params.cur_alerts)
  end

  ntop.setCache(NO_ACTIVITY_PLUGIN_CACHE_KEY .. ifname, new_counters, 360)
end

-- #################################################################

script = {
  -- Script category
  category = user_scripts.script_categories.internals,

  default_enabled = true,
  hooks = {
    -- Time past between one call and an other
    --["5mins"] = check_interface_activity,
    min = check_interface_activity,
  },

  -- This script is only for alerts generation
  is_alert = true,

  gui = {
    i18n_title        = "no_if_activity.no_if_activity_title",
    i18n_description  = "no_if_activity.no_if_activity_description",
  }
}

-- #################################################################

function script.onEnable(hook, hook_config)
  ntop.setPref(NO_ACTIVITY_PLUGIN_CACHE_KEY, "1")
end

-- #################################################################

function script.onUnload(hook, hook_config)
  local tmp_table = interface.getIfNames()

  -- Removing the entries from the redis cache table
  for k in pairs(tmp_table) do 
    ntop.delCache(NO_ACTIVITY_PLUGIN_CACHE_KEY .. tmp_table[k]) 
  end
end

-- #################################################################

function script.onDisable(hook, hook_config)
  local tmp_table = interface.getIfNames()

  -- Removing the entries from the redis cache table
  for k in pairs(tmp_table) do 
    ntop.delCache(NO_ACTIVITY_PLUGIN_CACHE_KEY .. tmp_table[k]) 
  end
end

-- #################################################################

function script.onLoad(hook, hook_config)
  if hook_config and hook_config.enabled then
     ntop.setPref(NO_ACTIVITY_PLUGIN_CACHE_KEY, "1")
  end

end

-- #################################################################


return script
