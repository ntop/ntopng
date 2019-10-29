--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

require "lua_utils"
require "graph_utils"
local page_utils = require("page_utils")
local os_utils = require "os_utils"
local ts_utils = require "ts_utils"

local user_script     = _GET["user_script"]
local subdir     = _GET["subdir"]

local ifstats = interface.getStats()
local ifId = ifstats.id

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if((user_script == nil) or (subdir == nil)) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> user_script/subdir parameter is missing (internal error ?)</div>")
   return
end

if(not ts_utils.exists("user_script:duration", {ifid = ifId, user_script = user_script, subdir = subdir})) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No available stats for user script "..user_script.."</div>")
   return
end

print [[
<div class="bs-docs-example">
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">User Script: "..user_script.."</A> </li>")
print("<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i>\n")

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
</div>
]]

local schema = _GET["ts_schema"] or "user_script:duration"
local selected_epoch = _GET["epoch"] or ""
local url = ntop.getHttpPrefix()..'/lua/user_script_details.lua?ifid='..ifId..'&user_script='..user_script..'&page=historical&subdir='..subdir

local tags = {
   ifid = ifId,
   user_script = user_script,
   subdir = subdir,
}

drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
   top_user_script = "top:user_script:duration",

   timeseries = {
      {schema = "user_script:duration", label = i18n("internals.script_duration"), value_formatter = {"fmillis"}},
      {schema = "user_script:num_calls", label = i18n("internals.num_calls")},
   }
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
