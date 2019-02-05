--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('application/json')

interface.select(ifname)
flows_stats = interface.getFlowsInfo()
flows_stats = flows_stats["flows"]

links = {}
processes = {}

for key, value in pairs(flows_stats) do
   flow = flows_stats[key]

   if(flow["cli.host"] ~= nil) then c = flow["cli.host"] else c = flow["cli.ip"] end
   if(flow["srv.host"] ~= nil) then s = flow["srv.host"] else s = flow["srv.ip"] end
   
   c = c .. "@" .. flow["cli.source_id"]
   s = s .. "@" .. flow["srv.source_id"]

   if(flow["client_process"] ~= nil) then
      if(links[c] == nil) then links[c] = {} end
      links[c]["peer"] = s
      if(links[c]["num"] == nil) then links[c]["num"] = 0 end
      links[c]["num"] = links[c]["num"] + 1
   end

   if(flow["server_process"] ~= nil) then
      if(links[s] == nil) then links[s] = {} end
      links[s]["peer"] = c
      if(links[s]["num"] == nil) then links[s]["num"] = 0 end
   end
end

print("[")
n = 0
for key, value in pairs(links) do
   if(n > 0) then print(",") end

   print('\n{"source": "'..key..'", "source_num": '.. links[key]["num"]..', "source_type": "host", "source_pid": -1, "source_name": "'..ntop.getResolvedAddress(hostkey2hostinfo(key))..'", "target": "'..value["peer"]..'", "target_num": '.. value["num"]..', "target_type": "host", "target_pid": -1, "target_name": "'.. ntop.getResolvedAddress(hostkey2hostinfo(value["peer"]))..'", "type": "host2host"}')
   n = n + 1
end
print("\n]\n")

