--
-- (C) 2019-25 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local syslog_utils = require "syslog_utils"
local rest_utils = require("rest_utils")

local res = {}

local ifid = tonumber(_GET["ifid"])
local rc = rest_utils.consts.success.ok

if ifid == nil then
  rest_utils.answer(rest_utils.consts.err.missing_parameters, {"Interface id (ifid) required"})
end

if ifid ~= nil then
  res = syslog_utils.getProducers(ifid)
end
tprint(res)
rest_utils.answer(rc, res)
