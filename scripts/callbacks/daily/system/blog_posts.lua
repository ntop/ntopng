--
-- (C) 2024-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

-- Refresh ntop blog posts daily (startup.lua also fetches them at boot)
if not (ntop.isnEdge and ntop.isnEdge()) then
    local blog_utils = require("blog_utils")
    blog_utils.fetchLatestPosts()
end
