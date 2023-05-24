--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo()
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local os_utils = require "os_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.about, { product=info.product })
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@4.5.0/swagger-ui.css" />
  <script src="https://unpkg.com/swagger-ui-dist@4.5.0/swagger-ui-bundle.js" crossorigin></script>
  <script src="https://unpkg.com/swagger-ui-dist@4.5.0/swagger-ui-standalone-preset.js" crossorigin></script>

   <div id="swagger-ui"></div>

   <script>
    window.onload = function() {
      const ui = SwaggerUIBundle({
	    url: "/misc/rest-api-v2.json",
	    dom_id: '#swagger-ui',
	    presets: [
	       SwaggerUIBundle.presets.apis,
	       SwaggerUIStandalonePreset
            ]
      })

      window.ui = ui
    }
    </script>

]]
