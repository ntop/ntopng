--
-- (C) 2019-20 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local info = ntop.getInfo() 

local json = require ("dkjson")
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local os_utils = require "os_utils"
local host_pools_utils = require "host_pools_utils"
local rest_utils = require("rest_utils")

--
-- Import host pools configuration
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPHeader('application/json')

local ifid = _GET["ifid"]

if not haveAdminPrivileges() then
   print(rest_utils.rc(rest_utils.consts_not_granted))
   return
end

if isEmptyString(ifid) then
   ifid = interface.name2id(ifname)
end

if isEmptyString(ifid) then
   print(rest_utils.rc(rest_utils.consts_invalid_interface))
   return
end

if(_POST["JSON"] == nil) then
  print(rest_utils.rc(rest_utils.consts_invalid_args))
  return
end

local data = json.decode(_POST["JSON"])

if(table.empty(data)) then
  print(rest_utils.rc(rest_utils.consts_bad_format))
  return
end

if data["0"] == nil then
  print(rest_utils.rc(rest_utils.consts_bad_content))
  return
end

-- ################################################

local success = host_pools_utils.import(data, ifid)

interface.reloadHostPools()

if not success then
  print(rest_utils.rc(rest_utils.consts_internal_error))
  return
end

-- ################################################

print(rest_utils.rc(rest_utils.consts_ok))
