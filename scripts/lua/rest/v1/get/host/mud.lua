--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local mud_utils = require("mud_utils")
local json = require("dkjson")
local rest_utils = require("rest_utils")

--
-- Read MUD information of a host
-- Example: curl -u admin:admin -d '{"ifid": "1", "host" : "192.168.1.1"}' http://localhost:3000/lua/rest/v1/get/host/mud.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts_ok
local res = {}

local ifid = _GET["ifid"]
local host = _GET["host"]

if isEmptyString(ifid) then
   print(rest_utils.rc(rest_utils.consts_invalid_interface))
   return
end

if isEmptyString(host) then
   print(rest_utils.rc(rest_utils.consts_invalid_host))
   return
end

local mud = mud_utils.getHostMUD(host)

if mud ~= nil then
   res = mud
end

print(rest_utils.rc(rc, res))
