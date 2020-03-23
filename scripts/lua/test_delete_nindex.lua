--
-- (C) 2013-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path

local page_utils = require "page_utils"
require "lua_utils"

sendHTTPContentTypeHeader('text/html')
page_utils.manage_system_interface()
page_utils.print_header(i18n("about.about_x", { product=info.product }))

if ntop.isEnterprise() and hasNindexSupport() then
  local nindex_utils = require "nindex_utils"
  nindex_utils.deleteOldFLows(true --[[ verbose ]])
else
  print("nIndex delete unsupported")
end
