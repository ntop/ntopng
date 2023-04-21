--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

require "lua_utils"
local auth = require "auth"
local alert_consts = require("alert_consts")
local alert_entities = require "alert_entities"
local rest_utils = require "rest_utils"
local checks = require "checks"

--
-- Trigger a custom host alert
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": 0, "host": "192.168.2.134", "vlan": 0, "score": 100, "info": "Custom alert triggered through the REST API"}' http://localhost:3000/lua/rest/v2/trigger/host/alert.lua
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

if not checks.isCheckEnabled("host", "external_host_script") then
   rest_utils.answer(rest_utils.consts.err.not_enabled)
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

local host_key = hostinfo2hostkey(hostinfo)
score = tonumber(score)

-- Option 1. Trigger alert through the C check
-- Note: This expects that the host is live, otherwise the alert is not triggered
-- interface.triggerExternalHostAlert(host_key, score, info)

-- Option 2. Trigger alert directly from Lua
-- Note: This does not require the host to be live, however some metadata may be missing
local alert = alert_consts.alert_types.host_alert_external_script.new(info)
alert:set_score(score)
alert:set_subtype(host_key)
local alert_info = {
   entity_val = host_key,
   alert_entity = alert_entities.host
}
alert:store(alert_info)

rest_utils.answer(rc, {})
