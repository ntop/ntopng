--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

local rc = rest_utils.consts.success.ok
local res = {}

local hashname = _GET["hashname"] or "ntop.host.blackhole" 

if isEmptyString(hashname) then
  rc = rest_utils.consts.err.invalid_interface
  rest_utils.answer(rc)
  return
end

local h_values = ntop.getHashKeysCache(hashname)

for key, val in pairs(h_values) do
    res[#res + 1] = {
       ip = key,
       time = ntop.getHashCache(hashname, key)
    }
    
end

rest_utils.answer(rc, res)
