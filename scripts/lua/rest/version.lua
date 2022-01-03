--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local json = require "dkjson"
local rest_utils = require "rest_utils"

--
-- Return all the supported REST API versions and the current REST API version used by ntopng
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/version.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {
   -- An array of all the supported REST API versions
   supported_versions = {
      { version = "1", root = string.format("%s/lua/rest/v1", ntop.getHttpPrefix())},
      { version = "2", root = string.format("%s/lua/rest/v2", ntop.getHttpPrefix())},
   },
   -- Current REST API version used by ntopng
   current_version = "2"
}

rest_utils.answer(rc, res)

