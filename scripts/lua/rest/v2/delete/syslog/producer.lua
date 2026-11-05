--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Delete a syslog producer of a syslog interface (administrators).
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "5", "syslog_producer_host": "192.168.1.1"}' http://localhost:3000/lua/rest/v2/delete/syslog/producer.lua
--

require "http_lint"
require "ntop_utils"
local rest_utils = require "rest_utils"
local syslog_utils = require "syslog_utils"

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

local host = _POST["syslog_producer_host"]
if isEmptyString(host) or not syslog_utils.hasProducer(interface.getId(), host) then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { field = "syslog_producer_host" })
   return
end

syslog_utils.deleteProducer(interface.getId(), host)
interface.updateSyslogProducers()
rest_utils.answer(rest_utils.consts.success.ok)
