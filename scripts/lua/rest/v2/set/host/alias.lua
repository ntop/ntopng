--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local tracker = require("tracker")
local rest_utils = require("rest_utils")

--
-- Set host alias
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"host" : "192.168.1.1", "custom_name" : "Mario"}' http://localhost:3000/lua/rest/v2/set/host/alias.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local host_info = url2hostinfo(_POST)
local custom_name = _POST["custom_name"]

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if host_info == nil or isEmptyString(host_info["host"]) or custom_name == nil then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

setHostAltName(host_info["host"], custom_name)

-- TRACKER HOOK
tracker.log('set_host_alias', { host = hostinfo2hostkey(host_info), custom_name = custom_name })

rest_utils.answer(rc, res)

