--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils        = require "rest_utils"
-- Heavy (lua_utils, ts_utils) but it owns the request keys; called once per
-- Manage Data page load
local delete_data_utils = require "delete_data_utils"

--
-- Pending data delete/purge requests (performed at the next restart), for the
-- Manage Data page (Developer > Manage Data).
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/system/delete_data_status.lua
--

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

rest_utils.answer(rest_utils.consts.success.ok, {
   delete_active_interface_requested = delete_data_utils.delete_active_interface_data_requested(getInterfaceName(interface.getId())),
   purge_clickhouse_requested        = delete_data_utils.purge_all_clickhouse_data_requested(),
   purge_datadir_requested           = delete_data_utils.purge_all_datadir_data_requested(),
})
