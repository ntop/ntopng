--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"

--
-- Add a new pool
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts_ok
local res = {
   pool_id = "abcdeficgejx01234" -- stub
}

print(rest_utils.rc(rc, res))

