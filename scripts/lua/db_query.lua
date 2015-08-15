--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

ifstats = interface.getStats()

sql = _GET["sql"]
print('<p><form>SQL: <input type=text name=sql size="80" value="')

if((sql == nil) or (string.len(sql) == 0)) then
   sql = "select * from flowsv4_"..ifstats.id.." order by LAST_SWITCHED desc limit 10"
end

print(sql)
print('"><br>&nbsp;<br><input type=submit> <input type=reset></form><p><hr><p>')


if((_GET["sql"] ~= nil) and (string.len(_GET["sql"]) > 0)) then
   res = interface.execSQLQuery(_GET["sql"])

   if(res ~= nil) then      
      if(type(res) == "string") then
	 print("<b><font color=red>"..res.."</font></b>\n")
      else
      local num = 0
      for _,_v in pairs(res) do
	 if(num == 0) then
	    print("<table border=1>\n<tr>")

	    for k,v in pairs(_v) do
	       print("<th>"..k.."</th>")
	    end

	    print("</tr>\n")
	 end

	 print("<tr>")
	 for _,v in pairs(_v) do
	    print("<td align=center>"..v.."</td>")
	 end
	 print("</tr>\n")
	 num = num + 1
      end

      print("</table>\n")
   end
else
   print("<font color=red>Please start ntopng with -F mysql.... in order to make DB queries</font>")
   end
end