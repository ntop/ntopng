--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"
local page_utils = require("page_utils")
local is_system_interface = page_utils.is_system_view()
local observationPointId = _GET["observationPointId"]

if(observationPointId ~= nil) then
-- tprint("--->>> SET("..observationPointId..")")
  ntop.setUserObservationPointId(tonumber(observationPointId))
  -- Read it to make it sure it is validated
 observationPointId = ntop.getUserObservationPointId()
end

interface.select(ifname)

if (is_system_interface) then
  print(ntop.httpRedirect(ntop.getHttpPrefix().."/lua/system_stats.lua"))
  return
end

if ntop.isnEdge() or ntop.isAppliance() then
  local sys_config
  local first_start_page

  if ntop.isnEdge() then
    package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/system_config/?.lua;" .. package.path
    sys_config = require("nf_config"):create()
    first_start_page = "interfaces.lua"
  else -- ntop.isAppliance()
    package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path
    sys_config = require("appliance_config"):create()
    first_start_page = "mode.lua"
  end

  if sys_config.isFirstStart() then
    print(ntop.httpRedirect(ntop.getHttpPrefix().."lua/system_setup_ui/"..first_start_page))
    return
  end
end

local mode  = _GET["dashboard_mode"]

if(ntop.isPro() and (mode ~= "community")) then
   if interface.isPcapDumpInterface() == false then
      print(ntop.httpRedirect(ntop.getHttpPrefix().."/lua/pro/dashboard.lua"))
      return
   else
      -- it doesn't make sense to show the dashboard for pcap files...
      print(ntop.httpRedirect(ntop.getHttpPrefix().."/lua/if_stats.lua?ifid="..getInterfaceId(ifname)))
      return
   end
else
   if(mode) then
      mode = "&dashboard_mode="..mode
   else
      mode = "&dashboard_mode=community"
   end
end

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.traffic_dashboard)

-- NOTE: in the home page, footer.lua checks the ntopng version
-- so in case we change it, footer.lua must also be updated
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")


ifstats = interface.getStats()
is_loopback = interface.isLoopback()
iface_id = interface.name2id(ifname)

-- Load from or set in redis the refresh frequency for the top flow sankey

refresh = _GET["refresh"]
refresh_key = 'ntopng.prefs.'.._SESSION["user"]..'.'..tostring(iface_id)..'.top_flow_refresh'

if (refresh ~= nil) then
  ntop.setCache(refresh_key,refresh)
else
  refresh = ntop.getCache(refresh_key)
end
-- Default frequency (ms)
if (refresh == '') then refresh = 5000 end

--

print([[
    <div class='row'>
      <div class='col-12'>
]])

local page = _GET["page"]
page = (page_utils.is_valid_page(page, {'TopFlowTalkers', 'TopHosts', 'TopPorts', 'TopApplications'}) and page or nil)

if(page == nil) then
   if(not(is_loopback)) then
      page = "TopFlowTalkers"
   else
      page = "TopHosts"
   end
end

if((ifstats ~= nil) and (ifstats.stats.packets > 0)) then

  local nav_url = ntop.getHttpPrefix()..'/?ifid='..interface.getId()..mode
  local title = i18n("index_page.dashboard")

   page_utils.print_navbar(title, nav_url,
      {
        {
          active = page == "TopFlowTalkers" or not page,
          page_name = "TopFlowTalkers",
          label = i18n("talkers"),
        },
        {
          active = page == "TopHosts",
          page_name = "TopHosts",
          label = i18n("index_page.hosts"),
        },
        {
          active = page == "TopPorts",
          page_name = "TopPorts",
          label = i18n("ports"),
        },
        {
          active = page == "TopApplications",
          page_name = "TopApplications",
          label = i18n("index_page.applications"),
        },
      }
   )

   if(page == "TopFlowTalkers") then
      print('<div style="text-align: center;">\n<h4>'..i18n("index_page.top_flow_talkers")..'</h4></div>\n')

      print('<div class="row" style="text-align: center;">')
      dofile(dirs.installdir .. "/scripts/lua/inc/sankey.lua")
      print('\n</div><br/><br/><br/>\n')

print [[
<div class="control-group text-center">
<span class='mx-1'>]] print(i18n("index_page.refresh_frequency"))
print[[:</span><div class="btn-group btn-small">
  <button class="btn btn-secondary btn-xs dropdown-toggle" data-bs-toggle="dropdown">
]]
if (refresh ~= '0') then
  if (refresh == '60000') then
    print('1 '..i18n("index_page.minute"))
  else
     print(string.format("%u %s", refresh / 1000, i18n("index_page.seconds")))
  end
