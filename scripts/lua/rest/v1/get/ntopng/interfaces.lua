--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local rest_utils = require("rest_utils")

--
-- Return all the actively monitored ntopng interfaces along with their ids
-- Example: curl -u admin:admin  http://localhost:3000/lua/rest/v1/get/ntopng/interfaces.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts_ok
local res = {}

for ifid, ifname in pairs(interface.getIfNames()) do
   res[#res + 1] = {ifid = tonumber(ifid), ifname = ifname}
end

print(rest_utils.rc(rc, res))
