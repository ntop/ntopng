--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

--
-- Read statistics about nDPI application protocols for a hsot
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "host": "192.168.1.1"}' http://localhost:3000/lua/rest/v1/get/host/l7/stats.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local host_info = url2hostinfo(_GET)
local breed = _GET["breed"]
local ndpi_category = _GET["ndpi_category"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
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

local stats = interface.getHostInfo(host_info["host"], host_info["vlan"])

if stats == nil then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

tot = stats["bytes.sent"] + stats["bytes.rcvd"]

local _ifstats = computeL7Stats(stats, show_breed, show_ndpi_category)

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

   local duration = 0

   if(stats["ndpi"][key] ~= nil) then
      duration = stats["ndpi"][key]["duration"]
   end

   res[#res + 1] = {
      label = key,
      value = value,
      duration = duration,
   }

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

rest_utils.answer(rc, res)
