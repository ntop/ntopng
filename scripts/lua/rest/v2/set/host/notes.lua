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
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"host" : "192.168.1.1", "custom_notes" : "macbook in conference room"}' http://localhost:3000/lua/rest/v2/set/host/alias.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local host_info = url2hostinfo(_POST)
local custom_notes = _POST["custom_notes"]

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if host_info == nil or isEmptyString(host_info["host"]) or custom_notes == nil then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

setHostNotes(host_info["host"], custom_notes)

-- TRACKER HOOK
tracker.log('set_host_notes', { host = hostinfo2hostkey(host_info), custom_notes = custom_notes })

rest_utils.answer(rc, res)

