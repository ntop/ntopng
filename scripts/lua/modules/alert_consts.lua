--
-- (C) 2018 - ntop.org
--
-- This file contains the alert constats

local alert_consts = {}
local alert_keys = require "alert_keys"
local format_utils  = require "format_utils"
local os_utils = require("os_utils")
local plugins_utils = require("plugins_utils")
require("ntop_utils")

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  -- NOTE: import snmp_utils below to avoid import cycles
end

-- NOTE: sqlite can handle about 10-50 alerts/sec
alert_consts.MAX_NUM_QUEUED_ALERTS_PER_MODULE = 1024 -- should match ALERTS_MANAGER_MAX_ENTITY_ALERTS

-- Alerts (see ntop_typedefs.h)
-- each table entry is an array as:
-- {"alert html string", "alert C enum value", "plain string", "syslog severity"}
alert_consts.alert_severities = {
  info = {
    severity_id = 0,
    label = "badge-info",
    i18n_title = "alerts_dashboard.info",
    syslog_severity = 6,
  }, warning = {
    severity_id = 1,
    label = "badge-warning",
    i18n_title = "alerts_dashboard.warning",
    syslog_severity = 4,
  }, error = {
    severity_id = 2,
    label = "badge-danger",
    i18n_title = "alerts_dashboard.error",
    syslog_severity = 3,
  }
}

-- ##############################################

function alert_consts.formatAlertEntity(ifid, entity_type, entity_value)
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
        "'>"..getHumanReadableInterfaceName(getInterfaceName(ifid)).."</a>"
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
   return(os_utils.fixPath(plugins_utils.getRuntimePath() .. "/alert_definitions"))
end

-- ##############################################

function alert_consts.alertEntityRaw(entity_id)
  entity_id = tonumber(entity_id)

  for key, entity_info in pairs(alert_consts.alert_entities) do
    if(entity_info.entity_id == entity_id) then
      return(key)
    end
  end
end

function alert_consts.alertEntity(v)
   return(alert_consts.alert_entities[v].entity_id)
end

function alert_consts.alertEntityLabel(v, nothml)
  local entity_id = alert_consts.alertEntityRaw(v)

  if(entity_id) then
    return(alert_consts.alert_entities[entity_id].label)
  end
end

-- ##############################################

-- NOTE: flow alerts are formatted based on their status. See flow_consts.status_types.
-- See alert_consts.resetDefinitions()
alert_consts.alert_types = {}
local alerts_by_id = {}

local function loadAlertsDefs()
   if(false) then
      if(string.find(debug.traceback(), "second.lua")) then
         traceError(TRACE_WARNING, TRACE_CONSOLE, "second.lua is loading alert_consts.lua. This will slow it down!")
      end
   end

   local dirs = ntop.getDirs()
   local defs_dirs = {alert_consts.getDefinititionsDir()}

   if ntop.isPro() then
      defs_dirs[#defs_dirs + 1] = alert_consts.getDefinititionsDir() .. "/pro"
   end

   alert_consts.resetDefinitions()

   for _, defs_dir in pairs(defs_dirs) do
      for fname in pairs(ntop.readdir(defs_dir)) do
         if string.ends(fname, ".lua") then
            local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
            local full_path = os_utils.fixPath(defs_dir .. "/" .. fname)
            local def_script = dofile(full_path)

            if(def_script == nil) then
                traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Error loading alert definition from %s", full_path))
                goto next_script
            end

            alert_consts.loadDefinition(def_script, mod_fname, full_path)
         end

         ::next_script::
      end
   end
end

-- ##############################################

function alert_consts.resetDefinitions()
   alert_consts.alert_types = {}
   alerts_by_id = {}
end

-- ##############################################

function alert_consts.loadDefinition(def_script, mod_fname, script_path)
   local required_fields = {"alert_key", "i18n_title", "icon"}

   -- Check the required fields
   for _, k in pairs(required_fields) do
      if(def_script[k] == nil) then
         traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing required field '%s' in %s", k, script_path))
         return(false)
      end
   end

   -- local def_id = tonumber(def_script.alert_id)
   local def_id = def_script.alert_key

   if(def_id == nil) then
       traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("%s: missing alert ID", script_path))
       return(false)
   end

   -- Sanity check: make sure this is a valid alert key
   local valid = false
   for pen, pen_keys in pairs(alert_keys) do
      for _, key in pairs(pen_keys) do
	 if key == def_id then
	    valid = true
	    break
	 end
      end
   end

   if not valid then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("%s: unknown alert ID", script_path))
      return(false)
   end

   if(alerts_by_id[def_id] ~= nil) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("%s: alert ID %d redefined, skipping", script_path, def_id))
      return(false)
   end

   def_script.alert_id = def_id
   alert_consts.alert_types[mod_fname] = def_script
   alerts_by_id[def_id] = mod_fname

   -- Success
   return(true)
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
    label = "RTT",
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
