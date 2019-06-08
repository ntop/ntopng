--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local telemetry_utils = require "telemetry_utils"
local page = _GET["page"] or "overview"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("telemetry"))

active_page = "telemetry"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

--[[
Create Menu Bar with buttons
--]]
local nav_url = ntop.getHttpPrefix().."/lua/telemetry.lua"

print [[
<div class="bs-docs-example">
<nav class="navbar navbar-default" role="navigation">
<div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">"..i18n("telemetry").."</A> </li>")

if page == "overview" then
   print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-home fa-lg\"></i>\n")
else
   print("<li><a href=\""..nav_url.."?page=overview\"><i class=\"fa fa-home fa-lg\"></i>\n")
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
</div>
]]

if page == "overview" then
   telemetry_utils.print_overview()
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
