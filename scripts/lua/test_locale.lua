--
-- (C) 2013-22 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

print('<script type="text/javascript" src="'..ntop.getHttpPrefix()..'/lua/locale.lua"> </script>')

print [[
<script>
	document.write(i18n("about.alert_defines"));
</script>
]]
   
