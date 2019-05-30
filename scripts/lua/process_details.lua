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
if isEmptyString(page) then page = "process_ndpi" end
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local pid = _GET["pid"]
local name_key = _GET["pid_name"] or "no name"
local host_info = url2hostinfo(_GET)
local ifstats = interface.getStats()
local refresh_rate

local have_nedge = ntop.isnEdge()
if have_nedge then
   refresh_rate = 5
else
   refresh_rate = getInterfaceRefreshRate(ifstats["id"])
end

if not pid or not name_key then
   print("<div class=\"alert alert-danger\"><img src=/img/warning.png> "..i18n("processes_stats.missing_pid_name_message").."</div>")
else

   local name = ''
   if num == 0 then
      print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "..i18n("processes_stats.no_traffic_detected").."</div>")
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

      print [[ <i class="fa fa-terminal fa-lg"></i> ]] print(name_key)

      print [[ </a></li>]]

      local active = ''
      if page == "process_ndpi" then
	 active=' class="active"'
      end

      print('<li'..active..'><a href="?pid='.. pid..'&pid_name='..name_key)
      if host_info then
	 print("&"..hostinfo2url(host_info))
      end
      print('&page=process_ndpi">'..i18n("applications")..'</a></li>\n')

      active = ''
      if page == "flows" then
	 active=' class="active"'
      end

      print('<li'..active..'><a href="?pid='.. pid..'&pid_name='..name_key)
      if host_info then
	 print("&"..hostinfo2url(host_info))
      end
      print('&page=flows">'..i18n("flows")..'</a></li>\n')

      print [[ <li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a> ]]

      -- End Tab Menu

      print('</ul>\n\t</div>\n\t</nav>\n')

      if page == "process_ndpi" then
	 ebpf_utils.draw_ndpi_piecharts(ifstats, "get_process_data.lua", host_info, nil, name_key)
      elseif page == "flows" then
	 ebpf_utils.draw_flows_datatable(ifstats, host_info, nil, name_key)
      end
   end
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
