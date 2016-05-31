require "lua_utils"

local pcap_status_url = ntop.getHttpPrefix().."/lua/get_nbox_data.lua?action=status"
local pcap_request_url = ntop.getHttpPrefix().."/lua/get_nbox_data.lua?action=schedule"
local favourites_url = ntop.getHttpPrefix().."/lua/get_historical_favourites.lua"
local flows_download_url = ntop.getHttpPrefix().."/lua/get_db_flows.lua"

function commonJsUtils()
print[[

function hideAll(cla){
  $('.' + cla).hide();
}

function showOne(cla, id){
  $('.' + cla).not('#' + id).hide();
  $('#' + id).show();
}

function disableAllDropdowns(){
  $("select").each(function() {
    $(this).prop("disabled", true);
  });
}

function enableAllDropdowns(){
  $("select").each(function() {
    $(this).prop("disabled", false);
  });
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

function buildRequestData(source_div_id){
  var epoch_begin = $('#' + source_div_id).attr("epoch_begin");
  var epoch_end = $('#' + source_div_id).attr("epoch_end");
  var ifname = $('#' + source_div_id).attr("ifname");
  var ifId = "]] print(tostring(ifId)) print [[";
  var host = $('#' + source_div_id).attr("host");
  var peer = $('#' + source_div_id).attr("peer");
  var l7_proto_id = $('#' + source_div_id).attr("l7_proto_id");
  var l4_proto_id = $('#' + source_div_id).attr("l4_proto_id");
  var port = $('#' + source_div_id).attr("port");
  var res = {epoch_begin: epoch_begin, epoch_end: epoch_end};
  if (typeof ifname != 'undefined') res.ifname = ifname;
  if (typeof ifId != 'undefined') res.ifId = ifId;
  if (typeof host != 'undefined') res.host = host;
  if (typeof peer != 'undefined') res.peer = peer;
  if (typeof port != 'undefined') res.port = port;
  if (typeof l7_proto_id != 'undefined'){
    res.l7_proto_id = l7_proto_id;
    res.l7proto = l7_proto_id;
  };
  if (typeof l4_proto_id != 'undefined'){
    res.l4_proto_id = l4_proto_id;
    res.l4proto = l4_proto_id;
  };
  return res;
}

function addToFavourites(source_div_id, stats_type, favourite_type, select_id){
  $.ajax({type:'GET',url:"]]print(favourites_url)print[[?action=set&stats_type=" + stats_type + "&favourite_type=" + favourite_type,
    data:buildRequestData(source_div_id),
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
    data:buildRequestData(source_div_id),
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
  var multival_separator = " <---> ";

  $('#'+select_id).find('option').remove();
  $.ajax({type:'GET',url:"]]print(favourites_url)print[[?action=get&stats_type=" + stats_type + "&favourite_type=" + favourite_type,
    data:buildRequestData(source_div_id),
    success:function(data){
      data=jQuery.parseJSON(data);
      // if no favourite has been added, we hide the div that contains the dropdown
      if(Object.keys(data).length == 0){
	$('#' + select_id).parent().closest('div').hide();

      // alternatively, we ajax data to the dropdown menu
      } else {
	$('#' + select_id).parent().closest('div').show();
	$('<option value="noaction"> Select saved...</option>').appendTo('#' + select_id);
	$.each(data, function(key, value){
	  if (key.split(',').length == 1){
	    var option_data = '<option value="' + key + '"> ' + value + '</option>';
	  }else if (key.split(',').length == 2) {
	    var option_data = '<option value="' + key + '"> ' + value.split(",").join(multival_separator) + '</option>';
	  }
	  $(option_data).appendTo('#'+select_id);
	});
	$('#' + select_id).change(function() {
	  if (stats_type == "top_talkers"){
	    var host = $(this).find(':selected').val();
	    if (host == "noaction"){
	      return;
	    }
	    host = host.split(',');
	    if (host.length == 1){
	      populateHostTopTalkersTable(host[0]);
	    } else if (host.length == 2){
	      populateAppsPerHostsPairTable(host[0], host[1]);
	    }
	  } else if (stats_type == "top_applications"){
	    var value = $(this).find(':selected').val();
	    var human_readable = $(this).find(':selected').text();

	    if (value == "noaction"){
	      return;
	    }
	    value = value.split(',');
	    if (value.length == 1){
	      // only the l7 protocol id in value[0]
	      var proto = human_readable;
	      $('#historical-apps-container').attr("l7_proto", proto);
	      $('#historical-apps-container').attr("l7_proto_id", value[0]);
	      populateAppTopTalkersTable(value[0]);
	    } else if (value.length == 2){
	      // both the l7 protocol id and the peer have been selected
	      var proto = human_readable.split(multival_separator)[0];
	      var addr = human_readable.split(multival_separator)[1];
	      $('#historical-apps-container').attr("l7_proto", proto);
	      $('#historical-apps-container').attr("l7_proto_id", value[0]);
	      $('#historical-apps-container').attr("host", addr);
	      populatePeersPerHostByApplication(value[1], value[0]);
	    }
	  }
	  // finally, put the dropdown in the default position
	  // after waiting a couple of seconds to give the user the feeling its
	  // choice has had an impact
	  setTimeout(function(){
	    $('#'+select_id + '>option:eq(0)').prop("selected", true);
	  }, 2000);
	});
      }
     },
     error:function(){
       perror('An HTTP error occurred.');
     }
  });

}


function removeAllFavourites(stats_type, favourite_type, select_id){
  $.ajax({type:'GET',url:"]]print(favourites_url)print[[?action=del_all&stats_type=" + stats_type + "&favourite_type=" + favourite_type,
    success:function(data){
      // remove all the exising options...
      $('#'+select_id).find('option').remove();

      // and hide the container div...
      $('#' + select_id).parent().closest('div').hide();

     // refresh the right breacrumb
     if (stats_type == "top_talkers"){
       if(favourite_type == "talker"){
	 $('.bc-item-add.talker').show();
	 $('.bc-item-remove.talker').hide();
       } else if (favourite_type == "apps_per_host_pair"){
	 $('.bc-item-add.host-pair').show();
	 $('.bc-item-remove.host-pair').hide();
       }
     } else if (stats_type == "top_applications"){
       if(favourite_type == "host_peers_by_app"){
	 $('.bc-app-item-add.host-peers-by-app').show();
	 $('.bc-app-item-remove.host-peers-by-app').hide();
       } else if (favourite_type == "app"){
	 $('.bc-app-item-add.app').show();
	 $('.bc-app-item-remove.app').hide();
       }
     }
     },
     error:function(){
       perror('An HTTP error occurred.');
     }
  });
}

]]
end


function historicalDownloadButtonsBar(button_id, pcap_request_data_container_div_id, ipv4_enabled, ipv6_enabled)
   if not ntop.isPro() then return end -- integrate only in the Pro version

   -- ipv4 and ipv6 download buttons can be either disabled from lua using the parameters above.
   -- If download buttons are not disabled explicitly from Lua, then a javascript check will disable
   -- them at display time to make sure no button is shown when the number of flows equals to zero
   local style_ipv4 = ""
   local style_ipv6 = ""
   if ipv4_enabled == false or tonumber(ipv4_enabled) == 0 then
      style_ipv4 = "display:none;"
   end
   if ipv6_enabled == false or tonumber(ipv6_enabled) == 0 then
      style_ipv6 = "display:none;"
   end

	  print [[

     <div class="row">

       <div class='col-md-3'>
	 Download flows:
          <a class="btn btn-default btn-sm" href="#" role="button" id="download_flows_v4_]] print(button_id) print[[" style="]] print(style_ipv4) print[[">IPv4</a>&nbsp;
          <a class="btn btn-default btn-sm" href="#" role="button" id="download_flows_v6_]] print(button_id) print[[" style="]] print(style_ipv6) print[[">IPv6</a>
       </div>

       <div class='col-md-2'>
	 Extract pcap: <a class="btn btn-default btn-sm" href="#" role="button" id="extract_pcap_]] print(button_id) print[["><i class="fa fa-download fa-lg"></i></a><br><span id="pcap_download_msg_]] print(button_id) print[["></span>
       </div>

       <div class='col-md-7'>
       </div>
     </div>

     <div class="row">
     <div class='col-md-3'><div></div></div>
     <div class='col-md-2'>

     </div>
     <div class='col-md-7'></div>
     </div>



  <script type="text/javascript">
]]



print[[
  if($('#tab-ipv4').length > 0){
    $('#download_flows_v4_]] print(button_id) print[[').click(function (event){
      window.location.assign("]] print(flows_download_url) print [[?version=4&format=txt&" + $.param(buildRequestData(']] print(pcap_request_data_container_div_id) print[[')));
      return false;
    });
  } else {
    $('#download_flows_v4_]] print(button_id) print[[').attr("style", "display:none;");
  }

  if($('#tab-ipv6').length > 0){
    $('#download_flows_v6_]] print(button_id) print[[').click(function (event){
      window.location.assign("]] print(flows_download_url) print [[?version=6&format=txt&" + $.param(buildRequestData(']] print(pcap_request_data_container_div_id) print[[')));
      return false;
    });
  } else {
    $('#download_flows_v6_]] print(button_id) print[[').attr("style", "display:none;");
  }
]]

if ntop.getCache("ntopng.prefs.nbox_integration") == "1" and haveAdminPrivileges() then
print[[
   $('#extract_pcap_]] print(button_id) print[[').click(function (event)
  {
    event.preventDefault();
    var perror = function(msg){
      alert("Request failed: " + msg);
      $('#pcap_download_msg_]] print(button_id) print[[').show().fadeOut(4000).html("<small>Request failed.</small>");
    };

    $.ajax({type: 'GET', url: "]] print(pcap_request_url) print [[",
    data: buildRequestData(']] print(pcap_request_data_container_div_id) print[['),
      success: function(data) {
	data = jQuery.parseJSON(data);
	if (data["result"] === "KO"){
	  perror(data["description"]);
	} else if (data["result"] == "OK"){
	  $('#pcap_download_msg_]] print(button_id) print[[').show().fadeOut(4000).html('<small>OK, request sent.</small>');
	} else { alert('Unknown response.'); }
      },
      error: function() {
	perror('An HTTP error occurred.');
      }
    });
  });
]]

else -- either the nbox integration is disabled or the user doesn't have admin privilieges

   print[[
  $('#extract_pcap_]] print(button_id) print[[').click(function (event)
  {
     event.preventDefault();
     $('#pcap_download_msg_]] print(button_id) print[[').show().fadeOut(4000).html(
	 "<small>nBox integration is disabled. <br>" +
	 " Enable it via <a href=\"]] print(ntop.getHttpPrefix()) print[[/lua/admin/prefs.lua\"><i class=\"fa fa-flask\"></i> preferences</a>.</small>");
     });
     ]]
  end


print[[
 </script>
  <br>
  ]]
end

function historicalTopTalkersTable(ifid, epoch_begin, epoch_end, host, l7proto, l4proto, port)
   local breadcrumb_root = "interface"
   local host_talkers_url_params = ""
   local interface_talkers_url_params = ""
   interface_talkers_url_params = interface_talkers_url_params.."&epoch_start="..epoch_begin
   interface_talkers_url_params = interface_talkers_url_params.."&epoch_end="..epoch_end

   if l7proto ~= "" and l7proto ~= nil and not string.starts(tostring(l7proto), 'all') then
      if not isnumber(l7proto) then
	 local id
	 l7proto = string.gsub(l7proto, "%.rrd", "")
	 id = interface.getnDPIProtoId(l7proto)
	 if id ~= -1 then
	    l7proto = id
	    interface_talkers_url_params = interface_talkers_url_params.."&l7_proto_id="..l7proto
	 else
	    l7proto = ""
	 end
      elseif tonumber(l7proto) ~= nil then
	 interface_talkers_url_params = interface_talkers_url_params.."&l7_proto_id="..tonumber(l7proto)
      end
   end

   if l4proto ~= "" and l4proto ~= nil and tonumber(l4proto) ~= nil then
      interface_talkers_url_params = interface_talkers_url_params.."&l4_proto_id="..tonumber(l4proto)
   end

   if port ~= "" and port ~= nil and tonumber(port) ~= nil then
      interface_talkers_url_params = interface_talkers_url_params.."&port="..tonumber(port)
   end

   if host and host ~= "" then
      host_talkers_url_params = interface_talkers_url_params.."&peer1="..host
      breadcrumb_root = "host"
   else
      host_talkers_url_params = interface_talkers_url_params
   end

   local preference = tablePreferences("historical_rows_number",_GET["perPage"])
   local sort_order = getDefaultTableSortOrder("historical_stats_top_talkers")
   local sort_column= getDefaultTableSort("historical_stats_top_talkers")
   if not sort_column or sort_column == "column_" then sort_column = "column_bytes" end
   print[[

<ol class="breadcrumb" id="bc-talkers" style="margin-bottom: 5px;"]] print('root="'..breadcrumb_root..'"') print [[>
</ol>


<!-- attach some status information to the historical container -->
<div id="historical-container" epoch_begin="" epoch_end="" ifname="" host="" peer="" l7_proto_id="" l7_proto="" l4_proto_id="" l4_proto="">


  <div class="row">
    <div class="form-group">
      <div class='col-md-3'>
	<form name="top_talkers_faves">
	<i class="fa fa-heart"></i> &nbsp;talkers <span style="float:right"><small><a onclick="removeAllFavourites('top_talkers', 'talker', 'top_talkers_talker')"><i class="fa fa-trash"></i> all </a></small></span>
	<select name="top_talkers_talker" id="top_talkers_talker" class="form-control">
	</select>
      </div>
      <div class='col-md-6'>
	 <i class="fa fa-heart"></i> &nbsp;applications between pairs of talkers <span style="float:right"><small><a onclick="removeAllFavourites('top_talkers', 'apps_per_host_pair', 'top_talkers_host_pairs')"><i class="fa fa-trash"></i> all </a></small></span>
	<select name="top_talkers_host_pairs" id="top_talkers_host_pairs" class="form-control">
	</select>
	</form>
      </div>
    </div>
  </div>

  <div id="historical-interface-top-talkers-table" class="historical-interface" total_rows=-1 loaded=0> </div>
  <div id="hosts-container"> </div>
  <div id="apps-per-pair-container"> </div>
  <div id="flows-per-pair-container"> </div>
</div>

]] historicalDownloadButtonsBar("pcap-button-top-talkers", "historical-container") print [[

<script type="text/javascript">
]] commonJsUtils() print[[

var emptyBreadCrumb = function(){
  $('#bc-talkers').empty();
};

var refreshBreadCrumbInterface = function(){
  emptyBreadCrumb();
  $("#bc-talkers").append('<li>Interface ]] print(getInterfaceName(ifid)) print [[</li>');
  $('#historical-container').removeAttr("host");
  $('#historical-container').removeAttr("peer");
}

var refreshBreadCrumbHost = function(host){
  emptyBreadCrumb();
  $("#bc-talkers").append('<li><a onclick="populateInterfaceTopTalkersTable();">Interface ]] print(getInterfaceName(ifid)) print [[</a></li>');

  // append a pair of li to the breadcrumb: the first is shown if the host has not been added to the favourites,
  // the second is shown if it has been added...

  // first pair: shown if the host has not been favourited
  $("#bc-talkers").append('<li class="bc-item-add talker">' + host + ' talkers <a onclick="addToFavourites(\'historical-container\', \'top_talkers\', \'talker\', \'top_talkers_talker\');"><i class="fa fa-heart-o" title="Save"></i></a> </li>');

  // second pair: shown if the host has been favourited
  $("#bc-talkers").append('<li class="bc-item-remove talker">' + host + ' talkers <a onclick="removeFromFavourites(\'historical-container\', \'top_talkers\', \'talker\', \'top_talkers_talker\');"><i class="fa fa-heart" title="Unsave"></i></a> </li>');

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

var refreshBreadCrumbPairs = function(peer1, peer2, l7_proto_id){
  emptyBreadCrumb();
  $('#historical-container').attr("host", peer1);
  $('#historical-container').attr("peer", peer2);
  if (typeof l7_proto_id !== "undefined"){
    $('#historical-container').attr("l7_proto_id", l7_proto_id);
  } else {
    $('#historical-container').removeAttr("l7_proto_id");
  }

  $("#bc-talkers").append('<li><a onclick="populateInterfaceTopTalkersTable();">Interface ]] print(getInterfaceName(ifid)) print [[</a></li>');
  $("#bc-talkers").append('<li><a onclick="populateHostTopTalkersTable(\'' + peer1 + '\');">' + peer1 + ' talkers</a></li>');

  // here we append to li: one will be shown if the pair of peers is favourited, the other is shown in the opposite case

  // first li: shown if the pair has been favourited
  var bc_talkers_li_text = 'Applications between ' + peer1 + ' and ' + peer2;
  if (typeof l7_proto_id !== "undefined"){
    bc_talkers_li_text = '<a onclick="populateAppsPerHostsPairTable(\'' + peer1 + '\',\'' + peer2 + '\');">' + bc_talkers_li_text + '</a>';
  }

  $("#bc-talkers").append('<li class="bc-item-add host-pair">' + bc_talkers_li_text + ' <a onclick="addToFavourites(\'historical-container\', \'top_talkers\', \'apps_per_host_pair\', \'top_talkers_host_pairs\');"><i class="fa fa-heart-o" title="Save"></i></a></li>');
  $('#historical-container').attr("peer", peer2);

  // second li: shown if the pair has not been favorited
  $("#bc-talkers").append('<li class="bc-item-remove host-pair">' + bc_talkers_li_text + ' <a onclick="removeFromFavourites(\'historical-container\', \'top_talkers\', \'apps_per_host_pair\', \'top_talkers_host_pairs\');"><i class="fa fa-heart" title="Unsave"></i></a></li>');

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

  // finally add a possible l7 protocol indication
  if (typeof l7_proto_id !== "undefined"){
     $("#bc-talkers").append('<li>Application flows</li>');
  }
}

var populateInterfaceTopTalkersTable = function(){
  refreshBreadCrumbInterface();
  hideAll("host-talkers");
  hideAll("apps-per-host-pair");
  hideAll('flows-per-host-pair');
  showOne('historical-interface', 'historical-interface-top-talkers-table');


  if ($('#historical-interface-top-talkers-table').attr("loaded") == 1) {
    enableAllDropdowns();
  } else {
    disableAllDropdowns();
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
	tableCallback: function(){$('#historical-interface-top-talkers-table').attr("total_rows", this.options.totalRows);enableAllDropdowns();},
	rowCallback: function(row){
	  var addr_td = $("td:eq(1)", row[0]);
	  var label_td = $("td:eq(0)", row[0]);
	  var addr = addr_td.text();
	  label_td.append('&nbsp;<a onclick="populateHostTopTalkersTable(\'' + addr +'\');"><i class="fa fa-pie-chart" title="Talkers with this host"></i></a>');
	  return row;
	},
	columns:
	[
	  {title: "Host Name",     field: "column_label",         sortable: true},
	  {title: "IP Address",    field: "column_addr",          sortable:true, hidden: false},
	  {title: "Traffic Sent", field: "column_bytes_sent",     sortable: true,css: {textAlign:'right'}},
	  {title: "Traffic Received", field: "column_bytes_rcvd", sortable: true,css: {textAlign:'right'}},
	  {title: "Total Traffic", field: "column_bytes",         sortable: true,css: {textAlign:'right'}},
	  {title: "Total Packets", field: "column_packets",       sortable: true, css: {textAlign:'right'}},
	  {title: "Flows",         field: "column_flows",         sortable: true, css: {textAlign:'right'}}
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
  hideAll('flows-per-host-pair');
  showOne("host-talkers", div_id);

  // load the table only if it is the first time we've been called
  div_id='#'+div_id;

  if ($(div_id).attr("loaded") == 1) {
    enableAllDropdowns();
  } else {
    disableAllDropdowns();
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
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);enableAllDropdowns();},
	rowCallback: function(row){
	  var addr_td = $("td:eq(1)", row[0]);
	  var label_td = $("td:eq(0)", row[0]);
	  var addr = addr_td.text();
	  label_td.append('&nbsp;<a onclick="populateAppsPerHostsPairTable(\'' + host +'\',\'' + addr +'\');"><i class="fa fa-exchange" title="Applications between ' + host + ' and ' + addr + '"></i></a>');
	  return row;
	},
	columns:
	[
	  {title: "Host Name",       field: "column_label",      sortable: true},
	  {title: "IP Address",      field: "column_addr",       sortable:true, hidden: false},
	  {title: "Traffic Sent",    field: "column_bytes_sent", sortable: true,css: {textAlign:'right'}},
	  {title: "Traffic Received",field: "column_bytes_rcvd", sortable: true,css: {textAlign:'right'}},
	  {title: "Total Traffic",   field: "column_bytes",      sortable: true,css: {textAlign:'right'}},
	  {title: "Total Packets",   field: "column_packets",    sortable: true, css: {textAlign:'right'}},
	  {title: "Flows",           field: "column_flows",      sortable: true, css: {textAlign:'right'}}
	]
    });
  }
};

var populateAppsPerHostsPairTable = function(peer1, peer2){
  refreshBreadCrumbPairs(peer1, peer2);

  var kpeer1 = hostkey2hostid(peer1)[0];
  var kpeer2 = hostkey2hostid(peer2)[0];
  if (kpeer2 > kpeer1){
    var tmp = kpeer2;
    kpeer2 = kpeer1;
    kpeer1 = tmp;
  }
  var div_id = 'pair-' + kpeer1 + "_" + kpeer2;
  if ($('#'+div_id).length == 0)  // create the div only if it does not exist
    $('#apps-per-pair-container').append('<div class="apps-per-host-pair" id="' + div_id + '" total_rows=-1 loaded=0></div>');

  hideAll('historical-interface');
  hideAll('host-talkers');
  hideAll('flows-per-host-pair');
  showOne('apps-per-host-pair', div_id);

  div_id='#'+div_id;

  // if the table has already been loaded, we just show up all the dropdowns
  if ($(div_id).attr("loaded") == 1) {
    enableAllDropdowns();
  } else {   // load the table only if it is the first time we've been called
    disableAllDropdowns();
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
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);enableAllDropdowns();},
	rowCallback: function(row){
	  var l7_proto_id_td = $("td:eq(0)", row[0]);
	  var label_td = $("td:eq(1)", row[0]);
	  var label = label_td.text();
	  var l7_proto_id = l7_proto_id_td.text();
          var num_flows = parseInt($("td:eq(4)", row[0]).text().replace(/[^0-9]/g, ''));
	  label_td.append('&nbsp;<a onclick="populateFlowsPerHostsPairTable(\'' + peer1 +'\',\'' + peer2 +'\',\'' + l7_proto_id +'\',\'' + num_flows +'\');"><i class="fa fa-tasks" title="' + label + ' application flows between ' + peer1 + ' and ' + peer2 + '"></i></a>');
	  return row;
	},
	columns:
	[
	  {title: "Protocol id", field: "column_application", hidden: true},
	  {title: "Application", field: "column_label", sortable: false},
	  {title: "Total Traffic", field: "column_bytes", sortable: true, css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
    });
  }
};

var populateFlowsPerHostsPairTable = function(peer1, peer2, l7_proto_id, num_flows){
  refreshBreadCrumbPairs(peer1, peer2, l7_proto_id);

  var kpeer1 = hostkey2hostid(peer1)[0];
  var kpeer2 = hostkey2hostid(peer2)[0];
  if (kpeer2 > kpeer1){
    var tmp = kpeer2;
    kpeer2 = kpeer1;
    kpeer1 = tmp;
  }
  var div_id = 'flows-pair-' + kpeer1 + "_" + kpeer2;
  if(typeof l7_proto_id !== "undefined"){
    div_id = div_id + "_" + l7_proto_id;
  }
  if ($('#'+div_id).length == 0)  // create the div only if it does not exist
    $('#flows-per-pair-container').append('<div class="flows-per-host-pair" id="' + div_id + '" total_rows=-1 loaded=0></div>');

  hideAll('historical-interface');
  hideAll('host-talkers');
  hideAll('apps-per-host-pair');
  showOne('flows-per-host-pair', div_id);

  div_id='#'+div_id;

  // if the table has already been loaded, we just show up all the dropdowns
  if ($(div_id).attr("loaded") == 1) {
    enableAllDropdowns();
  } else {   // load the table only if it is the first time we've been called
    disableAllDropdowns();
    $(div_id).attr("loaded", 1);
    $(div_id).attr("peer1", peer1);
    $(div_id).attr("peer2", peer2);
    $(div_id).attr("l7_proto_id", l7_proto_id);
    $(div_id).datatable({
	title: "",]]
	print("url: '"..ntop.getHttpPrefix().."/lua/get_db_flows.lua?ifId="..tostring(ifId)..interface_talkers_url_params.."&host=' + peer1 + '&peer=' + peer2 + '&l7_proto_id=' + l7_proto_id + '&limit=' + num_flows,")
  if preference ~= "" then print ('perPage: '..preference.. ",\n") end
  -- Automatic default sorted. NB: the column must be exists.
	print [[
	post: {totalRows: function(){ return $(div_id).attr("total_rows");} },
	showFilter: true,
	showPagination: true,
totalRows: 100,
	sort: [ [ "BYTES","desc"] ],
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);enableAllDropdowns();},
	columns:
	[
	  {title: "Key",         field: "idx",            hidden: true},
	  {title: "",            field: "FLOW_URL",       sortable:false, css:{textAlign:'center'}},
	  {title: "Application", field: "L7_PROTO",       sortable: true, css:{textAlign:'center'}},
	  {title: "L4 Proto",    field: "PROTOCOL",       sortable: true, css:{textAlign:'center'}},
	  {title: "Client",      field: "CLIENT",         sortable: false},
	  {title: "Server",      field: "SERVER",         sortable: false},
	  {title: "Begin",       field: "FIRST_SWITCHED", sortable: true, css:{textAlign:'center'}},
	  {title: "End",         field: "LAST_SWITCHED",  sortable: true, css:{textAlign:'center'}},
	  {title: "Traffic",     field: "BYTES",          sortable: true, css:{textAlign:'right'}},
	  {title: "Info",        field: "INFO",           sortable: true, css:{textAlign:'right'}},
	  {title: "Avg Thpt",    field: "AVG_THROUGHPUT", sortable: false, css:{textAlign:'right'}}
	]
    });
  }
};

