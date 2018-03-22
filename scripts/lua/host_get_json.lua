--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")

-- whether to return host statistics: on by default
local host_stats           = _GET["host_stats"]

-- whether to return statistics regarding host flows: off by default
local host_stats_flows     = _GET["host_stats_flows"]
local host_stats_flows_num = _GET["limit"]

host_info = url2hostinfo(_GET)
host = _GET["host"]

if(host_info["host"] == nil) then
   sendHTTPContentTypeHeader('text/html')
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Host parameter is missing (internal error ?)</div>")
   return
end

function flows2protocolthpt(flows)
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

ifid = _GET["ifid"]
-- parse interface names and possibly fall back to the selected interface:
-- priority goes to the interface id
if ifid ~= nil and ifid ~= "" then
   if_name = getInterfaceName(ifid)
-- finally, we fall back to the default selected interface name
else
   -- fall-back to the default interface
   if_name = ifname
   ifid = interface.name2id(ifname)
end

interface.select(if_name)
host = interface.getHostInfo(host_info["host"], host_info["vlan"])

if(host == nil) then
   sendHTTPContentTypeHeader('text/html')
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Host ".. host_info["host"] .. " Vlan" ..host_info["vlan"].." cannot be found (expired ?)</div>")
   return
else
   sendHTTPHeader('application/json')
   local hj = {}
   -- hosts stats are on by default, one must explicitly disable them
   if host_stats == nil or host_stats == "" or host_stats == "true" or host_stats == "1" then
      hj = json.decode(host["json"])
      hj["sites"] = host["sites"]
      hj["http"] = host["http"]
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
      hj["ndpiThroughputStats"] = flows2protocolthpt(flows)
      hj["flows"] = flows
      hj["flows_count"] = total
   end
   print(json.encode(hj, nil))
end

