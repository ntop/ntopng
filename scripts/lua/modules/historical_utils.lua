require "lua_utils"

function commonJsUtils()
print[[

function hideAll(cla){
  $('.' + cla).hide();
}

function showOne(cla, id){
  $('.' + cla).not('#' + id).hide();
  $('#' + id).show();
}

function hostkey2hostid(host_key) {
    var info;
    var hostinfo = [];

    host_key = host_key.replace(/\:/g, "____");
    host_key = host_key.replace(/\//g, "___");
    host_key = host_key.replace(/\./g, "__");

    info = host_key.split("@");
    return(info);
}

]]
end

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
]] commonJsUtils() print[[

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

  var div_id = 'host-' + hostkey2hostid(host)[0];
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

  var kpeer1 = hostkey2hostid(peer1)[0];
  var kpeer2 = hostkey2hostid(peer2)[0];
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
   local breadcrumb_root = "interface"
   local top_apps_url_params=""
   top_apps_url_params = top_apps_url_params.."&epoch_start="..epoch_begin
   top_apps_url_params = top_apps_url_params.."&epoch_end="..epoch_end
   if host and host ~= "" then
      breadcrumb_root="host"
   end
   local preference = tablePreferences("rows_number",_GET["perPage"])
   local sort_order = getDefaultTableSortOrder("historical_stats_top_applications")
   local sort_column= getDefaultTableSort("historical_stats_top_applications")
   if not sort_column or sort_column == "column_" then sort_column = "column_bytes" end

   print[[
<ol class="breadcrumb" id="bc-apps" style="margin-bottom: 5px;"]] print('root="'..breadcrumb_root..'"') print [[>
</ol>

<div id="historical-apps-container">
  <div id="historical-interface-top-apps-table" class="historical-interface-apps" total_rows=-1 loaded=0> </div>
  <div id="apps-container"> </div>
  <div id="peers-per-host-by-app-container"> </div>
</div>

<script type="text/javascript">
var totalRows = -1;

var emptyAppsBreadCrumb = function(){
  $('#bc-apps').empty();
};

var refreshHostPeersByAppBreadCrumb = function(peer1, proto_id){
  emptyAppsBreadCrumb();
  var root = $("#bc-apps").attr("root");
    var app = $('#historical-interface-top-apps-table').attr("proto");
  if (root === "interface"){
    $("#bc-apps").append('<li><a onclick="populateInterfaceTopAppsTable();">Interface ]] print(getInterfaceName(ifid)) print [[</a></li>');
    $("#bc-apps").append('<li><a onclick="populateAppTopTalkersTable(\'' + proto_id + '\');">Talkers speaking ' + app + '</a></li>');
    $("#bc-apps").append('<li>Talkers speaking ' + app + ' with ' + peer1 + ' </li>');
  } else if (root == "host"){
    var host = $('#historical-interface-top-apps-table').attr("host");
    $("#bc-apps").append('<li><a onclick="populateHostTopAppsTable(host);">Protocols spoken by ' + peer1 + '</a></li>');
    $("#bc-apps").append('<li>Talkers speaking ' + app + ' with ' + peer1 + ' </li>');
  }
}

var populateInterfaceTopAppsTable = function(){
  emptyAppsBreadCrumb();
  $("#bc-apps").append('<li>Interface ]] print(getInterfaceName(ifid)) print [[</li>');

  hideAll("app-talkers");
  hideAll("peers-by-app");
  showOne('historical-interface-apps', 'historical-interface-top-apps-table');

  if ($('#historical-interface-top-apps-table').attr("loaded") != 1) {
    $('#historical-interface-top-apps-table').attr("loaded", 1);
    $('#historical-interface-top-apps-table').datatable({
      title: "",]]
      print("url: '"..ntop.getHttpPrefix().."/lua/get_historical_data.lua?stats_type=top_applications"..top_apps_url_params.."',")
if preference ~= "" then print ('perPage: '..preference.. ",") end
-- Automatic default sorted. NB: the column must be exists.
print ('sort: [ ["'..sort_column..'","'..sort_order..'"] ],')
print [[
      post: {totalRows: function(){ return $('#historical-interface-top-apps-table').attr("total_rows");} },
      showFilter: true,
      showPagination: true,
      tableCallback: function(){$('#historical-interface-top-apps-table').attr("total_rows", this.options.totalRows);},
      rowCallback: function(row){
	var proto_id_td = $("td:eq(0)", row[0]);
	var proto_label_td = $("td:eq(1)", row[0]);
	var proto_id = proto_id_td.text();
	var proto_label = proto_label_td.text();
	proto_label_td.append('&nbsp;<a onclick="$(\'#historical-interface-top-apps-table\').attr(\'proto\', \'' + proto_label + '\');populateAppTopTalkersTable(\'' + proto_id +'\');"><i class="fa fa-pie-chart" title="Get Talkers using this protocol"></i></a>');
	  return row;
	},
      columns:
	[
	  {title: "Protocol id", field: "column_application", hidden: true},
	  {title: "Application", field: "column_label", sortable: false},
	  {title: "Avg. Flow Duration", field: "column_avg_flow_duration", sortable: true, css: {textAlign:'center'}},
	  {title: "Traffic Volume", field: "column_bytes", sortable: true, css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
    });
  }
};


var populateAppTopTalkersTable = function(proto_id){
  emptyAppsBreadCrumb();
  var app = $('#historical-interface-top-apps-table').attr("proto");
  $("#bc-apps").append('<li><a onclick="populateInterfaceTopAppsTable();">Interface ]] print(getInterfaceName(ifid)) print [[</a></li>');
  $("#bc-apps").append('<li>Talkers speaking ' + app + ' </li>');

  var div_id = 'app-' + proto_id;
  if ($('#'+div_id).length == 0)  // create the div only if it does not exist
    $('#apps-container').append('<div class="app-talkers" id="' + div_id + '" total_rows=-1 loaded=0></div>');

  hideAll('historical-interface-apps');
  hideAll('peers-by-app');
  showOne('app-talkers', div_id);

  // load the table only if it is the first time we've been called
  div_id='#'+div_id;
  if ($(div_id).attr("loaded") != 1) {
    $(div_id).attr("loaded", 1);
    $(div_id).attr("l7_proto", proto_id);
    $(div_id).datatable({
	title: "",]]
	print("url: '"..ntop.getHttpPrefix().."/lua/get_historical_data.lua?stats_type=top_talkers"..top_apps_url_params.."&l7_proto_id=' + proto_id ,")
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
	  label_td.append('&nbsp;<a onclick="populatePeersPerHostByApplication(\'' + addr +'\',\'' + proto_id +'\');"><i class="fa fa-exchange" title="Hosts talking ' + proto_id + ' with ' + addr + '"></i></a>');
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


var populatePeersPerHostByApplication = function(host, proto_id){
  refreshHostPeersByAppBreadCrumb(host, proto_id);

  var div_id = 'app-' + proto_id + '-host-' + hostkey2hostid(host)[0];
  if ($('#'+div_id).length == 0)  // create the div only if it does not exist
    $('#peers-per-host-by-app-container').append('<div class="peers-by-app" id="' + div_id + '" total_rows=-1 loaded=0></div>');

  hideAll('historical-interface-apps');
  hideAll('app-talkers');
  showOne('peers-by-app', div_id);

  // load the table only if it is the first time we've been called
  div_id='#'+div_id;
  if ($(div_id).attr("loaded") != 1) {
    $(div_id).attr("loaded", 1);
    $(div_id).attr("l7_proto", proto_id);
    $(div_id).attr("host", host);
    $(div_id).datatable({
	title: "",]]
	print("url: '"..ntop.getHttpPrefix().."/lua/get_historical_data.lua?stats_type=top_talkers"..top_apps_url_params.."&l7_proto_id=' + proto_id + '&peer1=' + host ,")
  if preference ~= "" then print ('perPage: '..preference.. ",\n") end
  -- Automatic default sorted. NB: the column must be exists.
  print ('sort: [ ["'..sort_column..'","'..sort_order..'"] ],\n')
	print [[
	post: {totalRows: function(){ return $(div_id).attr("total_rows");} },
	showFilter: true,
	showPagination: true,
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);},
/*
	rowCallback: function(row){
	  var addr_td = $("td:eq(0)", row[0]);
	  var label_td = $("td:eq(1)", row[0]);
	  var addr = addr_td.text();
	  var label = addr_td.text();
	  label_td.append('&nbsp;<a onclick="populateAppsPerHostsPairTable(\'' + host +'\',\'' + addr +'\');"><i class="fa fa-exchange" title="Hosts talking ' + label + ' with ' + host + '"></i></a>');
	  return row;
	},
*/
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

// this is the entry point for the navigation that starts at hosts
var populateHostTopAppsTable = function(host){
  emptyAppsBreadCrumb();
  $("#bc-apps").append('<li>Protocols spoken by ]] print(ntop.getResolvedAddress(host)) print [[</li>');

  hideAll("app-talkers");
  hideAll("peers-by-app");
  showOne('historical-interface-apps', 'historical-interface-top-apps-table');

  if ($('#historical-interface-top-apps-table').attr("loaded") != 1) {
    $('#historical-interface-top-apps-table').attr("loaded", 1);
    $('#historical-interface-top-apps-table').attr("host", host);
    $('#historical-interface-top-apps-table').datatable({
      title: "",]]
      print("url: '"..ntop.getHttpPrefix().."/lua/get_historical_data.lua?stats_type=top_applications"..top_apps_url_params.."&peer1=' + host,")
if preference ~= "" then print ('perPage: '..preference.. ",") end
-- Automatic default sorted. NB: the column must be exists.
print ('sort: [ ["'..sort_column..'","'..sort_order..'"] ],')
print [[
      post: {totalRows: function(){ return $('#historical-interface-top-apps-table').attr("total_rows");} },
      showFilter: true,
      showPagination: true,
      tableCallback: function(){$('#historical-interface-top-apps-table').attr("total_rows", this.options.totalRows);},
	rowCallback: function(row){
	var proto_id_td = $("td:eq(0)", row[0]);
	var proto_label_td = $("td:eq(1)", row[0]);
	var proto_id = proto_id_td.text();
	var proto_label = proto_label_td.text();
	proto_label_td.append('&nbsp;<a onclick="$(\'#historical-interface-top-apps-table\').attr(\'proto\', \'' + proto_label + '\');populatePeersPerHostByApplication(\'' + host +'\',\'' + proto_id +'\');"><i class="fa fa-exchange" title="Hosts talking ' + proto_id + ' with ' + host + '"></i></a>');
	  return row;
	},
      columns:
	[
	  {title: "Protocol id", field: "column_application", hidden: true},
	  {title: "Application", field: "column_label", sortable: false},
	  {title: "Avg. Flow Duration", field: "column_avg_flow_duration", sortable: true, css: {textAlign:'center'}},
	  {title: "Traffic Volume", field: "column_bytes", sortable: true, css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
    });
  }
};


/*
This event is triggered every time the user focuses the "Protocols" tab.

The Protocols tab can be focused from two different pages:
- from the historical interface chart (e.g., http://localhost:3000/lua/if_stats.lua?if_name=en4&page=historical), and;
- from the historical host chart (e.g., http://localhost:3000/lua/host_details.lua?ifname=0&host=192.168.2.130&page=historical)

Depending on the page that triggers the event, there is a slightly different behavior
of the ajax navigation.

Historical interface chart
==========================
The navigation follows this path:

0. Interface en4 (populateInterfaceTopAppsTable)
1. Talkers speaking SSL (populateAppTopTalkersTable)
2. Talkers speaking SSL with 192.168.x.x (populatePeersPerHostByApplication)

The entry point is at 0. and then it is possible to go back and forth.

Historical host chart
========================
The navigation follows this path:
0. Protocols spoken by 192.168.y.y (populateHostTopAppsTable)
1. Talkers speaking SSL with 192.168.y.y (populatePeersPerHostByApplication)


Code Re-Use
========================
Interface function 2. and host function 1. are the same function that
is used in two different contex. There is a breadcrumb function that
adapts the breadcrumb depending on the page.

*/
$('a[href="#historical-top-apps"]').on('shown.bs.tab', function (e) {
  if ($('a[href="#historical-top-apps"]').attr("loaded") == 1){
    // do nothing if the tabs have already been computed and populated
    return;
  }

  var target = $(e.target).attr("href"); // activated tab

  var root = $("#bc-apps").attr("root");
  if (root === "interface"){
    populateInterfaceTopAppsTable();
  } else if (root === "host"){
    populateHostTopAppsTable(']] print(host) print[[');
  }

  // Finally set a loaded flag for the current tab
  $('a[href="#historical-top-apps"]').attr("loaded", 1);
});

</script>

]]
end
