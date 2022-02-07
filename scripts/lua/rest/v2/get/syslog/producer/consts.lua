--
-- (C) 2019-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local rest_utils = require "rest_utils"
local checks = require "checks"

--
-- Read all the defined syslog producer typed
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/syslog/producer/consts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPContentTypeHeader('application/json')

local rc = rest_utils.consts.success.ok
local res = {}


local res = {};
local syslog_plugins = checks.listScripts(checks.script_types.syslog, "syslog")
for k, v in pairs(syslog_plugins) do
  res[#res + 1] = { title = i18n(v.."_collector.title"), value = v  }
end

rest_utils.answer(rc, res)
