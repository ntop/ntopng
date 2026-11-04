--
-- (C) 2026 - ntop.org
--

-- This page shows the HTTP errors that a user can get
-- example: 404, 403, ...

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local page_utils = require("page_utils")

local status_codes = {
   bad_request    = 400,
   not_found      = 404,
   internal_error = 500,
   shut_start     = 503,
}

sendHTTPContentTypeHeader('text/html', nil, nil, nil, status_codes[_GET["message"]] or 403)
page_utils.print_header()

-- The page is an SPA route (page-http-status-code.vue, see router.js): its context
-- comes from the URL params
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
