--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")
local stats_utils = require("stats_utils")

--
-- Read statistics about nDPI application protocols for a hsot
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "host": "192.168.1.1"}' http://localhost:3000/lua/rest/v2/get/host/l7/stats.lua
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

for key, value in pairsByValues(_ifstats, rev) do

   local duration = 0

   if(stats["ndpi"][key] ~= nil) then
      duration = stats["ndpi"][key]["duration"]
   end

   res[#res + 1] = {
      label = key,
      value = value,
      duration = duration,
   }

end

local collapsed = stats_utils.collapse_stats(res, 1, 3 --[[ threshold ]])

rest_utils.answer(rc, collapsed)
