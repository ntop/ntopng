--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local syslog_utils = require "syslog_utils"

sendHTTPContentTypeHeader('application/json')

local res = {}

local ifid = interface.getId()
if tonumber(_GET["ifid"]) ~= nil then
  ifid = _GET["ifid"]
end

if ifid ~= nil then
  res = syslog_utils.getProducers(ifid)
end

print(json.encode(res))
