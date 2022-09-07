--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo()
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

local info = ntop.getInfo()
page_utils.set_active_menu_entry(page_utils.menu_entries.about, { product=info.product })
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(_POST.uploaded_file ~= nil) then
   local iface_id = ntop.registerPcapInterface(_POST.uploaded_file)

   if(iface_id > 0) then
       print [[
	 <form method='POST' action="]] print(ntop.getHttpPrefix()) print [[/lua/flows_stats.lua?ifid=]] print(toint(iface_id)) print[[">
	   <input hidden name='switch_interface' value='1' />
	   <input hidden name='csrf' value=']] print(ntop.getRandomCSRFValue()) print[[' />
           <input type="submit" value="]] print(i18n("switch_new_pcap_interface")) print [[">  
         </form>
	]]
   else
      print(i18n("switch_new_pcap_interface_error"))
      ntop.unlink(_POST.uploaded_file)
   end
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
