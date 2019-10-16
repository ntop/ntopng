--
-- (C) 2018 - ntop.org
--
-- This file contains the alert constats

local alert_consts = {}
local locales_utils = require "locales_utils"
local format_utils  = require "format_utils"
local os_utils = require("os_utils")

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  -- NOTE: import snmp_utils below to avoid import cycles
end

-- Alerts (see ntop_typedefs.h)
-- each table entry is an array as:
-- {"alert html string", "alert C enum value", "plain string", "syslog severity"}
alert_consts.alert_severities = {
  info = {
    severity_id = 0,
    label = "label-info",
    i18n_title = "alerts_dashboard.info",
    syslog_severity = 6,
  }, warning = {
    severity_id = 1,
    label = "label-warning",
    i18n_title = "alerts_dashboard.warning",
    syslog_severity = 4,
  }, error = {
    severity_id = 2,
    label = "label-danger",
    i18n_title = "alerts_dashboard.error",
    syslog_severity = 3,
  }
}

-- ##############################################

-- Custom User Alerts
alert_consts.custom_alert_1 = 59
alert_consts.custom_alert_2 = 60
alert_consts.custom_alert_3 = 61
alert_consts.custom_alert_4 = 62
alert_consts.custom_alert_5 = 63

-- ##############################################

-- NOTE: the following formatting functions need to be global since they
-- are used inside the alert_defs scripts
function formatAlertEntity(ifid, entity_type, entity_value)
   require "flow_utils"
   local value
   local epoch_begin, epoch_end = getAlertTimeBounds({alert_tstamp = os.time()})
   local label = string.lower(alert_consts.alert_entities[entity_type].label)

   if entity_type == "host" then
      local host_info = hostkey2hostinfo(entity_value)
      value = resolveAddress(host_info)

      if host_info ~= nil then
	 value = "<a href='"..ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifid..
	    "&host="..hostinfo2hostkey(host_info).."&page=historical&epoch_begin="..
	    epoch_begin .."&epoch_end=".. epoch_end .."'>"..value.."</a>"
      end
   elseif entity_type == "interface" then
      value = "<a href='"..ntop.getHttpPrefix().."/lua/if_stats.lua?ifid="..ifid..
        "&page=historical&epoch_begin="..epoch_begin .."&epoch_end=".. epoch_end ..
        "'>"..getInterfaceName(ifid).."</a>"
   elseif entity_type == "network" then
      value = getLocalNetworkAlias(hostkey2hostinfo(entity_value)["host"])

      value = "<a href='"..ntop.getHttpPrefix().."/lua/network_details.lua?network_cidr="..
        entity_value.."&page=historical&epoch_begin=".. epoch_begin
         .."&epoch_end=".. epoch_end .."'>" ..value.."</a>"
   elseif entity_type == "host_pool" then
      host_pools_utils = require("host_pools_utils")
      value = host_pools_utils.getPoolName(ifid, entity_value)
   else
      -- fallback
      value = entity_value
   end

   -- try to get a localized message
   local localized = i18n("alert_messages."..entity_type.."_entity", {entity_value=value})

   if localized ~= nil then
      return localized
   else
      -- fallback
      return label.." "..value
   end
end

-- ##############################################

function getMacUrl(mac)
   return ntop.getHttpPrefix() .. "/lua/mac_details.lua?host=" .. mac
end

-- ##############################################

function getHostUrl(host, vlan_id)
   return ntop.getHttpPrefix() .. "/lua/host_details.lua?" .. hostinfo2url({host = host, vlan = vlan_id})
end

-- ##############################################

function getHostPoolUrl(pool_id)
   return ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?pool=" .. pool_id
end

-- ##############################################

function snmpDeviceUrl(snmp_device)
  return ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_device_details.lua?host=%s", snmp_device)
end

-- ##############################################

function snmpIfaceUrl(snmp_device, interface_idx)
  return ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_interface_details.lua?host=%s&snmp_port_idx=%d", snmp_device, interface_idx)
end

-- ##############################################

