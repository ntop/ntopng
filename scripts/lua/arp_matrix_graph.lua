--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

local page_utils = require("page_utils")

interface.select(ifname)

if(ntop.isnEdge()) then
  package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/?.lua;" .. package.path
  local nf_config = require("nf_config"):readable()

  if nf_config.isFirstStart() then
    print(ntop.httpRedirect(ntop.getHttpPrefix().."lua/pro/nedge/system_setup/interfaces.lua"))
    return
  end
end

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

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

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

   print('<li><a href="#">'..i18n("index_page.dashboard")..': </a></li>\n')

   if(not(is_loopback)) then
      if(page == "TopFlowTalkers") then active=' class="active"' else active = "" end
      print('<li'..active..'><a href="'..ntop.getHttpPrefix()..'/?page=TopFlowTalkers">'..i18n("talkers")..'</a></li>\n')
   end

   if((page == "TopHosts")) then active=' class="active"' else active = "" end
   print('<li'..active..'><a href="'..ntop.getHttpPrefix()..'/?page=TopHosts">'..i18n("index_page.hosts")..'</a></li>\n')

   if((page == "TopPorts")) then active=' class="active"' else active = "" end
   print('<li'..active..'><a href="'..ntop.getHttpPrefix()..'/?page=TopPorts">'..i18n("ports")..'</a></li>\n')

   if((page == "TopApplications")) then active=' class="active"' else active = "" end
   print('<li'..active..'><a href="'..ntop.getHttpPrefix()..'/?page=TopApplications">'..i18n("index_page.applications")..'</a></li>\n')

   if(not(is_loopback)) then
      if((page == "TopASNs")) then active=' class="active"' else active = "" end
      print('<li'..active..'><a href="'..ntop.getHttpPrefix()..'/?page=TopASNs">'..i18n("index_page.asns")..'</a></li>\n')
      if((page == "TopFlowSenders")) then active=' class="active"' else active = "" end
      print('<li'..active..'><a href="'..ntop.getHttpPrefix()..'/?page=TopFlowSenders">'..i18n("index_page.senders")..'</a></li>\n')
   end

   

   print('</ul>\n\t</div>\n\t</nav>\n')

   print[[

<script src="http://d3js.org/d3.v4.js"></script>

<div style="background-color:whitesmoke", id="container"></div>
<div style="background-color:whitesmoke", id="container2"></div>

<script src="https://d3js.org/d3-scale-chromatic.v1.min.js"></script>
<script src="]] print(ntop.getHttpPrefix()) print[[/js/heatmap.js"></script>

<style>
  div.tooltip {	
    position: absolute;			
    text-align: center;			
    width: 60px;					
    height: 40px;					
    padding: 2px;				
    font: 12px sans-serif bold;		
    background: rgb(171, 203, 245);	
    border: 0px;		
    border-radius: 8px;			
    pointer-events: none;			
  }
</style>

<script>
    map.build();
</script>

<script>history.scrollRestoration = "manual"</script>

   ]]



  end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
