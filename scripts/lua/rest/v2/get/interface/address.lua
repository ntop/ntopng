--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"
local json = require("dkjson")
local rest_utils = require("rest_utils")

--
-- Read the IP address(es) for an interface
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/interface/address.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

local ifstats = interface.getStats()

local addresses = {}

if not isEmptyString(ifstats.ip_addresses) then
   local tokens = split(ifstats.ip_addresses, ",")
   if tokens ~= nil then
      for _,s in pairs(tokens) do
         addresses[#addresses+1] = s
      end

   end
end

res.addresses = addresses;

rest_utils.answer(rc, res)
