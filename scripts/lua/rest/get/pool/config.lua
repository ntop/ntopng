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

sendHTTPContentTypeHeader('application/json', 'attachment; filename="pools_configuration.json"')

local conf = host_pools_utils.export()

print(json.encode(conf, nil))
