--
-- (C) 2026 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils     = require "page_utils"
local json           = require "dkjson"
local template_utils = require "template_utils"

sendHTTPHeaderLogout('text/html')

ntop.delCache("ntopng.cache.sessions.".._SESSION["session"])

page_utils.print_header_minimal(i18n("login.logging_out"))

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
