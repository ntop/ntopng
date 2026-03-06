--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local ebpf_utils = require "ebpf_utils"

sendHTTPContentTypeHeader('text/html')


page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.hosts)

local page = _GET["page"]

if(page == nil) then page = "username_processes" end
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local user_key    = _GET["username"]
local host_info    = url2hostinfo(_GET)
local uid         = _GET["uid"]
local name
local ifstats = interface.getStats()
local refresh_rate

local http_prefix = ntop.getHttpPrefix()
local have_nedge = ntop.isnEdge()
if have_nedge then
   refresh_rate = 5
else
   refresh_rate = interface.getStatsUpdateFreq(ifstats["id"])
end


if(user_key == nil) then
   print("<div class=\"alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> "..i18n("user_info.missing_user_name_message").."</div>")
else
   local title = ''
   local nav_url = http_prefix.."/lua/username_details.lua?username="..user_key.."&uid="..uid

   if host_info and host_info["host"] then
      name = hostinfo2label(host_info)
      if isEmptyString(name) then
	 name = host_info["host"]
      end

      title = string.format("%s: %s", i18n("host_details.host"), name)
      nav_url = nav_url.."&"..hostinfo2url(host_info)
   end
   title = title.." <i class=\"fab fa-linux fa-lg\"></i> "..user_key

   page_utils.print_navbar(title, nav_url,
			   {
			      {
				 active = page == "username_processes" or not page,
				 page_name = "username_processes",
				 label = i18n("user_info.processes"),
			      },
			      {
				 active = page == "username_ndpi",
				 page_name = "username_ndpi",
				 label = i18n("applications"),
			      },
			      {
				 active = page == "flows",
				 page_name = "flows",
				 label = '<i class="fas fa-stream"></i>',
			      },
			   }
   )

   if(page == "username_processes") then
      print([[<table class="table table-bordered table-striped">]])
      print([[<tr><th class="text-start">]] .. i18n("user_info.processes_overview") .. [[</th><td>]])

      template.render("pages/vue_page.template", {
         vue_page_name = "MultiPieChart",
         page_context  = json.encode({
            charts = {{
               name       = "topProcesses",
               title      = i18n("user_info.processes_overview"),
               update_url = http_prefix .. "/lua/get_username_data.lua",
               url_params = { username = user_key, ebpf_data = "processes" },
               refresh    = refresh_rate * 1000,
               unit       = "number",
            }}
         }),
      })

      print([[</td></tr>]])
      print([[</table>]])
   elseif(page == "username_ndpi") then
      ebpf_utils.draw_ndpi_piecharts(ifstats, "get_username_data.lua", host_info, user_key, nil)
   elseif page == "flows" then
      ebpf_utils.draw_flows_datatable(ifstats, host_info, user_key, nil)
   end
end



dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
