require "lua_utils"

function historicalTopTalkersTable(ifid, epoch_begin, epoch_end, host)
   local breadcrumb_root = "interface"
   local host_talkers_url_params = ""
   local interface_talkers_url_params = ""
   interface_talkers_url_params = interface_talkers_url_params.."&epoch_start="..epoch_begin
   interface_talkers_url_params = interface_talkers_url_params.."&epoch_end="..epoch_end
   if host and host ~= "" then
      host_talkers_url_params = interface_talkers_url_params.."&peer1="..host
      breadcrumb_root = "host"
   else
      host_talkers_url_params = interface_talkers_url_params
   end
   local preference = tablePreferences("rows_number",_GET["perPage"])
   local sort_order = getDefaultTableSortOrder("historical_stats_top_talkers")
   local sort_column= getDefaultTableSort("historical_stats_top_talkers")
   if not sort_column or sort_column == "column_" then sort_column = "column_bytes" end
   print[[

<ol class="breadcrumb" id="bc-talkers" style="margin-bottom: 5px;"]] print('root="'..breadcrumb_root..'"') print [[>
</ol>

<div id="historical-container">
  <div id="historical-interface-top-talkers-table" total_rows=-1 loaded=0> </div>
  <div id="historical-host-top-talkers-table" total_rows=-1 loaded=0> </div>
  <div id="historical-apps-per-pair-of-hosts-table" total_rows=-1 loaded=0> </div>
</div>

<script type="text/javascript">

var emptyBreadCrumb = function(){
  $('#bc-talkers').empty();
};

var updateBreadCrumb = function(host){
  emptyBreadCrumb();
    $("#bc-talkers").append('<li>Interface ]] print(getInterfaceName(ifid)) print [[</li>');
  if (host) {
    $("#bc-talkers").append('<li>Talkers with host ' + host + ' </li>');
  }
};

// populates the breadcrump according to the current level of depth
/*
var updateBreadCrumb = function(){
  var root = $("#bc-talkers").attr("root");
  if (root === "interface"){
    $("#bc-talkers").append('<li>Interface ]] print(getInterfaceName(ifid)) print [[</li>');
  } else if (root === "host"){
    //$("#bc-talkers").append('<li><a onclick="populateInterfaceTopTalkersTable();">Interface ]] print(getInterfaceName(ifid)) print [[</a></li>');
    $("#bc-talkers").append('<li>Interface ]] print(getInterfaceName(ifid)) print [[</li>');
    $("#bc-talkers").append('<li>Talkers with host ]] print(host) print [[</li>');
 }
};
*/

var populateInterfaceTopTalkersTable = function(){
  $('#historical-host-top-talkers-table').hide();
  $('#historical-interface-top-talkers-table').show();
  if ($('#historical-interface-top-talkers-table').attr("loaded") != 1) {
    $('#historical-interface-top-talkers-table').attr("loaded", 1);
    $('#historical-interface-top-talkers-table').datatable({
	title: "",]]
	print("url: '"..ntop.getHttpPrefix().."/lua/get_historical_data.lua?stats_type=top_talkers"..interface_talkers_url_params.."',")
  if preference ~= "" then print ('perPage: '..preference.. ",\n") end
  -- Automatic default sorted. NB: the column must be exists.
  print ('sort: [ ["'..sort_column..'","'..sort_order..'"] ],\n')
	print [[
	post: {totalRows: function(){ return $('#historical-interface-top-talkers-table').attr("total_rows");} },
	showFilter: true,
	showPagination: true,
	tableCallback: function(){$('#historical-interface-top-talkers-table').attr("total_rows", this.options.totalRows);},
	rowCallback: function(row){
	  var addr_td = $("td:eq(0)", row[0]);
	  var label_td = $("td:eq(1)", row[0]);
	  var addr = addr_td.text();
	  label_td.append('&nbsp;<a onclick="populateHostTopTalkersTable(\'' + addr +'\');"><i class="fa fa-pie-chart" title="Get Talkers with this host"></i></a>');
	  return row;
	},
	columns:
	[
	  {title: "Address", field: "column_addr", hidden: true},
	  {title: "Host Name", field: "column_label", sortable: true},
	  {title: "Traffic Volume", field: "column_bytes", sortable: true,css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
    });
  }
  updateBreadCrumb();
};

var populateHostTopTalkersTable = function(host){
  $('#historical-interface-top-talkers-table').hide();
  $('#historical-host-top-talkers-table').show();
  // load the table only if it is the first time we've been called
  if ($('#historical-host-top-talkers-table').attr("loaded") != 1 || $('#historical-host-top-talkers-table').attr("host") != host) {
    $('#historical-host-top-talkers-table').attr("loaded", 1);
    $('#historical-host-top-talkers-table').attr("host", host);
    $('#historical-host-top-talkers-table').datatable({
	title: "",]]
	print("url: '"..ntop.getHttpPrefix().."/lua/get_historical_data.lua?stats_type=top_talkers"..interface_talkers_url_params.."&peer1=' + host ,")
  if preference ~= "" then print ('perPage: '..preference.. ",\n") end
  -- Automatic default sorted. NB: the column must be exists.
  print ('sort: [ ["'..sort_column..'","'..sort_order..'"] ],\n')
	print [[
	post: {totalRows: function(){ return $('#historical-host-top-talkers-table').attr("total_rows");} },
	showFilter: true,
	showPagination: true,
	tableCallback: function(){$('#historical-host-top-talkers-table').attr("total_rows", this.options.totalRows);},
	columns:
	[
	  {title: "Address", field: "column_addr", hidden: true},
	  {title: "Host Name", field: "column_label", sortable: true},
	  {title: "Traffic Volume", field: "column_bytes", sortable: true,css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
    });
  }
  updateBreadCrumb(host);
};

// executes when the talkers tab is focused
$('a[href="#historical-top-talkers"]').on('shown.bs.tab', function (e) {
  if ($('a[href="#historical-top-talkers"]').attr("loaded") == 1){
    // do nothing if the tabs have already been computed and populated
    return;
  }

  var target = $(e.target).attr("href"); // activated tab

  var root = $("#bc-talkers").attr("root");
  if (root === "interface"){
    populateInterfaceTopTalkersTable();
  } else if (root === "host"){
    populateHostTopTalkersTable(']] print(host) print[[');
  }

  // Finally set a loaded flag for the current tab
  $('a[href="#historical-top-talkers"]').attr("loaded", 1);
});
</script>

]]
end

function historicalTopApplicationsTable(ifid, epoch_begin, epoch_end, host)
   local top_apps_url_params=""
   top_apps_url_params = top_apps_url_params.."&epoch_start="..epoch_begin
   top_apps_url_params = top_apps_url_params.."&epoch_end="..epoch_end
   if host and host ~= "" then
      top_apps_url_params = top_apps_url_params.."&peer1="..host
   end
   local preference = tablePreferences("rows_number",_GET["perPage"])
   local sort_order = getDefaultTableSortOrder("historical_stats_top_applications")
   local sort_column= getDefaultTableSort("historical_stats_top_applications")
   if not sort_column or sort_column == "column_" then sort_column = "column_tot_bytes" end

   print[[
<div id="historical-top-applications-table" total_rows=-1>

</div>


<script type="text/javascript">
var totalRows = -1;

$('a[href="#historical-top-apps"]').on('shown.bs.tab', function (e) {
  var target = $(e.target).attr("href"); // activated tab
  $('#historical-top-applications-table').datatable({
      title: "",]]
      print("url: '"..ntop.getHttpPrefix().."/lua/get_historical_data.lua?stats_type=top_applications"..top_apps_url_params.."',")
if preference ~= "" then print ('perPage: '..preference.. ",") end
-- Automatic default sorted. NB: the column must be exists.
print ('sort: [ ["'..sort_column..'","'..sort_order..'"] ],')
print [[
      post: {totalRows: function(){ return $('#historical-top-applications-table').attr("total_rows");} },
      showFilter: true,
      showPagination: true,
      tableCallback: function(){$('#historical-top-applications-table').attr("total_rows", this.options.totalRows);},
      columns:
	[
	  {title: "Protocol id", field: "column_application", hidden: true},
	  {title: "Application", field: "column_label", sortable: false},
	  {title: "Traffic Volume", field: "column_bytes", sortable: true, css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
  });

});
</script>

]]
end
