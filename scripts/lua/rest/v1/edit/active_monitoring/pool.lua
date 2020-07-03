--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"

--
-- Edit an existing pool
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts_ok
local res = {
   -- STUB
}

print(rest_utils.rc(rc, res))

