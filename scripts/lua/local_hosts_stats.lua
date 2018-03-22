--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

criteria    = _GET["criteria"]
ipversion   = _GET["version"]

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local base_url = ntop.getHttpPrefix() .. "/lua/local_hosts_stats.lua"
local page_params = {}

if isEmptyString(criteria) then
  criteria = "downloaders"
end

page_params["criteria"] = criteria

if not isEmptyString(ipversion) then
  page_params["version"] = ipversion
end

prefs = ntop.getPrefs()

ifstats = interface.getStats()

print [[
      <hr>
      </ul>

      <div id="table-localhosts"></div>
	 <script>
	 var url_update = "]]
local url_update_params = table.clone(page_params)
url_update_params["mode"] = "local"
print(getPageUrl(ntop.getHttpPrefix().."/lua/get_hosts_data.lua", url_update_params))
print ('";')

print [[



// ---------------- Automatic table update code ------------------------
// Use the host_rows_option object in order to simplify the option setting from lua script.

var host_rows_option = {};
host_rows_option["ip"] = false;


function host_table_setID (row) {
  var index = 0;
  var host_key = row.find("td").eq(0).text();
  
  // Set the row index to the host key
  row.attr('id', host_key);

  row.find("td").eq(index++).attr('id', host_key+"_key");
  //custom
  if (host_rows_option["ip"]) row.find("td").eq(index++).attr('id', host_key+"_ip");
  row.find("td").eq(index++).attr('id', host_key+"_vlan");
  // hosts_stats_top
  row.find("td").eq(index++).attr('id', host_key+"_alerts");
  row.find("td").eq(index++).attr('id', host_key+"_name");
  row.find("td").eq(index++).attr('id', host_key+"_since");
    
  row.find("td").eq(index++).attr('id', host_key+"_]] print(criteria) print [[");
  // hosts_stats_bottom
  row.find("td").eq(index++).attr('id', host_key+"_breakdown");
  row.find("td").eq(index++).attr('id', host_key+"_throughput");
  row.find("td").eq(index++).attr('id', host_key+"_traffic");
  
  // console.log(row);
  return row;

}

function row_update(host_key) {
   var hostInfo = hostkey2hostInfo(host_key);
   var vlan = "";
   if (hostInfo[1])
     vlan = "&vlan=" + hostInfo[1];
   var url = "]] print(ntop.getHttpPrefix()) print [[/lua/get_host_data.lua?criteria=]] print(criteria) print [[&host="+hostInfo[0]+vlan;

  $.ajax({
    type: 'GET',
    url: url,
    cache: false,
    success: function(content) {
      var data = jQuery.parseJSON(content);
      // console.log(url);
      // console.log(data);
      $('td[id="'+host_key+'_since"]').html(data.column_since);
      $('td[id="'+host_key+'_breakdown"]').html(data.column_breakdown);
      $('td[id="'+host_key+'_throughput"]').html(data.column_thpt);
      $('td[id="'+host_key+'_traffic"]').html(data.column_traffic);
      $('td[id="'+host_key+'_]] print(criteria) print [["]').html(data.column_]] print(criteria) print [[);
    },
    error: function(content) {
      console.log("error");
    }
  });
}

// Updating function
function host_table_update () {

  var $dt = $("#table-localhosts").data("datatable");
  var rows = $dt.rows;

  for (var row in rows){
    var host_key = rows[row][0].id;
    row_update(host_key);
  }
}

// Refresh Interval (10 sec)
var host_table_interval = window.setInterval(host_table_update, 10000);
// ---------------- End automatic table update code ------------------------



	 host_rows_option["ip"] = true;
	 $("#table-localhosts").datatable({
			title: "Local Hosts",
			url: url_update ,
	 ]]

label = criteria2label(criteria)

print('title: ' .. '\"' .. i18n("local_hosts_stats.looking_glass") .. ': '..label..'",\n')

print ('rowCallback: function ( row ) { return host_table_setID(row, "'..criteria..'"); },')


-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("localhosts_"..criteria) ..'","' .. getDefaultTableSortOrder("localhosts_"..criteria).. '"] ],\n')

print [[    showPagination: true, 
]]

print('buttons: [ ')

print[['<div class="btn-group pull-right">]]
printIpVersionDropdown(base_url, page_params)
print[[</div>']]

print(', \'<div class="btn-group pull-right"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">' .. i18n("local_hosts_stats.criteria") .. '<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" style="min-width: 90px;">')
local criteria_params = table.clone(page_params)

--for id, _ in ipairs(looking_glass_criteria) do
for id, _ in pairsByKeys(looking_glass_criteria, asc) do
   local key = looking_glass_criteria[id][1]
   local label = looking_glass_criteria[id][2]
   criteria_params["criteria"] = key

   if(key ~= criteria) then
	 print('<li><a href="')
	 print(getPageUrl(base_url, criteria_params))
	 print ('">'..label..'</a></li>')
   end
end

   print("</ul></div>'")

   print(" ],")

print [[
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
			     title: "]] print(i18n("ip_address")) print[[",
				 field: "column_ip",
				 sortable: true,
			     css: {
				textAlign: 'left'
			     }
				 },
			{
			     title: "]] print(i18n("vlan")) print [[",
				 field: "column_vlan",
				 sortable: true,
			     css: {
				textAlign: 'center'
			     }
			}, {
			     title: "]] print(i18n("show_alerts.alerts")) print[[",
				 field: "column_alerts",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }

				 },
			     {
			     title: "]] print(i18n("name")) print[[",
				 field: "column_name",
				 sortable: true,
	 	             css: {
			        textAlign: 'left'
			     }

				 },
			     {
			     title: "]] print(i18n("seen_since")) print[[",
				 field: "column_since",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			     }

				 },    {
			     title: "]] print(label) print [[",
				 field: "column_]] print(criteria) print [[",
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
