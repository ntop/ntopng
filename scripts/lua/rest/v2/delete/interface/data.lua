--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils        = require "rest_utils"
local delete_data_utils = require "delete_data_utils"

--
-- Request the deletion of the data of an active interface: performed at the
-- next restart, as the data is in use (Developer > Manage Data).
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid":"1"}' http://localhost:3000/lua/rest/v2/delete/interface/data.lua
--

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = tonumber(_POST["ifid"])

if not ifid or isEmptyString(getInterfaceName(ifid)) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

delete_data_utils.request_delete_active_interface_data(ifid)

rest_utils.answer(rest_utils.consts.success.ok, { ifid = ifid })
