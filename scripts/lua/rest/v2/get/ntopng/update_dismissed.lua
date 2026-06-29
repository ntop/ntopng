--
-- (C) 2013-26 - ntop.org
--
-- GET /lua/rest/v2/get/ntopng/update_dismissed.lua
--
-- Returns the previously dismissed update version stored in Redis.
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local version = ntop.getCache("ntopng.prefs.update_available") or ""

rest_utils.answer(rest_utils.consts.success.ok, { version = version })
