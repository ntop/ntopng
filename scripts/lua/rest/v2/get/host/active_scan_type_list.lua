--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/active_scan/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local ascan_utils = require "ascan_utils"

local debug = false

local res = {}

res = ascan_utils.retrieve_scan_types()

rest_utils.answer(rest_utils.consts.success.ok, {rsp = res})


