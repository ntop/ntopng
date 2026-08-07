--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local debug = false

sendHTTPHeaderLogout('text/html')

ntop.delCache("ntopng.cache.sessions.".._SESSION["session"])
if (debug) then io.write("Deleting ".."ntopng.cache.sessions.".._SESSION["session"].."\n") end

print [[
<meta http-equiv="refresh" content="1; URL=]] print(ntop.getHttpPrefix()) print [[/">
<html>
<body>
 ]] print(i18n("login.logging_out")) print[[
</body>
</html>

]]

--
-- (C) 2026 - ntop.org
--

--[[
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils     = require "page_utils"
local json           = require "dkjson"
local template_utils = require "template_utils"

sendHTTPHeaderLogout('text/html')

ntop.delCache("ntopng.cache.sessions.".._SESSION["session"])

local context = {
  redirect_url = ntop.getHttpPrefix() .. "/",
}

template_utils.render("pages/vue_page.template", {
  vue_page_name = "PageLogout",
  page_context  = json.encode(context)
})

print [[
</body>
</html>
]]