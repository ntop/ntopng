--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"


interface.select(ifname)

if(ntop.isPro()) then
   if interface.isPcapDumpInterface() == false then
      print(ntop.httpRedirect(ntop.getHttpPrefix().."/lua/pro/dashboard.lua"))
      return
   else
      -- it doesn't make sense to show the dashboard for pcap files...
      print(ntop.httpRedirect(ntop.getHttpPrefix().."/lua/if_stats.lua?ifid="..getInterfaceId(ifname)))
      return
   end
end

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

-- NOTE: in the home page, footer.lua checks the ntopng version
-- so in case we change it, footer.lua must also be updated
active_page = "home"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")


ifstats = interface.getStats()
is_loopback = isLoopback(ifname)
iface_id = interface.name2id(ifname)


-- Load from or set in redis the refresh frequency for the top flow sankey

refresh = _GET["refresh"]
refresh_key = 'ntopng.prefs.'.._SESSION["user"]..'.'..ifname..'.top_flow_refresh'

if (refresh ~= nil) then
  ntop.setCache(refresh_key,refresh)
else
  refresh = ntop.getCache(refresh_key)
end
-- Default frequency (ms)
if (refresh == '') then refresh = 5000 end

--

page = _GET["page"]
if(page == nil) then
   if(not(is_loopback)) then
      page = "TopFlowTalkers"
   else
      page = "TopHosts"
   end
end


if((ifstats ~= nil) and (ifstats.stats.packets > 0)) then
-- Print tabbed header

   print('<nav class="navbar navbar-default" role="navigation">\n\t<div class="navbar-collapse collapse">\n\t<ul class="nav navbar-nav">\n')

   print('<li><a href="#">Dashboard: </a></li>\n')

   if(not(is_loopback)) then
      if(page == "TopFlowTalkers") then active=' class="active"' else active = "" end
      print('<li'..active..'><a href="'..ntop.getHttpPrefix()..'/?page=TopFlowTalkers">Talkers</a></li>\n')
   end

   if((page == "TopHosts")) then active=' class="active"' else active = "" end
   print('<li'..active..'><a href="'..ntop.getHttpPrefix()..'/?page=TopHosts">Hosts</a></li>\n')

   if((page == "TopPorts")) then active=' class="active"' else active = "" end
   print('<li'..active..'><a href="'..ntop.getHttpPrefix()..'/?page=TopPorts">Ports</a></li>\n')

   if((page == "TopApplications")) then active=' class="active"' else active = "" end
   print('<li'..active..'><a href="'..ntop.getHttpPrefix()..'/?page=TopApplications">Applications</a></li>\n')

   if(not(is_loopback)) then
      if((page == "TopASNs")) then active=' class="active"' else active = "" end
      print('<li'..active..'><a href="'..ntop.getHttpPrefix()..'/?page=TopASNs">ASNs</a></li>\n')
      if((page == "TopFlowSenders")) then active=' class="active"' else active = "" end
      print('<li'..active..'><a href="'..ntop.getHttpPrefix()..'/?page=TopFlowSenders">Senders</a></li>\n')
   end

   print('</ul>\n\t</div>\n\t</nav>\n')

   if(page == "TopFlowTalkers") then
      print('<div style="text-align: center;">\n<h4>Top Flow Talkers</h4></div>\n')

      print('<div class="row" style="text-align: center;">')
      dofile(dirs.installdir .. "/scripts/lua/inc/sankey.lua")
      print('\n</div><br/><br/><br/>\n')

print [[
<div class="control-group" style="text-align: center;">
&nbsp;Refresh frequency: <div class="btn-group btn-small">
  <button class="btn btn-default btn-xs dropdown-toggle" data-toggle="dropdown">
]]
if (refresh ~= '0') then
  if (refresh == '60000') then
    print('1 Minute')
  else
    print((refresh/1000)..' Seconds ')
  end
else
  print(' Never ')
end

print [[<span class="caret"></span></button>
  <ul class="dropdown-menu ">
]]
print('<li style="text-align: left;"> <a href="'..ntop.getHttpPrefix()..'?refresh=5000" >5 Seconds</a></li>\n')
print('<li style="text-align: left;"> <a href="'..ntop.getHttpPrefix()..'?refresh=10000" >10 Seconds</a></li>\n')
print('<li style="text-align: left;"> <a href="'..ntop.getHttpPrefix()..'?refresh=30000" >30 Seconds</a></li>\n')
print('<li style="text-align: left;"> <a href="'..ntop.getHttpPrefix()..'?refresh=60000" >1 Minute</a></li>\n')
print('<li style="text-align: left;"> <a href="'..ntop.getHttpPrefix()..'?refresh=0" >Never</a></li>\n')
print [[
  </ul>
</div><!-- /btn-group -->
]]

if (refresh ~= '0') then
  print [[
          &nbsp;Live update:  <div class="btn-group btn-group-xs" data-toggle="buttons-radio" data-toggle-name="topflow_graph_state">
            <button id="topflow_graph_state_play" value="1" type="button" class="btn btn-default btn-xs active" data-toggle="button" ><i class="fa fa-play"></i></button>
            <button id="topflow_graph_state_stop" value="0" type="button" class="btn btn-default btn-xs" data-toggle="button" ><i class="fa fa-stop"></i></button>
          </div>
  ]]
else
  print [[
         &nbsp;Refresh:  <div class="btn-group btn-small">
          <button id="topflow_graph_refresh" class="btn btn-default btn-xs">
            <i rel="tooltip" data-toggle="tooltip" data-placement="top" data-original-title="Refresh graph" class="glyphicon glyphicon-refresh"></i></button>
          </div>
  ]]
  end
print [[
</div>
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
               $("#topflow_graph_state_play").addClass("active");
            }
         });
         $("#topflow_graph_state_stop").click(function() {
            if (!topflow_stop) {
               clearInterval(sankey_interval);
               topflow_stop = true;
               $("#topflow_graph_state_play").removeClass("active");
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
   print("<div class=\"alert alert-warning\">No packet has been received yet on interface " .. getHumanReadableInterfaceName(ifname) .. ".<p>Please wait <span id='countdown'></span> seconds until this page reloads.</div> <script type=\"text/JavaScript\">(function countdown(remaining) { if(remaining <= 0) location.reload(true); document.getElementById('countdown').innerHTML = remaining;  setTimeout(function(){ countdown(remaining - 1); }, 1000);})(10);</script>")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
