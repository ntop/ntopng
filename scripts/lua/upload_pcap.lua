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

page_utils.set_active_menu_entry(page_utils.menu_entries.analyze_pcap, {  })
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- accept=".pcap"

if isAdministrator() then
   print("<H3>"..i18n("analyze_pcap").."</H3>")

   print [[
     <table class="table table-bordered table-striped">
     <tr><td>
     <form action="]] print(ntop.getHttpPrefix()) print [[/lua/analyze_pcap.lua" method=POST enctype="multipart/form-data">
     <input type="file" id="pcap" name="pcap">
     <input type="submit" value="]] print(i18n("upload_pcap")) print [[">
     </form>
     </td></tr>
     </table>
   ]]
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
