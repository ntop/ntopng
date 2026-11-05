--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Add (or change, with old_syslog_producer_host) a syslog producer of a syslog interface
-- (administrators): the host sending the logs and the type of its logs (a syslog check).
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "5", "syslog_producer_host": "192.168.1.1", "syslog_producer": "suricata"}' http://localhost:3000/lua/rest/v2/add/syslog/producer.lua
--

require "http_lint"
require "ntop_utils"
local rest_utils = require "rest_utils"
local syslog_utils = require "syslog_utils"
local checks = require "checks"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _POST["ifid"]
if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end
interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) or not interface.isSyslogInterface() then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end
ifid = interface.getId()

local host = _POST["syslog_producer_host"]
local producer = _POST["syslog_producer"]
local old_host = _POST["old_syslog_producer_host"]

-- An IP address or a host name
if isEmptyString(host) or not host:match("^[%w%.%-:_]+$") then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { field = "syslog_producer_host" })
   return
end

-- The producer types are the syslog checks
local valid_type = false
for _, v in pairs(checks.listScripts(checks.script_types.syslog, "syslog") or {}) do
   if v == producer then valid_type = true end
end
if not valid_type then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { field = "syslog_producer" })
   return
end

if not isEmptyString(old_host) and not syslog_utils.hasProducer(ifid, old_host) then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { field = "old_syslog_producer_host" })
   return
end
if host ~= old_host and syslog_utils.hasProducer(ifid, host) then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { field = "syslog_producer_host", exists = true })
   return
end

if not isEmptyString(old_host) then syslog_utils.deleteProducer(ifid, old_host) end
syslog_utils.addProducer(ifid, host, producer)
interface.updateSyslogProducers()

rest_utils.answer(rest_utils.consts.success.ok)