// executes when the talkers tab is focused
$('a[href="#historical-top-talkers"]').on('shown.bs.tab', function (e) {
  if ($('a[href="#historical-top-talkers"]').attr("loaded") == 1){
    // do nothing if the tabs have already been computed and populated
    enableAllDropdowns();
    return;
  }

  var target = $(e.target).attr("href"); // activated tab

  $('#historical-container').attr("ifname", "]] print(getInterfaceName(ifid)) print [[");

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
  ]]

if l7proto ~= nil and l7proto ~= "" and not string.starts(tostring(l7proto), 'all') then
   print[[$('#historical-container').attr("l7_proto_id", "]] print(tostring(l7proto)) print[[");]]
end

if l4proto ~= nil and l4proto ~= "" then
   print[[$('#historical-container').attr("l4_proto_id", "]] print(tostring(l4proto)) print[[");]]
end

if port ~= nil and port ~= "" then
   print[[$('#historical-container').attr("port", "]] print(tostring(port)) print[[");]]
end

  print[[
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
   local preference = tablePreferences("historical_rows_number",_GET["perPage"])
   local sort_order = getDefaultTableSortOrder("historical_stats_top_applications")
   local sort_column= getDefaultTableSort("historical_stats_top_applications")
   if not sort_column or sort_column == "column_" then sort_column = "column_bytes" end

   print[[
<ol class="breadcrumb" id="bc-apps" style="margin-bottom: 5px;"]] print('root="'..breadcrumb_root..'"') print [[>
</ol>

<div id="historical-apps-container" epoch_begin="" epoch_end="" ifname="" host="" peer="" l7_proto_id="" l7_proto="" l4_proto_id="" l4_proto="">


  <div class="row">
    <div class="form-group">
    <div class='col-md-3'>
      <form name="top_apps_faves">
	<i class="fa fa-heart"></i> &nbsp;protocols <span style="float:right"><small><a onclick="removeAllFavourites('top_applications', 'app', 'top_applications_app')"><i class="fa fa-trash"></i> all </a></small></span>
	<select name="top_applications_app" id="top_applications_app" class="form-control">
	</select>
    </div>
    <div class='col-md-6'>
	 <i class="fa fa-heart"></i> &nbsp; host peers by protocol <span style="float:right"><small><a onclick="removeAllFavourites('top_applications', 'host_peers_by_app', 'top_applications_host_peers_by_app')"><i class="fa fa-trash"></i> all </a></small></span>
	<select name="top_applications_host_peers_by_app" id="top_applications_host_peers_by_app" class="form-control">
	</select>
      </form>
    </div>
    </div>
  </div>


  <div id="historical-interface-top-apps-table" class="historical-interface-apps" total_rows=-1 loaded=0> </div>
  <div id="host-apps-container"> </div>
  <div id="apps-container"> </div>
  <div id="peers-per-host-by-app-container"> </div>
  <div id="flows-per-pair-by-app-container"> </div>
</div>

]] historicalDownloadButtonsBar("pcap-button-top-protocols", "historical-apps-container") print [[

<script type="text/javascript">
var totalRows = -1;

var emptyAppsBreadCrumb = function(){
  $('#bc-apps').empty();
};

var refreshHostPeersByAppBreadCrumb = function(peer1, proto_id, peer2){
  emptyAppsBreadCrumb();

  var root = $("#bc-apps").attr("root");
  var app = $('#historical-apps-container').attr("l7_proto");

  if (typeof peer2 !== "undefined"){
    $('#historical-apps-container').attr("peer", peer2);
  } else {
    $('#historical-apps-container').removeAttr("peer");
  }

  if (root === "interface"){
    $("#bc-apps").append('<li><a onclick="populateInterfaceTopAppsTable();">Interface ]] print(getInterfaceName(ifid)) print [[</a></li>');
    $("#bc-apps").append('<li><a onclick="populateAppTopTalkersTable(\'' + proto_id + '\');">' + app + ' talkers</a></li>');

    // append two li: one is to be shown when the favourites has not beena added;
    // the other is shown when the favourites has been added

    // first li: there is no exising favorited peer --> app pair saved
    var bc_apps_text = app + ' talkers with ' + peer1;
    if (typeof peer2 !== "undefined"){
      bc_apps_text = '<a onclick="populatePeersPerHostByApplication(\'' + peer1 + '\',\'' + proto_id + '\');">' + bc_apps_text + '</a>';
    }

    $("#bc-apps").append('<li class="bc-app-item-add host-peers-by-app">' + bc_apps_text + ' <a onclick="addToFavourites(\'historical-apps-container\', \'top_applications\', \'host_peers_by_app\', \'top_applications_host_peers_by_app\');"><i class="fa fa-heart-o" title="Save"></i></a> </li>');

    // second li: there is an already exising favorited peer --> app pair saved
    $("#bc-apps").append('<li class="bc-app-item-remove host-peers-by-app"> ' + bc_apps_text + ' <a onclick="removeFromFavourites(\'historical-apps-container\', \'top_applications\', \'host_peers_by_app\', \'top_applications_host_peers_by_app\');"><i class="fa fa-heart" title="Unsave"></i></a> </li>');

  // here we decide which li has to be shown, depending on the elements contained in the drop-down menu
  if($('#top_applications_host_peers_by_app > option[value=\'' + proto_id + ',' + peer1 + '\']').length == 0){
    $('.bc-app-item-add').show();
    $('.bc-app-item-remove').hide();
  } else {
    // the host has already been added to favourites
    $('.bc-app-item-remove').show();
    $('.bc-app-item-add').hide();
  }

  // we also add a function to toggle the currently active li
  $('.bc-app-item-add, .bc-app-item-remove').on('click', function(){
    $('.bc-app-item-add, .bc-app-item-remove').toggle();
  });

  } else if (root == "host"){
    var host = $('#historical-apps-container').attr("host");
    $("#bc-apps").append('<li><a onclick="populateHostTopAppsTable(\'' + host + '\');">' + host + ' protocols</a></li>');

    var bc_apps_text = ""
    if(app.toLowerCase().endsWith("unknown")){
      bc_apps_text = 'Unknown protocol talkers with ' + host;
    } else {
      bc_apps_text = app + ' talkers with ' + host;
    }
    if (typeof peer2 !== "undefined"){
      bc_apps_text = '<a onclick="populatePeersPerHostByApplication(\'' + peer1 + '\',\'' + proto_id + '\');">' + bc_apps_text + '</a>';
    }
    $("#bc-apps").append('<li>' + bc_apps_text + '</li>');
  }

  if (typeof peer2 !== "undefined"){
    $("#bc-apps").append('<li>' +$("#historical-apps-container").attr("l7_proto") + ' protocol flows between ' + peer1 + ' and ' + peer2 + '</li>');
  }

}

var populateInterfaceTopAppsTable = function(){
  emptyAppsBreadCrumb();
  $('#historical-apps-container').removeAttr("host");
  $("#bc-apps").append('<li>Interface ]] print(getInterfaceName(ifid)) print [[</li>');

  hideAll("app-talkers");
  hideAll("peers-by-app");
  hideAll('flows-per-host-pair-by-app-container');
  showOne('historical-interface-apps', 'historical-interface-top-apps-table');

  if ($('#historical-interface-top-apps-table').attr("loaded") == 1) {
    enableAllDropdowns();
  } else {
    disableAllDropdowns();
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
      tableCallback: function(){$('#historical-interface-top-apps-table').attr("total_rows", this.options.totalRows);enableAllDropdowns();},
      rowCallback: function(row){
	var proto_id_td = $("td:eq(0)", row[0]);
	var proto_label_td = $("td:eq(1)", row[0]);
	var proto_id = proto_id_td.text();
	var proto_label = proto_label_td.text();
	proto_label_td.append('&nbsp;<a onclick="$(\'#historical-apps-container\').attr(\'l7_proto_id\', \'' + proto_id + '\');$(\'#historical-apps-container\').attr(\'l7_proto\', \'' + proto_label + '\');populateAppTopTalkersTable(\'' + proto_id +'\');"><i class="fa fa-pie-chart" title="Get Talkers using this protocol"></i></a>');
	  return row;
	},
      columns:
	[
	  {title: "Protocol id", field: "column_application", hidden: true},
	  {title: "Application", field: "column_label", sortable: false},
	  {title: "Total Traffic", field: "column_bytes", sortable: true, css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
    });
  }
};


var populateAppTopTalkersTable = function(proto_id){
  emptyAppsBreadCrumb();
  $('#historical-apps-container').removeAttr("host");
  var app = $('#historical-apps-container').attr("l7_proto");

  // UPDATE THE BREADCRUMB
  $("#bc-apps").append('<li><a onclick="populateInterfaceTopAppsTable();">Interface ]] print(getInterfaceName(ifid)) print [[</a></li>');

  // add two li: show the first li when no favourite has been added; show the second li in the other case
  $("#bc-apps").append('<li class="bc-app-item-add app"> ' + app + ' talkers <a onclick="addToFavourites(\'historical-apps-container\', \'top_applications\', \'app\', \'top_applications_app\');"><i class="fa fa-heart-o" title="Save"></i></a> </li>');
  $("#bc-apps").append('<li class="bc-app-item-remove app"> ' + app + ' talkers <a onclick="removeFromFavourites(\'historical-apps-container\', \'top_applications\', \'app\', \'top_applications_app\');"><i class="fa fa-heart" title="Unsave"></i></a> </li>');

  // here we decide which li has to be shown, depending on the elements contained in the drop-down menu
  if($('#top_applications_app > option[value=\'' + proto_id + '\']').length == 0){
    $('.bc-app-item-add').show();
    $('.bc-app-item-remove').hide();
  } else {
    // the host has already been added to favourites
    $('.bc-app-item-remove').show();
    $('.bc-app-item-add').hide();
  }

  // we also add a function to toggle the currently active li
  $('.bc-app-item-add, .bc-app-item-remove').on('click', function(){
    $('.bc-app-item-add, .bc-app-item-remove').toggle();
  });

  // LOAD TABLE CONTENTS
  var div_id = 'app-' + proto_id;
  if ($('#'+div_id).length == 0)  // create the div only if it does not exist
    $('#apps-container').append('<div class="app-talkers" id="' + div_id + '" total_rows=-1 loaded=0></div>');

  hideAll('historical-interface-apps');
  hideAll('peers-by-app');
  hideAll('flows-per-host-pair-by-app-container');
  showOne('app-talkers', div_id);

  // load the table only if it is the first time we've been called
  div_id='#'+div_id;

  if ($(div_id).attr("loaded") == 1) {
    enableAllDropdowns();
  } else {
    disableAllDropdowns();
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
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);enableAllDropdowns();},
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
	  {title: "Traffic Sent",    field: "column_bytes_sent", sortable: true,css: {textAlign:'right'}},
	  {title: "Traffic Received",field: "column_bytes_rcvd", sortable: true,css: {textAlign:'right'}},
	  {title: "Total Traffic", field: "column_bytes", sortable: true,css: {textAlign:'right'}},
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
  hideAll('flows-per-host-pair-by-app-container');
  showOne('peers-by-app', div_id);

  // load the table only if it is the first time we've been called
  div_id='#'+div_id;

  if ($(div_id).attr("loaded") == 1) {
    enableAllDropdowns();
  } else {
    disableAllDropdowns();
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
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);enableAllDropdowns();},
	rowCallback: function(row){
	  var addr_td = $("td:eq(1)", row[0]);
	  var label_td = $("td:eq(0)", row[0]);
	  var addr = addr_td.text();
          var num_flows = parseInt($("td:eq(6)", row[0]).text().replace(/[^0-9]/g, ''));
          label_td.append('&nbsp;<a onclick="$(\'#historical-apps-container\').attr(\'l7_proto_id\', \'' + proto_id + '\');populateFlowsPerHostPairByApplicationTable(\'' + host +'\',\'' + addr + '\',\'' + proto_id + '\',\'' + num_flows +'\');"><i class="fa fa-tasks" title="' + $('#historical-apps-container').attr("l7_proto") + ' protocol flows between ' + host + ' and ' + addr + '"></i></a>');
	  return row;
	},
	columns:
	[
	  {title: "Host Name", field: "column_label", sortable: true},
	  {title: "Address", field: "column_addr", hidden: false, sortable: true},
	  {title: "Traffic Sent",    field: "column_bytes_sent", sortable: true,css: {textAlign:'right'}},
	  {title: "Traffic Received",field: "column_bytes_rcvd", sortable: true,css: {textAlign:'right'}},
	  {title: "Total Traffic", field: "column_bytes", sortable: true,css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
    });
  }
};

var populateFlowsPerHostPairByApplicationTable = function(peer1, peer2, l7_proto_id, num_flows){
  refreshHostPeersByAppBreadCrumb(peer1, l7_proto_id, peer2);

  var kpeer1 = hostkey2hostid(peer1)[0];
  var kpeer2 = hostkey2hostid(peer2)[0];
  if (kpeer2 > kpeer1){
    var tmp = kpeer2;
    kpeer2 = kpeer1;
    kpeer1 = tmp;
  }
  var div_id = 'app-flows-pair-' + kpeer1 + "_" + kpeer2;
  if(typeof l7_proto_id !== "undefined"){
    div_id = div_id + "_" + l7_proto_id;
  }
  if ($('#'+div_id).length == 0)  // create the div only if it does not exist
    $('#flows-per-pair-by-app-container').append('<div class="flows-per-host-pair-by-app-container" id="' + div_id + '" total_rows=-1 loaded=0></div>');

  hideAll('historical-interface-apps');
  hideAll('app-talkers');
  hideAll('peers-by-app');
  showOne('flows-per-host-pair-by-app-container', div_id);

  div_id='#'+div_id;

  // if the table has already been loaded, we just show up all the dropdowns
  if ($(div_id).attr("loaded") == 1) {
    enableAllDropdowns();
  } else {   // load the table only if it is the first time we've been called
    disableAllDropdowns();
    $(div_id).attr("loaded", 1);
    $(div_id).attr("peer1", peer1);
    $(div_id).attr("peer2", peer2);
    $(div_id).attr("l7_proto_id", l7_proto_id);
    $(div_id).datatable({
	title: "",]]
	print("url: '"..ntop.getHttpPrefix().."/lua/get_db_flows.lua?ifId="..tostring(ifId)..top_apps_url_params.."&host=' + peer1 + '&peer=' + peer2 + '&l7_proto_id=' + l7_proto_id + '&limit=' + num_flows,")
  if preference ~= "" then print ('perPage: '..preference.. ",\n") end
  -- Automatic default sorted. NB: the column must be exists.
	print [[
	post: {totalRows: function(){ return $(div_id).attr("total_rows");} },
	showFilter: true,
	showPagination: true,
totalRows: 100,
	sort: [ [ "BYTES","desc"] ],
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);enableAllDropdowns();},
	columns:
	[
	  {title: "Key",         field: "idx",            hidden: true},
	  {title: "",            field: "FLOW_URL",       sortable:false, css:{textAlign:'center'}},
	  {title: "Application", field: "L7_PROTO",       sortable: true, css:{textAlign:'center'}},
	  {title: "L4 Proto",    field: "PROTOCOL",       sortable: true, css:{textAlign:'center'}},
	  {title: "Client",      field: "CLIENT",         sortable: false},
	  {title: "Server",      field: "SERVER",         sortable: false},
	  {title: "Begin",       field: "FIRST_SWITCHED", sortable: true, css:{textAlign:'center'}},
	  {title: "End",         field: "LAST_SWITCHED",  sortable: true, css:{textAlign:'center'}},
	  {title: "Traffic",     field: "BYTES",          sortable: true, css:{textAlign:'right'}},
	  {title: "Info",        field: "INFO",           sortable: true, css:{textAlign:'right'}},
	  {title: "Avg Thpt",    field: "AVG_THROUGHPUT", sortable: false, css:{textAlign:'right'}}
	]
    });
  }
};

