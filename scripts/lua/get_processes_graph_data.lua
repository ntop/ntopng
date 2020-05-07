--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"

sendHTTPHeader('application/json')

local host_info = url2hostinfo(_GET)
local host_key = hostinfo2hostkey(host_info)

local pageinfo = {
   -- ["sortColumn"] = "column_bytes",
   -- ["maxHits"] = 15,
   -- ["a2zSortOrder"] = false,
   ["hostFilter"] = host_key,
   ["detailsLevel"] = "high", -- to obtain processes information
}

local flows_stats = interface.getFlowsInfo(host_key, pageinfo)
flows_stats = flows_stats["flows"] or {}

local proc2proc_edges = {}
local proc2host_edges = {}
local host2proc_edges = {}

local procs = {}
local hosts = {}

local res = {}

local num = 0
for _, flow in ipairs(flows_stats) do
   local cli_key = hostinfo2hostkey({host = flow["cli.ip"], vlan = flow["cli.vlan"]})
   local srv_key = hostinfo2hostkey({host = flow["srv.ip"], vlan = flow["srv.vlan"]})

   if not flow["client_process"] and not flow["server_process"] then
      goto continue
   end

   local has_source_process
   local source
   if flow["client_process"] then
      has_source_process = true
      source = flow["client_process"]["pid"]

      if not procs[source] then
	 procs[source] = {name = flow["client_process"]["name"]}
      end
   else
      has_source_process = false
      source = cli_key

      if not hosts[source] then
	 hosts[source] = {name = ip2label(flow["cli.ip"], flow["cli.vlan"])}
      end
   end

   local has_target_process
   local target
   if flow["server_process"] then
      has_target_process = true
      target = flow["server_process"]["pid"]

      if not procs[target] then
	 procs[target] = {name = flow["server_process"]["name"]}
      end
   else
      has_target_process = false
      target = cli_key

      if not hosts[target] then
	 hosts[target] = {name = ip2label(flow["srv.ip"], flow["srv.vlan"])}
      end
   end

   local edges
   if has_source_process and has_target_process then
      edges = proc2proc_edges
   elseif has_source_process and not has_target_process then
      edges = proc2host_edges
   elseif not has_source_process and has_target_process then
      edges = host2proc_edges
   end

   if not edges[source] then
	 edges[source] = {}
   end

   if not edges[source][target] then
      edges[source][target] = 0
   end

   edges[source][target] = edges[source][target]
      + flow["srv2cli.bytes"]
      + flow["cli2srv.bytes"]

   ::continue::
end

local r = {}

for source, targets in pairs(proc2proc_edges) do
   for target, weigth in pairs(targets) do
      r[#r + 1] = {source = source, source_type = "proc", source_pid = source, source_name = procs[source]["name"],
		   target = target, target_type = "proc", target_pid = target, target_name = procs[target]["name"],
		   type = "proc2proc"}
   end
end

for source, targets in pairs(proc2host_edges) do
   for target, weigth in pairs(targets) do
      r[#r + 1] = {source = source, source_type = "proc", source_pid = source, source_name = procs[source]["name"],
		   target = target, target_type = "host", target_pid = -1, target_name = hosts[target]["name"],
		   type = "proc2host"}
   end
end

for source, targets in pairs(host2proc_edges) do
   for target, weigth in pairs(targets) do
      r[#r + 1] = {source = source, source_type = "host", source_pid = -1, source_name = hosts[source]["name"],
		   target = target, target_type = "proc", target_pid = target, target_name = procs[target]["name"],
		   type = "host2proc"}
   end
end

print(json.encode(r))
