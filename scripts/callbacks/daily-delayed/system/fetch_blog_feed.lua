--
-- (C) 2013-22 - ntop.org
--

--
-- This script fetches the latest blog entries that
-- will be shown in the web GUI on the top right corner
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local blog_utils = require("blog_utils")

blog_utils.fetchLatestPosts()
