--
-- (C) 2013-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

local json = require("dkjson")
local top_talkers_utils = require("top_talkers_utils")
local direction = _GET["senders_receivers"] or "senders"
sendHTTPContentTypeHeader('text/html')

local top_type = _GET["module"]
local data = {}

local json_res = top_talkers_utils.makeTopJson(ifname, false --[[ do not save checkpoint as we are not in minute.lua ]])

if json_res ~= nil then
  local res = json.decode(json_res)

  if res and res.vlan[1] then
    res = res.vlan[1]

    if top_type == "top_asn" then
      res = res.asn[1]
    else
      res = res.hosts[1]
    end

    if res ~= nil then
      data = res[direction]
    end
  end
end

print(json.encode(data))
