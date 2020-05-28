--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"

--
-- Read all the defined L7 application categories
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v1/get/l7/category/consts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts_ok
local res = {}

local categories = interface.getnDPICategories()

for category, cat_id in pairs(categories) do
   res[category] = {cat_id = tonumber(cat_id)}
end

print(rest_utils.rc(rc, res))
