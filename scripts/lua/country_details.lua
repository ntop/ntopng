--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

local country        = _GET["country"]
local page           = _GET["page"]

interface.select(ifname)
local ifstats = interface.getStats()
local ifId = ifstats.id

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(country == nil) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> ".. i18n("country_details.country_parameter_missing_message") .. "</div>")
    return
end

rrdname = dirs.workingdir .. "/" .. ifId .. "/countrystats/" .. getPathFromKey(country) .. "/bytes.rrd"

if(not ntop.exists(rrdname)) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("country_details.no_available_stats_for_country",{country=country}) .. "</div>")
    return
end

--[[
Create Menu Bar with buttons
--]]
local nav_url = ntop.getHttpPrefix().."/lua/country_details.lua?country="..country
print [[
<div class="bs-docs-example">
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">" .. i18n("country_details.country") .. ": "..country.."</A> </li>")

if(page == "historical") then
    print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i></a></li>\n")
else
    print("\n<li><a href=\""..nav_url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
</div>
]]

--[[
Selectively render information pages
--]]
if page == "historical" then
    if(_GET["rrd_file"] == nil) then
        rrdfile = "bytes.rrd"
    else
        rrdfile=_GET["rrd_file"]
    end

    host_url = ntop.getHttpPrefix()..'/lua/country_details.lua?ifid='..ifId..'&country='..country..'&page=historical'
    drawRRD(ifId, 'country:'..country, rrdfile, _GET["zoom"], host_url, 1, _GET["epoch"])
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
