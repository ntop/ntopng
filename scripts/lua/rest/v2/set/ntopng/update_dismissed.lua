--
-- (C) 2013-26 - ntop.org
--
-- POST /lua/rest/v2/set/ntopng/update_dismissed.lua
--
-- Records the dismissed update version in Redis so the banner is not shown again
-- for that specific version.
--
-- POST body: { "version": "<version_string>" }
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local version = _POST["update_version"]

if isEmptyString(version) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

ntop.setCache("ntopng.prefs.update_available", version)

rest_utils.answer(rest_utils.consts.success.ok, {})
