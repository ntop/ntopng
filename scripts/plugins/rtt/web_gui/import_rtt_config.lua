--
-- (C) 2019-20 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json = require ("dkjson")
local page_utils = require("page_utils")
local rtt_utils = require "rtt_utils"

local json = require ("dkjson")

if not haveAdminPrivileges() then
   sendHTTPContentTypeHeader('text/html')
page_utils.manage_system_interface()
   page_utils.print_header()
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png>"..i18n("error_not_granted").."</div>")
  return
end

local result = {}
result.csrf = ntop.getRandomCSRFValue()

sendHTTPContentTypeHeader('application/json')

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

-- ################################################

rtt_utils.resetConfig()

for host, conf in pairs(data) do
  rtt_utils.addHost(host, conf.max_rtt or 500)
end

-- ################################################

if result.error == nil then
   result.success = true
end

print(json.encode(result))
