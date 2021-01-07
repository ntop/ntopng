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

-- Value to change: data-ntop-widget-datasource

print([[
    <div class='row my-1'>
        <div class='col-3'>
            <div class='ntop-widget d-inline-block' data-ntop-widget-datasource='interface_packet_distro' data-ntop-widget-type='pie' data-ntop-widget-params='{"ifid":0}'>
            </div>
        </div>
        <div class='col-9'>
            <div class='w-50'>
                <code>
                &lt;div class='ntop-widget d-inline-block' data-ntop-widget-datasource='interface_packet_distro' data-ntop-widget-type='pie' <span class='text-danger'>data-ntop-widget-params='{"ifid":0}'</span>&gt;	
                &lt;/div&gt;
                </code>	
            </div>
        </div>
        <div class='col-3 my-2'>
            <div class='ntop-widget d-inline-block' data-ntop-widget-datasource='interface_packet_distro' data-ntop-widget-type='pie' data-ntop-widget-params='{"ifid":9}'>
            </div>
        </div>
        <div class='col-9'>
            <div class='w-50'>
                <code>
                &lt;div class='ntop-widget d-inline-block' data-ntop-widget-datasource='interface_packet_distro' data-ntop-widget-type='pie' <span class='text-danger'>data-ntop-widget-params='{"ifid":11}'</span>&gt;	
                &lt;/div&gt;
                </code>	
            </div>
        </div>
    </div>
]])

print([[
    <script type="module" src="]].. ntop.getHttpPrefix() ..[[/js/widgets/ntop-widget-utils.js"></script>
]])

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

