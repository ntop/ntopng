--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local protos_utils = require("protos_utils")
local rest_utils = require("rest_utils")

-- ##################################################

local rc = rest_utils.consts.success.ok
local res = {}

local l7_proto = _GET["protocol_alias"]
local has_protos_file = protos_utils.hasProtosFile()

if has_protos_file then
  protos_utils.deleteAppRules(l7_proto)
end

rest_utils.answer(rc, res)