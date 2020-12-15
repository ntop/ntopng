--
-- (C) 2018 - ntop.org
--
-- This file contains the alert constats

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local alert_severities = require "alert_severities"
local alert_consts = {}
local alert_keys = require "alert_keys"
local alert = require "alert" -- The alert base class
local format_utils  = require "format_utils"
local os_utils = require("os_utils")
local plugins_utils = require("plugins_utils")
local lua_path_utils = require "lua_path_utils"
require("ntop_utils")

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  -- NOTE: import snmp_utils below to avoid import cycles
end

-- NOTE: sqlite can handle about 10-50 alerts/sec
alert_consts.MAX_NUM_QUEUED_ALERTS_PER_MODULE = 1024 -- should match ALERTS_MANAGER_MAX_ENTITY_ALERTS

alert_consts.MAX_NUM_QUEUED_ALERTS_PER_RECIPIENT = 4096

-- ##############################################

-- Groups for alert severities to obtain coarser-grained groups of finer-grained alert severities.
-- Used when grouping flow status severities into groups (shown in the UI header bar and flows page drilldown)
--
-- NOTE: keep it in sync with ntop_typedefs.h AlertLevelGroup
--
alert_consts.severity_groups = {
   group_none = {
      severity_group_id = 0,
      i18n_title = "severity_groups.group_none",
   },
   notice_or_lower = {
      severity_group_id = 1,
      i18n_title = "severity_groups.group_notice_or_lower",
   },
   warning = {
      severity_group_id = 2,
      i18n_title = "severity_groups.group_warning",
   },
   error_or_higher = {
      severity_group_id = 3,
      i18n_title = "severity_groups.group_error_or_higher",
   },
}

-- ##############################################

-- See flow_consts.status_types in flow_consts for flow alerts

