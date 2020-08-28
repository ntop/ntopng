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
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "host" : "192.168.1.1"}' http://localhost:3000/lua/rest/v1/get/host/mud.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local host = _GET["host"]

if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

interface.select(ifid)

if isEmptyString(host) then
   rest_utils.answer(rest_utils.consts.err.invalid_host)
   return
end

local mud = mud_utils.getHostMUD(host)

if mud ~= nil then
   res = mud
end

rest_utils.answer(rc, res)
