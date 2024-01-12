--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

require "lua_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"

sendHTTPContentTypeHeader('application/json')

--
-- Test ntopng reachability and authentication (used by Python API)
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/connect/test.lua
--

local rc = rest_utils.consts.success.ok
local res = {}

rest_utils.answer(rc, res)
