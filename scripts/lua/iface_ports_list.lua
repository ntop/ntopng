--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require "format_utils"
local rsp_resp = toboolean(_GET["scan_ports_rsp"]) or false

if not rsp_resp then
   sendHTTPContentTypeHeader('text/html')
end
local host_info = url2hostinfo(_GET)
local host_key = hostinfo2hostkey(host_info)

if isEmptyString(host_key) then
   host_info = nil
   host_key = nil
end

local function fill_ports_array(field_key, flows_stats)
   local ports_array = {}

   for _, value in ipairs(flows_stats) do
      local p = value[field_key..".port"]
      if(ports_array[p] == nil) then ports_array[p] = 0 end
      ports_array[p] = ports_array[p] + value["bytes"]
   end

   return ports_array
end

local flows_stats = interface.getFlowsInfo(host_key) or {}
if flows_stats["flows"] then
   flows_stats = flows_stats["flows"]
end

local client_ports = fill_ports_array("cli", flows_stats)
local server_ports = fill_ports_array("srv", flows_stats)
local ports

if(_GET["clisrv"] == "server") then
   ports = server_ports
else
   ports = client_ports
end

local _ports = { }
local tot = 0

for k, v in pairs(ports) do
   _ports[k] = v
   tot = tot + v
end

local threshold_percent = 5
local threshold = (tot * threshold_percent) / 100

if rsp_resp then
   local rest_utils = require("rest_utils")
   local host = _GET["host"]

   local res = {}
   local splitted_host = {}
   for str in string.gmatch(host,"([^@]+)") do
      splitted_host[#splitted_host+1] = str
   end

   local host_info = {
      ip = splitted_host[1],
      vlan = splitted_host[2]
   }
   local host = interface.getHostInfo(host_info["ip"], host_info["vlan"])
   
   if host then

      _ports = host.used_ports.local_server_ports
      for key, value in pairsByValues(_ports, rev) do

         local port_details = {}
         for str in string.gmatch(key,"([^:]+)") do
            port_details[#port_details+1] = str
         end

         local already_set = false
         for _,item in ipairs(res) do 
            if item == port_details[2] then
               already_set = true
               break
            end
         end
         if not already_set then
            res[#res+1] = {
               key = port_details[2],
               value = port_details[2]
            }
         end
      end
   

      rest_utils.answer(rest_utils.consts.success.ok, res)
   else 
      rest_utils.answer(rest_utils.consts.err.bad_content)

   end
else

   print "[ "

   local min_num = 4
   local num = 0
   local accumulate = 0
   for key, value in pairsByValues(_ports, rev) do

      if value < threshold then
         break
      end

      if(num > 0) then
         print ",\n"
      end

      print("\t { \"label\": \"" .. key .."\", \"value\": ".. value ..", \"url\": \""..ntop.getHttpPrefix().."/lua/flows_stats.lua?port="..key)
      if host_key then
         print("&host="..host_key)
      end

      print("\" }")

      accumulate = accumulate + value
      num = num + 1
   end

   -- In case there is some leftover do print it as "Other"
   if accumulate < tot then
      local other_label = i18n("other")
      local url = hostinfo2detailsurl(host_info, {page = "flows"})

      if(num > 0) then
         print (",\n")
      else
         if table.len(_ports) > 0 then
      other_label = i18n("num_different_ports", {num = format_utils.formatValue(table.len(_ports)), threshold = threshold_percent})
         end
      end

      print("\t { \"label\": \""..other_label.."\", \"value\": ".. (tot - accumulate) ..", \"url\": \""..url.."\"}")
   end

   if tot == 0 then
      print("\t { \"label\": \""..i18n("no_ports").."\", \"value\": 0 }")
   end

print "\n]"

end
