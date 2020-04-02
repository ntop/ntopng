--
-- (C) 2020 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local blog_utils = require("blog_utils")

sendHTTPContentTypeHeader('application/json')

print(json.encode({
    success = true,
    posts = blog_utils.readPostsFromRedis(_SESSION['user'])
}))
