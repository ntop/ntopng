--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

local dirs = ntop.getDirs()

sendHTTPContentTypeHeader('application/json')

local collapsed_sidebar = _GET["sidebar_collapsed"]

sendHTTPContentTypeHeader('application/json')

if (collapsed_sidebar == nil) then
    -- 'ntopng.prefs'
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad Sidebar Collapse property")
    return
end

-- save preferences
ntop.setPref('ntopng.prefs.sidebar_collapsed', collapsed_sidebar)
