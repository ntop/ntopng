--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")
sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.geo_map)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

interface.select(ifname)
local hosts_stats = interface.getHostsInfo()
local num = hosts_stats["numHosts"]
hosts_stats = hosts_stats["hosts"]

if(num > 0) then

  print ([[
    <div class="container-fluid">
      <div class="row">
        <div class='col-md-12 col-lg-12 col-xs-12'>
          <div class='border-bottom pb-2 mb-3'> 
            <h1 class='h2'>]].. i18n("geo_map.hosts_geomap").. [[</h1>
          </div>
          <div id='geomap-alert' style="display: none" role="alert" class='alert alert-danger'>
            <button type="button" class="close" data-dismiss="alert" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
            <p id='error-message'></p>
          </div>
          <div style="height: 720px" id="map-canvas"></div>
          <div class='border-top mt-4'>
            <p id='my-location'></p>
          </div>
        </div>
      </div>
    </div>
  ]])

  print([[
    <link rel="stylesheet" href="]].. ntop.getHttpPrefix() ..[[/leaflet/leaflet.css"/>
    <link rel="stylesheet" href="]].. ntop.getHttpPrefix() ..[[/leaflet/MarkerCluster.Default.css"/>
    <link rel="stylesheet" href="]].. ntop.getHttpPrefix() ..[[/leaflet/MarkerCluster.css"/>
    <script src="]].. ntop.getHttpPrefix() ..[[/leaflet/leaflet.js" type="text/javascript"></script>
    <script src="]].. ntop.getHttpPrefix() ..[[/leaflet/leaflet.markercluster.js" type="text/javascript"></script>
    <script type='text/javascript'>

      const zoomIP = undefined;

      const display_localized_error = (error_code) => {
        $('#geomap-alert p').html(`]].. i18n("geo_map.geolocation_error") ..[[[${error_code}]: ]].. i18n("geo_map.using_default_location") ..[[`);
        $('#geomap-alert').removeClass('alert-info').addClass('alert-danger').show();
      }

      const display_localized_position = (position) => {
          $('#my-location').html(`
          ]].. i18n("geo_map.browser_reported_home_map")..[[: 
          <a href='https://www.openstreetmap.org/#map=6/${position[0]}/${position[1]}'>
          ]]..i18n("geo_map.latitude").. [[: ${position[0]}, ]].. i18n("geo_map.longitude").. [[: ${position[1]} </a>
        `);
      }

      const display_localized_no_geolocation_msg = () => {

          $('#geomap-alert p').html(`]].. i18n("geo_map.unavailable_geolocation") .. ' ' .. i18n("geo_map.using_default_location") ..[[`);
          $('#geomap-alert').addClass('alert-info').removeClass('alert-danger').show();

      }
    </script>
    <script src="]].. ntop.getHttpPrefix() ..[[/js/osm-maps.js"  type='text/javascript'></script>
  ]])

else 
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("no_results_found") .. "</div>")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
