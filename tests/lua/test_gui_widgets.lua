--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/datasources/?.lua;" .. package.path

require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo() 
local page_utils = require("page_utils")
local alerts_api = require("alerts_api")
local format_utils = require("format_utils")
local json = require "dkjson"
local rest_utils = require "rest_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("about.about_x", { product=info.product }))

if not isAdministrator() then
  return
end

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- NOTE: THE NTOP WIDGET SCRIPTS MUST BE LOADED FIRST!
print([[

    <script type='text/javascript'>
        window.__NTOPNG_WIDGET_CSRF__ = "]].. ntop.getRandomCSRFValue() ..[[";
    </script>
    <script type="module" src="]].. ntop.getHttpPrefix() ..[[/js/ntop-widgets/ntop-widgets.esm.js"></script>
    <script nomodule src="]].. ntop.getHttpPrefix() ..[[/js/ntop-widgets/ntop-widgets.js"></script>

]])

print([[
    <div class='row my-4'>
        <div class='col-12'>
            <ntop-widget transformation="pie" width="400px" height="400px">
                <b class='mb-2'>Interfaces 0 (external) + 9 (internal)</b>
                <ntop-datasource type="interface_packet_distro" params-ifid='0'></ntop-datasource>
                <ntop-datasource type="interface_packet_distro" params-ifid='9'></ntop-datasource>
            </ntop-widget>
        </div>
        <div class='col-12 my-1'>
            <ntop-widget transformation="donut" width="400px" height="400px">
                <b class='mb-2'>Interface 9 (Donut)</b>
                <ntop-datasource type="interface_packet_distro" params-ifid='9'></ntop-datasource>
            </ntop-widget>
        </div>
    </div>
]])

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

