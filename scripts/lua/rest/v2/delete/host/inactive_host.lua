--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local inactive_hosts_utils = require("inactive_hosts_utils")
--
-- Read alerts data
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/delete/host/alerts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _GET["ifid"]
local serial_key = _GET["serial_key"]

if isEmptyString(ifid) or isEmptyString(serial_key) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

local num_hosts_deleted = 0

if tonumber(serial_key) then
   local epoch = os.time() - tonumber(serial_key)
   num_hosts_deleted = inactive_hosts_utils.deleteAllEntriesSince(ifid, epoch)
elseif (serial_key == "all") then
   num_hosts_deleted = inactive_hosts_utils.deleteAllEntries(ifid)
else
   num_hosts_deleted = inactive_hosts_utils.deleteSingleEntry(ifid, serial_key)
end

rest_utils.answer(rc, {deleted_hosts = num_hosts_deleted})

