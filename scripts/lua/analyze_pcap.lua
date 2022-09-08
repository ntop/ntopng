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

local info = ntop.getInfo()
page_utils.set_active_menu_entry(page_utils.menu_entries.analyze_pcap, {  })
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(_POST.uploaded_file ~= nil) then
   local iface_id = ntop.registerPcapInterface(_POST.uploaded_file)

   if(iface_id > 0) then
      print(template.gen("analyze_pcap.template", { iface_id = toint(iface_id) }))
   else
      print(i18n("analyze_pcap_error"))
      ntop.unlink(_POST.uploaded_file)
   end
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
