--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
local format_utils = require("format_utils")
local flow_utils = require "flow_utils"
local icmp_utils = require "icmp_utils"
local json = require "dkjson"
local rest_utils = require("rest_utils")

--
-- Read list of active flows
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/flow/active.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local verbose = (_GET["verbose"] == "true")

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

if not isEmptyString(_GET["sortColumn"]) then
   -- Backward compatibility
   _GET["sortColumn"] = "column_" .. _GET["sortColumn"]
end

-- This is using GET parameters to handle:
--
-- Pagination:
-- - sortColumn
-- - sortOrder
-- - currentPage
-- - perPage
--
-- Filtering, including:
-- - application
-- - l4proto
-- - host
-- - vlan
--
local flows_filter = getFlowsFilter()

local flows_stats = interface.getFlowsInfo(flows_filter["hostFilter"], flows_filter)

if flows_stats == nil then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

local total = flows_stats["numFlows"]

flows_stats = flows_stats["flows"]

if flows_stats == nil then
   rest_utils.answer(rest_utils.consts.err.internal_error)
   return
end

local data = {}

for _key, value in ipairs(flows_stats) do
   local record = {}

   local key = value["ntopng.key"]

   record["key"] = string.format("%u", value["ntopng.key"])
   record["hash_id"] = string.format("%u", value["hash_entry_id"])

   record["first_seen"] = value["seen.first"]
   record["last_seen"] = value["seen.last"]

   local client = {}

   local cli_name = flowinfo2hostname(value, "cli")
   client["name"] = stripVlan(cli_name)
   client["ip"] = value["cli.ip"]
   client["port"] = value["cli.port"]

   local info = interface.getHostInfo(value["cli.ip"], value["cli.vlan"])
   if info then
      client["is_broadcast_domain"] = info.broadcast_domain_host
      client["is_dhcp"] = info.dhcpHost
      client["is_blacklisted"] = info.is_blacklisted
   end

   record["client"] = client

   local server = {}

   local srv_name = flowinfo2hostname(value, "srv")
   server["name"] = stripVlan(srv_name) 
   server["ip"] = value["srv.ip"]
   server["port"] = value["srv.port"]

   info = interface.getHostInfo(value["srv.ip"], value["srv.vlan"])
   local info = interface.getHostInfo(value["cli.ip"], value["cli.vlan"])
   if info then
      server["is_broadcast"] = info.broadcast_domain_host
      server["is_dhcp"] = info.dhcpHost
      server["is_blacklisted"] = info.is_blacklisted
   end

   record["server"] = server

   record["vlan"] = value["vlan"]

   record["protocol"] = {}
   record["protocol"]["l4"] = value["proto.l4"]
   record["protocol"]["l7"] = value["proto.ndpi"]

   record["duration"] = value["duration"]

   record["bytes"] = value["bytes"]

   record["thpt"] = {}
   record["thpt"]["pps"] = value["throughput_pps"]
   record["thpt"]["bps"] = value["throughput_bps"]*8

   local cli2srv = round((value["cli2srv.bytes"] * 100) / value["bytes"], 0)
   record["breakdown"] = {}
   record["breakdown"]["cli2srv"] = cli2srv
   record["breakdown"]["srv2cli"] =  (100-cli2srv)

   if isScoreEnabled() then
      record["score"] = format_utils.formatValue(value["score"]["flow_score"])
   end

   if verbose then
      record["packets"] = value["cli2srv.packets"] + value["srv2cli.packets"]

      record["tcp"] = {}

      record["tcp"]["appl_latency"] = value["tcp.appl_latency"]
 
      record["tcp"]["nw_latency"] = {}
      record["tcp"]["nw_latency"]["cli"] = value["tcp.nw_latency.client"]
      record["tcp"]["nw_latency"]["srv"] = value["tcp.nw_latency.server"]

      record["tcp"]["retransmissions"] = {}
      record["tcp"]["retransmissions"]["cli2srv"] = value["cli2srv.retransmissions"]
      record["tcp"]["retransmissions"]["srv2cli"] = value["srv2cli.retransmissions"]

      record["tcp"]["out_of_order"] = {}
      record["tcp"]["out_of_order"]["cli2srv"] = value["cli2srv.out_of_order"]
      record["tcp"]["out_of_order"]["srv2cli"] = value["srv2cli.out_of_order"]

      record["tcp"]["lost"] = {}
      record["tcp"]["lost"]["cli2srv"] = value["cli2srv.lost"]
      record["tcp"]["lost"]["srv2cli"] = value["srv2cli.lost"]
   end

   data[#data + 1] = record

end -- for

res = {
   perPage = flows_filter["perPage"],
   currentPage = flows_filter["currentPage"],
   totalRows = total,
   data = data,
   sort = {
      {
         flows_filter["sortColumn"],
         flows_filter["sortOrder"]
      }
   },
}

rest_utils.answer(rc, res)
