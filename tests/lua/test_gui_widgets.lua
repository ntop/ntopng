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

    <script type="module" src="]].. ntop.getHttpPrefix() ..[[/js/ntop-widgets/ntop-widgets.esm.js"></script>
    <script nomodule src="]].. ntop.getHttpPrefix() ..[[/js/ntop-widgets/index.js"></script>

]])

local ifaces = interface.getIfNames()
local options = {}
for id, ifname in pairs(ifaces) do
    options[#options+1] = string.format("<option %s value='%d'>%s</option>", ternary(id == 0, 'selected', ''), id, ifname)
end

print([[
    <div class='row my-4'>
        <div class='col-6'>
            <ntop-widget id='first-widget' type="pie" update="5000" height='30rem'>
                <ntop-datasource src="interface_packet_distro?ifid=0"></ntop-datasource>
            </ntop-widget>
        </div>
        <div class='col-6'>
            <ntop-widget id='second-widget' display='none' type="donut" update="5000" height='30rem'>
                <ntop-datasource src="interface_packet_distro?ifid=0"></ntop-datasource>
            </ntop-widget>
        </div>
        <div class='col-6 my-4'>
            <ntop-widget id='third-widget' display='raw' type="stackedBar" update="5000" height='28.5rem' width='100%'>
                <h3 slot='header' class='mt-2 mb-4' style='flex: auto'>
                    Stacked Bar Chart (Interface/Packet Distro)
                </h3>
                <ntop-datasource src="interface_packet_distro?ifid=0"></ntop-datasource>
                <ntop-datasource src="interface_packet_distro?ifid=9"></ntop-datasource>
                <ntop-datasource src="interface_packet_distro?ifid=15"></ntop-datasource>
            </ntop-widget>
        </div>
        <div class='col-6 my-4'>
            <ntop-widget id='fourth-widget' update="5000" height='100%' width='100%'>
                <h3 slot='header' class='mt-2 mb-4' style='flex: auto'>
                    Line + 2xBars (Interface/Packet Distro)
                </h3>
                <ntop-datasource src="interface_packet_distro?ifid=0" type="line" styling='{"fill": false}'></ntop-datasource>
                <ntop-datasource src="interface_packet_distro?ifid=9" type="bar"></ntop-datasource>
                <ntop-datasource src="interface_packet_distro?ifid=15" type="bar"></ntop-datasource>
            </ntop-widget>
        </div>
        <div class='col-6 my-4'>
            <ntop-widget id='fifth-widget' display='raw' update="5000" height='100%' width='100%'>
                <h3 slot='header' class='mt-2 mb-4' style='flex: auto'>
                    3x Lines (No Fill, 2xFills) (Interface/Packet Distro)
                </h3>
                <ntop-datasource src="interface_packet_distro?ifid=0" type="line" styling='{"fill": false}'></ntop-datasource>
                <ntop-datasource src="interface_packet_distro?ifid=9" type="line"></ntop-datasource>
                <ntop-datasource src="interface_packet_distro?ifid=15" type="line"></ntop-datasource>
            </ntop-widget>
        </div>
        <div class='col-6 my-4'>
            <ntop-widget id='sixth-widget' display='raw' update="5000" height='100%' width='100%'>
                <h3 slot='header' class='mt-2 mb-4' style='flex: auto'>
                    Scatter (Interface/Packet Distro)
                </h3>
                <ntop-datasource src="interface_packet_distro?ifid=0" type="scatter"></ntop-datasource>
                <ntop-datasource src="interface_packet_distro?ifid=9" type="scatter"></ntop-datasource>
                <ntop-datasource src="interface_packet_distro?ifid=15" type="scatter"></ntop-datasource>
            </ntop-widget>
        </div>
    </div>
]])

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

