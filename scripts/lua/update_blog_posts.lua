--
-- (C) 2020 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local blog_utils = require("blog_utils")
local http_lint = require("http_lint")

sendHTTPContentTypeHeader('application/json')
local blog_notification_id = _POST['blog_notification_id']

if (blog_notification_id == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'blog_notification_id' parameter. Bad CSRF?")
end

local username = _SESSION["user"] or ''
if (isNoLoginUser()) then username = 'no_login' end

print(json.encode({
    success = blog_utils.updatePostState(tonumber(blog_notification_id), username),
}))
