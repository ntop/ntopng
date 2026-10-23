--
-- (C) 2020-26 - ntop.org
--
-- License Limits is now a tab of the License page (see page-license-overview.vue):
-- this page is kept for the bookmarks and redirects there
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"

rest_utils.sendHTTPHeader("text/html", nil, {
   ["Location"] = ntop.getHttpPrefix() .. "/lua/license.lua?page=limits"
}, 302, "Found")
