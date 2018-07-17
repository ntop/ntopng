--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    require "snmp_utils"
end

require "lua_utils"
require "graph_utils"
local ts_utils = require("ts_utils")

local asn         = tonumber(_GET["asn"])
local page        = _GET["page"]

local application = _GET["application"]

interface.select(ifname)

local as_info = interface.getASInfo(asn) or {}
local ifId = getInterfaceId(ifname)
local asname = as_info["asname"]

local label = (asn or '')..''
if not isEmptyString(asname) then
   label = label.." ["..shortenString(asname).."]"
end

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if isEmptyString(asn) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> ".. i18n("as_details.as_parameter_missing_message") .. "</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

--[[
Create Menu Bar with buttons
--]]
local nav_url = ntop.getHttpPrefix().."/lua/as_details.lua?asn="..tonumber(asn)
print [[
<div class="bs-docs-example">
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">" .. i18n("as_details.as") .. ": "..label.."</A> </li>")

if(page == "flows") then
  print("<li class=\"active\"><a href=\"#\">"..i18n("flows").."</a></li>\n")
else
   print("<li><a href=\""..nav_url.."&page=flows\">"..i18n("flows").."</a></li>")
end

if(page == "historical") then
   print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i></a></li>\n")
else
   print("\n<li><a href=\""..nav_url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
</div>
]]

if isEmptyString(page) or page == "historical" then   
   local default_schema = "asn:traffic"

   if(not ts_utils.exists(default_schema, {ifid=ifId, asn=asn})) then
      print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "..i18n("as_details.no_available_data_for_as",{asn = label}))
      print(" "..i18n("as_details.as_timeseries_enable_message",{url = ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=on_disk_ts",icon_flask="<i class=\"fa fa-flask\"></i>"})..'</div>')

   else
      local schema = _GET["ts_schema"] or default_schema
      local selected_epoch = _GET["epoch"] or ""
      local asn_url = ntop.getHttpPrefix()..'/lua/as_details.lua?ifid='..ifId..'&asn='..asn..'&page=historical'

      local tags = {
         ifid = ifId,
         asn = asn,
         protocol = _GET["protocol"],
       }

       drawGraphs(ifId, schema, tags, _GET["zoom"], asn_url, selected_epoch, {
         top_protocols = "top:asn:ndpi",
         timeseries = {
            {schema="asn:traffic",                 label=i18n("traffic")},
            {schema="asn:rtt",                     label=i18n("graphs.num_ms_rtt"), nedge_exclude=1},
         },
       })
   end

   print[[
     <br>
       <div>
         <b>]] print(i18n('notes')) print[[</b>
         <ul>
           <li>]] print(i18n('graphs.note_ases_traffic')) print[[</li>
           <li>]] print(i18n('graphs.note_ases_sent')) print[[</li>
           <li>]] print(i18n('graphs.note_ases_rcvd')) print[[</li>
         </ul>
       </div>
]]

elseif page == "flows" then
   
print [[
      <div id="table-flows"></div>
	 <script>
   var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_flows_data.lua?ifid=]]
print(ifId.."&")
if not isEmptyString(application) then
   print("application="..application)
end
print("&asn="..asn..'";')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_id.inc")

local active_flows_msg = i18n("flows_page.active_flows",{filter = ""})
if not interface.isPacketInterface() then
   active_flows_msg = i18n("flows_page.recently_active_flows",{filter = ""})
elseif interface.isPcapDumpInterface() then
   active_flows_msg = i18n("flows")
end

local application_filter = ''
if(application ~= nil) then
   application_filter = '<span class="glyphicon glyphicon-filter"></span>'
end
local dt_buttons = "['<div class=\"btn-group\"><button class=\"btn btn-link dropdown-toggle\" data-toggle=\"dropdown\">"..i18n("flows_page.applications").. " " .. application_filter .. "<span class=\"caret\"></span></button> <ul class=\"dropdown-menu\" role=\"menu\" >"
dt_buttons = dt_buttons..'<li><a href="'..nav_url..'&page=flows">'..i18n("flows_page.all_proto")..'</a></li>'

local ndpi_stats = interface.getASInfo(asn)

for key, value in pairsByKeys(ndpi_stats["ndpi"], asc) do
   local class_active = ''
   if(key == application) then
      class_active = ' class="active"'
   end
   dt_buttons = dt_buttons..'<li '..class_active..'><a href="'..nav_url..'&page=flows&application='..key..'">'..key..'</a></li>'
end

dt_buttons = dt_buttons .. "</ul></div>']"

print [[
         flow_rows_option["type"] = 'host';
	 $("#table-flows").datatable({
         url: url_update,
         buttons: ]] print(dt_buttons) print[[,
         rowCallback: function ( row ) { return flow_table_setID(row); },
         tableCallback: function()  { $("#dt-bottom-details > .pull-left > p").first().append('. ]]
   print(i18n('flows_page.idle_flows_not_listed'))
   print[['); },
	       showPagination: true,
	       ]]

  print('title: "'..active_flows_msg..'",')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if(preference ~= "") then print ('perPage: '..preference.. ",\n") end


print ('sort: [ ["' .. getDefaultTableSort("flows") ..'","' .. getDefaultTableSortOrder("flows").. '"] ],\n')

print [[
	        columns: [
           {
        title: "Key",
         field: "key",
         hidden: true
         },
			     {
			     title: "",
				 field: "column_key",
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
                             title: "]] print(i18n("application")) print[[",
				 field: "column_ndpi",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("flows_page.l4_proto")) print[[",
				 field: "column_proto_l4",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("client")) print[[",
				 field: "column_client",
				 sortable: true,
				 },
			     {
			     title: "]] print(i18n("server")) print[[",
				 field: "column_server",
				 sortable: true,
				 },
			     {
                             title: "]] print(i18n("duration")) print[[",
				 field: "column_duration",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			       }
			       },
			     {
			     title: "]] print(i18n("flows_page.actual_throughput")) print[[",
				 field: "column_thpt",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			     }
				 },
			     {
                             title: "]] print(i18n("flows_page.total_bytes")) print[[",
				 field: "column_bytes",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			     }

				 }
			     ,{
                             title: "]] print(i18n("info")) print[[",
				 field: "column_info",
				 sortable: true,
	 	             css: {
			        textAlign: 'left'
			     }
				 }
			     ]
	       });
       </script>

   ]]

end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
