--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local ebpf_utils = require "ebpf_utils"

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.flows)

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
   print("<div class=\"alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> "..i18n("processes_stats.missing_pid_name_message").."</div>")
else

   local name = ''
   if num == 0 then
      print("<div class=\"alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> "..i18n("processes_stats.no_traffic_detected").."</div>")
   else
      local title = ''
      local nav_url = ntop.getHttpPrefix().."/lua/process_details.lua?pid="..pid.."&pid_name="..name_key

      if host_info and host_info["host"] then
	 name = ip2label(host_info["host"])
	 if isEmptyString(name) then
	    name = host_info["host"]
	 end

	 title = string.format("%s: %s", i18n("host_details.host"), name)
	 nav_url = nav_url.."&"..hostinfo2url(host_info)
      end
      title = title..' <i class="fas fa-terminal"></i> '..name_key

      page_utils.print_navbar(title, nav_url,
			      {
				 {
				    active = page == "process_ndpi" or not page,
				    page_name = "process_ndpi",
				    label = i18n("applications"),
				 },
				 {
				    active = page == "flows",
				    page_name = "flows",
				    label = i18n("flows"),
				 },
			      }
      )

      if page == "process_ndpi" then
	 ebpf_utils.draw_ndpi_piecharts(ifstats, "get_process_data.lua", host_info, nil, name_key)
      elseif page == "flows" then
	 ebpf_utils.draw_flows_datatable(ifstats, host_info, nil, name_key)
      end
   end
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
