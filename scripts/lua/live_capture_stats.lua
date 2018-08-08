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

print("<HR><H2>"..i18n("live_capture.active_live_captures").."</H2>")

print [[
       <div id="livecaptures"></div>

       <script>
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

      function reloadTable() {
        $("#livecaptures").data("datatable").render();
        setTimeout(reloadTable, 10000); /* Refresh content every a few seconds */
      }

     $(document).ready(function() {
       setTimeout(reloadTable, 10000); /* Refresh content every a few seconds */
     });

     </script>
]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
