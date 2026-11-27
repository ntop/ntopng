--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/toasts/?.lua;" .. package.path

-- Loaded anyway by toast_ui, required by every toast
require "lua_utils"
local rest_utils = require("rest_utils")
local toasts_manager = require("toasts_manager")

--
-- The toasts of every page, asked by the PageToasts Vue component at the SPA navigations
-- (the toasts of a single page come with its full load)
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/ntopng/toasts.lua?ifid=1"
--

local ifid = _GET["ifid"]

if not isEmptyString(ifid) then
   interface.select(ifid)

   if tostring(interface.getId()) ~= tostring(ifid) then
      rest_utils.answer(rest_utils.consts.err.invalid_interface)
      return
   end
end

rest_utils.answer(rest_utils.consts.success.ok, {
   toasts = toasts_manager.toasts_to_table(toasts_manager.load_main_toasts(true --[[ global only ]])),
})
