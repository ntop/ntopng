--
-- (C) 2017-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local info = ntop.getInfo()

if not haveAdminPrivileges() then
  return
end

-- ##############################################

sendHTTPHeader('application/json')

local latest_version = ntop.getCache("ntopng.cache.major_release")

if isEmptyString(latest_version) then
  local rsp = ntop.httpGet("https://www.ntop.org/ntopng.version", "", "", 10 --[[ seconds ]])

  if(not isEmptyString(rsp)) and (not isEmptyString(rsp["CONTENT"])) then
     latest_version = trimSpace(string.gsub(rsp["CONTENT"], "\n", ""))
  else
     -- a value that won't trigger an update message
     latest_version = "0.0.0"
  end

  ntop.setCache("ntopng.cache.major_release", latest_version, 86400 --[[ recheck interval]])
end

local res = {msg=get_version_update_msg(info, latest_version)}

print(json.encode(res, nil, 1))
