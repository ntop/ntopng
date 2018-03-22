--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

interface.select(ifname)
local hosts_stats = interface.getHostsInfo()
local num = hosts_stats["numHosts"]
hosts_stats = hosts_stats["hosts"]

if(num > 0) then
print [[

     <style type="text/css">
     #map-canvas { width: 640px; height: 480px; }
   </style>

<hr>
<h2>]] print(i18n("geo_map.hosts_geomap")) print[[</H2>

]]

addGoogleMapsScript()

print[[

    <script src="]] print(ntop.getHttpPrefix()) print [[/js/markerclusterer.js"></script>
<div class="container-fluid">
  <div class="row-fluid">
    <div class="span8">
      <div id="map-canvas"></div>
]]

dofile(dirs.installdir .. "/scripts/lua/show_geolocation_note.lua")

print [[
</div>
</div>
</div>

<script type="text/javascript">
var zoomIP = undefined;
var url_prefix = "]] print(ntop.getHttpPrefix()) print [[";
</script>

<script type="text/javascript" src="]] print(ntop.getHttpPrefix()) print [[/js/googleMapJson.js" ></script>

</body>
</html>
]]
else 
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("no_results_found") .. "</div>")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
