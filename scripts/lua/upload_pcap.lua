--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo()
local page_utils = require("page_utils")
local template = require "template_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.analyze_pcap, {  })
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- accept=".pcap"

if isAdministrator() then
   print(template.gen("upload_pcap.template", {  }))
end   

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
