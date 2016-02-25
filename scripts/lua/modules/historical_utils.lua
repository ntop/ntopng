require "lua_utils"

local pcap_status_url = ntop.getHttpPrefix().."/lua/get_nbox_data.lua?action=status"
local pcap_request_url = ntop.getHttpPrefix().."/lua/get_nbox_data.lua?action=schedule"
local favourites_url = ntop.getHttpPrefix().."/lua/get_historical_favourites.lua"

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

function buildPcapRequestData(source_div_id){
  var epoch_begin = $('#' + source_div_id).attr("epoch_begin");
  var epoch_end = $('#' + source_div_id).attr("epoch_end");
  var ifname = $('#' + source_div_id).attr("ifname");
  var host = $('#' + source_div_id).attr("host");
  var peer = $('#' + source_div_id).attr("peer");
  var res = {epoch_begin: epoch_begin, epoch_end: epoch_end};
  if (typeof ifname != 'undefined') res.ifname = ifname;
  if (typeof host != 'undefined') res.host = host;
  if (typeof peer != 'undefined') res.peer = peer;
  return res;
}

function addToFavourites(source_div_id, stats_type, favourite_type, select_id){
  $.ajax({type:'GET',url:"]]print(favourites_url)print[[?action=set&stats_type=" + stats_type + "&favourite_type=" + favourite_type,
    data:buildPcapRequestData(source_div_id),
    success:function(data){
      data=jQuery.parseJSON(data);
      populateFavourites(source_div_id, stats_type, favourite_type, select_id);
     },
     error:function(){
       perror('An HTTP error occurred.');
     }
  });
}

function removeFromFavourites(source_div_id, stats_type, favourite_type, select_id){
  $.ajax({type:'GET',url:"]]print(favourites_url)print[[?action=del&stats_type=" + stats_type + "&favourite_type=" + favourite_type,
    data:buildPcapRequestData(source_div_id),
    success:function(data){
      data=jQuery.parseJSON(data);
      populateFavourites(source_div_id, stats_type, favourite_type, select_id);
     },
     error:function(){
       perror('An HTTP error occurred.');
     }
  });
}


function populateFavourites(source_div_id, stats_type, favourite_type, select_id){
  $('#'+select_id).find('option').remove();
  $.ajax({type:'GET',url:"]]print(favourites_url)print[[?action=get&stats_type=" + stats_type + "&favourite_type=" + favourite_type,
    data:buildPcapRequestData(source_div_id),
    success:function(data){
      data=jQuery.parseJSON(data);
      $.each(data, function(hosts, hostnames){
        if (hosts.split(',').length == 1){
          var option_data = '<option value="' + hosts + '"> ' + hostnames + '</option>';
        }else if (hosts.split(',').length == 2) {
          var option_data = '<option value="' + hosts + '"> ' + hostnames.split(",").join(" <---> ") + '</option>';
        }
        $(option_data).appendTo('#'+select_id);
      });
     },
     error:function(){
       perror('An HTTP error occurred.');
     }
  });
  $('#' + select_id).change(function() {
    var host = $(this).find(':selected').val();
    host = host.split(',');
    if (host.length == 1){
      populateHostTopTalkersTable(host[0]);
    } else if (host.length == 2){
      populateAppsPerHostsPairTable(host[0], host[1]);
    }
  });
}

]]
end


function historicalPcapButton(button_id, pcap_request_data_container_div_id)
  if not ntop.isPro() then return end -- integrate only in the Pro version
  print("<br><br>")

  if false then
     a = 1
  else
	  print [[
  <div class="panel-body">
     <div class="row">
	  <div class='col-md-10' id="info_]] print(button_id) print[[">
	  Request a pcap containing the recorded traffic matching search criteria. Requests will be queued and pcaps will be available for download once generated.
	  </div>

	  <div class='col-md-2'>
	    <form name="request_pcap_form">
	      <input type="submit" value="Request pcap" class="btn btn-default" id="]] print(button_id) print[[">
	    </form>
	    <br>
	    <span id="download_msg_]] print(button_id) print[["></span>
	  </div>
	  <script type="text/javascript">
]]


  if ntop.getCache("ntopng.prefs.nbox_integration") ~= "1" or not haveAdminPrivileges() then
     print[[
     $('#]] print(button_id) print[[').prop('disabled', true);
     $('#info_]] print(button_id) print[[').html(
	 "<small>In order to be able to request pcaps containing recorded traffic for the selected criteria, admin privileges are required and nBox integration must be enabled" +
	 " via ntopng <a href=\"]] print(ntop.getHttpPrefix()) print[[/lua/admin/prefs.lua\"><i class=\"fa fa-flask\"></i> Preferences</a>.</small>");
     ]]
  end


