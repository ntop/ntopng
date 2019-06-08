--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local ebpf_utils = require "ebpf_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

local page = _GET["page"]

if(page == nil) then page = "username_processes" end
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local user_key    = _GET["username"]
local host_info    = url2hostinfo(_GET)
local uid         = _GET["uid"]
local name
local ifstats = interface.getStats()
local refresh_rate

local have_nedge = ntop.isnEdge()
if have_nedge then
   refresh_rate = 5
else
   refresh_rate = getInterfaceRefreshRate(ifstats["id"])
end


if(user_key == nil) then
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "..i18n("user_info.missing_user_name_message").."</div>")
else
   if host_info and host_info["host"] then
      name = getResolvedAddress(hostkey2hostinfo(host_info["host"]))
      if isEmptyString(name) then
	 name = host_info["host"]
      end
   end
   print [[
	    <nav class="navbar navbar-default" role="navigation">
	      <div class="navbar-collapse collapse">
      <ul class="nav navbar-nav">
	    <li><a href="#">]]

   if host_info then
      print(string.format("%s: %s", i18n("host_details.host"), name))
   end

   print [[ <i class="fa fa-linux fa-lg"></i> ]] print(user_key)

   print [[  </a></li>]]


   if(page == "username_processes") then active=' class="active"' else active = "" end
   print('<li'..active..'><a href="?username='.. user_key..'&uid='..uid)
   if host_info then
      print('&'..hostinfo2url(host_info))
   end
   print('&page=username_processes">'..i18n("user_info.processes")..'</a></li>\n')

   if(page == "username_ndpi") then active=' class="active"' else active = "" end
   print('<li'..active..'><a href="?username='.. user_key..'&uid='..uid)
   if host_info then
      print('&'..hostinfo2url(host_info))
   end
   print('&page=username_ndpi">'..i18n("applications")..'</a></li>\n')

   if(page == "flows") then active=' class="active"' else active = "" end
   print('<li'..active..'><a href="?username='.. user_key..'&uid='..uid)
   if host_info then
      print('&'..hostinfo2url(host_info))
   end
   print('&page=flows">'..i18n("flows")..'</a></li>\n')

   print [[ <li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a> ]]

   print('</ul>\n\t</div>\n\t\t</nav>\n')

   if(page == "username_processes") then
      print [[
    <table class="table table-bordered table-striped">
      <tr><th class="text-left">
      ]] print(i18n("user_info.processes_overview")) print[[
	<td><div class="pie-chart" id="topProcesses"></div></td>

      </th>
    </tr>]]

      print [[
      </table>
<script type='text/javascript'>
window.onload=function() {
   var refresh = ]] print(refresh_rate..'') print[[000 /* ms */;
		    do_pie("#topProcesses", ']]
      print (ntop.getHttpPrefix())
      print [[/lua/get_username_data.lua', { username: "]] print(user_key) print [[", ebpf_data: "processes" ]]
      if (host_info ~= nil) then print(", "..hostinfo2json(host_info)) end
      print [[
 }, "", refresh);
}
</script>
]]

   elseif(page == "username_ndpi") then
      ebpf_utils.draw_ndpi_piecharts(ifstats, "get_username_data.lua", host_info, user_key, nil)
   elseif page == "flows" then
      ebpf_utils.draw_flows_datatable(ifstats, host_info, user_key, nil)
   end
end



dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
