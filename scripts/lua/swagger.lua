--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.rest_api)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@4.5.0/swagger-ui.css" />
  <script src="https://unpkg.com/swagger-ui-dist@4.5.0/swagger-ui-bundle.js" crossorigin></script>
  <script src="https://unpkg.com/swagger-ui-dist@4.5.0/swagger-ui-standalone-preset.js" crossorigin></script>

   <div id="swagger-ui"></div>

   <script>
    window.onload = function() {
      const ui = SwaggerUIBundle({
	    url: "]] print(ntop.getHttpPrefix()) print[[/misc/rest-api-v2.json",
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
