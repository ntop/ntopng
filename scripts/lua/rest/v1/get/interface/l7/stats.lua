--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

--
-- Read statistics about nDPI application protocols on an interface
-- Example: curl -u admin:admin -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v1/get/interface/l7/stats.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPContentTypeHeader('text/html')

local rc = rest_utils.consts_ok
local res = {}

local ifid = _GET["ifid"]
local host_info = url2hostinfo(_GET)
local breed = _GET["breed"]
local ndpi_category = _GET["ndpi_category"]
local ndpistats_mode = _GET["ndpistats_mode"]

if isEmptyString(ifid) then
   rc = rest_utils.consts_invalid_interface
   print(rest_utils.rc(rc))
   return
end

local show_breed = false
if breed == "true" then
   show_breed = true
end

local show_ndpi_category = false
if ndpi_category == "true" then
   show_ndpi_category = true
end

interface.select(ifid)

local ndpi_protos = interface.getnDPIProtocols()

local function getAppUrl(app)
   if ndpi_protos[app] ~= nil then
      return ntop.getHttpPrefix().."/lua/flows_stats.lua?application="..app
   end
   return nil
end

local tot = 0
local _ifstats = {}

if ndpistats_mode == "sinceStartup" then
   stats = interface.getStats()
   tot = stats.stats.bytes
elseif ndpistats_mode == "count" then
   stats = interface.getnDPIFlowsCount()
else
   stats = interface.getHostInfo(host_info["host"], host_info["vlan"])
   if stats == nil then
      print(rest_utils.rc(rest_utils.consts_not_found))
      return
   end
   tot = stats["bytes.sent"] + stats["bytes.rcvd"]
end

if stats == nil then
   print(rest_utils.rc(rest_utils.consts_internal_error))
   return
end

if(ndpistats_mode == "count") then
   tot = 0

   for k, v in pairs(stats) do
      tot = tot + v
      stats[k] = tonumber(v)
   end

   local threshold = (tot * 3) / 100
   local num = 0
   for k, v in pairsByValues(stats, rev) do
      if((num < 5) and (v > threshold)) then
         res[#res + 1] = {
            label = k,
            value = v,
            url = getAppUrl(k),
         }
         num = num + 1
         tot = tot - v
      else
         break
      end
   end

   if(tot > 0) then
      res[#res + 1] = {
         label = i18n("other"),
         value = tot,
      }
   elseif(num == 0) then
      res[#res + 1] = {
         label = i18n("no_flows"),
         value = 0,
      }
   end

   print(rest_utils.rc(rc, res))
   return
end

if(show_breed) then
   local breed_stats = {}

   for key, value in pairs(stats["ndpi"]) do
      local b = stats["ndpi"][key]["breed"]

      local traffic = stats["ndpi"][key]["bytes.sent"] + stats["ndpi"][key]["bytes.rcvd"]

      if(breed_stats[b] == nil) then
         breed_stats[b] = traffic
      else
         breed_stats[b] = breed_stats[b] + traffic
      end
   end

   for key, value in pairs(breed_stats) do
      _ifstats[key] = value
   end

elseif(show_ndpi_category) then
   local ndpi_category_stats = {}

   for key, value in pairs(stats["ndpi_categories"]) do
      key = getCategoryLabel(key)
      local traffic = value["bytes"]

      if(ndpi_category_stats[key] == nil) then
         ndpi_category_stats[key] = traffic
      else
         ndpi_category_stats[key] = ndpi_category_stats[key] + traffic
      end
   end

   for key, value in pairs(ndpi_category_stats) do
      _ifstats[key] = value
   end

else
   -- Add ARP to stats
   if(stats["eth"] ~= nil) then
      arpBytes = stats["eth"]["ARP_bytes"]
   else
      arpBytes = 0
   end

   if(arpBytes > 0) then
      _ifstats["ARP"] = arpBytes
   end

   for key, value in pairs(stats["ndpi"]) do
      local traffic = value["bytes.sent"] + value["bytes.rcvd"]
      if(key == "Unknown") then
         traffic = traffic - arpBytes
      end

      if(traffic > 0) then
         if(show_breed) then
            _ifstats[value["breed"]] = traffic
         else
            _ifstats[key] = traffic
         end
      end
   end
end

-- Print up to this number of entries
local max_num_entries = 5

-- Print entries whose value >= 3% of the total
local threshold = (tot * 3) / 100

local num = 0
local accumulate = 0

for key, value in pairsByValues(_ifstats, rev) do
   if(value < threshold) then
      break
   end

   if(host_info["host"] == nil) then
      res[#res + 1] = {
         label = key,
         value = value,
         url = getAppUrl(key),
      }
   else
      local duration

      if(stats["ndpi"][key] ~= nil) then
         duration = stats["ndpi"][key]["duration"]
      else
         duration = 0
      end

      res[#res + 1] = {
         label = key,
         value = value,
         duration = duration,
      }
   end

   accumulate = accumulate + value
   num = num + 1

   if(num == max_num_entries) then
      break
   end
end

if(tot == 0) then
   tot = 1
end

-- In case there is some leftover do print it as "Other"
if(accumulate < tot) then
   res[#res + 1] = {
      label = i18n("other"),
      value = (tot-accumulate),
   }
end

print(rest_utils.rc(rc, res))
