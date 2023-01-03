--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"

--
-- Read all the  L4 protocols
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/l4/protocol/consts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local ip = _GET['ip']
local rc = rest_utils.consts.success.ok

local label = ntop.getASName(ip)

rest_utils.answer(rc, label)
