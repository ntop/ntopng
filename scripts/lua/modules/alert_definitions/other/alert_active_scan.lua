--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

-- ##############################################

local alert_active_scan = classes.class(alert)

alert_active_scan.meta = {
  alert_key = other_alert_keys.alert_active_scan,
  i18n_title = "alerts_dashboard.active_scan_title",
  icon = "fas fa-fw fa-exclamation-triangle",
  entities = {
     alert_entities.am_host,
  },

   -- Mitre Att&ck Matrix values
   mitre_values = {
      mitre_tactic = mitre.tactic.persistence,
      mitre_technique = mitre.technique.ext_remote_services,
      mitre_id = "T1133"
   },
}

-- ##############################################

function alert_active_scan:init(differences_list)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = differences_list
   -- Trick to set this alert as an active monitoring alert
   self.alert_type_params.threshold = 0
   self.alert_type_params.value = 0
   self.alert_type_params.measurement = differences_list.measurement
end

-- #######################################################

-- Function to normalize values (check nil cases)
local function normalize_values(primary_key, secondary_key) 
   if (primary_key == nil) then
      return nil
   elseif (primary_key[secondary_key] == nil) then
      return nil
   else
      return primary_key[secondary_key]
   end
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @param local_explorer Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_active_scan.format(ifid, alert, alert_type_params, local_explorer)
   local msg = ""
   -- case standard with scan_type == "TCP_PORTSCAN"
   if (alert_type_params.scan_type == "tcp_portscan" or alert_type_params.scan_type == "tcp_openports") then
      if (not isEmptyString(alert_type_params.tcp_ports_case)) then
         msg = msg .. i18n('active_scan.ports_changed_cases.'..alert_type_params.tcp_ports_case, {
            open_ports_num = normalize_values(alert_type_params.tcp_open_ports,"num"),
            open_ports = normalize_values(alert_type_params.tcp_open_ports,"ports"),
            closed_ports_num = normalize_values(alert_type_params.tcp_closed_ports,"num"),
            closed_ports = normalize_values(alert_type_params.tcp_closed_ports,"ports"),
            protocol = i18n("tcp")
         })
         msg = msg:gsub("%,", ", ")
      end

   elseif (alert_type_params.scan_type == "udp_portscan") then
      if (not isEmptyString(alert_type_params.udp_ports_case)) then
      msg = msg .. i18n('active_scan.ports_changed_cases.'..alert_type_params.udp_ports_case, {
         open_ports_num = normalize_values(alert_type_params.udp_open_ports,"num"),
         open_ports = normalize_values(alert_type_params.udp_open_ports,"ports"),
         closed_ports_num = normalize_values(alert_type_params.udp_closed_ports,"num"),
         closed_ports = normalize_values(alert_type_params.udp_closed_ports,"ports"),
         protocol = i18n("udp")
      })
      msg = msg:gsub("%,", ", ")
      end

   end

   -- message for host unreachable alert
   if (alert_type_params.is_up_check_case) then
      msg = msg .. i18n("active_scan.host_down_case", { host = alert_type_params.host })
   end

   -- message for host not configured alert
   if (alert_type_params.is_host_not_configured) then
      msg = msg .. i18n("active_scan.host_not_configured", {host = alert_type_params.host })
   end

   local host = alert_type_params.host_name
   if isEmptyString(host) then
      host = alert_type_params.host
   else
      if (not isIPv4(alert_type_params.host)) then
         host = string.format("%s <span class=\"badge bg-secondary\">%s</span>",host,i18n('ipv6'))
      end
   end

   local scan_type = alert_type_params.scan_type

   if scan_type == "tcp_openports" then
      scan_type = "tcp_portscan"
   end

   local scan_type_label = i18n(string.format("hosts_stats.page_scan_hosts.scan_type_list.%s",scan_type))

   local url = string.format("%s/lua/active_scan.lua?host=%s&scan_type=%s&scan_return_result=true&page=show_result&scan_date=%s",getHttpHost() .. ntop.getHttpPrefix(),alert_type_params.host,scan_type,alert_type_params.date)
   if (alert_type_params.epoch) then
      url = string.format("%s&epoch=%u",url,alert_type_params.epoch)
   end

   local alert_descr = i18n('active_scan.host_alert', { host = host, msg = msg, url = url, scan_type = scan_type_label })
   if(alert_type_params.is_up_check_case or alert_type_params.is_host_not_configured) then
      alert_descr = msg
   end
   return alert_descr
end

-- #######################################################

return alert_active_scan