function alert_consts.getDefinititionsDir()
   return(os_utils.fixPath(dirs.installdir .. "/scripts/callbacks/alert_defs"))
end

-- ##############################################

-- NOTE: flow alerts are formatted based on their status. See flow_consts.status_types.
alert_consts.alert_types = {}
local alerts_by_id = {}

local function loadAlertsDefs()
   local dirs = ntop.getDirs()
   local defs_dir = alert_consts.getDefinititionsDir()
   package.path = defs_dir .. "/?.lua;" .. package.path
   local required_fields = {"alert_id", "i18n_title", "icon"}

   for fname in pairs(ntop.readdir(defs_dir)) do
      if ends(fname, ".lua") then
         local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
         local def_script = require(mod_fname)

         -- Check the required fields
         for _, k in pairs(required_fields) do
            if(def_script[k] == nil) then
               traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing required field '%s' in alert_defs/%s", k, fname))
               goto next_script
            end
         end

         local def_id = tonumber(def_script.alert_id)

         if(alerts_by_id[def_id] ~= nil) then
            traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("alert_defs/%s: alert ID %d redefined, skipping", fname, def_id))
            goto next_script
         end

         -- Success
         alert_consts.alert_types[mod_fname] = def_script
         alerts_by_id[def_id] = mod_fname
      end

      ::next_script::
   end
end

-- ##############################################

function alert_consts.getAlertType(alert_id)
    return(alerts_by_id[tonumber(alert_id)])
end

-- ##############################################

function alert_consts.alertLevelToSyslogLevel(v)
  return alert_consts.alert_severities[v].syslog_severity
end

-- ##############################################

-- See flow_consts.status_types in flow_consts for flow alerts
-- See Utils::flowStatus2AlertType to determine the alert_type for flow alerts

-- Keep in sync with ntop_typedefs.h:AlertEntity
alert_consts.alert_entities = {
   interface = {
    entity_id = 0,
    label = "Interface",
   }, host = {
    entity_id = 1,
    label = "Host",
   }, network = {
    entity_id = 2,
    label = "Network",
   }, snmp_device = {
    entity_id = 3,
    label = "SNMP device",
   }, flow = {
    entity_id = 4,
    label = "Flow",
   }, mac = {
    entity_id = 5,
    label = "Device",
   }, host_pool = {
    entity_id = 6,
    label = "Host Pool",
   }, process = {
    entity_id = 7,
    label = "Process",
   }, user = {
    entity_id = 8,
    label = "User",
   }, influx_db = {
    entity_id = 9,
    label = "Influx DB",
   }, test = {
    entity_id = 10,
    label = "Test",
   }, category_lists = {
    entity_id = 11,
    label = "Category Lists",
   }, pinged_host = {
    entity_id = 12,
    label = "PINGed host",
   }, periodic_activity = {
    entity_id = 13,
    label = "Periodic Activity",
  }
}

-- Keep in sync with C
alert_consts.alerts_granularities = {
   ["min"] = {
      granularity_id = 1,
      granularity_seconds = 60,
      i18n_title = "show_alerts.minute",
      i18n_description = "alerts_thresholds_config.every_minute",
   },
   ["5mins"] = {
      granularity_id = 2,
      granularity_seconds = 300,
      i18n_title = "show_alerts.5_min",
      i18n_description = "alerts_thresholds_config.every_5_minutes",
   },
   ["hour"] = {
      granularity_id = 3,
      granularity_seconds = 3600,
      i18n_title = "show_alerts.hourly",
      i18n_description = "alerts_thresholds_config.hourly",
   },
   ["day"] = {
      granularity_id = 4,
      granularity_seconds = 86400,
      i18n_title = "show_alerts.daily",
      i18n_description = "alerts_thresholds_config.daily",
   }
}

-- ################################################################################

alert_consts.ids_rule_maker = {
  GPL = "GPL",
  SURICATA = "Suricata",
  ET = "Emerging Threats",
}


-- ################################################################################

-- Load definitions now
loadAlertsDefs()

return alert_consts
