--
-- (C) 2017-18 - ntop.org
--
local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?/init.lua;" .. package.path

local ntop_info = ntop.getInfo()

local os_utils = require "os_utils"

local ebpf_utils = {}

function ebpf_utils.draw_processes_graph(host_info)
   print[[

<div align="center" id="chart"></div>

<script>
draw_processes_graph(']] print(ntop.getHttpPrefix()) print[[',']] print("chart") print[[',']] print(hostinfo2hostkey(host_info)) print[[');
</script>
]]
end

function ebpf_utils.draw_ndpi_piecharts(ifstats, url, host_info, uid, pid)
   local refresh_rate

   local have_nedge = ntop.isnEdge()
   if have_nedge then
      refresh_rate = 5
   else
      refresh_rate = getInterfaceRefreshRate(ifstats["id"])
   end

   print [[

  <table class="table table-bordered table-striped">
    <tr>
      <th class="text-left" colspan=2>]] print(i18n("ndpi_page.overview", {what = i18n("protocol")})) print[[</th>
      <td>
	<div class="pie-chart" id="topApplicationProtocols"></div>
      </td>
      <td colspan=2>
	<div class="pie-chart" id="topApplicationBreeds"></div>
      </td>
    </tr>
    <tr>
      <th class="text-left" colspan=2>]] print(i18n("ndpi_page.overview", {what = i18n("category")})) print[[</th>
      <td colspan=2>
	<div class="pie-chart" id="topApplicationCategories"></div>
      </td>
    </tr>
  </table>

	<script type='text/javascript'>
	       var refresh = ]] print(refresh_rate..'') print[[000 /* ms */;
	       window.onload=function() {]]

   print[[ do_pie("#topApplicationProtocols", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/]] print(url) print[[', { ebpf_data: "applications" ]]
   if host_info then print(", "..hostinfo2json(host_info)) end
   if uid then print(", uid: "..uid) end
   if pid then print(", pid: "..pid) end
   print [[ }, "", refresh); ]]

   print[[ do_pie("#topApplicationCategories", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/]] print(url) print[[', { ebpf_data: "categories" ]]
   if host_info then print(", "..hostinfo2json(host_info)) end
   if uid then print(", uid: "..uid) end
   if pid then print(", pid: "..pid) end
   print [[ }, "", refresh); ]]

   print[[do_pie("#topApplicationBreeds", ']]
   print (ntop.getHttpPrefix())
   print [[/lua/]] print(url) print[[', { ebpf_data: "breeds" ]]
   if host_info then print(", "..hostinfo2json(host_info)) end
   if uid then print(", uid: "..uid) end
   if pid then print(", pid: "..pid) end
   print [[ }, "", refresh);]]

   print[[
				}

	    </script>
]]
end

function ebpf_utils.draw_flows_datatable(ifstats, host_info, uid, pid)
   print [[
      <div id="table-flows"></div>
	 <script>
   var url_update = "]]
   print (ntop.getHttpPrefix())
   print [[/lua/get_flows_data.lua?]]
   print(table.tconcat({uid = uid, pid = pid, host = hostinfo2hostkey(host_info)}, "=", "&"))
   print ('";')

   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_id.inc")

   local show_vlan
   if ifstats.vlan then show_vlan = true else show_vlan = false end
   -- Set the host table option
   if show_vlan then print ('flow_rows_option["vlan"] = true;\n') end

   local active_flows_msg = i18n("flows_page.active_flows",{filter=""})
   if not interface.isPacketInterface() then
      active_flows_msg = i18n("flows_page.recently_active_flows",{filter=""})
   elseif interface.isPcapDumpInterface() then
      active_flows_msg = i18n("flows")
   end

   local dt_buttons = ''
   -- TODO: add application filter, etc.
   dt_buttons = "["..dt_buttons.."]"

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
   local preference = tablePreferences("rows_number", _GET["perPage"])
   if preference ~= "" then
      print ('perPage: '..preference.. ",\n")
   end

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
			     title: "]] print(i18n("protocol")) print[[",
				 field: "column_proto_l4",
				 sortable: true,
			     css: {
				textAlign: 'center'
			     }
				 },]]

   if show_vlan then

      if ifstats.vlan then
	 print('{ title: "'..i18n("vlan")..'",\n')
      end


      print [[
	 field: "column_vlan",
	 sortable: true,
		 css: {
	      textAlign: 'center'
	   }

	 },
]]
   end
   print [[
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
				textAlign: 'center'
			       }
			       },
			     {
			     title: "]] print(i18n("breakdown")) print[[",
				 field: "column_breakdown",
				 sortable: true,
			     css: {
				textAlign: 'center'
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
]]

   if ntop.isnEdge() then
      printBlockFlowJs()
   end

   print[[
       </script>

   ]]
end

return ebpf_utils