else
  print(' '..i18n("index_page.never")..' ')
end

print [[</button>
  <ul class="dropdown-menu ">
]]
print('<li class="nav-item text-start"> <a class="dropdown-item" href="'..ntop.getHttpPrefix()..'?refresh=5000" >5 '..i18n("index_page.seconds")..'</a></li>\n')
print('<li class="nav-item text-start"> <a class="dropdown-item" href="'..ntop.getHttpPrefix()..'?refresh=10000" >10 '..i18n("index_page.seconds")..'</a></li>\n')
print('<li class="nav-item text-start"> <a class="dropdown-item" href="'..ntop.getHttpPrefix()..'?refresh=30000" >30 '..i18n("index_page.seconds")..'</a></li>\n')
print('<li class="nav-item text-start"> <a class="dropdown-item" href="'..ntop.getHttpPrefix()..'?refresh=60000" >1 '..i18n("index_page.minute")..'</a></li>\n')
print('<li class="nav-item text-start"> <a class="dropdown-item" href="'..ntop.getHttpPrefix()..'?refresh=0" >'..i18n("index_page.never")..'</a></li>\n')
print [[
  </ul>
</div><!-- /btn-group -->
]]

if (refresh ~= '0') then
  print [[<span class='mx-1'>]] print(i18n("index_page.live_update")) print [[:</span>]] print[[<div class="btn-group btn-group-toggle btn-group-xs" data-bs-toggle="buttons" data-bs-toggle-name="topflow_graph_state">
            <button id="topflow_graph_state_play" value="1" type="button" class="btn btn-secondary btn-xs active" data-bs-toggle="button" disabled><i class="fas fa-pause"></i></button>
            <button id="topflow_graph_state_stop" value="0" type="button" class="btn btn-secondary btn-xs" data-bs-toggle="button" ><i class="fas fa-stop"></i></button>
          </div>
  ]]
else
  print [[<span class='mx-1'>]] print(i18n("index_page.refresh")) print [[:</span>]] print[[<div class="btn-group btn-small">
          <button id="topflow_graph_refresh" class="btn btn-secondary btn-xs">
            <i rel="tooltip" data-bs-toggle="tooltip" data-placement="top" data-original-title="]] print(i18n("index_page.refresh_graph_popup_msg")) print [[" class="fas fa-sync"></i></button>
          </div>
  ]]
  end
print [[
</div>
<br>
]]

print [[
      <script>
      // Stop sankey interval in order to change the default refresh frequency
      clearInterval(sankey_interval);
]]

if (refresh ~= '0') then
  print ('sankey_interval = window.setInterval(sankey,'..refresh..');')
end

print [[
         var topflow_stop = false;
         $("#topflow_graph_state_play").click(function() {
            if (topflow_stop) {
               sankey();
               sankey_interval = window.setInterval(sankey, 5000);
               topflow_stop = false;
               $("#topflow_graph_state_stop").removeClass("active");
               $("#topflow_graph_state_play").addClass("active").html(`<i class='fas fa-pause'></i>`).attr("disabled", "disabled");
            }
         });
         $("#topflow_graph_state_stop").click(function() {
            if (!topflow_stop) {
               clearInterval(sankey_interval);
               topflow_stop = true;
               $("#topflow_graph_state_play").removeClass("active").removeAttr("disabled").html(`<i class='fas fa-play'></i>`);
               $("#topflow_graph_state_stop").addClass("active");
            }
        });
        $("#topflow_graph_refresh").click(function() {
          sankey();
        });

      </script>

      ]]
   else
      ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/index_" .. page .. ".inc")
   end


  --ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/index_top.inc")
  -- ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/index_bottom.inc")
else
   print("<div class=\"alert alert-warning\">"..i18n("index_page.no_packet_warning",{ifname=getHumanReadableInterfaceName(ifname),countdown="<span id=\'countdown\'></span>"}).."</div> <script type=\"text/JavaScript\">(function countdown(remaining) { if(remaining <= 0) location.reload(true); document.getElementById('countdown').innerHTML = remaining;  setTimeout(function(){ countdown(remaining - 1); }, 1000);})(10);</script>")
end

print([[
  </div>
  </div>
]])

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
