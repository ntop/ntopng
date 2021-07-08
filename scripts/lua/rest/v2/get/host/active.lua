--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
local format_utils = require("format_utils")
local json = require "dkjson"
local rest_utils = require("rest_utils")

--
-- Read list of active hosts
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/host/active.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]

-- Pagination:
local all = _GET["all"]
local currentPage = _GET["currentPage"]
local perPage     = _GET["perPage"]
local sortColumn  = _GET["sortColumn"] -- ip, name, since, last, alerts, country, vlan, num_flows, traffic, thpt
local sortOrder   = _GET["sortOrder"]

-- Filters
local mode        = _GET["mode"] -- all local remote broadcast_domain filtered blacklisted dhcp
local ipversion   = _GET["version"]
local protocol    = _GET["protocol"]
local traffic_type = _GET["traffic_type"]
local asn          = _GET["asn"]
local vlan         = _GET["vlan"]
local network      = _GET["network"]
local cidr         = _GET["network_cidr"]
local pool         = _GET["pool"]
local country      = _GET["country"]
local os_          = tonumber(_GET["os"])
local mac          = _GET["mac"]
local top_hidden   = ternary(_GET["top_hidden"] == "1", true, nil)

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

if not isEmptyString(_GET["sortColumn"]) then
   -- Backward compatibility
   _GET["sortColumn"] = "column_" .. _GET["sortColumn"]
   sortColumn  = _GET["sortColumn"]
end

if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(perPage == nil) then
   perPage = getDefaultTableSize()
else
   perPage = tonumber(perPage)
   tablePreferences("rows_number",perPage)
end

local traffic_type_filter

if traffic_type == "one_way" then
   traffic_type_filter = 1 -- ntop_typedefs.h TrafficType traffic_type_one_way
elseif traffic_type == "bidirectional" then
   traffic_type_filter = 2 -- ntop_typedefs.h TrafficType traffic_type_bidirectional
end

if isEmptyString(mode) then
   mode = "all"
end

interface.select(ifname)

local to_skip = (currentPage-1) * perPage

if(sortOrder == "desc") then sOrder = false else sOrder = true end

local filtered_hosts = false
local blacklisted = false
local anomalous = false
local dhcp_hosts = false

local hosts_retrv_function = interface.getHostsInfo
if mode == "local" then
   hosts_retrv_function = interface.getLocalHostsInfo
elseif mode == "remote" then
   hosts_retrv_function = interface.getRemoteHostsInfo
elseif mode == "broadcast_domain" then
   hosts_retrv_function = interface.getBroadcastDomainHostsInfo
elseif mode == "filtered" then
   filtered_hosts = true
elseif mode == "blacklisted" then
   blacklisted_hosts = true
elseif mode == "dhcp" then
   dhcp_hosts = true
end



local hosts_stats = hosts_retrv_function(false, sortColumn, perPage, to_skip, sOrder,
                          country, os_, tonumber(vlan), tonumber(asn),
                          tonumber(network), mac,
                          tonumber(pool), tonumber(ipversion),
                          tonumber(protocol), traffic_type_filter,
                          filtered_hosts, blacklisted_hosts, top_hidden, anomalous, dhcp_hosts, cidr)

if hosts_stats == nil then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

hosts_stats = hosts_stats["hosts"]

if hosts_stats == nil then
   rest_utils.answer(rest_utils.consts.err.internal_error)
   return
end

if all ~= nil then
   perPage = 0
   currentPage = 0
end

function get_host_name(h)
   if h["name"] == nil then
      if h["ip"] ~= nil then
         h["name"] = ip2label(h["ip"])
      else
         h["name"] = h["mac"]
      end
   end
   return(h["name"])
end

