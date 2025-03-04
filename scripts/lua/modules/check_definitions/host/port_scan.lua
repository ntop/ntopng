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
   alert_id = host_alert_keys.host_alert_port_scan,

   -- This module is disabled by default
   default_enabled = false,

   -- Default value (reset with "Reset Default" button)
   default_value = {
      operator = "gt",
      threshold = 20,
   },

   gui = {
      i18n_title       = "flow_checks.port_scan_title",
      i18n_description = "flow_checks.port_scan_description",
      i18n_field_unit = checks.field_units.ports,
      input_builder = "threshold_cross",
      field_min = 1,
      field_max = 1000,
      field_operator = "gt";
   },

   hooks = {},
}

-- #################################################################

-- Generate alert (store)
local function report_host(params, ip, vlan, victim, num_victims)

   local hostinfo = {
      host = ip,
      vlan = vlan
   }
   
   local descr = ""
   local score = 100

   local alert = alert_consts.alert_types.host_alert_port_scan.new(
      interface.getId(),
      victim,
      num_victims
   )
   local host_key = hostinfo2hostkey(hostinfo)
   alert:set_subtype(host_key)
   alert:set_score(score)
   alert:set_require_attention()
   alert:set_category(checks.check_categories.security)
   alert:set_info(params)
   local alert_info = {
      entity_val = host_key,
      alert_entity = alert_entities.host
   }
   alert:set_require_attention()
   alert:set_as_attacker()
   alert:store(alert_info)
end

-- #################################################################

-- Check number of ports contacted by an host towards another host
local function ports_check(params)
   -- Settings
   local threshold = tonumber(params.check_config.threshold) or script.default_value.threshold
   local interval_size = 8 * 60 -- 8 min

   if not ntop.isClickHouseEnabled() then
      return
   end

   local now = os.time()
   local interval_begin = now - interval_size
   local interval_end = now

   local q = string.format(
      "SELECT "
      .. "VLAN_ID vlan_id, "
      .. "IPv4NumToString(IPV4_SRC_ADDR) AS ip_src_4, "
      .. "IPv6NumToString(IPV6_SRC_ADDR) AS ip_src_6, "
      .. "IPv4NumToString(IPV4_DST_ADDR) AS ip_dst_4, "
      .. "IPv6NumToString(IPV6_DST_ADDR) AS ip_dst_6, "
      .. "COUNT(DISTINCT IP_DST_PORT) AS count_dst_ports, "
      .. "COUNT(*) AS total_flows, "
      .. "MAX(LAST_SEEN) AS last_seen "
   .. "FROM flows "
   .. "WHERE INTERFACE_ID=%u "
      .. "AND (FIRST_SEEN >= %u AND FIRST_SEEN <= %u AND LAST_SEEN <= %u)"
      .. "AND L7_PROTO != 5 "
      .. "AND DST2SRC_PACKETS <= 1 "
   .. "GROUP BY vlan_id, ip_src_4, ip_src_6, ip_dst_4, ip_dst_6 "
   .. "HAVING count_dst_ports >= %u "
   .. "ORDER BY total_flows DESC "
   .. "LIMIT 50",
      tonumber(interface.getId()),
      interval_begin, interval_end, interval_end,
      threshold
   )

   local results = interface.execSQLQuery(q)
   local port_scan_map = {}
   for _, row in ipairs(results) do
      local vlan_id = tonumber(row.vlan_id) or 0

      local ip = row.ip_src_4
      if row.ip_src_6 and row.ip_src_6 ~= '::' then ip = row.ip_src_6 end

      local victim_ip = row.ip_dst_4
      if row.ip_dst_6 and row.ip_dst_6 ~= '::' then victim_ip = row.ip_dst_6 end
      -- Concatenate the attacker IP and vlan id to create port_scan_map key
      ip = ip .. "_" .. vlan_id
      if port_scan_map[ip] == nil then
         port_scan_map[ip] = {victim_ip,1}
      -- Only 3 victims are saved for each attacker
      elseif port_scan_map[ip][2] < 3 then 
         port_scan_map[ip][1] = port_scan_map[ip][1] .. ", " .. victim_ip 
         port_scan_map[ip][2] = port_scan_map[ip][2] + 1
      -- If the top 3 victims have been saved, only increase the counter
      else
         port_scan_map[ip][2] = port_scan_map[ip][2] + 1
      end
   end
   -- attacker_data[1] = top 3 victims, attacker_data[2] = total victims
   for attacker_ip, attacker_data in pairs(port_scan_map) do
      local ip, vlan_id = string.match(attacker_ip, "([^_]+)_(%d+)")
      report_host(params, ip, vlan_id, attacker_data[1], attacker_data[2])
   end

end

-- #################################################################

script.hooks["5mins"] = ports_check

-- #################################################################

return script