print[[
	  $('#]] print(button_id) print[[').click(function (event)
	  {
	     event.preventDefault();
	     var perror = function(msg){
		  alert("Request failed: " + msg);
		  $('#download_msg_]] print(button_id) print[[').html("Request failed.<br>");
		  $('#]] print(button_id) print[[').prop('value', 'Request pcap [retry]')};
	     $.ajax({type: 'GET', url: "]] print(pcap_request_url) print [[",
		data: buildPcapRequestData(']] print(pcap_request_data_container_div_id) print[['),
		success: function(data) {
		   data = jQuery.parseJSON(data);
		   if (data["result"] === "KO"){
		    perror(data["description"]);
		  } else if (data["result"] == "OK"){
		    $('#download_msg_]] print(button_id) print[[').show().fadeOut(4000).html('OK, request sent.');
		  } else { alert('Unknown response.'); }
		},
		error: function() {
		   perror('An HTTP error occurred.');
		}
	     });

	   });
	  </script>

  </div>
  </div>
  <br>
  ]]
  end
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


<!-- attach some status information to the historical container -->
<div id="historical-container" epoch_begin="" epoch_end="" ifname="" host="" peer="">


  <div class="row">
    <div class="form-group">
    <div class='col-md-3'>
      <form name="top_talkers_faves">
        <b>Favorite Talkers</b>
        <select name="top_talkers_talker" id="top_talkers_talker" class="form-control">
        </select>
    </div>
    <div class='col-md-6'>
        <b>Favorite applications between pairs of talkers</b>
        <select name="top_talkers_host_pairs" id="top_talkers_host_pairs" class="form-control">
        </select>
      </form>
    </div>
    </div>
  </div>

  <div id="historical-interface-top-talkers-table" class="historical-interface" total_rows=-1 loaded=0> </div>
  <div id="hosts-container"> </div>
  <div id="apps-per-pair-container"> </div>
