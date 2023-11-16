--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"

--
-- Read all the defined L7 application protocols
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/l7/application/consts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local applications = interface.getnDPIProtocols()

for application, appl_id in pairs(applications) do
   appl_id = tonumber(appl_id)
   local cat = ntop.getnDPIProtoCategory(appl_id)

   res[#res + 1] = {
     name = application, 
     appl_id = appl_id,
     cat_id = cat.id,
   }
end

rest_utils.answer(rc, res)

