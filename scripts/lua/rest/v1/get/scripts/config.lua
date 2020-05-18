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
local user_scripts = require "user_scripts"
local rest_utils = require("rest_utils")

--
-- Read user scripts configuration
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v1/get/scripts/config.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local download = _GET["download"] 

if not haveAdminPrivileges() then
   sendHTTPHeader('application/json')
   print(rest_utils.rc(rest_utils.consts_not_granted))
   return
end

local res = user_scripts.getConfigsets()

if isEmptyString(download) then
  sendHTTPHeader('application/json')
  print(rest_utils.rc(rc, res))
else
  sendHTTPContentTypeHeader('application/json', 'attachment; filename="scripts_configuration.json"')
  print(json.encode(res, nil))
end
