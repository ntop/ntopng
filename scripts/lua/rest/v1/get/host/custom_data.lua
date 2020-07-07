--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local tracker = require("tracker")
local rest_utils = require("rest_utils")

--
-- Read information about a host and maps host fields into custom fields
-- Example: curl -s -u admin:admin  -H "Content-Type: application/json" -d '{"host": "192.168.2.222", "ifid":"0"}' http://localhost:3000/lua/rest/v1/get/host/custom_data.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts_ok
local res = {}

local ifid = _GET["ifid"]
local host_info = url2hostinfo(_GET)
local field_alias = _GET["field_alias"]

-- whether to return host statistics: on by default
local host_stats           = _GET["host_stats"]

if isEmptyString(ifid) then
   print(rest_utils.rc(rest_utils.consts_invalid_interface))
   return
end

if isEmptyString(host_info["host"]) or isEmptyString(field_alias) then
   print(rest_utils.rc(rest_utils.consts_invalid_args))
   return
end

interface.select(ifid)

local host = interface.getHostInfo(host_info["host"], host_info["vlan"])

if not host then
   print(rest_utils.rc(rest_utils.consts_not_found))
   return
end

field_alias = field_alias:split(",") or {field_alias}

for _, fa in pairs(field_alias) do
   local field, alias = fa:split("=")
   if host[field] then
      -- TODO: implement
      res[alias] = host[field]
   end
end

tracker.log("host_get_json", {host_info["host"], host_info["vlan"]})

print(rest_utils.rc(rc, res))

