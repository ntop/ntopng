--
-- (C) 2017-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
json = require("dkjson")

sendHTTPHeader('application/json')

local latest_version = ntop.getCache("ntopng.cache.version")

if isEmptyString(latest_version) then
  local rsp = ntop.httpGet("http://www.ntop.org/ntopng.version", "", "", 10 --[[ seconds ]])

  if(not isEmptyString(rsp)) and (not isEmptyString(rsp["CONTENT"])) then
     latest_version = trimSpace(string.gsub(rsp["CONTENT"], "\n", ""))
  else
    -- a value that won't trigger an update message
    latest_version = "0.0.0"
  end

  ntop.setCache("ntopng.cache.version", latest_version, 86400)  
end

res = {msg=get_version_update_msg(ntop.getInfo(), latest_version)}

print(json.encode(res, nil, 1))