-- Keep in sync with ntop_typedefs.h:AlertEntity
alert_consts.alert_entities = {
   interface = {
    entity_id = 0,
    label = "Interface",
    pools = "interface_pools", -- modules/pools/interface_pools.lua
   }, host = {
    entity_id = 1,
    label = "Host",
    pools = "host_pools", -- modules/pools/host_pools.lua
   }, network = {
    entity_id = 2,
    label = "Network",
    pools = "local_network_pools", -- modules/pools/local_network_pools.lua
   }, snmp_device = {
    entity_id = 3,
    label = "SNMP device",
    pools = "snmp_device_pools", -- modules/pools/snmp_device_pools.lua
   }, flow = {
    entity_id = 4,
    label = "Flow",
    pools = "flow_pools", -- modules/pools/flow_pools.lua
   }, mac = {
    entity_id = 5,
    label = "Device",
    pools = "mac_pools", -- modules/pools/mac_pools.lua
   }, host_pool = {
    entity_id = 6,
    label = "Host Pool",
    pools = "host_pool_pools", -- modules/pools/host_pool_pools.lua
   }, process = {
    entity_id = 7,
    label = "Process",
    pools = "system_pools", -- modules/pools/system_pools.lua
   }, user = {
    entity_id = 8,
    label = "User",
    pools = "system_pools", -- modules/pools/system_pools.lua
   }, influx_db = {
    entity_id = 9,
    label = "Influx DB",
    pools = "system_pools", -- modules/pools/system_pools.lua
   }, test = {
    entity_id = 10,
    label = "Test",
    pools = "system_pools", -- modules/pools/system_pools.lua
   }, category_lists = {
    entity_id = 11,
    label = "Category Lists",
    pools = "system_pools", -- modules/pools/system_pools.lua
   }, am_host = {
    entity_id = 12,
    label = "Active Monitoring Host",
    pools = "active_monitoring_pools", -- modules/pools/active_monitoring_pools.lua
   }, periodic_activity = {
    entity_id = 13,
    label = "Periodic Activity",
    pools = "system_pools", -- modules/pools/system_pools.lua
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

-- ##############################################

local alert_entities_id_to_key = {}
local alert_severities_id_to_key = {}
local alerts_granularities_id_to_key = {}
local alerts_granularities_seconds_to_key = {}

local function initMappings()
   -- alert_entities_id_to_key
   for key, entity_info in pairs(alert_consts.alert_entities) do
      alert_entities_id_to_key[entity_info.entity_id] = key
   end

   -- alert_severities_id_to_key 
   for key, severity_info in pairs(alert_severities) do
      alert_severities_id_to_key[severity_info.severity_id] = key
   end

   -- alerts_granularities_id_to_key 
   for key, granularity_info in pairs(alert_consts.alerts_granularities) do
     alerts_granularities_id_to_key[granularity_info.granularity_id] = key
   end

   -- alerts_granularities_seconds_to_key
   for key, granularity_info in pairs(alert_consts.alerts_granularities) do
     alerts_granularities_seconds_to_key[granularity_info.granularity_seconds] = key
   end
end

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
	 if hostinfo2hostkey(host_info) ~= value then
	    -- Avoid overwriting the IP
	    value = string.format("%s [%s]", hostinfo2hostkey(host_info), value)
	 end

	 value = hostinfo2detailshref(host_info, {page = "historical", epoch_begin = epoch_begin, epoch_end = epoch_end}, value, nil, true --[[ check if the link brings to an active page]])
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
      local host_pools = require "host_pools"

      -- Instantiate host pools
      local host_pools_instance = host_pools:create()

      value = host_pools_instance:get_pool_name(entity_value)
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
   return hostinfo2detailsurl({host = host, vlan = vlan_id})
end

-- ##############################################

function getHostPoolUrl(pool_id)
   return ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?pool=" .. pool_id
end

-- ##############################################

local function showSnmpUrl(snmp_device)
   local show_url = true

   if ntop.isPro() then
      local snmp_config = require "snmp_config"
      local device_config = snmp_config.get_device_config(snmp_device)

      if not device_config then
	 show_url = false
      end
   elseif not snmp_device then
      show_url = false
   end

   return show_url
end

-- ##############################################

function snmpDeviceUrl(snmp_device)
   if showSnmpUrl(snmp_device) then
      return ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_device_details.lua?host=%s", snmp_device)
   end

   return "#"
end

-- ##############################################

function snmpIfaceUrl(snmp_device, interface_idx)
   if showSnmpUrl(snmp_device) then
      return ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_interface_details.lua?host=%s&snmp_port_idx=%d", snmp_device, interface_idx)
   end

   return "#"
end

-- ##############################################

function alert_consts.getDefinititionDirs()
   local dirs = ntop.getDirs()

   return({
	 -- Path for ntopng-defined builtin alerts
	 os_utils.fixPath(dirs.installdir .. "/scripts/lua/modules/alert_definitions"),
	 -- Path for user-defined alerts written in plugins
	 os_utils.fixPath(plugins_utils.getRuntimePath() .. "/alert_definitions"),
	  }
   )
end

-- ##############################################

function alert_consts.alertEntityRaw(entity_id)
   entity_id = tonumber(entity_id)
   return alert_entities_id_to_key[entity_id]
end

function alert_consts.alertEntityById(entity_id)
   entity_id = tonumber(entity_id)
   return alert_consts.alert_entities[alert_entities_id_to_key[entity_id]]
end

function alert_consts.alertEntity(v)
   return(alert_consts.alert_entities[v].entity_id)
end

function alert_consts.alertEntityLabel(v)
  local entity_id = alert_consts.alertEntityRaw(v)

  if(entity_id) then
    return(alert_consts.alert_entities[entity_id].label)
  end
end

-- ##############################################

-- NOTE: flow alerts are formatted based on their status. See flow_consts.status_types.
-- See alert_consts.resetDefinitions()
alert_consts.alert_types = {}
local alerts_by_id      = {} -- All available alerts keyed by alert id
local alerts_by_flow_status_id = {} -- All available FLOW alerts keyed by flow status id

local function loadAlertsDefs()
   if(false) then
      if(string.find(debug.traceback(), "second.lua")) then
         traceError(TRACE_WARNING, TRACE_CONSOLE, "second.lua is loading alert_consts.lua. This will slow it down!")
      end
   end

   local defs_dirs = alert_consts.getDefinititionDirs()

   for _, defs_dir in pairs(defs_dirs) do
      lua_path_utils.package_path_prepend(defs_dir)

      for fname in pairs(ntop.readdir(defs_dir)) do
         if string.ends(fname, ".lua") then
            local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
            local def_script = require(mod_fname)

            if(def_script == nil) then
	       traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Error loading alert definition from %s", mod_fname))
	       goto next_script
            end

            if not alert_consts.loadDefinition(def_script, mod_fname, defs_dir) then
	       -- Retry reload
	       package.loaded[mod_fname] = nil
	    end
         end

         ::next_script::
      end
   end
end

-- ##############################################

-- @brief Cleanup all the currently loaded alert definitions from the current vm.
--        This will cause subsequent new `require`s to be performed.
--        It is only necessary to call this method when alert definitions are changed,
--        i.e., upon plugins reload, or when a license expires.
function alert_consts.resetDefinitions()
   alert_consts.alert_types = {}
   alerts_by_id = {}

   local defs_dirs = alert_consts.getDefinititionDirs()

   for _, defs_dir in pairs(defs_dirs) do
      lua_path_utils.package_path_prepend(defs_dir)

      for fname in pairs(ntop.readdir(defs_dir)) do
         if string.ends(fname, ".lua") then
            local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
	    package.loaded[mod_fname] = nil
	 end
      end
   end
end

-- ##############################################

function alert_consts.loadDefinition(def_script, mod_fname, script_path)
   local required_fields = {"alert_key", "i18n_title", "icon"}

   if mod_fname ~= "alert_host_new_api_demo" and mod_fname ~= "alert_flow_new_api_demo" then -- TODO: remove when new api migration done
      -- Check the required fields
      for _, k in pairs(required_fields) do
	 if(def_script[k] == nil) then
	    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing required field '%s' in %s from %s", k, mod_fname, script_path))
	    return(false)
	 end
      end

      -- Sanity check: make sure this is a valid alert key
      local parsed_alert_key, status = alert_keys.parse_alert_key(def_script.alert_key)
      if not parsed_alert_key then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Invalid alert key specified %s in %s from %s", status, mod_fname, script_path))
	 return(false)
      end

      if(alerts_by_id[parsed_alert_key] ~= nil) then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Alert key %d redefined, skipping in %s from %s", parsed_alert_key, mod_fname, script_path))
	 return(false)
      end

      -- Save the original creator to wrap it with the aim of attaching the `alert_type`
      -- This avoids repeating the alert type twice in every alert definition file
      local cur_creator = def_script.creator
      local creator = function(...)
	 local created = {}

	 if cur_creator then
	    created = cur_creator(...)
	 end

	 created["alert_type"] = def_script
	 return created
      end

      def_script.alert_key = parsed_alert_key
      def_script.create = creator
      alert_consts.alert_types[mod_fname] = def_script
      alerts_by_id[parsed_alert_key] = mod_fname

      -- Success
      return(true)
   else -- EXPERIMENTAL: will become new API

      -- Check the required metadata fields
      for _, k in pairs(required_fields) do
	 if(def_script.meta[k] == nil) then
	    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing required field '%s' in %s from %s", k, mod_fname, script_path))
	    return(false)
	 end
      end

      -- Sanity check: make sure this is a valid alert key
      local parsed_alert_key, status = alert_keys.parse_alert_key(def_script.meta.alert_key)
      if not parsed_alert_key then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Invalid alert key specified %s in %s from %s", status, mod_fname, script_path))
	 return(false)
      end

      if(alerts_by_id[parsed_alert_key] ~= nil) then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Alert key %d redefined, skipping in %s from %s", parsed_alert_key, mod_fname, script_path))
	 return(false)
      end

      if def_script.meta.status_key and alerts_by_flow_status_id[def_script.meta.status_key] then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Status key %d redefined, skipping in %s from %s", def_script.meta.status_key, mod_fname, script_path))
	 return(false)
      end

      def_script.meta.alert_key = parsed_alert_key
      alert_consts.alert_types[mod_fname] = def_script
      alerts_by_id[parsed_alert_key] = mod_fname
      if def_script.meta.status_key then
	 -- Add the module to the modules table keyd by flow status - if flow status is present for this alert
	 alerts_by_flow_status_id[def_script.meta.status_key] = mod_fname
      end

      -- Success
      return(true)
   end
end
 
-- ##############################################

function alert_consts.alertTypeLabel(v, nohtml)
   local alert_key = alert_consts.alertTypeRaw(v)

   if(alert_key) then
      local type_info = alert_consts.alert_types[alert_key]
      -- TODO: .meta is the new format, OR are for compatibility and can be removed when migration is done
      local title = i18n(type_info.i18n_title or type_info.meta.i18n_title) or type_info.i18n_title or type_info.meta.i18n_title

      if(nohtml) then
        return(title)
      else
        return(string.format('<i class="%s"></i> %s', type_info.icon or type_info.meta.icon, title))
      end
   end

   return(i18n("unknown"))
end
 
-- ##############################################

-- @brief Returns the label of an alert, given the flow status the alert is associated to
function alert_consts.statusTypeLabel(flow_status_key, nohtml)
   local alert_key = alert_consts.flowStatusTypeRaw(flow_status_key)

   if alert_key then
      return alert_consts.alertTypeLabel(alert_consts.alertType(alert_key), nohtml)
   end

   return i18n("unknown")
end

-- ##############################################

function alert_consts.alertType(v)
   if(alert_consts.alert_types[v] == nil) then
      tprint(debug.traceback())
   end

   local res = alert_consts.alert_types[v].alert_key

   if not res and alert_consts.alert_types[v].meta then
      -- TODO AM: attempt at looking inside new implementation `meta`
      res = alert_consts.alert_types[v].meta.alert_key
   end

   return res
 end

-- ##############################################

function alert_consts.getAlertType(alert_key)
    return(alerts_by_id[tonumber(alert_key)])
end

-- ##############################################

function alert_consts.alertLevelToSyslogLevel(v)
   return alert_severities[alert_consts.alertSeverityRaw(v)].syslog_severity
end

-- ################################################################################

function alert_consts.alertSeverityRaw(severity_id)
   severity_id = tonumber(severity_id)
   return alert_severities_id_to_key[severity_id] 
end

 -- ################################################################################

function alert_consts.alertSeverityLabel(v, nohtml, emoji)
   local severity_id = alert_consts.alertSeverityRaw(v)

   if(severity_id) then
      local severity_info = alert_severities[severity_id]
      local title = i18n(severity_info.i18n_title) or severity_info.i18n_title

      if(emoji) then
	 title = (severity_info.emoji or "").. " " .. title
      end
      
      if(nohtml) then
        return(title)
      else
        return(string.format('<span class="badge %s">%s</span>', severity_info.label, title))
      end
   end

   return "(unknown severity)"
end

-- ################################################################################

function alert_consts.alertSeverity(v)
   return(alert_severities[v].severity_id)
end
 
-- ################################################################################

function alert_consts.alertSeverityById(severity_id)
   local key = alert_consts.alertSeverityRaw(severity_id)
   if key == nil then 
      return alert_severities.error
   end
   return(alert_severities[key])
end

-- ################################################################################
 
function alert_consts.alertTypeRaw(type_id)
   type_id = tonumber(type_id)
   return alerts_by_id[type_id]
end

-- ################################################################################
 
function alert_consts.flowStatusTypeRaw(flow_status_type_id)
   flow_status_type_id = tonumber(flow_status_type_id)
   return alerts_by_flow_status_id[flow_status_type_id]
end

 -- ################################################################################

-- Rename engine -> granulariy
local function alertEngineRaw(granularity_id)
   granularity_id = tonumber(granularity_id)
   return alerts_granularities_id_to_key[granularity_id] 
end
 
-- ################################################################################
 
function alert_consts.alertEngine(v)
   if(alert_consts.alerts_granularities[v] == nil) then
      tprint(debug.traceback())
   end

   return(alert_consts.alerts_granularities[v].granularity_id)
end

-- ################################################################################

function alert_consts.alertEngineLabel(v)
   local granularity_id = alertEngineRaw(v)
 
   if(granularity_id ~= nil) then
     return(i18n(alert_consts.alerts_granularities[granularity_id].i18n_title))
   end
 end

 -- ################################################################################

function alert_consts.granularity2sec(v)
   if(alert_consts.alerts_granularities[v] == nil) then
      tprint(debug.traceback())
   end

  return(alert_consts.alerts_granularities[v].granularity_seconds)
end

-- ################################################################################

-- See NetworkInterface::checkHostsAlerts()
function alert_consts.granularity2id(granularity)
   -- TODO replace alertEngine
   return(alert_consts.alertEngine(granularity))
end

-- ################################################################################

function alert_consts.sec2granularity(seconds)
   seconds = tonumber(seconds)
   return alerts_granularities_seconds_to_key[seconds]
end
 
-- Load definitions now
loadAlertsDefs()
initMappings()

return alert_consts
