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

if (num > 0) then

  print ([[
      <div class="row">
        <div class='col-md-12 col-lg-12 col-xs-12 mb-4'>
  ]])
  page_utils.print_page_title(i18n("geo_map.hosts_geomap"))
  print([[
          <div id='geomap-alert' style="display: none" role="alert" class='alert alert-danger'>
            <span id='error-message'></span>
            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
          </div>
          <div class="d-flex justify-content-center align-items-center" style="height: 720px" id="map-canvas">
              <div class="spinner-border text-primary" role="status">
                <span class="sr-only">Loading...</span>
              </div>
          </div>
        </div>
      </div>
  ]])

  print([[
    <link rel="stylesheet" href="]].. ntop.getHttpPrefix() ..[[/leaflet/leaflet.css"/>
    <link rel="stylesheet" href="]].. ntop.getHttpPrefix() ..[[/leaflet/MarkerCluster.Default.css"/>
    <link rel="stylesheet" href="]].. ntop.getHttpPrefix() ..[[/leaflet/MarkerCluster.css"/>
    <script src="]].. ntop.getHttpPrefix() ..[[/leaflet/leaflet.js?]].. ntop.getStaticFileEpoch() ..[[" type="text/javascript"></script>
    <script src="]].. ntop.getHttpPrefix() ..[[/leaflet/leaflet.curve.js?]].. ntop.getStaticFileEpoch() ..[[" type="text/javascript"></script>
    <script src="]].. ntop.getHttpPrefix() ..[[/leaflet/leaflet.markercluster.js?]].. ntop.getStaticFileEpoch() ..[[" type="text/javascript"></script>
    <script type='text/javascript'>

      const zoomIP = undefined;

      const display_localized_error = (error_code) => {
        $('#geomap-alert #error-message').html(`<b>]].. i18n("geo_map.geolocation_warning") ..[[</b>: ]].. i18n("geo_map.using_default_location") ..[[`);
        $('#geomap-alert').removeClass('alert-danger').addClass('alert-warning').show();
      }

      const display_localized_no_geolocation_msg = () => {
          $('#geomap-alert p').html(`]].. i18n("geo_map.unavailable_geolocation") .. ' ' .. i18n("geo_map.using_default_location") ..[[`);
          $('#geomap-alert').addClass('alert-info').removeClass('alert-danger').show();
      }
    </script>
    <script src="]].. ntop.getHttpPrefix() ..[[/js/osm-maps.js?]].. ntop.getStaticFileEpoch() ..[[" type='text/javascript'></script>
  ]])
else
   print("<div class=\"alert alert-danger\">".. "<i class='fas fa-exclamation-triangle fa-lg' style='color: #B94A48;'></i> " .. i18n("no_results_found") .. "</div>")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
