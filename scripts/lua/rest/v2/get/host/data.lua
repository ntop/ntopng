--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local tracker = require("tracker")
local rest_utils = require("rest_utils")

--
-- Read information about a host
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "host" : "192.168.1.1"}' http://localhost:3000/lua/rest/v2/get/host/data.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local host_info = url2hostinfo(_GET)

-- whether to return host statistics: on by default
local host_stats           = _GET["host_stats"]

-- whether to return statistics regarding host flows: off by default
local host_stats_flows     = _GET["host_stats_flows"]
local host_stats_flows_num = _GET["limit"]

if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

if isEmptyString(host_info["host"]) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(ifid)

local host = interface.getHostInfo(host_info["host"], host_info["vlan"])

if not host then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

local function flows2protocolthpt(flows)
   local protocol_thpt = {}
   for _, flow in pairs(flows) do
      local proto_ndpi = ""
      if flow["proto.ndpi"] == nil or flow["proto.ndpi"] == "" then
	 goto continue
      else
	 proto_ndpi = flow["proto.ndpi"]
      end

      if protocol_thpt[proto_ndpi] == nil then
	 protocol_thpt[proto_ndpi] =
	    {["cli2srv"]={["throughput_bps"]=0, ["throughput_pps"]=0},
	       ["srv2cli"]={["throughput_bps"]=0, ["throughput_pps"]=0}}
      end

      for _, dir in pairs({"cli2srv", "srv2cli"}) do
	 for _, dim in pairs({"bps", "pps"}) do
	    protocol_thpt[proto_ndpi][dir]["throughput_"..dim] =
	       protocol_thpt[proto_ndpi][dir]["throughput_"..dim] + flow[dir..".throughput_"..dim]
	 end
      end
      ::continue::
   end
   return protocol_thpt
end

-- hosts stats are on by default, one must explicitly disable them
if not (host_stats == nil or host_stats == "" or host_stats == "true" or host_stats == "1") then
   host = {}
end

-- host flow stats are off by default and must be explicitly enabled
if host_stats_flows ~= nil and host_stats_flows ~= "" then
   if host_stats_flows_num == nil or tonumber(host_stats_flows_num) == nil then
      -- default: do not limit the number of flows
      host_stats_flows_num = 99999
   else
      -- ... unless otherwise specified
      host_stats_flows_num = tonumber(host_stats_flows_num)
   end

   local total = 0

   local pageinfo = {["sortColumn"]="column_bytes", ["a2zSortOrder"]=false,
      ["maxHits"]=host_stats_flows_num, ["toSkip"]=0, ["detailedResults"]=true}

   --local flows = interface.getFlowsInfo(host_info["host"], nil, "column_bytes", host_stats_flows_num, 0, false)
   local flows = interface.getFlowsInfo(host_info["host"], pageinfo)
   flows = flows["flows"]
   for i, fl in ipairs(flows) do
      flows[i] = {
            ["srv.ip"] = fl["srv.ip"], ["cli.ip"] = fl["cli.ip"],
            ["srv.port"] = fl["srv.port"], ["cli.port"] = fl["cli.port"],
            ["proto.ndpi_id"] = fl["proto.ndpi_id"], ["proto.ndpi"] = fl["proto.ndpi"],
            ["bytes"] = fl["bytes"],
            ["cli2srv.throughput_bps"] = round(fl["throughput_cli2srv_bps"], 2),
            ["srv2cli.throughput_bps"] = round(fl["throughput_srv2cli_bps"], 2),
            ["cli2srv.throughput_pps"] = round(fl["throughput_cli2srv_pps"], 2),
            ["srv2cli.throughput_pps"] = round(fl["throughput_srv2cli_pps"], 2),
      }

      if fl["proto.l4"] == "TCP" then
         flows[i]["cli2srv.tcp_flags"] = TCPFlags2table(fl["cli2srv.tcp_flags"])
         flows[i]["srv2cli.tcp_flags"] = TCPFlags2table(fl["srv2cli.tcp_flags"])
         flows[i]["tcp_established"]   = fl["tcp_established"]
      end
   end

   host["ndpiThroughputStats"] = flows2protocolthpt(flows)
   host["flows"] = flows
   host["flows_count"] = total
end

res = host

tracker.log("host_get_json", {host_info["host"], host_info["vlan"]})

rest_utils.answer(rc, res)

