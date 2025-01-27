--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local rest_utils = require("rest_utils")
local asset_utils = require("asset_utils")
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
   num_hosts_deleted = asset_utils.deleteAllEntriesSince(ifid, 'host', tonumber(serial_key))
elseif (serial_key == "all") then
   num_hosts_deleted = asset_utils.deleteAll(ifid, 'host')
elseif (not isEmptyString(serial_key)) then
   num_hosts_deleted = asset_utils.deleteHost(ifid, serial_key)
end

rest_utils.answer(rc, {deleted_hosts = num_hosts_deleted})

