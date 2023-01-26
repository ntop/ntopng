--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

require "lua_utils"
local auth = require "auth"
local rest_utils = require "rest_utils"
local all_alert_store = require "all_alert_store".new()

--
-- Trigger a custom host alert
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": 0, "host": "192.168.2.134", "vlan": 0, "score": 100, "info": "Custom alert triggered thrugh the REST API"}' http://localhost:3000/lua/rest/v2/trigger/host/alert.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok

local ifid = _POST["ifid"]
local hostinfo = url2hostinfo(_POST)
local score = _POST["score"] or "0"
local info = _POST["info"]

if not auth.has_capability(auth.capabilities.alerts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

if isEmptyString(hostinfo['host']) or
   isEmptyString(info) then
   rc = rest_utils.consts.err.invalid_args
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

interface.triggerExternalHostAlert(hostinfo2hostkey(hostinfo), tonumber(score), info)

local res = {}

rest_utils.answer(rc, res)