// this is the entry point for the navigation that starts at hosts
var populateHostTopAppsTable = function(host){
  emptyAppsBreadCrumb();
  $('#historical-apps-container').attr("host", host);
  $('#historical-apps-container').removeAttr("l7_proto");
  $('#historical-apps-container').removeAttr("l7_proto_id");
  $("#bc-apps").append('<li>' + host +' protocols</li>');

  // remove the favourite top apps dropdowns
  $('#top_applications_app').parent().closest('div').detach();
  $('#top_applications_host_peers_by_app').parent().closest('div').detach();

  hideAll("app-talkers");
  hideAll("peers-by-app");
  hideAll('flows-per-host-pair-by-app-container');
  showOne('historical-interface-apps', 'historical-interface-top-apps-table');

  if ($('#historical-interface-top-apps-table').attr("loaded") == 1) {
    enableAllDropdowns();
  } else {
    disableAllDropdowns();
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
      tableCallback: function(){$('#historical-interface-top-apps-table').attr("total_rows", this.options.totalRows);enableAllDropdowns();},
	rowCallback: function(row){
	var proto_id_td = $("td:eq(0)", row[0]);
	var proto_label_td = $("td:eq(1)", row[0]);
	var proto_id = proto_id_td.text();
	var proto_label = proto_label_td.text();
        var num_flows = parseInt($("td:eq(4)", row[0]).text().replace(/[^0-9]/g, ''));
	proto_label_td.append('&nbsp;<a onclick="$(\'#historical-apps-container\').attr(\'l7_proto_id\', \'' + proto_id + '\');$(\'#historical-apps-container\').attr(\'l7_proto\', \'' + proto_label + '\');populatePeersPerHostByApplication(\'' + host +'\',\'' + proto_id +'\');"><i class="fa fa-exchange" title="Hosts talking ' + proto_id + ' with ' + host + '"></i></a>');
	  return row;
	},
      columns:
	[
	  {title: "Protocol id", field: "column_application", hidden: true},
	  {title: "Application", field: "column_label", sortable: false},
	  {title: "Total Traffic", field: "column_bytes", sortable: true, css: {textAlign:'right'}},
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
    enableAllDropdowns();
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
  $("#historical-apps-container").attr("ifname", "]] print(getInterfaceName(ifid)) print [[");

  // populate favourites dropdowns
  populateFavourites('historical-apps-container', 'top_applications', 'app', 'top_applications_app');
  populateFavourites('historical-apps-container', 'top_applications', 'host_peers_by_app', 'top_applications_host_peers_by_app');

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

function jump_to_nbox_activity_scheduler(){
  var url = document.URL;
  res = url.split("http://");
  if(res[0]=="") url=res[1]; else url=res[0];
  res = url.split("https://");
  if(res[0]=="") url=res[1]; else url=res[0];
  res = url.split("/");
  url = res[0];
  res = url.split(":");
  url = res[0];
  window.open("https://"+url+"/ntop-bin/config_scheduler.cgi", "_blank");
}

function download_pcap_from_nbox(task_id){
  var url = document.URL;
  res = url.split("http://");
  if(res[0]=="") url=res[1]; else url=res[0];
  res = url.split("https://");
  if(res[0]=="") url=res[1]; else url=res[0];
  res = url.split("/");
  url = res[0];
  res = url.split(":");
  url = res[0];
  window.open("https://"+url+"/ntop-bin/sudowrapper.cgi?script=n2disk_filemanager.cgi&opt=download_pcap&dir=/storage/n2disk/&pcap_name=/storage/n2disk/"+task_id+".pcap", "_blank");
}

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
			     title: "Filter (BPF)",
				 field: "column_bpf",
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
    enableAllDropdowns();
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
