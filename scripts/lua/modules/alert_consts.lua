--
-- (C) 2021 - ntop.org
--
-- This file contains the alert constants

local clock_start = os.clock()

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/alert_keys/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "ntop_utils"
require "label_utils"
require "gui_utils"
require "lua_trace"
local alert_entities_utils = require "alert_entities_utils"
local os_utils = require "os_utils"
local alert_consts = {}

-- ###################################

-- These set of requires just import structs
local alert_severity_groups = require "alert_severity_groups"
local alert_granularities = require "alert_granularities"
local alert_severities = require "alert_severities"
local alert_categories = require "alert_categories"
local alert_entities = require "alert_entities"
local consts = require "consts"

-- ##############################################

alert_consts.categories = alert_categories
alert_consts.severity_groups = alert_severity_groups
alert_consts.alert_entities = alert_entities
alert_consts.alerts_granularities = alert_granularities
alert_consts.alertEntity = alert_entities_utils.alertEntity

-- ###################################

if (ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   -- NOTE: import snmp_utils below to avoid import cycles
end

alert_consts.SEPARATOR = consts.SEPARATOR
-- NOTE: sqlite can handle about 10-50 alerts/sec
alert_consts.MAX_NUM_QUEUED_ALERTS_PER_MODULE = 1024 -- should match ALERTS_MANAGER_MAX_ENTITY_ALERTS
alert_consts.MAX_NUM_QUEUED_ALERTS_PER_RECIPIENT = 4096
alert_consts.ALL_ALERT_KEY = 0 -- Special ID to select 'all' alerts

-- ##############################################

local function format_by_id()
   local f_categories = {}
   for cat, cat_v in pairs(alert_consts.categories) do
      if (cat ~= 'other') then
         f_categories[cat_v.id] = cat_v
      end
   end
   return f_categories
end

alert_consts.categories_id = format_by_id()

function alert_consts.get_category_by_id(id)
   if (id == 0) then return alert_consts.categories.other end
   return alert_consts.categories_id[id]
end

-- ################################################################################

-- This status is written in Clickhouse/SQLite column `alert_status`
alert_consts.alert_status = {
   ["historical"] = {
      -- Alerts written to the database that require attention
      alert_status_id = 0,
   },
   ["acknowledged"] = {
      -- Acknowledged (automatically or from the user) alerts written to the database
      alert_status_id = 1,
   },
   ["engaged"] = {
      -- Engaged (not actually used in the database as engaged alerts are in memory)
      alert_status_id = 2,
   },
   ["any"] = {
      -- Not actually used in the database (historical | acknowledged)
      alert_status_id = 3,
   },
}

-- ################################################################################

alert_consts.ids_rule_maker = {
   GPL = "GPL",
   SURICATA = "Suricata",
   ET = "Emerging Threats",
}

-- ##############################################

local function getAlertTimeBounds(alert, engaged)
   local epoch_begin
   local epoch_end
   local half_interval = 1800
   local alert_tstamp = alert.alert_tstamp

   if alert.first_switched and alert.last_switched then
       -- Flow alert
       epoch_begin = alert.first_switched - half_interval
       epoch_end = alert.last_switched + half_interval
   else
       local tend = ternary(engaged, os.time(), alert.alert_tstamp_end) or alert_tstamp
       -- tprint(debug.traceback())
       half_interval = math.max(half_interval, (tend - alert_tstamp) / 2) -- at least 1 hour interval
       local middle_time = (tend + alert_tstamp) / 2

       epoch_begin = middle_time - half_interval
       epoch_end = middle_time + half_interval
   end

   return math.floor(epoch_begin), math.floor(epoch_end)
end

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
      if severity_info.severity_id ~= 0 then
         alert_severities_id_to_key[severity_info.severity_id] = key
      end
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

function alert_consts.formatHostAlert(ifid, host, vlan)
   return hostinfo2label({ host = host, vlan = vlan }, vlan)
end

-- ##############################################

function alert_consts.formatAlertEntity(ifid, entity_type, entity_value)
   -- TODO: remove this dependency
   require "lua_utils_gui"
   local value
   local epoch_begin, epoch_end = getAlertTimeBounds({ alert_tstamp = os.time() })

   if entity_type == "host" then
      local host_info = hostkey2hostinfo(entity_value)
      value = resolveAddress(host_info)

      if host_info ~= nil then
         if hostinfo2hostkey(host_info) ~= value then
            -- Avoid overwriting the IP
            value = string.format("%s [%s]", hostinfo2hostkey(host_info), value)
         end

         value = hostinfo2detailshref(host_info, { page = "historical", epoch_begin = epoch_begin, epoch_end = epoch_end },
            value, nil, true --[[ check if the link brings to an active page]])
      end
   elseif entity_type == "interface" then
      value = "<a href='" .. ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=" .. ifid ..
          "&page=historical&epoch_begin=" .. epoch_begin .. "&epoch_end=" .. epoch_end ..
          "'>" .. getHumanReadableInterfaceName(getInterfaceName(ifid)) .. "</a>"
   elseif entity_type == "network" then
      value = getLocalNetworkAlias(hostkey2hostinfo(entity_value)["host"])

      value = "<a href='" .. ntop.getHttpPrefix() .. "/lua/network_details.lua?network_cidr=" ..
          entity_value .. "&page=historical&epoch_begin=" .. epoch_begin
          .. "&epoch_end=" .. epoch_end .. "'>" .. value .. "</a>"
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
   local localized = i18n("alert_messages." .. entity_type .. "_entity", { entity_value = value })

   if localized ~= nil then
      return localized
   else
      -- fallback
      return value
   end
end

-- ##############################################

function getMacUrl(mac)
   if not mac then
      return ""
   end
   return ntop.getHttpPrefix() .. "/lua/mac_details.lua?host=" .. mac
end

-- ##############################################

function getHostUrl(host, vlan_id)
   require "lua_utils_gui"
   return hostinfo2detailsurl({ host = host, vlan = vlan_id })
end

-- ##############################################

function getNedgeHostPoolUrl(pool_name)
   if not pool_name then
      tprint(debug.traceback())
      return ""
   end
   return ntop.getHttpPrefix() .. "/lua/pro/nedge/admin/nf_edit_user.lua?username=" .. pool_name
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
      return string.format(
      getHttpHost() .. ntop.getHttpPrefix() .. "/lua/pro/enterprise/snmp_device_details.lua?host=%s", snmp_device)
   end

   return "#"
end

-- ##############################################

function snmpIfaceUrl(snmp_device, interface_idx)
   if showSnmpUrl(snmp_device) then
      return string.format(
      getHttpHost() .. ntop.getHttpPrefix() .. "/lua/pro/enterprise/snmp_interface_details.lua?host=%s&snmp_port_idx=%d",
         snmp_device, interface_idx)
   end

   return "#"
end

-- ##############################################

function alert_consts.getDefinititionDirs()
   local dirs = ntop.getDirs()

   return ({
      -- Path for ntopng-defined builtin alerts
      os_utils.fixPath(dirs.installdir .. "/scripts/lua/modules/alert_definitions/flow"),
      os_utils.fixPath(dirs.installdir .. "/scripts/lua/modules/alert_definitions/host"),
      os_utils.fixPath(dirs.installdir .. "/scripts/lua/modules/alert_definitions/other"),
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

function alert_consts.alertEntityLabel(v)
   local entity_id = alert_consts.alertEntityRaw(v)

   if (entity_id) then
      return i18n(alert_consts.alert_entities[entity_id].i18n_label)
   end
end

-- ##############################################

-- See alert_consts.resetDefinitions()
alert_consts.alert_types = {}
local alerts_by_id = {} -- All available alerts keyed by entity_id and alert_id

local function loadAlertsDefs()
   local lua_path_utils = require "lua_path_utils"

   if (false) then
      if (string.find(debug.traceback(), "second.lua")) then
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

            if (def_script == nil) then
               traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Error loading alert definition from %s", mod_fname))
               goto next_script
            end

            if not loadDefinition(def_script, mod_fname, defs_dir) then
               -- Retry reload
               package.loaded[mod_fname] = nil
            end
         end

         ::next_script::
      end

      if defs_dir:ends(os_utils.fixPath("/flow")) then
         -- Load flow alerts for flows with nDPI risks that don't have an alert .lua file explicitly defined under alert_definitions/
         local flow_risk_alerts = ntop.getFlowRiskAlerts()
         for mod_fname, flow_risk_alert in pairs(flow_risk_alerts) do
            local alert_type = alert_consts.getAlertType(flow_risk_alert.alert_id, alert_entities.flow.entity_id)

            -- Make sure the alert hasn't already been loaded via a dedicated alert_definition .lua file
            if not alert_type then
               -- Can't use the require. Require always returns the same table and this would result in overwritten alert_key and title
               local def_script = dofile(os_utils.fixPath(string.format(
               "%s/scripts/lua/modules/flow_risk_simple_alert_definition.lua", dirs.installdir)))

               -- Add the mandatory fields according to what arrives from C++
               def_script.meta.alert_key = flow_risk_alert.alert_id
               def_script.meta.i18n_title = flow_risk_alert.risk_name

               if not loadDefinition(def_script, mod_fname, defs_dir) then
                  -- Retry reload
                  package.loaded[mod_fname] = nil
               end
            end
         end
      end
   end
end

-- ##############################################

function loadDefinition(def_script, mod_fname, script_path)
   local required_fields = { "alert_key", "i18n_title", "icon" }

   -- Check the required meta table
   if (def_script.meta == nil) then
      traceError(TRACE_ERROR, TRACE_CONSOLE,
         string.format("Missing required table 'meta' in %s from %s", mod_fname, script_path))
      return (false)
   end

   -- Check the required metadata fields
   for _, k in pairs(required_fields) do
      if (def_script.meta[k] == nil) then
         traceError(TRACE_ERROR, TRACE_CONSOLE,
            string.format("Missing required field '%s' in %s from %s", k, mod_fname, script_path))
         return (false)
      end
   end

   local alert_entity
   if script_path:ends(os_utils.fixPath("/flow")) then
      alert_entity = alert_entities.flow
   elseif script_path:ends(os_utils.fixPath("/host")) then
      alert_entity = alert_entities.host
   else
      -- TODO: migrate all. currently assumes other for non-flow non-host
      alert_entity = alert_entities.other
   end

   local alert_key = def_script.meta.alert_key

   if not alert_entity or not alert_key then
      traceError(TRACE_ERROR, TRACE_CONSOLE,
         string.format("Invalid alert key specified %s in %s from %s", status, mod_fname, script_path))
      return (false)
   end

   -- Coherence check: make sure the alert key is not redefined
   local alert_entity_id = alert_entity.entity_id

   if alerts_by_id[alert_entity_id] and alerts_by_id[alert_entity_id][alert_key] then
      traceError(TRACE_ERROR, TRACE_CONSOLE,
         string.format("Alert key %d redefined, skipping in %s from %s", alert_key, mod_fname, script_path))
      return (false)
   end

   -- Add alert metadata to the script
   alert_consts.alert_types[mod_fname] = def_script

   if not alerts_by_id[alert_entity_id] then
      alerts_by_id[alert_entity_id] = {}
   end
   alerts_by_id[alert_entity_id][alert_key] = mod_fname

   -- Handle 'other' alerts
   -- Note: some are used by multiple entities, defined under
   -- meta in the alert definition
   if def_script.meta['entities'] then
      for _, entity in ipairs(def_script.meta['entities']) do
         if not alerts_by_id[entity.entity_id] then
            alerts_by_id[entity.entity_id] = {}
         end
         alerts_by_id[entity.entity_id][alert_key] = mod_fname
      end
   end

   -- Success
   return (true)
end

-- ##############################################

function alert_consts.alertTypeLabel(alert_id, nohtml, alert_entity_id, nil_on_not_found)
   local alert_key = alert_consts.getAlertType(alert_id, alert_entity_id)

   if alert_key then
      local type_info = alert_consts.alert_types[alert_key]
      -- TODO: .meta is the new format, OR are for compatibility and can be removed when migration is done
      local title = i18n(type_info.i18n_title or type_info.meta.i18n_title) or type_info.i18n_title or
      type_info.meta.i18n_title

      if nohtml then
         return title
      else
         -- return(string.format('<i class="%s"></i> %s', type_info.icon or type_info.meta.icon, shortenString(title)))
         return string.format('%s', title)
      end
   elseif nil_on_not_found then
      return nil
   else
      return (i18n("unknown"))
   end
end

-- ##############################################

-- @brief Given a flow status identified by `status_key`, returns an icon associated to the severity
-- @param `status info`, A human readable (localized) status info
-- @param `alerted_severity`, Integer severity of the alert associated to this status
-- @return The HTML with icon and ALT text, or empty if no icon is available
function alert_consts.alertTypeIcon(alert_info, alerted_severity, icon_size)
   local severity = alert_consts.alertSeverityById(alerted_severity)
   local icon = ''

   if severity then
      local severity_icon = (icon_size or 'fa-fw') .. " " .. severity.icon
      icon = "<i class='" ..
      severity_icon .. "' title='" .. noHtml(alert_consts.alertTypeLabel(alert_info, true)) .. "'></i> "
   end

   return icon
end

-- ##############################################

function alert_consts.getAlertMitreInfo(v)
   if (alert_consts.alert_types[v] == nil) then
      tprint(debug.traceback())
   end

   local res = nil
   local key = alert_consts.alert_types[v]

   if key and key.meta then
      -- TODO AM: attempt at looking inside new implementation `meta`
      res = key.meta.mitre_values
   end

   return res
end

-- ##############################################

function alert_consts.getAlertMitreInfoIDs(v)
   if (alert_consts.alert_types[v] == nil) then
      tprint(debug.traceback())
   end

   local res = nil
   local key = alert_consts.alert_types[v]

   if key and key.meta then
      -- TODO AM: attempt at looking inside new implementation `meta`
      if key.meta.mitre_values then
         local values = key.meta.mitre_values
         local tactic = nil
         local tecnique = nil
         local sub_tecnique = nil
         if values.mitre_tactic then
            tactic = values.mitre_tactic.id or nil
         end
         if values.mitre_tecnique then
            tecnique = values.mitre_tecnique.id or nil
         end
         if values.mitre_sub_tecnique then
            sub_tecnique = values.mitre_sub_tecnique.id or nil
         end
         res = {
            mitre_tactic_id = tactic,
            mitre_tecnique_id = tecnique,
            mitre_sub_tecnique_id = sub_tecnique,
            mitre_id = values.mitre_id
         }
      end
   end

   return res
end

-- ##############################################

function alert_consts.alertType(v)
   if (alert_consts.alert_types[v] == nil) then
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

function alert_consts.getAlertType(alert_key, alert_entity_id)
   -- Make sure we are working with numbers
   alert_key = tonumber(alert_key)
   alert_entity_id = tonumber(alert_entity_id)

   -- If the alert entity has been explicity submitted and is one among 'flow' or 'host', then
   -- this method return if no alert is found. Otherwise, fallbacks are tried.
   -- NOTE: This is because 'flow' and 'host' alert entities have their explicit alert definitions
   -- under modules/alert_definitions. All other entities currently fall under the 'other' entity.
   if alert_entity_id and (alert_entity_id == alert_entities.flow.entity_id or alert_entity_id == alert_entities.host.entity_id) then
      if alerts_by_id[alert_entity_id] and alerts_by_id[alert_entity_id][alert_key] then
         return alerts_by_id[alert_entity_id][alert_key]
      end

      -- Alert entity explicitly submitted and no alert found. Returning.
      return
   end

   -- TODO: remove fallbacks when all alerts in alert_keys.lua will be migrated and will have their own entity specified

   -- Fallback 01: if no alert_entity_id is passed, alert_entity is assumed to be flow.
   if alerts_by_id[alert_entities.flow.entity_id][alert_key] then
      return alerts_by_id[alert_entities.flow.entity_id][alert_key]
   end

   -- Fallback 02: if no alert_entity_id is passed, alert_entity is assumed to be host.
   if alerts_by_id[alert_entities.host.entity_id][alert_key] then
      return alerts_by_id[alert_entities.host.entity_id][alert_key]
   end

   -- Fallback 03: if no alert_entity_id is passed, alert_entity is assumed to be other.
   if alerts_by_id[alert_entities.other.entity_id][alert_key] then
      return alerts_by_id[alert_entities.other.entity_id][alert_key]
   end
end

-- ##############################################

function alert_consts.getAlertTypes(alert_entity_id)
   return alerts_by_id[alert_entity_id]
end

-- ##############################################

function alert_consts.alert_type_info_asc(a, b)
   return (a.label:upper() < b.label:upper())
end

function alert_consts.getAlertTypesInfo(alert_entity_id)
   local alert_types = alert_consts.getAlertTypes(alert_entity_id)

   if not alert_types then
      return {}
   end

   local alert_types_info = {}
   for alert_id, alert_name in pairs(alert_types) do
      alert_types_info[alert_id] = {
         alert_id = alert_id,
         name = alert_name,
         label = alert_consts.alertTypeLabel(alert_id, true, alert_entity_id),
      }
   end

   return alert_types_info
end

-- ##############################################

function alert_consts.alertLevelToSyslogLevel(v)
   return alert_severities[alert_consts.alertSeverityRaw(v)].syslog_severity
end

-- ################################################################################

function alert_consts.alertSeverityRaw(severity_id)
   severity_id = tonumber(severity_id)
   if not alert_severities_id_to_key[severity_id] then
      severity_id = 1 -- falling back to min severity
   end
   return alert_severities_id_to_key[severity_id]
end

-- ################################################################################

function alert_consts.get_printable_severities()
   local severities = {}

   for name, conf in pairs(alert_severities, "severity_id", asc) do
      if (conf.severity_id > 2) then
         severities[name] = conf
      end
   end

   return severities
end

-- ################################################################################

function alert_consts.alertSeverityLabel(score, nohtml, emoji)
   local severity_id = alert_consts.alertSeverityRaw(map_score_to_severity(score))

   if (severity_id) then
      local severity_info = alert_severities[severity_id]
      local title = i18n(severity_info.i18n_title) or severity_info.i18n_title

      if (emoji) then
         title = (severity_info.emoji or "") .. " " .. title
      end

      if (nohtml) then
         return (title)
      else
         return (string.format('<span class="badge %s" title="%s">%s</span>', severity_info.label, title, title))
      end
   end

   return "(unknown severity)"
end

-- ################################################################################

function alert_consts.alertSeverity(v)
   return (alert_severities[v].severity_id)
end

-- ################################################################################

function alert_consts.alertSeverityById(severity_id)
   local key = alert_consts.alertSeverityRaw(severity_id)
   if key == nil then
      return alert_severities.none
   end
   return (alert_severities[key])
end

-- ################################################################################

-- Rename engine -> granulariy
local function alertEngineRaw(granularity_id)
   granularity_id = tonumber(granularity_id)
   return alerts_granularities_id_to_key[granularity_id]
end

-- ################################################################################

function alert_consts.alertEngine(v)
   if (alert_consts.alerts_granularities[v] == nil) then
      tprint(debug.traceback())
   end

   return (alert_consts.alerts_granularities[v].granularity_id)
end

-- ################################################################################

function alert_consts.alertEngineLabel(v)
   local granularity_id = alertEngineRaw(v)

   if (granularity_id ~= nil) then
      return (i18n(alert_consts.alerts_granularities[granularity_id].i18n_title))
   end
end

-- ################################################################################

function alert_consts.granularity2sec(v)
   if (alert_consts.alerts_granularities[v] == nil) then
      tprint(debug.traceback())
   end

   return (alert_consts.alerts_granularities[v].granularity_seconds)
end

-- ################################################################################

-- See NetworkInterface::checkHostsAlerts()
function alert_consts.granularity2id(granularity)
   -- TODO replace alertEngine
   return (alert_consts.alertEngine(granularity))
end

-- ################################################################################

function alert_consts.formatBehaviorAlert(params, anomalies, stats, id, subtype, name)
    local debug = false
    -- Cycle throught the behavior stats
    for anomaly_type, anomaly_table in pairs(anomalies) do
        local lower_bound = stats[anomaly_type]["lower_bound"]
        local upper_bound = stats[anomaly_type]["upper_bound"]
        local value = stats[anomaly_type]["value"]

        if debug then
            local msg = string.format("Checking %s behavior for %s (lower bound | value | upper bound): %s | %s | %s",
                subtype, name, lower_bound, value, upper_bound)
            traceError(TRACE_NORMAL, TRACE_CONSOLE, msg)
        end

        if anomaly_table["cut_values"] then
            value = tonumber(string.format("%.2f", tonumber(value * (anomaly_table["multiplier"] or 1))))
            lower_bound = tonumber(string.format("%.2f", tonumber(lower_bound * (anomaly_table["multiplier"] or 1))))
            upper_bound = tonumber(string.format("%.2f", tonumber(upper_bound * (anomaly_table["multiplier"] or 1))))
        end

        if anomaly_table["formatter"] then
            value = anomaly_table["formatter"](value)
            lower_bound = anomaly_table["formatter"](lower_bound)
            upper_bound = anomaly_table["formatter"](upper_bound)
        end

        local alert = anomaly_table.alert.new(i18n(subtype .. "_id", {
            id = name or id
        }), anomaly_type, value, lower_bound, upper_bound, anomaly_table["entity_id"], id, anomaly_table["extra_params"])

        alert:set_info(params)
        alert:set_subtype(name)

        -- Trigger an alert if an anomaly is found
        if anomaly_table["anomaly"] == true then
            alert:trigger(params.alert_entity, nil, params.cur_alerts)
        else
            alert:release(params.alert_entity, nil, params.cur_alerts)
        end
    end
end

-- ################################################################################

function alert_consts.sec2granularity(seconds)
   seconds = tonumber(seconds)
   local key = alerts_granularities_seconds_to_key[seconds]
   if not key then
      key = alerts_granularities_seconds_to_key[60]
   end
   return key
end
-- Load definitions now
loadAlertsDefs()
initMappings()

if (trace_script_duration ~= nil) then
   io.write(debug.getinfo(1, 'S').source .. " executed in " .. (os.clock() - clock_start) * 1000 .. " ms\n")
end

return alert_consts
