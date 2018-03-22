--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

mode = _GET["pid_mode"]
host = _GET["host"]
user = _GET["username"]

interface.select(ifname)
flows_stats = interface.getFlowsInfo()
flows_stats = flows_stats["flows"]
-- flows = interface.findUserFlows(user)

local debug = false


if (debug) then io.write("Host:"..host.."\n") end
if(flows == nil) then
   print('[ { "label": "Other", "value": 1 } ]') -- No flows found
else   
  
  if(mode == nil) then mode = "apps" end  

   apps = {}
   tot = 0
   for k,f in pairs(flows) do
    process = 1
    -- Filer users
    if (debug) then io.write("Client:"..f["cli.ip"]..", Server:"..f["srv.ip"].."\n") end
    if((host ~= nil) and ((f["cli.ip"] ~= host) and (f["srv.ip"] ~= host))) then
      process = 0
    end
    -- Prepare aggregation parameter
    if(mode == "apps") then
      if ((f["cli.ip"] == host) and (f["client_process"] ~= nil) and (f["client_process"]["user_name"] == user)) then
        key = f["client_process"]["name"]
        if (debug) then io.write("User:"..f["client_process"]["user_name"]..", Process:"..f["client_process"]["name"].."\n") end
      elseif ((f["srv.ip"] == host) and (f["server_process"] ~= nil) and (f["server_process"]["user_name"] == user)) then
        key = f["server_process"]["name"]
        if (debug) then io.write("User:"..f["server_process"]["user_name"]..", Process:"..f["server_process"]["name"].."\n") end
      end
    elseif(mode == "l7") then
      key = f["proto.ndpi"]
    elseif(mode == "l4") then
      key = f["proto.l4"]
    end

    -- Do aggregation 
    if((key ~= nil) and (process == 1))then
      if(apps[key] == nil) then apps[key] = 0 end
      v = f["cli2srv.bytes"] + f["srv2cli.bytes"]
      apps[key] = apps[key] + v
      tot = tot + v
    end
   end

-- Print up to this number of entries
max_num_entries = 10

-- Print entries whose value >= 5% of the total
threshold = (tot * 5) / 100

print "[\n"
num = 0
accumulate = 0
for key, value in pairs(apps) do
   if ((value < threshold) and (num ~= 0)) then
      break
   end

   if(num > 0) then
      print ",\n"
   end

   print("\t { \"label\": \"" .. key .."\", \"value\": ".. value .." }")
   accumulate = accumulate + value
   num = num + 1

   if(num == max_num_entries) then
      break
   end
end

if((num == 0) and (top_key ~= nil)) then
   print("\t { \"label\": \"" .. top_key .."\", \"value\": ".. top_value ..", \"url\": \""..ntop.getHttpPrefix().."/lua/host_details.lua?host=".. top_key .."\" }")
   accumulate = accumulate + top_value
end

-- In case there is some leftover do print it as "Other"
if(accumulate < tot) then
   if(num > 0) then print(",") end 
   print("\n\t { \"label\": \"Other\", \"value\": ".. (tot-accumulate) .." }")
end

print "\n]"
end



