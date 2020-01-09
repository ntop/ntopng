--
-- (C) 2013-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo() 
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local os_utils = require "os_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("about.about_x", { product=info.product }))

active_page = "about"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(_POST["ntopng_license"] ~= nil) then
   ntop.setCache('ntopng.license', trimSpace(_POST["ntopng_license"]))
   ntop.checkLicense()
end

print("<hr /><h2>"..i18n("about.about_x", {product=info["product"]}).."</h2>")

print("<table class=\"table table-bordered table-striped\">\n")
print("<tr><th>") print(i18n("about.copyright")) print("</th><td colspan=2>"..info["copyright"].."</td></tr>\n")
print("<tr><th>") print(i18n("about.licence")) print("</th><td colspan=2>")

info["ntopng.license"] = ntop.getCache('ntopng.license')
if(info["pro.release"] == false) then
   print("<A HREF=\"http://www.gnu.org/licenses/gpl.html\" target=\"_blank\">".. info["license"] .."</A>")
else
   print("<A HREF=\"https://svn.ntop.org/svn/ntop/trunk/legal/LicenseAgreement/\" target=\"_blank\">EULA</A>")
end

if(info["pro.systemid"] and (info["pro.systemid"] ~= "")) then
   v = split(info["version"], " ")

   print(" [ SystemId: <A HREF=\"https://shop.ntop.org/mkntopng/?systemid=".. info["pro.systemid"].."&".."version=".. v[1] .."&edition=")

   if(info["version.embedded_edition"] == true) then
      print("embedded")
   elseif(info["version.enterprise_edition"] == true) then
      print("enterprise")
   else
      print("pro")
   end

   print("\" target=\"_blank\">".. info["pro.systemid"] .."</A> <i class='fas fa-external-link-alt'></i> ]")

print [[
    <br><small>]]
print(i18n("about.licence_generation", {
	      purchase_url='http://shop.ntop.org/',
	      universities_url='http://www.ntop.org/support/faq/do-you-charge-universities-no-profit-and-research/'
}))

print[[</small>
	 <p>
   ]]

   print('<form class="form-inline" method="post" onsubmit="return trimLicenceSpaces();">')

   if(isAdministrator()) then
      if(info["pro.use_redis_license"] or (info["pro.license"] == "")) then
	 print('<div class="form-group">')
	 print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	 print('<input id="ntopng_license" class="form-control" type="text" name="ntopng_license" placeholder="'..i18n("about.specify_licence")..'" size=70 pattern='.. getLicensePattern() ..' value="')
	 print(info["ntopng.license"])

	 print [["></input>
	 </div>
		     &nbsp;<button type="submit" class="btn btn-secondary">]] print(i18n("about.save_licence")) print[[</button>
		  </form>
	  <script>
	    function trimLicenceSpaces() {
		$("#ntopng_license").val($("#ntopng_license").val().trim());
		return true;
	    }
	  </script>
	    ]]
      else
	 if(info["pro.license"]) then
            print(i18n("about.licence")..": ".. info["pro.license"] .."\n")
            if info["pro.license_ends_at"] ~= nil and info["pro.license_days_left"] ~= nil then
               print("<br>"..i18n("about.maintenance", {
				     _until = format_utils.formatEpoch(info["pro.license_ends_at"]),
				     days_left = info["pro.license_days_left"]}))
	    end
	 end
      end
   end
end

print("</td></tr>")

vers = string.split(info["version.git"], ":")
if((vers ~= nil) and (vers[2] ~= nil)) then
   ntopng_git_url = "<A HREF=\"https://github.com/ntop/ntopng/commit/".. vers[2] .."\">"..info["version"].." ("..info["revision"]..")</A>"
else
   ntopng_git_url = info["version"]
end

print("<tr><th>"..i18n("about.version").."</th><td colspan=2>"..ntopng_git_url.." - ")

printntopngRelease(info)

