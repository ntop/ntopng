--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo()
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local os_utils = require "os_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.about, { product=info.product })
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print("<div class='row'>")
print("<div class='col-12'>")

page_utils.print_page_title(i18n("about.about_x", {product=info["product"]}))

print("</div>")
print("</div>")

print("<div class='row'>")
print("<div class='col-12'>")
print("<table class=\"table table-bordered table-striped\">\n")
print("<tr><th>") print(i18n("about.copyright")) print("</th><td colspan=2>"..info["copyright"].."</td></tr>\n")

--

vers = string.split(info["version.git"], ":")
if((vers ~= nil) and (vers[2] ~= nil)) then
   ntopng_git_url = "<A HREF=\"https://github.com/ntop/ntopng/commit/".. vers[2] .."\">"..info["version"].." ("..info["revision"]..")</A> <i class='fas fa-external-link-alt'></i>"
else
   ntopng_git_url = info["version"]
end

print("<tr><th>"..i18n("about.version").."</th><td colspan=2>"..getNtopngRelease(info).."</td></tr>\n")
print("<tr><th>"..i18n("about.system_id").."</th><td colspan=2>"..info["pro.systemid"].." <A HREF=\"".. ntop.getHttpPrefix() .. "/lua/license.lua\"><i class=\"fas fa-cog\"></i></A></td></tr>\n")

print("<tr><th nowrap>"..i18n("about.platform").."</th><td colspan=2>"..info["platform"].." - "..info["bits"] .." bit</td></tr>\n")
print("<tr><th nowrap>"..i18n("about.startup_line").."</th><td colspan=2>".. info["product"] .." "..info["command_line"].."</td></tr>\n")
--print("<tr><th colspan=2 align=center>&nbsp;</th></tr>\n")

ndpi_ver = info["version.ndpi"]
if (ndpi_ver ~= nil) then
  v = string.split(ndpi_ver, " ")
  if (v ~= nil) then
    ndpi_vers = v[1]
     v_all = string.sub(v[2], 2, -2)
     vers = string.split(v_all, ":")
     ndpi_hash = vers[1]
     ndpi_date = vers[2]
     print("<tr><th><A href=\"http://www.ntop.org/products/ndpi/\" target=\"_blank\">nDPI</a> <i class='fas fa-external-link-alt'></i></th><td colspan=2> <A HREF=\"https://github.com/ntop/nDPI/commit/\"".. ndpi_hash ..">"..ndpi_date.."</A></td></tr>\n")
  else
     print("<tr><th><A href=\"http://www.ntop.org/products/ndpi/\" target=\"_blank\">nDPI</A> <i class='fas fa-external-link-alt'></i></th><td colspan=2> <A HREF=\"https://github.com/ntop/nDPI/\">"..ndpi_ver.."</A></td></tr>\n")
  end
end

print("<tr><th><a href=\"https://curl.haxx.se\" target=\"_blank\">cURL</A> <i class='fas fa-external-link-alt'></i></th><td colspan=2>"..info["version.curl"].."</td></tr>\n")

print("<tr><th><a href=\"https://twitter.github.io/\" target=\"_blank\"><i class=\'fab fa-twitter fa-lg'></i> Twitter Bootstrap</A> <i class='fas fa-external-link-alt'></i></th><td colspan=2>5.0</td></tr>\n")
print("<tr><th><a href=\"https://github.com/FortAwesome/Font-Awesome\" target=\"_blank\"><i class=\'fab fa-font-awesome fa-lg'></i> Font Awesome</A> <i class='fas fa-external-link-alt'></i></th><td colspan=2>5.11.2</td></tr>\n")
print("<tr><th><a href=\"http://www.rrdtool.org/\" target=\"_blank\">RRDtool</A> <i class='fas fa-external-link-alt'></i></th><td colspan=2>"..info["version.rrd"].."</td></tr>\n")

if(info["version.nindex"] ~= nil) then
   print("<tr><th>ntop nIndex</th><td colspan=2>"..info["version.nindex"].."</td></tr>\n")
end

if ts_utils.getDriverName() == "influxdb" then
   print("<tr><th><a href=\"http://www.influxdata.com\" target=\"_blank\">InfluxDB</A></th><td colspan=2><span id='influxdb-info-load' class='spinner-border spinner-border-sm text-primary' role='status'><span class='sr-only'>Loading...</span></span> <span id=\"influxdb-info-text\"></span></td></tr>\n")
   print[[<script>
$(function() {
   $.get("]] print(ntop.getHttpPrefix()) print[[/lua/get_influxdb_info.lua", function(info) {
      $("#influxdb-info-load").hide();
      $("#influxdb-info-text").html(info.version + " ");
   }).fail(function() {
      $("#influxdb-info-load").hide();
   });
});
</script>
]]

   -- NOTE: need to calculate this dynamically as it can be temporary disabled at runtime
   local resolution = tonumber(ntop.getPref("ntopng.prefs.ts_resolution"))

   if hasHighResolutionTs() then
      l7_resolution = "1m"
   else
      l7_resolution = "5m"
   end
end

print("<tr><th><a href=\"http://www.redis.io\" target=\"_blank\">Redis</A>  <i class='fas fa-external-link-alt'></i> Server</th><td colspan=2>"..info["version.redis"].."</td></tr>\n")
print("<tr><th><a href=\"https://github.com/valenok/mongoose\" target=\"_blank\">Mongoose web server</A> <i class='fas fa-external-link-alt'></i></th><td colspan=2>"..info["version.httpd"].."</td></tr>\n")
print("<tr><th><a href=\"http://www.lua.org\" target=\"_blank\">Lua</A> <i class='fas fa-external-link-alt'></i></th><td colspan=2>"..info["version.lua"].."</td></tr>\n")
if info["version.zmq"] ~= nil then
   print("<tr><th><a href=\"http://www.zeromq.org\" target=\"_blank\">ØMQ</A> <i class='fas fa-external-link-alt'></i></th><td colspan=2>"..info["version.zmq"].."</td></tr>\n")
end
if(info["version.geoip"] ~= nil) then
print("<tr><th><a href=\"http://www.maxmind.com\" target=\"_blank\">GeoLite</A> <i class='fas fa-external-link-alt'></i></th><td colspan=2>"..info["version.geoip"])

print [[ <br><small>]] print(i18n("about.maxmind", {maxmind_url="http://www.maxmind.com/"})) print[[</small>
]]

print("</td></tr>\n")
end
print("<tr><th><a href=\"http://d3js.org\" target=\"_blank\">Data-Driven Documents (d3js)</A> <i class='fas fa-external-link-alt'></i></th><td colspan=2>2.9.1 / 3.0</td></tr>\n")



print("</table>\n")

print("</div>")
print("</div>")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
