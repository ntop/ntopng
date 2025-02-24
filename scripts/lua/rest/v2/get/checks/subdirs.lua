--
-- (C) 2019-25 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path


require "lua_utils"
local json = require("dkjson")
local checks = require("checks")
local rest_utils = require "rest_utils"
local auth = require "auth"


-- Return all checks subdirs supported by ntopng for checks
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/checks/subdirs.lua
--

local rc = rest_utils.consts.success.ok

if not auth.has_capability(auth.capabilities.checks) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local subdirs = {}

for _, subdir in pairs(checks.listSubdirs()) do
    subdirs[#subdirs + 1] = subdir.id
end

local subdirs_list = {
    checks_subdirs = subdirs
}

rest_utils.answer(rc, subdirs_list)