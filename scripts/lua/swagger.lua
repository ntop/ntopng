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

print [[
  <link rel="stylesheet" type="text/css" href="/dist/swagger-ui.css">
   <div id="swagger-ui"></div>

   <script src="/dist/swagger-ui-bundle.js"></script>
   <script src="/dist/swagger-ui-standalone-preset.js"></script>

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
