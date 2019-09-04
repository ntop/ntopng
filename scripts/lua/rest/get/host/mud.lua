--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local mud_utils = require("mud_utils")
local json = require("dkjson")

local host = _GET["host"]

if(_GET["ifid"] ~= nil) then
  interface.select(_GET["ifid"])
end

sendHTTPHeader('application/json')

if(host == nil) then
  print("{}")
  return
end

local mud = mud_utils.getHostMUD(host)

if(mud ~= nil) then
  print(json.encode(mud, {indent=true}))
else
  print("{}")
end
