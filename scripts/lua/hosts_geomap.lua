--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

interface.select(ifname)
hosts_stats = interface.getHostsInfo()
num = 0
for key, value in pairs(hosts_stats) do
    num = num + 1
end


if(num > 0) then
print [[

     <style type="text/css">
     #map-canvas { width: 640px; height: 480px; }
   </style>

<hr>
<h2>Hosts GeoMap</H2>

    <script src="https://maps.googleapis.com/maps/api/js?v=3.exp&sensor=false"></script>
    <script src="]] print(ntop.getHttpPrefix()) print [[/js/markerclusterer.js"></script>
<div class="container-fluid">
  <div class="row-fluid">
    <div class="span8">
      <div id="map-canvas"></div>
]]

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/geolocation_disclaimer.inc")

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
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No results found</div>")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")