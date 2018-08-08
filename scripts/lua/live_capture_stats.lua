--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"


interface.select(ifname)

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "home"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")


local rc = interface.dumpLiveCaptures()

print [[
       <div id="livecaptures"></div>

       <script>
       var livecaptures = null;
       $("#livecaptures").datatable({
         title: "",
         url: "/lua/live_capture_data.lua",
         columns: [
            {
            title: "Capture Host",
            field: "host",
            }, {
            title: "Captured Packets",
            field: "num_captured_packets",
           }, {
            title: "Capture Until",
            field: "capture_until",
           }, {
            title: "Action",
            field: "stop_href",
           }
         ],
      });

      livecaptures = $("#livecaptures").data("datatable");
      </script>
]]

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/footer.inc")