local vals = {}
local num = 0
for key, value in pairs(hosts_stats) do
   num = num + 1
   postfix = string.format("0.%04u", num)

   if(isEmptyString(sortColumn)) then
      vals[key] = key
   elseif(sortColumn == "column_name") then
      hosts_stats[key]["name"] = get_host_name(hosts_stats[key])
      vals[hosts_stats[key]["name"]..postfix] = key
   elseif(sortColumn == "column_since") then
      vals[hosts_stats[key]["seen.first"]+postfix] = key
   elseif(sortColumn == "column_alerts") then
      vals[hosts_stats[key]["num_alerts"]+postfix] = key
   elseif(sortColumn == "column_last") then
      vals[hosts_stats[key]["seen.last"]+postfix] = key
   elseif(sortColumn == "column_country") then
      vals[hosts_stats[key]["country"]..postfix] = key
   elseif(sortColumn == "column_vlan") then
      vals[hosts_stats[key]["vlan"]..postfix] = key
   elseif(sortColumn == "column_num_flows") then
      local t = hosts_stats[key]["active_flows.as_client"]+hosts_stats[key]["active_flows.as_server"]
      vals[t+postfix] = key
   elseif(sortColumn == "column_num_dropped_flows") then
      local t = hosts_stats[key]["flows.dropped"] or 0
      vals[t+postfix] = key
   elseif(sortColumn == "column_traffic") then
      vals[hosts_stats[key]["bytes.sent"]+hosts_stats[key]["bytes.rcvd"]+postfix] = key
   elseif(sortColumn == "column_thpt") then
      vals[hosts_stats[key]["throughput_bps"]+postfix] = key
   elseif(sortColumn == "column_queries") then
      vals[hosts_stats[key]["queries.rcvd"]+postfix] = key
   elseif(sortColumn == "column_ip") then
      vals[hosts_stats[key]["ipkey"]+postfix] = key
   else
      vals[key] = key
   end
end

if sortOrder == "asc" then
   funct = asc
else
   funct = rev
end

local data = {}

for _key, _value in pairsByKeys(vals, funct) do
   local record = {}
   local key = vals[_key]
   local value = hosts_stats[key]
   local symkey = hostinfo2jqueryid(hosts_stats[key])

   record["key"] = symkey
   record["first_seen"] = value["seen.first"]
   record["last_seen"] = value["seen.last"]
   record["vlan"] = value["vlan"]
   record["ip"] = stripVlan(key) 
   record["os"] = value["os"]
   record["num_alerts"] = value["num_alerts"]

   local host = interface.getHostInfo(hosts_stats[key].ip, hosts_stats[key].vlan)
   if host ~= nil then
      record["country"] = host["country"]
      record["is_blacklisted"] = host["is_blacklisted"]
   end

   local name = value["name"]
   if isEmptyString(name) then
      local hinfo = hostkey2hostinfo(key)
      name = hostinfo2label(hinfo)
   end
   if isEmptyString(name) then
      name = key
   end
   if value["ip"] ~= nil then
      local label = hostinfo2label(value)
      if label ~= value["ip"] and name ~= label then
         name = name .. " ["..label.."]"
      end
   end

   record["name"] = name

   record["thpt"] = {}
   record["thpt"]["pps"] = value["throughput_pps"]
   record["thpt"]["bps"] = value["throughput_bps"]*8

   record["bytes"] = {}
   record["bytes"]["total"] = (value["bytes.sent"]+value["bytes.rcvd"])
   record["bytes"]["sent"]  = value["bytes.sent"]
   record["bytes"]["recvd"] = value["bytes.rcvd"]

   record["is_localhost"] = value["localhost"]
   record["is_multicast"] = value["is_multicast"]
   record["is_broadcast"] = value["is_broadcast"]
   record["is_broadcast_domain"] = value["broadcast_domain_host"]

   record["num_flows"] = {}
   record["num_flows"]["total"]     = (value["active_flows.as_client"] + value["active_flows.as_server"])
   record["num_flows"]["as_client"] = (value["active_flows.as_client"])
   record["num_flows"]["as_server"] = (value["active_flows.as_server"])

   data[#data + 1] = record
end -- for

res = {
   perPage = perPage,
   currentPage = currentPage,
   totalRows = total,
   data = data,
   sort = {
      {
         sortColumn,
         sortOrder
      }
   },
}

rest_utils.answer(rc, res)
