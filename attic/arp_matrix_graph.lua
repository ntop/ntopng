--
-- (C) 2013-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

local page_utils = require("page_utils")
sendHTTPContentTypeHeader('text/html')
page_utils.manage_system_interface()

interface.select(ifname)
page_utils.print_header()

local host_info = url2hostinfo(_GET)
local host_ip = nil
if host_info then
    host_ip = host_info["host"]
end

--active_page = "home"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local ifstats = interface.getStats()
local is_loopback = interface.isLoopback()
local iface_id = interface.name2id(ifname)

-- Load from or set in redis the refresh frequency for the top talkers heatmap
local refresh = _GET["refresh"]
local refresh_key = 'ntopng.prefs.'.._SESSION["user"]..'.'..ifname..'.heatmap_refresh'

if (refresh ~= nil) then
  ntop.setCache(refresh_key,refresh)
else
  refresh = ntop.getCache(refresh_key)
end
-- Default frequency (ms)
if (refresh == '') then refresh = 5000 end


if((ifstats ~= nil) and (ifstats.stats.packets > 0)) then
-- Print tabbed header

  print [[
    <script src="]] print(ntop.getHttpPrefix()) print[[/js/d3.v4.min.js"></script>


   <div style="background-color:white", id="container"></div>
   <div style="background-color:white", id="container2"></div>

   <div class="control-group" style="text-align: center;">
   &nbsp;]] print(i18n("index_page.refresh_frequency")) print[[: <div class="btn-group btn-small">
     <button class="btn btn-secondary btn-xs dropdown-toggle" data-toggle="dropdown">
   ]]
   if (refresh ~= '0') then
     if (refresh == '60000') then
       print('1 '..i18n("index_page.minute"))
     else
       print((refresh/1000)..' '..i18n("index_page.seconds")..' ')
     end
   else
     print(' '..i18n("index_page.never")..' ')
   end
   
   print [[<span class="caret"></span></button>
     <ul class="dropdown-menu ">
   ]]
   print('<li style="text-align: left;"> <a href="'..ntop.getHttpPrefix()..'?refresh=5000" >5 '..i18n("index_page.seconds")..'</a></li>\n')
   print('<li style="text-align: left;"> <a href="'..ntop.getHttpPrefix()..'?refresh=10000" >10 '..i18n("index_page.seconds")..'</a></li>\n')
   print('<li style="text-align: left;"> <a href="'..ntop.getHttpPrefix()..'?refresh=30000" >30 '..i18n("index_page.seconds")..'</a></li>\n')
   print('<li style="text-align: left;"> <a href="'..ntop.getHttpPrefix()..'?refresh=60000" >1 '..i18n("index_page.minute")..'</a></li>\n')
   print('<li style="text-align: left;"> <a href="'..ntop.getHttpPrefix()..'?refresh=0" >'..i18n("index_page.never")..'</a></li>\n')
   print [[
     </ul>
   </div><!-- /btn-group -->
   ]]
   
   if (refresh ~= '0') then
      print [[
              &nbsp;]] print(i18n("index_page.live_update")) print[[:  <div class="btn-group btn-group-xs" data-toggle="buttons-radio" data-toggle-name="topflow_graph_state">
                <button id="topflow_graph_state_play" value="1" type="button" class="btn btn-secondary btn-xs active" data-toggle="button" ><i class="fas fa-play"></i></button>
                <button id="topflow_graph_state_stop" value="0" type="button" class="btn btn-secondary btn-xs" data-toggle="button" ><i class="fas fa-stop"></i></button>
              </div>
      ]]
    else
      print [[
             &nbsp;]] print(i18n("index_page.refresh")) print[[:  <div class="btn-group btn-small">
              <button id="topflow_graph_refresh" class="btn btn-secondary btn-xs">
                <i rel="tooltip" data-toggle="tooltip" data-placement="top" data-original-title="]] print(i18n("index_page.refresh_graph_popup_msg")) print [[" class="glyphicon glyphicon-refresh"></i></button>
              </div>
      ]]
      end
    print [[
    </div>
    ]]

   print[[
      <script src="]] print(ntop.getHttpPrefix()) print[[/js/heatmap.js"></script>

      <script>
         $("#topflow_graph_state_play").click(function() {
            map.startUpdate();
            map.build(]]
              print(refresh)
              if host_ip then 
                print[[, "]]print(host_ip.."\"")
              end
            print[[);
            $("#topflow_graph_state_stop").removeClass("active");
            $("#topflow_graph_state_play").addClass("active");
         });
         $("#topflow_graph_state_stop").click(function() {
            map.stopUpdate();
            $("#topflow_graph_state_play").removeClass("active");
            $("#topflow_graph_state_stop").addClass("active");
         });
         $("#topflow_graph_refresh").click(function() {
          map.build(]]
            print("0")
            if host_ip then 
              print[[, "]]print(host_ip.."\"")
            end

          print[[);
        });

        map.build(]]
          print(refresh)
          if host_ip then 
            print[[, "]]print(host_ip.."\"")
          end

        print[[);
      </script>
   ]]
  end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
