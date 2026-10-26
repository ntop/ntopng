--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint" -- validates _GET before it is read
local rest_utils = require "rest_utils"
local graph_utils = require "graph_utils"

--
-- Context of the PageStats Vue page (timeseries charts), the same one that
-- graph_utils.drawNewGraphs prints server side: used by the SPA routes that
-- mount PageStats client side (page-stats-route.vue). The data itself is
-- checked by the timeseries REST APIs, this only returns prefs and flags.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/timeseries/page_context.lua?ifid=-1"
--

local ifid = tonumber(_GET["ifid"])

if not ifid then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

-- shortcut: the source is the interface only, add the other keys (host, vlan, ...) with the pages that need them
rest_utils.answer(rest_utils.consts.success.ok, graph_utils.getNewGraphsContext({ ifid = ifid }))
