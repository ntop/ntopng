--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")
local alert_severities = require "alert_severities"
local alert_consts = require("alert_consts")
local json = require("dkjson")

local script = {
   category = user_scripts.script_categories.network,

   -- See below
   hooks = {},

   -- This script is disabled by default
   default_enabled = false,

   gui = {
      i18n_title = "snmp.lldp_topology_changed_title",
      i18n_description = "snmp.lldp_topology_changed_description",
   },
}

-- #################################################################

function script.setup()
   -- SNMP is only available in the ntopng Enterprise M edition
   return(ntop.isEnterpriseM())
end

-- #################################################################

local function storeTopologyChangedAlert(info, arc, nodes, subtype)
   local parts = split(arc, "@")

   if(#parts == 2) then
      local alert_type = alert_consts.alert_types.alert_snmp_topology_changed.create(
	 alert_severities.warning,
	 subtype,
	 info.granularity,
	 parts[1], -- node1
	 nodes[parts[1]], -- ip1
	 parts[2], -- node2
	 nodes[parts[2]] -- ip2
      )

      alerts_api.store(info.alert_entity, alert_type)
   end
end

-- #################################################################

-- In order to detect changes in the network topology, the connections
-- between SNMP devices (arcs in the topology chart) are compared with
-- the previosly saved connections.
function script.hooks.snmpDevice(device_ip, info)
   local snmp_utils = require "snmp_utils"
   -- The previos arcs are saved to be compared with the current arcs
   local arcs_key = "ntopng.cache.snmp_topology_arcs_monitor." .. device_ip
   local old_arcs = ntop.getPref(arcs_key)

   if not isEmptyString(old_arcs) then
      old_arcs = json.decode(old_arcs) or {}
   else
      old_arcs = {}
   end

   local nodes, arcs = snmp_utils.snmp_load_devices_topology(device_ip)
   local is_first_run = table.empty(old_arcs)
   local new_arcs = {}

   -- Detect new arcs between devices.
   for arc in pairs(arcs) do
      if(not is_first_run) then
         if(not old_arcs[arc]) then
            storeTopologyChangedAlert(info, arc, nodes, "arc_added")
         else
            old_arcs[arc] = nil
         end
      end

      new_arcs[arc] = true
   end

   for arc in pairs(old_arcs) do
      storeTopologyChangedAlert(info, arc, nodes, "arc_removed")
   end

   ntop.setPref(arcs_key, json.encode(new_arcs))
end

-- #################################################################

return script
