--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

criteria    = _GET["criteria"]
if(criteria == nil) then criteria = "downloaders" end

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

prefs = ntop.getPrefs()

ifstats = interface.getStats()

print [[
      <hr>
      </ul>

      <div id="table-localhosts"></div>
	 <script>
	 var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_hosts_data.lua?mode=local&criteria=]]
print(criteria)

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

function hostkey2hostInfo(host_key) {
    var info;
    var hostinfo = [];

    host_key = host_key.replace(/____/g, ":");
    host_key = host_key.replace(/___/g, "/");
    host_key = host_key.replace(/__/g, ".");

    info = host_key.split("@");
    return(info);
} 

function row_update(host_key) {
   var hostInfo = hostkey2hostInfo(host_key);
   var url = "]] print(ntop.getHttpPrefix()) print [[/lua/get_host_data.lua?criteria=]] print(criteria) print [[&host="+hostInfo[0]+"&vlan=" + hostInfo[1];

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

print('title: "Looking Glass: '..label..'",\n')

print ('rowCallback: function ( row ) { return host_table_setID(row, "'..criteria..'"); },')


-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("localhosts") ..'","' .. getDefaultTableSortOrder("localhosts").. '"] ],\n')

print [[    showPagination: true, 
]]

print('buttons: [ \'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Criteria<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" style="min-width: 90px;">')

--for id, _ in ipairs(looking_glass_criteria) do
for id, _ in pairsByKeys(looking_glass_criteria, asc) do
   local key = looking_glass_criteria[id][1]
   local label = looking_glass_criteria[id][2]

   if(key ~= criteria) then
	 print('<li><a href="')
	 print (ntop.getHttpPrefix())
	 print ('/lua/local_hosts_stats.lua?criteria='..key..'">'..label..'</a></li>')
   end
end

   print("</ul>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</div>' ],")

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
			     title: "IP Address",
				 field: "column_ip",
				 sortable: true,
	 	             css: {
			        textAlign: 'left'
			     }
				 },
			  ]]


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/hosts_stats_top.inc")

print [[
			     {
			     title: "]] print(label) print [[",
				 field: "column_]] print(criteria) print [[",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			     }
			 },
]]

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/hosts_stats_bottom.inc")



dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
