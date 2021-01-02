--
-- (C) 2019-21 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local info = ntop.getInfo() 

local json = require ("dkjson")
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local os_utils = require "os_utils"
local user_scripts = require "user_scripts"

if not haveAdminPrivileges() then
   sendHTTPContentTypeHeader('text/html')

   page_utils.print_header()
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png>"..i18n("error_not_granted").."</div>")
  return
end

sendHTTPHeader('application/json')

local result = {}

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

for config_id, configset in pairs(data) do
  if configset.name ~= nil then
    local success, err = user_scripts.createOrReplaceConfigset(configset)

    if not success then
      result.error = "internal-failure"
      result.description = err
    end
  end
end

if result.error == nil then
   result.success = true
end

-- ################################################

print(json.encode(result))
