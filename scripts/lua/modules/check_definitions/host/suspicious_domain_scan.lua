--
-- (C) 2019-24 - ntop.org
--

-- Check notes:
-- This check implements a periodic Lua check for triggering host alerts
-- Please note this actually runs periodically on an interface and should be used
-- to run queries on the database or scan hosts, it is NOT called for each host.
-- Only store() should be used, trigger/release (engaged alerts) are not supported

local checks = require("checks")
local alerts_api = require "alerts_api"
local alert_consts = require("alert_consts")
local host_alert_keys = require "host_alert_keys"
local alert_entities = require "alert_entities"

-- #################################################################

local script = {
   edition = "enterprise_m",
   category = checks.check_categories.security,
   severity = alert_consts.get_printable_severities().error,
   alert_id = host_alert_keys.host_alert_suspicious_domain_scan,

   -- This module is disabled by default
   default_enabled = false,

   -- Default value (reset with "Reset Default" button)
   default_value = {
      operator = "gt",
      threshold = 100,
   },

   gui = {
      i18n_title       = "flow_checks.suspicious_domain_scan_title",
      i18n_description = "flow_checks.suspicious_domain_scan_description",
      i18n_field_unit = checks.field_units.domains,
      input_builder = "threshold_cross",
      field_min = 1,
      field_max = 1000,
      field_operator = "gt";
   },

   hooks = {},
}

-- #################################################################

-- Generate alert (store)
local function report_host(params, ip, vlan, victim, num_domains)
   local hostinfo = {
      host = ip,
      vlan = vlan
   }
   local descr = ""
   local score = 100

   local alert = alert_consts.alert_types.host_alert_suspicious_domain_scan.new(
      interface.getId(),
      victim,
      num_domains
   )

   local host_key = hostinfo2hostkey(hostinfo)
   alert:set_subtype(host_key)
   alert:set_score(score)
   alert:set_category(checks.check_categories.security)
   alert:set_info(params)

   local alert_info = {
      entity_val = host_key,
      alert_entity = alert_entities.host
   }

   alert:store(alert_info)
end

-- #################################################################

-- Check number of domains contacted by an host towards another host
local function domains_check(params)

   -- Settings
   local threshold = tonumber(params.check_config.threshold) or script.default_value.threshold
   local interval_size = 60*60 -- 1 hour

   if not ntop.isClickHouseEnabled() then
      return
   end

   local now = os.time()
   local interval_begin = now - interval_size
   local interval_end = now

   local q = string.format(
      "SELECT f.ip_src_4, f.ip_src_6, f.ip_dst_4, f.ip_dst_6, count FROM (" 
      .. "SELECT "
         .. "VLAN_ID vlan_id, "
         .. "IPv4NumToString(IPV4_SRC_ADDR) ip_src_4, "
         .. "IPv6NumToString(IPV6_SRC_ADDR) ip_src_6, "
         .. "IPv4NumToString(IPV4_DST_ADDR) ip_dst_4, "
         .. "IPv6NumToString(IPV6_DST_ADDR) ip_dst_6, "
         .. "COUNT(DISTINCT DOMAIN_NAME) AS count "
      .. "FROM flows "
      .. "WHERE INTERFACE_ID=%u "
         .. "AND DOMAIN_NAME!='' "
         .. "AND (L7_PROTO!=5 AND L7_PROTO_MASTER!=5) "
         .. "AND (FIRST_SEEN >= %u AND FIRST_SEEN <= %u AND LAST_SEEN <= %u) "
      .. "GROUP BY VLAN_ID, IPV4_SRC_ADDR, IPV6_SRC_ADDR, IPV4_DST_ADDR, IPV6_DST_ADDR "
      .. "ORDER BY count DESC "
      .. ") f WHERE f.count > %u",
      tonumber(interface.getId()),
      interval_begin, interval_end, interval_end,
      threshold
   )

   local results = interface.execSQLQuery(q)

   for _, row in ipairs(results) do
      local count = tonumber(row.count) or 0
      local vlan_id = tonumber(row.vlan_id) or 0

      local ip = row.ip_src_4
      if row.ip_src_6 and row.ip_src_6 ~= '::' then ip = row.ip_src_6 end

      local victim_ip = row.ip_dst_4
      if row.ip_dst_6 and row.ip_dst_6 ~= '::' then victim_ip = row.ip_dst_6 end

      report_host(params, ip, vlan_id, victim_ip, count)
   end

end

-- #################################################################

script.hooks.hour = domains_check

-- #################################################################

return script
