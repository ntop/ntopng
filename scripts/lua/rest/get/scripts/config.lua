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
local checks = require "checks"

if not isAdministratorOrPrintErr() then
   sendHTTPContentTypeHeader('text/html')

   page_utils.print_header()
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> "..i18n("error_not_granted").."</div>")
  return
end

sendHTTPContentTypeHeader('application/json', 'attachment; filename="scripts_configuration.json"')

local conf = {}

conf[checks.DEFAULT_CONFIGSET_ID] = checks.getConfigset()

print(json.encode(conf, nil))
