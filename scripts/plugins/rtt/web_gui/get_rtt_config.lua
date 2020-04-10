--
-- (C) 2019-20 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json = require ("dkjson")
local page_utils = require("page_utils")
local rtt_utils = require "rtt_utils"

if not haveAdminPrivileges() then
   sendHTTPContentTypeHeader('text/html')

   page_utils.print_header()
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png>"..i18n("error_not_granted").."</div>")
  return
end

sendHTTPContentTypeHeader('application/json', 'attachment; filename="active_monitoring_conf.json"')

local conf = rtt_utils.getHosts(true --[[ only retrieve the configuration ]])

print(json.encode(conf, nil))
