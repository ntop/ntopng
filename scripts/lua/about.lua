--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "about"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(_GET["ntopng_license"] ~= nil) then
   ntop.setCache('ntopng.license', _GET["ntopng_license"])
   ntop.checkLicense()
end

info = ntop.getInfo()
print("<hr /><h2>About "..info["product"].."</h2>")

print("<table class=\"table table-bordered table-striped\">\n")
print("<tr><th>Copyright</th><td>"..info["copyright"].."</td></tr>\n")
print("<tr><th>License</th><td>")

if(info["pro.release"] == false) then
   print("<A HREF=http://www.gnu.org/licenses/gpl.html target=\"_blank\">"..info["license"].."</A>")
else
   print("<A HREF=https://svn.ntop.org/svn/ntop/trunk/legal/EULA.txt target=\"_blank\">EULA</A>")
end

if(info["pro.systemid"] and (info["pro.systemid"] ~= "")) then
   v = split(info["version"], " ")

   print(" [ SystemId: <A HREF=\"http://www.nmon.net/mkntopng/?systemid=".. info["pro.systemid"].."&".."version=".. v[1] .."&edition=")
   
   if(info["version.embedded_edition"] == true) then
      print("embedded")
   else
      print("pro")
   end
   print("\" target=\"_blank\">".. info["pro.systemid"] .."</A> <i class='fa fa-external-link fa-lg'></i> ]")

print [[
    <br><small>Click on the above URL to generate your professional version license, 
	       <br>purchase a license at <A HREF=http://shop.ntop.org/>e-shop</A>, or <A HREF=mailto:testing@ntop.org>mail us</A> for a free evaluation license.</small>
	 <p>
   ]]

   print('<form class="form-inline" style="margin-bottom: 0px;">')

   if(isAdministrator()) then
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print('<input type="text" name="ntopng_license" placeholder="Specify here your ntopng License" size=60 value="')
      print(info["ntopng.license"])

      print [["></input>
	       &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save License</button>

	       
    </form>
   ]]

   end
end

print("</td></tr>")

vers = string.split(info["version.git"], ":")
if((vers ~= nil) and (vers[1] ~= nil)) then
   v_hash = string.sub(vers[1], 2) 
   ntopng_git_url = "<A HREF=https://github.com/ntop/ntopng/commit/".. v_hash ..">"..info["version"].."</A>"
else
   ntopng_git_url = info["version"]
end

print("<tr><th>Version</th><td>"..ntopng_git_url)

if(info["pro.release"] == false) then
   print(" - Community")
else
   print(" - Professional")
end

if(info["version.embedded_edition"] == true) then
   print("/Embedded")
end

print(" Edition</td></tr>\n")

print("<tr><th>Platform</th><td>"..info["platform"].."</td></tr>\n")
print("<tr><th>Currently Logged User</th><td><i class='fa fa-user fa-lg'></i> ".._SESSION["user"].."</td></tr>\n")
print("<tr><th>Uptime</th><td><i class='fa fa-clock-o fa-lg'></i> "..secondsToTime(info["uptime"]).."</td></tr>\n")
print("<tr><th colspan=2 align=center>&nbsp;</th></tr>\n")

v = string.split(info["version.ndpi"], " ")
ndpi_vers = v[1]
v_all = string.sub(v[2], 2, -2)

vers = string.split(v_all, ":")
ndpi_hash = vers[1]
ndpi_date = vers[2]

print("<tr><th><a href=http://www.ntop.org/products/ndpi/ target=\"_blank\">nDPI</A></th><td> <A HREF=https://github.com/ntop/nDPI/commit/".. ndpi_hash ..">"..ndpi_date.."</A></td></tr>\n")
print("<tr><th><a href=http://twitter.github.io/ target=\"_blank\"><i class=\'fa fa-twitter fa-lg'></i> Twitter Bootstrap</A></th><td>3.x</td></tr>\n")
print("<tr><th><a href=http://fortawesome.github.io/Font-Awesome/ target=\"_blank\"><i class=\'fa fa-flag fa-lg'></i> Font Awesome</A></th><td>4.x</td></tr>\n")
print("<tr><th><a href=http://www.rrdtool.org/ target=\"_blank\">RRDtool</A></th><td>"..info["version.rrd"].."</td></tr>\n")
print("<tr><th><a href=http://www.redis.io target=\"_blank\">Redis</A> Server</th><td>"..info["version.redis"].."</td></tr>\n")
print("<tr><th><a href=https://github.com/valenok/mongoose target=\"_blank\">Mongoose web server</A></th><td>"..info["version.httpd"].."</td></tr>\n")
print("<tr><th><a href=http://www.luajit.org target=\"_blank\">LuaJIT</A></th><td>"..info["version.luajit"].."</td></tr>\n")
print("<tr><th><a href=http://www.zeromq.org target=\"_blank\">ØMQ</A></th><td>"..info["version.zmq"].."</td></tr>\n")
if(info["version.geoip"] ~= nil) then
print("<tr><th><a href=http://www.maxmind.com target=\"_blank\">GeoIP</A></th><td>"..info["version.geoip"])

print [[ <br>&nbsp;<br><small>This product includes GeoLite data created by <a href="http://www.maxmind.com">MaxMind</a>.</small>
]]

print("</td></tr>\n")
end
print("<tr><th><a href=http://www.d3js.org target=\"_blank\">Data-Driven Documents (d3js)</A></th><td>2.9.1 / 3.0</td></tr>\n")
print("<tr><th><a href=https://github.com/lemire/EWAHBoolArray target=\"_blank\">Compressed Bitmap (EWAHBoolArray)</A></th><td>0.4.0</td></tr>\n")



print("</table>\n")


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
