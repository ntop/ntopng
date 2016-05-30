--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")

-- whether to return host statistics: on by default
local host_stats           = _GET["host_stats"]

-- whether to return statistics regarding host flows: off by default
local host_stats_flows     = _GET["host_stats_flows"]
local host_stats_flows_num = _GET["host_stats_flows_num"]

host_info = url2hostinfo(_GET)
host = _GET["host"]

if(host_info["host"] == nil) then
   sendHTTPHeader('text/html; charset=iso-8859-1')
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Host parameter is missing (internal error ?)</div>")
   return
end

interface.select(ifname)
host = interface.getHostInfo(host_info["host"], host_info["vlan"])

if(host == nil) then
   sendHTTPHeader('text/html; charset=iso-8859-1')
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

      local flows = interface.getFlowsInfo(host_info["host"], nil, "column_bytes", host_stats_flows_num, 0, false)
      flows,total = aggregateFlowsStats(flows)
      for i, fl in ipairs(flows) do
	 flows[i] = {
	    ["srv.ip"] = fl["srv.ip"], ["cli.ip"] = fl["cli.ip"],
	    ["srv.port"] = fl["srv.port"], ["cli.port"] = fl["cli.port"],
	    ["proto.ndpi_id"] = fl["proto.ndpi_id"], ["proto.ndpi"] = fl["proto.ndpi"],
	    ["bytes"] = fl["bytes"],
	    ["cli2srv.throughput_bps"] = round(fl["throughput_cli2srv_bps"], 2),
	    ["srv2cli.throughput_bps"] = round(fl["throughput_srv2cli_bps"], 2),
	    ["cli2srv.throughput_pps"] = round(fl["throughput_cli2srv_pps"], 2),
	    ["srv2cli.throughput_pps"] = round(fl["throughput_srv2cli_pps"], 2)
	 }
      end
      hj["flows"] = flows
      hj["flows_count"] = total
   end
   print(json.encode(hj, nil))
end
