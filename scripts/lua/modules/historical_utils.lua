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
  <div id="historical-interface-top-talkers-table" class="historical-interface" total_rows=-1 loaded=0> </div>
  <div id="hosts-container"> </div>
  <div id="apps-per-pair-container"> </div>
</div>

<script type="text/javascript">

function hideAll(cla){
  $('.' + cla).hide();
}

function showOne(cla, id){
  $('.' + cla).not('#' + id).hide();
  $('#' + id).show();
}

function hostkey2hostInfo(host_key) {
    var info;
    var hostinfo = [];

    host_key = host_key.replace(/\:/g, "____");
    host_key = host_key.replace(/\//g, "___");
    host_key = host_key.replace(/\./g, "__");

    info = host_key.split("@");
    return(info);
}

var emptyBreadCrumb = function(){
  $('#bc-talkers').empty();
};

var refreshBreadCrumbInterface = function(){
  emptyBreadCrumb();
    $("#bc-talkers").append('<li>Interface ]] print(getInterfaceName(ifid)) print [[</li>');
}

var refreshBreadCrumbHost = function(host){
  emptyBreadCrumb();
    $("#bc-talkers").append('<li><a onclick="populateInterfaceTopTalkersTable();">Interface ]] print(getInterfaceName(ifid)) print [[</a></li>');
    $("#bc-talkers").append('<li>Talkers with host ' + host + ' </li>');
}

var refreshBreadCrumbPairs = function(peer1, peer2){
  emptyBreadCrumb();
    $("#bc-talkers").append('<li><a onclick="populateInterfaceTopTalkersTable();">Interface ]] print(getInterfaceName(ifid)) print [[</a></li>');
    $("#bc-talkers").append('<li><a onclick="populateHostTopTalkersTable(\'' + peer1 + '\');">Talkers with host ' + peer1 + '</a></li>');
    $("#bc-talkers").append('<li>Applications between ' + peer1 + ' and ' + peer2 + ' </li>');
}

var populateInterfaceTopTalkersTable = function(){
  refreshBreadCrumbInterface();
  hideAll("host-talkers");
  hideAll("apps-per-host-pair");
  showOne('historical-interface', 'historical-interface-top-talkers-table');

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
	  {title: "Avg. Flow Duration", field: "column_avg_flow_duration", sortable: true, css: {textAlign:'center'}},
	  {title: "Traffic Volume", field: "column_bytes", sortable: true,css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
    });
  }
};



var populateHostTopTalkersTable = function(host){
  refreshBreadCrumbHost(host);

  var div_id = 'host-' + hostkey2hostInfo(host)[0];
  if ($('#'+div_id).length == 0)  // create the div only if it does not exist
    $('#hosts-container').append('<div class="host-talkers" id="' + div_id + '" total_rows=-1 loaded=0></div>');

  hideAll('historical-interface');
  hideAll('apps-per-host-pair');
  showOne("host-talkers", div_id);

  // load the table only if it is the first time we've been called
  div_id='#'+div_id;
  if ($(div_id).attr("loaded") != 1) {
    $(div_id).attr("loaded", 1);
    $(div_id).attr("host", host);
    $(div_id).datatable({
	title: "",]]
	print("url: '"..ntop.getHttpPrefix().."/lua/get_historical_data.lua?stats_type=top_talkers"..interface_talkers_url_params.."&peer1=' + host ,")
  if preference ~= "" then print ('perPage: '..preference.. ",\n") end
  -- Automatic default sorted. NB: the column must be exists.
  print ('sort: [ ["'..sort_column..'","'..sort_order..'"] ],\n')
	print [[
	post: {totalRows: function(){ return $(div_id).attr("total_rows");} },
	showFilter: true,
	showPagination: true,
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);},
	rowCallback: function(row){
	  var addr_td = $("td:eq(0)", row[0]);
	  var label_td = $("td:eq(1)", row[0]);
	  var addr = addr_td.text();
	  label_td.append('&nbsp;<a onclick="populateAppsPerHostsPairTable(\'' + host +'\',\'' + addr +'\');"><i class="fa fa-exchange" title="Applications between ' + host + ' and ' + addr + '"></i></a>');
	  return row;
	},
	columns:
	[
	  {title: "Address", field: "column_addr", hidden: true},
	  {title: "Host Name", field: "column_label", sortable: true},
	  {title: "Avg. Flow Duration", field: "column_avg_flow_duration", sortable: true, css: {textAlign:'center'}},
	  {title: "Traffic Volume", field: "column_bytes", sortable: true,css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
    });
  }
};

var populateAppsPerHostsPairTable = function(peer1, peer2){
  refreshBreadCrumbPairs(peer1, peer2);

  var kpeer1 = hostkey2hostInfo(peer1)[0];
  var kpeer2 = hostkey2hostInfo(peer2)[0];
  if (kpeer2 > kpeer1){
    var tmp = kpeer1;
    kpeer2 = kpeer1;
    kpeer1 = tmp;
  }
  var div_id = 'pair-' + kpeer1 + "_" + kpeer2;
  if ($('#'+div_id).length == 0)  // create the div only if it does not exist
    $('#apps-per-pair-container').append('<div class="apps-per-host-pair" id="' + div_id + '" total_rows=-1 loaded=0></div>');

  hideAll('historical-interface');
  hideAll('host-talkers');
  showOne('apps-per-host-pair', div_id);
  div_id='#'+div_id;
  // load the table only if it is the first time we've been called
  if ($(div_id).attr("loaded") != 1) {
    $(div_id).attr("loaded", 1);
    $(div_id).attr("peer1", peer1);
    $(div_id).attr("peer2", peer2);
    $(div_id).datatable({
	title: "",]]
	print("url: '"..ntop.getHttpPrefix().."/lua/get_historical_data.lua?stats_type=top_applications"..interface_talkers_url_params.."&peer1=' + peer1 + '&peer2=' + peer2,")
  if preference ~= "" then print ('perPage: '..preference.. ",\n") end
  -- Automatic default sorted. NB: the column must be exists.
  print ('sort: [ ["'..sort_column..'","'..sort_order..'"] ],\n')
	print [[
	post: {totalRows: function(){ return $(div_id).attr("total_rows");} },
	showFilter: true,
	showPagination: true,
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);},
	columns:
	[
	  {title: "Address", field: "column_addr", hidden: true},
	  {title: "Host Name", field: "column_label", sortable: true},
	  {title: "Avg. Flow Duration", field: "column_avg_flow_duration", sortable: true, css: {textAlign:'center'}},
	  {title: "Traffic Volume", field: "column_bytes", sortable: true,css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
    });
  }
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
