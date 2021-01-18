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
        // window.__NTOPNG_WIDGET_CSRF__ = "]].. ntop.getRandomCSRFValue() ..[[";
    </script>
    <script type="module" src="]].. ntop.getHttpPrefix() ..[[/js/ntop-widgets/ntop-widgets.esm.js"></script>
    <script nomodule src="]].. ntop.getHttpPrefix() ..[[/js/ntop-widgets/ntop-widgets.js"></script>

]])

local ifaces = interface.getIfNames()
local options = {}
for id, ifname in pairs(ifaces) do
    options[#options+1] = string.format("<option %s value='%d'>%s</option>", ternary(id == 0, 'selected', ''), id, ifname)
end

print([[
    <div class='row my-4'>

        <div class='col-6'>
            <div class='form-group mb-2'>
                <label><b>Select an interface for the first Widget:</b></label>
                <select style='width: 600px' class='form-control' id='select-first'>
                    ]].. table.concat(options, '\n') ..[[
                </select>
            </div>
            <ntop-widget id='first-widget' transformation="pie" update="5000" width="600px" height="400px">
                <ntop-datasource src="interface_packet_distro" params-ifid='0'></ntop-datasource>
            </ntop-widget>
        </div>
        <div class='col-6'>
            <div class='form-group mb-2'>
                <label><b>Select an interface for the second Widget:</b></label>
                <select style='width: 600px' class='form-control' id='select-second'>
                    ]].. table.concat(options, '\n') ..[[
                </select>
            </div>
            <ntop-widget id='second-widget' class='d-inline-block' transformation="donut" update="5000" width="600px" height="400px">
                <ntop-datasource src="interface_packet_distro" params-ifid='0'></ntop-datasource>
            </ntop-widget>
        </div>
    </div>
]])

print([[

<script type='text/javascript'>
$(document).ready(function() {
    $(`#select-first`).on('change', async function() {
        const value = $(this).val();
        $(`#first-widget ntop-datasource`).attr("params-ifid", value);
        await $(`#first-widget`)[0].forceUpdate();
    });

    $(`#select-second`).on('change', async function() {
        const value = $(this).val();
        $(`#second-widget ntop-datasource`).attr("params-ifid", value);
        await $(`#second-widget`)[0].forceUpdate();
    });
});
</script>

]])

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

