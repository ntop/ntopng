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

if not haveAdminPrivileges() then
   sendHTTPContentTypeHeader('text/html')

   page_utils.print_header()
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png>"..i18n("error_not_granted").."</div>")
  return
end

local ifid = _GET["ifid"]
if isEmptyString(ifid) then
   ifid = interface.name2id(ifname)
end

sendHTTPHeader('application/json')

local result = {}

result.csrf = ntop.getRandomCSRFValue()

-- ################################################

if(_POST["JSON"] == nil) then
  result.error = "invalid-parameter"
  print(json.encode(result))
  return
end

local data = json.decode(_POST["JSON"])

if(table.empty(data)) then
  result.error = "bad-format"
  print(json.encode(result))
  return
end

if data["0"] == nil then
  result.error = "bad-content"
  print(json.encode(result))
  return
end

-- ################################################

local success = host_pools_utils.import(data, ifid)

interface.reloadHostPools()

if not success then
   result.error = "internal-failure"
end

-- ################################################

if result.error == nil then
   result.success = true
end

print(json.encode(result))
