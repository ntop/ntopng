--
-- (C) 2019-24 - ntop.org
--

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
   alert_id = host_alert_keys.host_alert_scan,

   -- This module is disabled by default
   default_enabled = false,

   -- Default value (reset with "Reset Default" button)
   default_value = {
      operator = "gt",
      threshold = 20,
   },

   gui = {
      i18n_title       = "flow_checks.scan_title",
      i18n_description = "flow_checks.scan_description",
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
local function report_alert(params, attacker, vlan, victim, num_victims, is_victim, attack)
   local hostinfo = {}
   if is_victim then
      hostinfo = {
         host = victim,
         vlan = vlan
      }
   else 
      hostinfo = {
         host = attacker,
         vlan = vlan
      }
   end
   local descr = ""
   local score = 100

   local alert = alert_consts.alert_types.host_alert_scan.new(
      interface.getId(),
      attacker,
      victim,
      num_victims,
      attack
   )
   local host_key = hostinfo2hostkey(hostinfo)
   alert:set_subtype(host_key)
   alert:set_score(score)
   alert:set_require_attention()
   alert:set_category(checks.check_categories.security)
   alert:set_info(params)
   if is_victim then alert:set_as_victim() 
   else
      alert:set_attacker(host_key)
      alert:set_as_attacker()
   end
   local alert_info = {
      entity_val = host_key,
      alert_entity = alert_entities.host
   }
   alert:set_require_attention()
   alert:store(alert_info)
end

-- #################################################################

-- Generate alerts for attacks where the query result is iterated 
-- for the attacker (source) and victim (destination) IP. 
-- Port scan only for now.
local function iterative_src_dst_alert(params, results, report_victim, attack)
   local scan_map = {}
   for _, row in ipairs(results) do
      local vlan_id = tonumber(row.vlan_id) or 0
      local attacker_ip = row.ip_src
      local victim_ip = row.ip_dst
      -- Concatenate the attacker IP and vlan id to create scan_map key
      local ipv = attacker_ip .. "_" .. vlan_id
      if scan_map[ipv] == nil then
         scan_map[ipv] = {victim_ip,1}
      -- Only 3 victims are saved for each attacker
      elseif scan_map[ipv][2] < 3 then 
         scan_map[ipv][1] = scan_map[ipv][1] .. ", " .. victim_ip 
         scan_map[ipv][2] = scan_map[ipv][2] + 1
      elseif scan_map[ipv][2] == 3 then
         scan_map[ipv][1] = scan_map[ipv][1] .. " and others" 
         scan_map[ipv][2] = scan_map[ipv][2] + 1
      -- If the top 3 victims have been saved, only increase the counter
      else
         scan_map[ipv][2] = scan_map[ipv][2] + 1
      end
      -- report a victim (If enabled)
      if report_victim then
         if attacker_ip ~= "" then
            report_alert(params, attacker_ip, vlan_id, victim_ip, 0, true, attack)
         end
      end
   end
   -- attacker_data[1] = top 3 victims, attacker_data[2] = total victims
   for attacker_ip, attacker_data in pairs(scan_map) do
      local ip, vlan_id = string.match(attacker_ip, "([^_]+)_(%d+)")
      -- report attacker
      if attacker_ip ~= "" then
         report_alert(params, ip, vlan_id, attacker_data[1], attacker_data[2], false, attack)
      end
   end
   return scan_map
end

-- #################################################################

local function scan_check(params)
   -- Settings
   local threshold = tonumber(params.check_config.threshold) or script.default_value.threshold
   local interval_size = 8 * 60 -- 8 min

   if not ntop.isClickHouseEnabled() then
      return
   end

   local now = os.time()
   local interval_begin = now - interval_size
   local interval_end = now
   
   -- Port Scan
   local q_port = string.format(
      "SELECT "
      .. "VLAN_ID vlan_id, "
      .. "COALESCE( "
         .. "NULLIF(IPv4NumToString(IPV4_SRC_ADDR), '0.0.0.0'), " 
         .. "NULLIF(IPv6NumToString(IPV6_SRC_ADDR), '::') "
      .. ") AS ip_src, "
      .. "COALESCE( "
         .. "NULLIF(IPv4NumToString(IPV4_DST_ADDR), '0.0.0.0'), "
         .. "NULLIF(IPv6NumToString(IPV6_DST_ADDR), '::') "
      .. ") AS ip_dst, "
      .. "COUNT(DISTINCT IP_DST_PORT) AS count_dst_ports, "
      .. "COUNT(*) AS total_flows, "
      .. "MAX(LAST_SEEN) AS last_seen "
   .. "FROM flows "
   .. "WHERE INTERFACE_ID=%u "
      .. "AND (FIRST_SEEN >= %u AND FIRST_SEEN <= %u AND LAST_SEEN <= %u) "
      .. "AND L7_PROTO != 5 "
      .. "AND DST2SRC_PACKETS <= 1 "
   .. "GROUP BY vlan_id, ip_src, ip_dst "
   .. "HAVING count_dst_ports >= %u "
   .. "ORDER BY total_flows DESC "
   .. "LIMIT 1000",
      tonumber(interface.getId()),
      interval_begin, interval_end, interval_end,
      threshold
   )

   local results_port_query = interface.execSQLQuery(q_port)
   results_port = iterative_src_dst_alert(params, results_port_query, false, "Port")
   
   -- Service down
   local q_service_down = string.format(
      "SELECT "
         .. "VLAN_ID vlan_id, "
         .. "COALESCE( "
            .. "NULLIF(IPv4NumToString(IPV4_SRC_ADDR), '0.0.0.0'), "
            .. "NULLIF(IPv6NumToString(IPV6_SRC_ADDR), '::') "
         .. ") AS ip_src, "
         .. "COALESCE( "
            .. "NULLIF(IPv4NumToString(IPV4_DST_ADDR), '0.0.0.0'), "
            .. "NULLIF(IPv6NumToString(IPV6_DST_ADDR), '::') "
         .. ") AS ip_dst, "
         .. "IP_DST_PORT dst_port, "
         .. "COUNT(DISTINCT IP_SRC_PORT) AS count_src_ports, "
         .. "COUNT(*) AS total_flows, "
         .. "MAX(LAST_SEEN) AS last_seen "
      .. "FROM flows "
      .. "WHERE INTERFACE_ID=%u "
         .. "AND (FIRST_SEEN >= %u AND FIRST_SEEN <= %u AND LAST_SEEN <= %u) "
         .. "AND L7_PROTO != 5 "
         .. "AND DST2SRC_PACKETS <= 1 "
      .. "GROUP BY vlan_id, ip_src, ip_dst, dst_port "
      .. "HAVING count_src_ports >= %u "
      .. "ORDER BY total_flows DESC "
      .. "LIMIT 500",
      tonumber(interface.getId()),
      interval_begin, interval_end, interval_end,
      50
   )
   local results_service_down = interface.execSQLQuery(q_service_down)
   for _, row in ipairs(results_service_down) do
      local vlan_id = tonumber(row.vlan_id) or 0
      local attacker_ip = row.ip_src
      local victim_port = row.dst_port
      local victim = row.ip_dst
      if attacker_ip ~= "" then
         report_alert(params, attacker_ip, vlan_id, victim, victim_port, false, "Service Down")
      end
   end

   -- Service Scan
   local q_service = string.format(
      "SELECT "
         .. "VLAN_ID vlan_id,"
         .. "COALESCE( "
            .. "NULLIF(IPv4NumToString(IPV4_SRC_ADDR), '0.0.0.0'), "
            .. "NULLIF(IPv6NumToString(IPV6_SRC_ADDR), '::') "
         .. ") AS ip_src, "
         .. "IP_DST_PORT AS dst_port, "
         .. "COUNT(DISTINCT COALESCE( "
            .. "NULLIF(IPv4NumToString(IPV4_DST_ADDR), '0.0.0.0'), "
            .. "NULLIF(IPv6NumToString(IPV6_DST_ADDR), '::') "
         .. ") AS ip_dst) AS count_ip_dst, "
         .. "COUNT(*) AS total_flows, "
         .. "MAX(LAST_SEEN) AS last_seen "
      .. "FROM flows "
      .. "WHERE INTERFACE_ID=%u "
         .. "AND (FIRST_SEEN >= %u AND FIRST_SEEN <= %u AND LAST_SEEN <= %u) "
         .. "AND L7_PROTO != 5 "
         .. "AND DST2SRC_PACKETS <= 1 "
      .. "GROUP BY vlan_id, ip_src, dst_port "
      .. "HAVING count_ip_dst >= %u "
      .. "ORDER BY total_flows DESC "
      .. "LIMIT 1000",
      tonumber(interface.getId()),
      interval_begin, interval_end, interval_end,
      50
   )
   local results_service = interface.execSQLQuery(q_service)
   local service_attackers = {}
   for _, row in ipairs(results_service) do
      local vlan_id = tonumber(row.vlan_id) or 0
      local attacker_ip = row.ip_src
      local attacker_key = row.ip_src .. "_" .. vlan_id
      service_attackers[attacker_key] = true
      if results_port[attacker_key] == nil or results_port[attacker_key][2] < 10 then
         local victim_port = row.dst_port
         local num_victim = row.count_ip_dst
         if attacker_ip ~= "" then
            report_alert(params, attacker_ip, vlan_id, victim_port, num_victim, false, "Service")
         end
      end
   end

   -- Network Scan 
   local q_network = string.format(
      "SELECT "
         .. "VLAN_ID vlan_id, "
         .. "COALESCE( "
            .. "NULLIF(IPv4NumToString(IPV4_SRC_ADDR), '0.0.0.0'), "
            .. "NULLIF(IPv6NumToString(IPV6_SRC_ADDR), '::') "
         .. ") AS ip_src, "
         .. "DST_NETWORK_ID as dst_network, "
         .. "COUNT(DISTINCT COALESCE( "
            .. "NULLIF(IPv4NumToString(IPV4_DST_ADDR), '0.0.0.0'), "
            .. "NULLIF(IPv6NumToString(IPV6_DST_ADDR), '::') "
         .. ") AS ip_dst) AS count_ip_dst, "
         .. "COUNT(*) AS total_flows, "
         .. "MAX(LAST_SEEN) AS last_seen "
      .. "FROM flows "
      .. "WHERE INTERFACE_ID=%u "
         .. "AND (FIRST_SEEN >= %u AND FIRST_SEEN <= %u AND LAST_SEEN <= %u) "
         .. "AND L7_PROTO != 5 "
         .. "AND DST2SRC_PACKETS <= 1 "
      .. "GROUP BY vlan_id, ip_src, dst_network "
      .. "HAVING count_ip_dst >= %u "
      .. "ORDER BY total_flows DESC "
      .. "LIMIT 1000",
      tonumber(interface.getId()),
      interval_begin, interval_end, interval_end,
      100
   )
   local results_network = interface.execSQLQuery(q_network)
   for _, row in ipairs(results_network) do
      local vlan_id = tonumber(row.vlan_id) or 0
      local attacker_ip = row.ip_src
      local attacker_key = row.ip_src .. "_" .. vlan_id
      -- Report a network scan only if the host has not performed a service scan
      if service_attackers[attacker_key] == nil then
         local victim_network = getLocalNetworkAliasById(row.dst_network)
         local num_victim = row.count_ip_dst
         if attacker_ip ~= "" then
            report_alert(params, attacker_ip, vlan_id, victim_network, num_victim, false, "Network")
         end
      end
   end
end

-- #################################################################

script.hooks["5mins"] = scan_check

-- #################################################################

return script