</div>

]] historicalPcapButton("pcap-button-top-talkers", "historical-container") print [[

<script type="text/javascript">
]] commonJsUtils() print[[

var emptyBreadCrumb = function(){
  $('#bc-talkers').empty();
};

var refreshBreadCrumbInterface = function(){
  emptyBreadCrumb();
  $("#bc-talkers").append('<li>Interface ]] print(getInterfaceName(ifid)) print [[</li>');
  $('#historical-container').attr("ifname", "]] print(getInterfaceName(ifid)) print [[");
  $('#historical-container').removeAttr("host");
  $('#historical-container').removeAttr("peer");
}

var refreshBreadCrumbHost = function(host){
  emptyBreadCrumb();
  $("#bc-talkers").append('<li><a onclick="populateInterfaceTopTalkersTable();">Interface ]] print(getInterfaceName(ifid)) print [[</a></li>');

  // append a pair of li to the breadcrumb: the first is shown if the host has not been added to the favourites,
  // the second is shown if it has been added...

  // first pair: shown if the host has not been favourited
  $("#bc-talkers").append('<li class="bc-item-add">Talkers with ' + host + ' <a onclick="addToFavourites(\'historical-container\', \'top_talkers\', \'talker\', \'top_talkers_talker\');"><i class="fa fa-heart-o" title="Add to Favorites"></i></a> </li>');

  // second pair: shown if the host has been favourited
  $("#bc-talkers").append('<li class="bc-item-remove">Talkers with ' + host + ' <a onclick="removeFromFavourites(\'historical-container\', \'top_talkers\', \'talker\', \'top_talkers_talker\');"><i class="fa fa-heart" title="Remove from Favorites"></i></a> </li>');

  // here we decide which li has to be shown, depending on the elements contained in the drop-down menu
  if($('#top_talkers_talker > option[value=\'' + host + '\']').length == 0){
    $('.bc-item-add').show();
    $('.bc-item-remove').hide();
  } else {
    // the host has already been added to favourites
    $('.bc-item-remove').show();
    $('.bc-item-add').hide();
  }

  // we also add a function to toggle the currently active li
  $('.bc-item-add, .bc-item-remove').on('click', function(){
    $('.bc-item-add, .bc-item-remove').toggle();
  });

  // finally we add some status variables to the historical container
  $('#historical-container').attr("host", host);
  $('#historical-container').removeAttr("peer");
}

var refreshBreadCrumbPairs = function(peer1, peer2){
  emptyBreadCrumb();
  $("#bc-talkers").append('<li><a onclick="populateInterfaceTopTalkersTable();">Interface ]] print(getInterfaceName(ifid)) print [[</a></li>');
  $("#bc-talkers").append('<li><a onclick="populateHostTopTalkersTable(\'' + peer1 + '\');">Talkers with ' + peer1 + '</a></li>');

  // here we append to li: one will be shown if the pair of peers is favourited, the other is shown in the opposite case 

  // first li: shown if the pair has been favourited
  $("#bc-talkers").append('<li class="bc-item-add">Applications between ' + peer1 + ' and ' + peer2 + ' <a onclick="addToFavourites(\'historical-container\', \'top_talkers\', \'apps_per_host_pair\', \'top_talkers_host_pairs\');"><i class="fa fa-heart-o" title="Add to Favorites"></i></a></li>');
  $('#historical-container').attr("peer", peer2);

  // second li: shown if the pair has not been favorited
  $("#bc-talkers").append('<li class="bc-item-remove">Applications between ' + peer1 + ' and ' + peer2 + ' <a onclick="removeFromFavourites(\'historical-container\', \'top_talkers\', \'apps_per_host_pair\', \'top_talkers_host_pairs\');"><i class="fa fa-heart" title="Remove from Favorites"></i></a></li>');
  $('#historical-container').attr("peer", peer2);

  // check which li has to be shown, depending on the content of a dropdown menu
  if($('#top_talkers_host_pairs > option[value=\'' + peer1 + ',' + peer2 + '\']').length == 0){
    $('.bc-item-add').show();
    $('.bc-item-remove').hide();
  } else {
    // the host has already been added to favourites
    $('.bc-item-remove').show();
    $('.bc-item-add').hide();
  }

  // we also add a function to toggle the currently active li
  $('.bc-item-add, .bc-item-remove').on('click', function(){
    $('.bc-item-add, .bc-item-remove').toggle();
  });
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
	  var addr_td = $("td:eq(1)", row[0]);
	  var label_td = $("td:eq(0)", row[0]);
	  var addr = addr_td.text();
	  label_td.append('&nbsp;<a onclick="populateHostTopTalkersTable(\'' + addr +'\');"><i class="fa fa-pie-chart" title="Talkers with this host"></i></a>');
	  return row;
	},
	columns:
	[
	  {title: "Host Name", field: "column_label", sortable: true},
	  {title: "IP Address", field: "column_addr", hidden: false, sortable: true},
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
	  var addr_td = $("td:eq(1)", row[0]);
	  var label_td = $("td:eq(0)", row[0]);
	  var addr = addr_td.text();
	  label_td.append('&nbsp;<a onclick="populateAppsPerHostsPairTable(\'' + host +'\',\'' + addr +'\');"><i class="fa fa-exchange" title="Applications between ' + host + ' and ' + addr + '"></i></a>');
	  return row;
	},
	columns:
	[
	  {title: "Host Name", field: "column_label", sortable: true},
	  {title: "IP Address", field: "column_addr", hidden: false, sortable: true},
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
	  {title: "Host Name", field: "column_label", sortable: true},
	  {title: "Address", field: "column_addr", hidden: false, sortable: true},
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

  // populate favourites dropdowns
  populateFavourites('historical-container', 'top_talkers', 'talker', 'top_talkers_talker');
  populateFavourites('historical-container', 'top_talkers', 'apps_per_host_pair', 'top_talkers_host_pairs');

  var root = $("#bc-talkers").attr("root");
  if (root === "interface"){
    populateInterfaceTopTalkersTable();
  } else if (root === "host"){
    populateHostTopTalkersTable(']] print(host) print[[');
  }

  // set epoch_begin and epoch_end status information to the container div
  $('#historical-container').attr("epoch_begin", "]] print(tostring(epoch_begin)) print[[");
  $('#historical-container').attr("epoch_end", "]] print(tostring(epoch_end)) print[[");
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

]] historicalPcapButton("pcap-button-top-protocols", "historical-apps-container") print [[

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
    $("#bc-apps").append('<li><a onclick="populateAppTopTalkersTable(\'' + proto_id + '\');">' + app + ' talkers</a></li>');
    $("#bc-apps").append('<li> ' + app + ' talkers with ' + peer1 + ' </li>');
  } else if (root == "host"){
    var host = $('#historical-interface-top-apps-table').attr("host");
    $("#bc-apps").append('<li><a onclick="populateHostTopAppsTable(\'' + host + '\');">Protocols spoken by ' + host + '</a></li>');
    $("#bc-apps").append('<li> ' + app + ' talkers with ' + host + ' </li>');
  }
}

var populateInterfaceTopAppsTable = function(){
  emptyAppsBreadCrumb();
  $('#historical-apps-container').removeAttr("host");
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
	  {title: "Traffic Volume", field: "column_bytes", sortable: true, css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
    });
  }
};


