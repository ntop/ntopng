--
-- (C) 2024 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local prefs = ntop.getPrefs()
local json = require "dkjson"
local rest_utils = require "rest_utils"


local auth = require "auth"

if not auth.has_capability(auth.capabilities.preferences) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

rest_utils.answer(rest_utils.consts.success.ok, prefs)