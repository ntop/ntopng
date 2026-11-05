--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Save settings of an interface (administrators): only the fields in the body are changed,
-- with the names of the old interface settings form. Answers restart_required when ntopng must
-- be restarted to apply them (the flows dump of the interface).
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "0", "interface_top_talkers_creation": "1"}' http://localhost:3000/lua/rest/v2/set/interface/config.lua
--

-- http_lint: validates the JSON body (CSRF included) into _POST
require "http_lint"
require "ntop_utils"
local rest_utils = require "rest_utils"
local interface_config_utils = require "interface_config_utils"

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
if tostring(interface.getId()) ~= tostring(ifid) or interface.isPcapDumpInterface() then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

local res, invalid_field = interface_config_utils.apply(interface.getId(), _POST)
if not res then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { field = invalid_field })
   return
end

rest_utils.answer(rest_utils.consts.success.ok, res)