var populateAppTopTalkersTable = function(proto_id){
  emptyAppsBreadCrumb();
  $('#historical-apps-container').removeAttr("host");
  var app = $('#historical-interface-top-apps-table').attr("proto");
  $("#bc-apps").append('<li><a onclick="populateInterfaceTopAppsTable();">Interface ]] print(getInterfaceName(ifid)) print [[</a></li>');
  $("#bc-apps").append('<li> ' + app + ' talkers</li>');

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
	  var addr_td = $("td:eq(1)", row[0]);
	  var label_td = $("td:eq(0)", row[0]);
	  var addr = addr_td.text();
	  label_td.append('&nbsp;<a onclick="populatePeersPerHostByApplication(\'' + addr +'\',\'' + proto_id +'\');"><i class="fa fa-exchange" title="' + app + ' talkers with ' + addr + '"></i></a>');
	  return row;
	},
	columns:
	[
	  {title: "Host Name", field: "column_label", sortable: true},
	  {title: "Address", field: "column_addr", hidden: false, sortable: true},
	  {title: "Traffic Volume", field: "column_bytes", sortable: true,css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
    });
  }
};


var populatePeersPerHostByApplication = function(host, proto_id){
  refreshHostPeersByAppBreadCrumb(host, proto_id);
  $('#historical-apps-container').attr("host", host);

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
	  var addr_td = $("td:eq(1)", row[0]);
	  var label_td = $("td:eq(0)", row[0]);
	  var addr = addr_td.text();
	  var label = addr_td.text();
	  label_td.append('&nbsp;<a onclick="populateAppsPerHostsPairTable(\'' + host +'\',\'' + addr +'\');"><i class="fa fa-exchange" title="Hosts talking ' + label + ' with ' + host + '"></i></a>');
	  return row;
	},
*/
	columns:
	[
	  {title: "Host Name", field: "column_label", sortable: true},
	  {title: "Address", field: "column_addr", hidden: false, sortable: true},
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
  $('#historical-apps-container').attr("host", host);
  $("#bc-apps").append('<li>Protocols spoken by ' + host +'</li>');

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

  // set epoch_begin and epoch_end status information to the container div
  $('#historical-apps-container').attr("epoch_begin", "]] print(tostring(epoch_begin)) print[[");
  $('#historical-apps-container').attr("epoch_end", "]] print(tostring(epoch_end)) print[[");
  // Finally set a loaded flag for the current tab
  $('a[href="#historical-top-apps"]').attr("loaded", 1);
});

</script>

]]
end


function historicalPcapsTable()
print[[
<div id="table-pcaps"></div>
<script>

var populatePcapsTable = function(){
  $("#table-pcaps").datatable({
    title: "Pcaps",
    url: "]] print (ntop.getHttpPrefix()) print [[/lua/get_nbox_data.lua?action=status" ,
    title: "Pcap Requests and Statuses",
]]

-- Set the preference table
preference = tablePreferences("rows_number","5")
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("pcaps") ..'","' .. getDefaultTableSortOrder("pcaps").. '"] ],')

print [[
	       showPagination: true,
		columns: [
			 {
			     title: "Task Id",
				 field: "column_task_id",
				 sortable: true,
			     css: {
				textAlign: 'left'
			     }
				 },
			     {
			     title: "Status",
				 field: "column_status",
				 sortable: true,
			     css: {
				textAlign: 'center'
			     }

				 },
			     {
			     title: "Actions",
				 field: "column_actions",
				 sortable: true,
			     css: {
				textAlign: 'center'
			     }
				 }
			     ]
	       });

};

$('a[href="#historical-pcaps"]').on('shown.bs.tab', function (e) {
  if ($('a[href="#historical-pcaps"]').attr("loaded") == 1){
    // do nothing if the tabs have already been computed and populated
    return;
  }

  var target = $(e.target).attr("href"); // activated tab
  populatePcapsTable();
  // Finally set a loaded flag for the current tab
  $('a[href="#historical-pcaps"]').attr("loaded", 1);
});

</script>
]]
end
