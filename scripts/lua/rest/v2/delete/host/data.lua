--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local delete_data_utils = require "delete_data_utils"

--
-- Delete host/network data for the given interface.
-- Example: curl -u admin:admin -H "Content-Type: application/json" \
--   -d '{"ifid":"1","host":"192.168.1.1","vlan":"0"}' \
--   http://localhost:3000/lua/rest/v2/delete/host/data.lua
--

local rc = rest_utils.consts.success.ok
local res = {}

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _POST["ifid"]
local host = _POST["host"]
local vlan = tonumber(_POST["vlan"]) or 0

if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

if isEmptyString(host) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(ifid)

local parts = split(host, "/")
local delete_res

if (#parts == 2) and (tonumber(parts[2]) ~= nil) then
   delete_res = delete_data_utils.delete_network(ifid, parts[1], parts[2], vlan)
else
   local host_info = { host = host, vlan = vlan }
   delete_res = delete_data_utils.delete_host(ifid, host_info)
end

local err_msgs = {}

for what, what_res in pairs(delete_res) do
   if what_res["status"] ~= "OK" then
      err_msgs[#err_msgs + 1] = delete_data_utils.status_to_i18n(what_res["status"])
   end
end

if #err_msgs > 0 then
   rc = rest_utils.consts.err.internal_error
   res = { errors = err_msgs }
end

rest_utils.answer(rc, res)
