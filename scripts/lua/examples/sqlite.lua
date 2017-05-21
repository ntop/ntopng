--
-- (C) 2014-15-15 - ntop.org
--

-- Hello world

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")


dirs = ntop.getDirs()

query = _GET["query"]

if (query == nil) then
   print [[
  <div class="alert alert-warning alert-dismissible" role="alert">
   <button type="button" class="close" data-dismiss="alert"><span aria-hidden="true">&times;</span>
   <span class="sr-only">Close</span></button>
   <strong>Query Empty!</strong> Example: localhost:3000/lua/examples/sqlite.lua?query=/var/tmp/ntopng/0/flows/2014-15-15/07/08/01/45.sqlite
</div>
   ]]

else

rsp = ntop.execQuery(query, "SELECT * from flows ORDER BY first_seen, srv_ip, srv_port, cli_ip, cli_port ASC")

if(rsp == nil) then
print [[
  <div class="alert alert-warning alert-dismissible" role="alert">
   <button type="button" class="close" data-dismiss="alert"><span aria-hidden="true">&times;</span>
   <span class="sr-only">Close</span></button>
      <strong>Query Error!</strong> Query: ]] print (query)
   print [[
   </div>
   ]]
else
   print("<table class=\"table table-bordered table-striped\">\n")

   num = 0
   for _k,_v in pairs(rsp) do

      if(num == 0) then
	 -- print("<tr><th>Id</th>")
	 for k,v in pairs(_v) do
	    print("<th>".. k .."</th>")
	 end
	 print("</tr>\n")
      end

      print("<tr>")
      -- print("<th>".. num .."</th>")

      for k,v in pairs(_v) do
	 print("<td>".. v .."</td>")
      end

      print("</tr>\n")
      num = num + 1
   end

   print("</table>\n")
end
end
print ('<strong>Total flows: ' .. num .. '</strong>')
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")