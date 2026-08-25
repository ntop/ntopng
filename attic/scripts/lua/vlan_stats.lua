--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

if (group_col == nil) then
   group_col = "asn"
end

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.vlans)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
      <div id="table-vlan"></div>
	 <script>
	 var url_update = "]]
	 print (ntop.getHttpPrefix())
	 print [[/lua/get_vlans_data.lua]]

	 print ('";')

	 -- ###################################

	 print [[

// ---------------- Automatic VLAN table update code ------------------------

function vlan_table_setID (row) {
  var index = 0;
  var vlan_key = row.find("td").eq(0).text();

  // Set the row index to the AS key
  row.attr('id', vlan_key);

  row.find("td").eq(index++).attr('id', vlan_key+"_key");
  row.find("td").eq(index++).attr('id', vlan_key+"_vlan");
  // vlan_stats_top
  row.find("td").eq(index++).attr('id', vlan_key+"_chart");
  row.find("td").eq(index++).attr('id', vlan_key+"_hosts");
  row.find("td").eq(index++).attr('id', vlan_key+"_alerts");
  row.find("td").eq(index++).attr('id', vlan_key+"_since");

  // vlan_stats_bottom
  row.find("td").eq(index++).attr('id', vlan_key+"_score");
  row.find("td").eq(index++).attr('id', vlan_key+"_breakdown");
  row.find("td").eq(index++).attr('id', vlan_key+"_throughput");
  row.find("td").eq(index++).attr('id', vlan_key+"_traffic");

  return row;

}

function vlan_row_update(vlan_key) {
  var url = "]]  print (ntop.getHttpPrefix()) print [[/lua/get_vlan_data.lua?vlan="+vlan_key;

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      $("#"+vlan_key+'_hosts').html(data.column_hosts);
      $("#"+vlan_key+'_chart').html(data.column_chart);
      $("#"+vlan_key+'_alerts').html(data.column_alerts);
      $("#"+vlan_key+'_since').html(data.column_since);
      $("#"+vlan_key+'_score').html(data.column_score);
      $("#"+vlan_key+'_breakdown').html(data.column_breakdown);
      $("#"+vlan_key+'_throughput').html(data.column_thpt);
      $("#"+vlan_key+'_traffic').html(data.column_traffic);
    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Updating function
function vlan_table_update () {

  var $dt = $("#table-vlan").data("datatable");
  var rows = $dt.rows;

  for (var row in rows){
    var vlan_key = rows[row][0].id;
    vlan_row_update(vlan_key);
  }
}

// Refresh Interval (10 sec)
var vlan_table_interval = window.setInterval(vlan_table_update, 10000);
// ---------------- End automatic table update code ------------------------

]]

	 -- ###################################
	 --	 ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/vlan_stats_id.inc")


	 print [[
	 $("#table-vlan").datatable({
                        title: "VLAN List",
			url: url_update ,
	 ]]

	 print('title: "'..i18n("vlan_stats.vlans")..'",\n')
	 print ('rowCallback: function ( row ) { return vlan_table_setID(row); },')

	 -- Set the preference table
	 preference = tablePreferences("rows_number",_GET["perPage"])
	 if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

	 -- Automatic default sorted. NB: the column must exist.
	 print ('sort: [ ["' .. getDefaultTableSort("vlan") ..'","' .. getDefaultTableSortOrder("vlan").. '"] ],')


	 print [[
	       showPagination: true,
	        columns: [
           {
                                title: "Key",
                                field: "key",
                                hidden: true,
                                css: {
                                   textAlign: 'center'
                                }
           },
                         {
			     title: "]] print(i18n("vlan_stats.vlan_id")) print[[",
				 field: "column_vlan",
				 sortable: true,
                             css: {
			        textAlign: 'left'
			     }
				 },
			  ]]


			  print [[
			     {
			     title: "]] print(i18n("chart")) print[[",
				 field: "column_chart",
				 sortable: false,
                             css: {
			        textAlign: 'center'
			     }

				 },
			     {
			     title: "]] print(i18n("hosts_stats.hosts")) print[[",
				 field: "column_hosts",
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }

				 },
			     {
			     title: "]] print(i18n("show_alerts.alerts")) print[[",
				 field: "column_alerts",
				 sortable: false,
                             css: {
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("seen_since")) print[[",
				 field: "column_since",
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("score")) print[[",
				 field: "column_score",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 },
]]

print [[
			     {
			     title: "]] print(i18n("breakdown")) print[[",
				 field: "column_breakdown",
				 sortable: false,
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("throughput")) print[[",
				 field: "column_thpt",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			     }
				 },
			     {
			     title: "]] print(i18n("traffic")) print[[",
				 field: "column_traffic",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			     }
				 }
			     ]
	       });


       </script>
]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
