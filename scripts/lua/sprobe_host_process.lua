--
-- (C) 2014-15-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

host_ip   = _GET["host"]
host_name = _GET["pid_name"]
host_id   = _GET["pid"]

if(mode ~= "embed") then
   sendHTTPContentTypeHeader('text/html')
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   active_page = "hosts"
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
end

print("<hr><h2><A HREF='"..ntop.getHttpPrefix().."/lua/host_details.lua?host="..host_ip.."'>"..host_name.."</A> Processes Interaction</H2>")

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/sprobe_process_header.inc")

print('d3.json("'..ntop.getHttpPrefix()..'/lua/sprobe_host_process_data.lua?host='..host_ip..'&pid='..host_id..'",')


print [[
      function(error, json) {
	    if (error) return console.warn(error);
	    links = json;

	    // Compute the distinct nodes from the links.
	    links.forEach(function(link) {
		if(link.source_pid == -1) {
		   /* IP Address -> PID */
		   _link = "]]
print (ntop.getHttpPrefix())
print [[/lua/sprobe_host_process.lua?host="+link.source+"&pid_name="+link.source_name+"&pid=0";
		} else {
		   /* PID -> IP Address */
		   _link = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_process_info.lua?pid="+link.source_pid+"&pid_name="+link.source_name+"&host=]] print(host_ip) print [[&page=Flows";
		}
		link.source = nodes[link.source] || (nodes[link.source] = {name: link.source_name, num:link.source, link: _link, type: link.source_type, pid: link.source_pid });

		if(link.target_pid == -1) {
		   /* IP Address -> PID */
		   _link = "]]
print (ntop.getHttpPrefix())
print [[/lua/sprobe_host_process.lua?host="+link.target+"&pid_name="+link.target_name+"&pid=0";
		} else {
		   /* PID -> IP Address */
		   _link = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_process_info.lua?pid="+link.target_pid+"&pid_name="+link.target_name+"&host=]] print(host_ip) print [[&page=Flows";
		}

		link.target = nodes[link.target] || (nodes[link.target] = {name: link.target_name, num: link.target, link: _link, type: link.target_type, pid: link.target_pid });
	     });

    ]]

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/sprobe_process.inc")

if(mode ~= "embed") then
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
end