if((info["OS"] ~= nil) and (info["OS"] ~= "")) then
   print("<tr><th>"..i18n("about.built_on").."</th><td colspan=2>"..info["OS"].."</td></tr>\n") 
end

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
     print("<tr><th><A href=\"http://www.ntop.org/products/ndpi/\" target=\"_blank\">nDPI</a></th><td colspan=2> <A HREF=\"https://github.com/ntop/nDPI/commit/\"".. ndpi_hash ..">"..ndpi_date.."</A></td></tr>\n")
  else
     print("<tr><th><A href=\"http://www.ntop.org/products/ndpi/\" target=\"_blank\">nDPI</A></th><td colspan=2> <A HREF=\"https://github.com/ntop/nDPI/\">"..ndpi_ver.."</A></td></tr>\n")
  end
end

print("<tr><th><a href=\"https://curl.haxx.se\" target=\"_blank\">cURL</A></th><td colspan=2>"..info["version.curl"].."</td></tr>\n")

print("<tr><th><a href=\"https://twitter.github.io/\" target=\"_blank\"><i class=\'fab fa-twitter fa-lg'></i> Twitter Bootstrap</A></th><td colspan=2>4.4.0</td></tr>\n")
print("<tr><th><a href=\"https://github.com/FortAwesome/Font-Awesome\" target=\"_blank\"><i class=\'fab fa-font-awesome fa-lg'></i> Font Awesome</A></th><td colspan=2>5.11.2</td></tr>\n")
print("<tr><th><a href=\"http://www.rrdtool.org/\" target=\"_blank\">RRDtool</A></th><td colspan=2>"..info["version.rrd"].."</td></tr>\n")

if(info["version.nindex"] ~= nil) then
   print("<tr><th>nIndex</th><td colspan=2>"..info["version.nindex"].."</td></tr>\n")
end

local l7_resolution = "5m"

if ts_utils.getDriverName() == "influxdb" then
   print("<tr><th><a href=\"http://www.influxdata.com\" target=\"_blank\">InfluxDB</A></th><td colspan=2><img id=\"influxdb-info-load\" border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber><span id=\"influxdb-info-text\"></span></td></tr>\n")
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
   local steps = tonumber(ntop.getPref("ntopng.prefs.ts_write_steps"))

   if steps and steps > 0 then
      l7_resolution = (steps * 5) .. "s"
   else
      l7_resolution = "1m"
   end
end

print("<tr><th>".. i18n("prefs.timeseries_resolution_resolution_title") .."</th><td colspan=2>"..l7_resolution.."</td></tr>\n")
print("<tr><th><a href=\"http://www.redis.io\" target=\"_blank\">Redis</A> Server</th><td colspan=2>"..info["version.redis"].."</td></tr>\n")
print("<tr><th><a href=\"https://github.com/valenok/mongoose\" target=\"_blank\">Mongoose web server</A></th><td colspan=2>"..info["version.httpd"].."</td></tr>\n")
print("<tr><th><a href=\"http://www.luajit.org\" target=\"_blank\">LuaJIT</A></th><td colspan=2>"..info["version.luajit"].."</td></tr>\n")
if info["version.zmq"] ~= nil then
   print("<tr><th><a href=\"http://www.zeromq.org\" target=\"_blank\">ØMQ</A></th><td colspan=2>"..info["version.zmq"].."</td></tr>\n")
end
if(info["version.geoip"] ~= nil) then
print("<tr><th><a href=\"http://www.maxmind.com\" target=\"_blank\">GeoLite</A></th><td colspan=2>"..info["version.geoip"])

print [[ <br><small>]] print(i18n("about.maxmind", {maxmind_url="http://www.maxmind.com/"})) print[[</small>
]]

print("</td></tr>\n")
end
print("<tr><th><a href=\"http://www.d3js.org\" target=\"_blank\">Data-Driven Documents (d3js)</A></th><td colspan=2>2.9.1 / 3.0</td></tr>\n")



print("</table>\n")


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
