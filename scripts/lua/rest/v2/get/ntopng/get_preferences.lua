--
-- (C) 2024 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local prefs = ntop.getPrefs()
local json = require "dkjson"
local rest_utils = require "rest_utils"


rest_utils.answer(rest_utils.consts.success.ok, prefs)