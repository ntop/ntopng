--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")
local dscp_consts = require "dscp_consts"

--
-- Read DSCP statistics on an interface
-- Example: curl -u admin:admin -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v1/get/interface/dscp/stats.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPContentTypeHeader('text/html')

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   print(rest_utils.rc(rc))
   return
end

interface.select(ifid)

local stats = interface.getStats()

if stats == nil then
   print(rest_utils.rc(rest_utils.consts.err.internal_error))
   return
end

for key, value in pairsByKeys(stats.dscp, asc) do
   res[#res + 1] = {
      label = dscp_consts.ds_class_descr(key),
      value = value['packets.rcvd'] + value['packets.sent']
   }
end

print(rest_utils.rc(rc, res))
