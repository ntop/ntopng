--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Settings of an interface (administrators): the ones that apply to it and their values, as
-- shown by Interface details > Settings. Saved by rest/v2/set/interface/config.lua.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/interface/config.lua?ifid=0"
--

-- No lua_utils: http_lint validates _GET, the helpers are in interface_config_utils
require "http_lint"
require "ntop_utils"
local rest_utils = require "rest_utils"
local interface_config_utils = require "interface_config_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _GET["ifid"]
if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

-- No settings for a pcap file (as the old page)
if interface.isPcapDumpInterface() then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

rest_utils.answer(rest_utils.consts.success.ok, interface_config_utils.read(interface.getId()))
