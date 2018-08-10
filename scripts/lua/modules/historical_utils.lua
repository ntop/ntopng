--
-- (C) 2014-18 - ntop.org
--

require "lua_utils"
require "flow_aggregation_utils"

local json = require ("dkjson")

local pcap_status_url = ntop.getHttpPrefix().."/lua/get_nbox_data.lua?nbox_action=status"
local pcap_request_url = ntop.getHttpPrefix().."/lua/get_nbox_data.lua?nbox_action=schedule"
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

function hostkey2hostid(host_key) {
    var info;
    var hostinfo = [];

    host_key = host_key.replace(/\:/g, "____");
    host_key = host_key.replace(/\//g, "___");
    host_key = host_key.replace(/\./g, "__");

    info = host_key.split("@");
    return(info);
}
/*
 * Returns a map of querystring parameters
 *
 * Keys of type <fieldName>[] will automatically be added to an array
 *
 * @param String url
 * @return Object parameters
 */
function getParams(url) {
  var regex = /([^=&?]+)=([^&#]*)/g, params = {}, parts, key, value;
  while((parts = regex.exec(url)) != null) {
    key = parts[1], value = parts[2];
    var isArray = /\[\]$/.test(key);

    if(isArray) {
      params[key] = params[key] || [];
        params[key].push(value);
    }
    else {
      params[key] = value;
    }
  }
  return params;
}

/* adds a CSS style to replace the / in the breadcrumb */
var style = $("<style>#search-criteria:before {content:\"]] print(i18n("db_explorer.observation_period")) print[[:\";}</style>");
$('html > head').append(style);
function addObservationPeriodToBreadCrumb(params_url, breadcrumb_id){
  var params = getParams(params_url);
  var begin = params["epoch_begin"]
  if (typeof begin === 'undefined') {
    if (typeof params["epoch_begin"] !== 'undefined')
      begin = params["epoch_begin"]
    else
      begin = 0
  }
  var end = params["epoch_end"]
  if (typeof end === undefined)
    end = 0
  if (end < begin)
    end = begin
  var durat = moment.duration(end-begin, 'seconds')
  var d_d = durat.days(), d_h = durat.hours(), d_m = durat.minutes(), d_s = durat.seconds()
  var str = '<li class="pull-right" id="search-criteria">'
  str += secondsToTime(end-begin)
  str += ' starting on ' + moment(begin*1000).format("dddd, MMMM Do YYYY, h:mm:ss a")
  str += '</li>'
  $(breadcrumb_id).append(str);
}

function buildRequestData(source_div_id){
  var epoch_begin = $('#' + source_div_id).attr("epoch_begin");
  var epoch_end = $('#' + source_div_id).attr("epoch_end");
  var ifId = "]] print(tostring(ifId)) print [[";
  var host = $('#' + source_div_id).attr("host");
  var peer = $('#' + source_div_id).attr("peer");
  var l7_proto_id = $('#' + source_div_id).attr("l7_proto_id");
  var l4_proto_id = $('#' + source_div_id).attr("l4_proto_id");
  var port = $('#' + source_div_id).attr("port");
  var vlan = $('#' + source_div_id).attr("vlan");
  var profile = $('#' + source_div_id).attr("profile");
  var res = {epoch_begin: epoch_begin, epoch_end: epoch_end};
  if (typeof ifId != 'undefined') res.ifid = ifId;
  if (typeof host != 'undefined') res.peer1 = host;
  if (typeof peer != 'undefined') res.peer2 = peer;
  if (typeof port != 'undefined') res.port = port;
  if (typeof vlan != 'undefined') res.vlan = vlan;
  if (typeof profile != 'undefined') res.profile = profile;
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
  $.ajax({type:'GET',url:"]]print(favourites_url)print[[?fav_action=set&stats_type=" + stats_type + "&favourite_type=" + favourite_type,
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
  $.ajax({type:'GET',url:"]]print(favourites_url)print[[?fav_action=del&stats_type=" + stats_type + "&favourite_type=" + favourite_type,
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

var zoom_vals = {
]]

if zoom_vals ~= nil then
  for _, zv in pairs(zoom_vals) do
     print('"'..zv[1]..'": '..zv[3]..', ')
  end
end
print[[
};

function populateHistoricalDbExplorerLink(the_td, host, l7_proto) {
  var url_params = getParams(window.location.href);
  var mandatory_params = ["host", "l4proto", "port", "info", "protocol", "search"];
  $.each(mandatory_params, function(_, p) {
    if(url_params[p] === undefined) {
      url_params[p] = "";
    }
  });

  if(host != '' && host !== undefined) {
    url_params["host"] = host;
  }
  if(l7_proto != '' && l7_proto !== undefined) {
    url_params["protocol"] = l7_proto;
  }

  if(url_params["zoom"]) { /* This is a chart url */
    var zoom = url_params["zoom"];
    var epoch = url_params["epoch"];
    if(!epoch) {
      url_params["epoch_end"] = Math.round(new Date() / 1000); /* now */
      url_params["epoch_begin"] = url_params["epoch_end"] - zoom_vals[zoom];
    } else {
      epoch = parseInt(epoch);
      url_params["epoch_end"] = epoch + zoom_vals[zoom] / 2;
      url_params["epoch_begin"] = epoch - zoom_vals[zoom] / 2;
    }
  }

  the_td.html('<a href="]]print(ntop.getHttpPrefix())print[[/lua/pro/db_explorer.lua?' + decodeURIComponent($.param(url_params)) + '"><i>' + the_td.text() + '</i></a>');
}

function populateFavourites(source_div_id, stats_type, favourite_type, select_id){
  var multival_separator = " <---> ";

  $('#'+select_id).find('option').remove();
  $.ajax({type:'GET',url:"]]print(favourites_url)print[[?fav_action=get&stats_type=" + stats_type + "&favourite_type=" + favourite_type,
    data:buildRequestData(source_div_id),
    success:function(data){
      data=jQuery.parseJSON(data);
      // if no favourite has been added, we hide the div that contains the dropdown
      if(Object.keys(data).length == 0){
	$('#' + select_id).parent().closest('div').hide();

      // alternatively, we ajax data to the dropdown menu
      } else {
	$('#' + select_id).parent().closest('div').show();
	$('<option value="noaction"> ]] i18n("db_explorer.selected_saved") print[[...</option>').appendTo('#' + select_id);
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
  $.ajax({type:'GET',url:"]]print(favourites_url)print[[?fav_action=del_all&stats_type=" + stats_type + "&favourite_type=" + favourite_type,
    success:function(data){
      // remove all the existing options...
      $('#'+select_id).find('option').remove();

      // and hide the container div...
      $('#' + select_id).parent().closest('div').hide();

     // refresh the right breadcrumb
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

   local displacement = "7"
   if not interface.isPacketInterface() then
      displacement = "9"
   end
	  print [[

     <div class="row">

       <div class='col-md-3'>
	 ]] print(i18n("db_explorer.download_flows")) print[[: ]]

	  if(ipv4_enabled) then
	     print [[ <a class="btn btn-default btn-sm" href="#" role="button" id="download_flows_v4_]] print(button_id) print[[" style="]] print(style_ipv4) print[[">]] print(i18n("ipv4")) print[[</a>&nbsp;]]
	  else
             print [[<a class="btn btn-default btn-sm" href="#" role="button" id="download_flows_v6_]] print(button_id) print[[" style="]] print(style_ipv6) print[[">]] print(i18n("ipv6")) print[[</a>]]
	end

	print [[
        <p class="text-muted">]] print(i18n("db_explorer.download_flows_limit")) print[[</p>
	</div>]]
	  if interface.isPacketInterface()
	    and ntop.getCache("ntopng.prefs.nbox_integration") == "1"
	    and haveAdminPrivileges() then
       print[[ <div class='col-md-2'><div style='margin-bottom:0.4em;'>
	       ]] print(i18n("db_explorer.extract_pcap")) print[[: <a class="btn btn-default btn-sm]]
	       print[[" href="#" role="button" id="extract_pcap_]] print(button_id)
	       print[["><i class="fa fa-download fa-lg"></i></a></div>
	       <span id="pcap_download_msg_]] print(button_id) print[[">]]
	       print[[</span>
	       </div>]]
	  end

	  print[[<div class='col-md-]] print(displacement) print[['>
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

  if($('#tab-ipv4').length > 0 || true /* TODO: disable if no flows are available */){
    $('#download_flows_v4_]] print(button_id) print[[').click(function (event){
      window.location.assign("]] print(flows_download_url) print [[?version=4&format=txt&" + $.param(buildRequestData(']] print(pcap_request_data_container_div_id) print[[')));
      return false;
    });
  } else {
    $('#download_flows_v4_]] print(button_id) print[[').attr("style", "display:none;");
  }

  if($('#tab-ipv6').length > 0 || true /* TODO: disable if no flows are available */){
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
      $('#pcap_download_msg_]] print(button_id) print[[').show().fadeOut(4000).html("<small>]] print(i18n("db_explorer.request_failed")) print[[.</small>");
    };

    $.ajax({type: 'GET', url: "]] print(pcap_request_url) print [[",
    data: buildRequestData(']] print(pcap_request_data_container_div_id) print[['),
      success: function(data) {
	data = jQuery.parseJSON(data);
	if (data["result"] === "KO"){
	  perror(data["description"]);
	} else if (data["result"] == "OK"){
	  $('#pcap_download_msg_]] print(button_id) print[[').show().fadeOut(4000).html('<small>]] print(i18n("db_explorer.ok_request_sent")) print[[.</small>');
	} else { alert('Unknown response.'); }
      },
      error: function() {
	perror('An HTTP error occurred.');
      }
    });
  });
]]
  end


print[[
 </script>
  <br>
  ]]
end

function printFlowsCountColumn()
   -- hides the flows count column when aggregated database flows are being used
   local col = '{title: "'..i18n("flows")
   local hide_count = ""
   if useAggregatedFlows() == true then
      hide_count = " hidden :true, "
   end
   col = col..'", field: "column_flows", '..hide_count..' sortable: true, css: {textAlign:\'right\'}}'
   return col
end

function historicalTopTalkersTable(ifid, epoch_begin, epoch_end, host, l7proto, l4proto, port, vlan, profile)
   local breadcrumb_root = "interface"
   local container_params = ' epoch_begin="" epoch_end="" host="" peer="" l7_proto_id="" l7_proto="" l4_proto_id="" l4_proto="" '
   local host_talkers_url_params = ""
   local interface_talkers_url_params = ""
   local isv6 = isIPv6Address(host)

   interface_talkers_url_params = interface_talkers_url_params.."&epoch_begin="..epoch_begin
   interface_talkers_url_params = interface_talkers_url_params.."&epoch_end="..epoch_end

   if l7proto ~= "" and l7proto ~= nil and not string.starts(tostring(l7proto), 'all') then
      if not isnumber(l7proto) then
	 local id
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

   if vlan ~= "" and vlan ~= nil and tonumber(vlan) ~= nil then
      interface_talkers_url_params = interface_talkers_url_params.."&vlan="..tostring(vlan)
      container_params = container_params..' vlan="'..(tostring(vlan) or '')..'"'
   else
      container_params = container_params..' vlan=0 '
   end

   if profile ~= "" and profile ~= nil then
      interface_talkers_url_params = interface_talkers_url_params.."&profile="..profile
      container_params = container_params..' profile="'..(profile or '')..'"'
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
<div id="historical-container" ]] print(container_params) print[[>


  <div class="row">
    <div class="form-group">
      <div class='col-md-3'>
	<form name="top_talkers_faves">
	<i class="fa fa-heart"></i> &nbsp;talkers <span style="float:right"><small><a onclick="removeAllFavourites('top_talkers', 'talker', 'top_talkers_talker')"><i class="fa fa-trash"></i> ]] print(i18n("db_explorer.all")) print[[ </a></small></span>
	<select name="top_talkers_talker" id="top_talkers_talker" class="form-control">
	</select>
      </div>
      <div class='col-md-6'>
	 <i class="fa fa-heart"></i> &nbsp;]] print(i18n("db_explorer.app_between_talkers_pairs")) print[[ <span style="float:right"><small><a onclick="removeAllFavourites('top_talkers', 'apps_per_host_pair', 'top_talkers_host_pairs')"><i class="fa fa-trash"></i> ]] print(i18n("db_explorer.all")) print[[ </a></small></span>
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

]] historicalDownloadButtonsBar("pcap-button-top-talkers", "historical-container", not(isv6), isv6)

if allowedNetworksRestrictions() then
   print("<b>"..i18n("notes").."</b>")
   print("<li>"..i18n("note_flow_search_allowed_networks",{nets=ntop.getAllowedNetworks()}).."</li>")
   print("<li>"..i18n("note_flow_search_allowed_networks_ipv6").."</li>")
   print("<li>"..i18n("note_flow_search_allowed_networks_talkers").."</li>")
end

print [[


<script type="text/javascript">
]] commonJsUtils() print[[

var emptyBreadCrumb = function(){
  $('#bc-talkers').empty();
};

var refreshBreadCrumbInterface = function(){
  emptyBreadCrumb();
  $("#bc-talkers").append('<li>]] print(i18n("interface_ifname", {ifname=getInterfaceName(ifId)})) print [[</li>');
  $('#historical-container').removeAttr("host");
  $('#historical-container').removeAttr("peer");
  addObservationPeriodToBreadCrumb(']] print(interface_talkers_url_params) print[[', '#bc-talkers');
}

var refreshBreadCrumbHost = function(host){
  emptyBreadCrumb();
  $("#bc-talkers").append('<li><a onclick="populateInterfaceTopTalkersTable();">]] print(i18n("interface_ifname", {ifname=getInterfaceName(ifId)})) print[[</a></li>');

  // append a pair of li to the breadcrumb: the first is shown if the host has not been added to the favourites,
  // the second is shown if it has been added...

  // first pair: shown if the host has not been favorited
  $("#bc-talkers").append('<li class="bc-item-add talker">]] print(i18n("db_explorer.host_talkers", {host="' + host + '"})) print[[ <a onclick="addToFavourites(\'historical-container\', \'top_talkers\', \'talker\', \'top_talkers_talker\');"><i class="fa fa-heart-o" title="]] print(i18n("save")) print[["></i></a> </li>');

  // second pair: shown if the host has been favorited
  $("#bc-talkers").append('<li class="bc-item-remove talker">]] print(i18n("db_explorer.host_talkers", {host="' + host + '"})) print[[ <a onclick="removeFromFavourites(\'historical-container\', \'top_talkers\', \'talker\', \'top_talkers_talker\');"><i class="fa fa-heart" title="]] print(i18n("db_explorer.unsave")) print[["></i></a> </li>');

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

  addObservationPeriodToBreadCrumb(']] print(interface_talkers_url_params) print[[', '#bc-talkers');
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

  $("#bc-talkers").append('<li><a onclick="populateInterfaceTopTalkersTable();">]] print(i18n("interface_ifname", {ifname=getInterfaceName(ifId)})) print[[</a></li>');
  $("#bc-talkers").append('<li><a onclick="populateHostTopTalkersTable(\'' + peer1 + '\');">]] print(i18n("db_explorer.host_talkers", {host="' + peer1 + '"})) print[[</a></li>');

  // here we append to li: one will be shown if the pair of peers is favorited, the other is shown in the opposite case

  // first li: shown if the pair has been favorited
  var bc_talkers_li_text = ']] print(i18n("db_explorer.applications_between", {peer1="' + peer1 + '", peer2="' + peer2 + '"})) print[[';
  if (typeof l7_proto_id !== "undefined"){
    bc_talkers_li_text = '<a onclick="populateAppsPerHostsPairTable(\'' + peer1 + '\',\'' + peer2 + '\');">' + bc_talkers_li_text + '</a>';
  }

  $("#bc-talkers").append('<li class="bc-item-add host-pair">' + bc_talkers_li_text + ' <a onclick="addToFavourites(\'historical-container\', \'top_talkers\', \'apps_per_host_pair\', \'top_talkers_host_pairs\');"><i class="fa fa-heart-o" title="]] print(i18n("save")) print[["></i></a></li>');
  $('#historical-container').attr("peer", peer2);

  // second li: shown if the pair has not been favorited
  $("#bc-talkers").append('<li class="bc-item-remove host-pair">' + bc_talkers_li_text + ' <a onclick="removeFromFavourites(\'historical-container\', \'top_talkers\', \'apps_per_host_pair\', \'top_talkers_host_pairs\');"><i class="fa fa-heart" title="]] print(i18n("unsave")) print[["></i></a></li>');

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
     $("#bc-talkers").append('<li>]] print(i18n("db_explorer.application_flows")) print[[</li>');
  }

  addObservationPeriodToBreadCrumb(']] print(interface_talkers_url_params) print[[', '#bc-talkers');
}

var populateInterfaceTopTalkersTable = function(){
  refreshBreadCrumbInterface();
  hideAll("host-talkers");
  hideAll("apps-per-host-pair");
  hideAll('flows-per-host-pair');
  showOne('historical-interface', 'historical-interface-top-talkers-table');


  if ($('#historical-interface-top-talkers-table').attr("loaded") == 1) {
    enableAllDropdownsAndTabs();
  } else {
    disableAllDropdownsAndTabs();
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
	tableCallback: function(){$('#historical-interface-top-talkers-table').attr("total_rows", this.options.totalRows);enableAllDropdownsAndTabs();},
	rowCallback: function(row){
	  var addr_td = $("td:eq(1)", row[0]);
	  var label_td = $("td:eq(0)", row[0]);
	  var addr = addr_td.text();

          populateHistoricalDbExplorerLink(label_td, addr);

	  label_td.append('&nbsp;<a onclick="populateHostTopTalkersTable(\'' + addr +'\');"><i class="fa fa-pie-chart" title="]] print(i18n("db_explorer.talkers_with_this_host")) print[["></i></a>');

	  return row;
	},
	columns:
	[
	  {title: "]] print(i18n("db_explorer.host_name")) print[[",     field: "column_label",         sortable: true},
	  {title: "]] print(i18n("ip_address")) print[[",    field: "column_addr",          sortable:true, hidden: false},
	  {title: "]] print(i18n("db_explorer.traffic_sent")) print[[", field: "column_bytes_sent",     sortable: true,css: {textAlign:'right'}},
	  {title: "]] print(i18n("db_explorer.traffic_received")) print[[", field: "column_bytes_rcvd", sortable: true,css: {textAlign:'right'}},
	  {title: "]] print(i18n("db_explorer.total_traffic")) print[[", field: "column_bytes",         sortable: true,css: {textAlign:'right'}},
	  {title: "]] print(i18n("db_explorer.total_packets")) print[[", field: "column_packets",       sortable: true, css: {textAlign:'right'}},]]
	print(printFlowsCountColumn())
	print[[
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
    enableAllDropdownsAndTabs();
  } else {
    disableAllDropdownsAndTabs();
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
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);enableAllDropdownsAndTabs();},
	rowCallback: function(row){
	  var addr_td = $("td:eq(1)", row[0]);
	  var label_td = $("td:eq(0)", row[0]);
	  var addr = addr_td.text();

          populateHistoricalDbExplorerLink(label_td, addr);

	  label_td.append('&nbsp;<a onclick="populateAppsPerHostsPairTable(\'' + host +'\',\'' + addr +'\');"><i class="fa fa-exchange" title="]] print(i18n("db_explorer.applications_between", {peer1="' + host + '", peer2="' + addr + '"})) print[["></i></a>');
	  return row;
	},
	columns:
	[
	  {title: "]] print(i18n("db_explorer.host_name")) print[[",       field: "column_label",      sortable: true},
	  {title: "]] print(i18n("ip_address")) print[[",      field: "column_addr",       sortable:true, hidden: false},
	  {title: "]] print(i18n("db_explorer.traffic_sent")) print[[",    field: "column_bytes_sent", sortable: true,css: {textAlign:'right'}},
	  {title: "]] print(i18n("db_explorer.traffic_received")) print[[",field: "column_bytes_rcvd", sortable: true,css: {textAlign:'right'}},
	  {title: "]] print(i18n("db_explorer.total_traffic")) print[[",   field: "column_bytes",      sortable: true,css: {textAlign:'right'}},
	  {title: "]] print(i18n("db_explorer.total_packets")) print[[",   field: "column_packets",    sortable: true, css: {textAlign:'right'}},]]
	print(printFlowsCountColumn())
	print[[
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
    enableAllDropdownsAndTabs();
  } else {   // load the table only if it is the first time we've been called
    disableAllDropdownsAndTabs();
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
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);enableAllDropdownsAndTabs();},
	rowCallback: function(row){
	  var l7_proto_id_td = $("td:eq(0)", row[0]);
	  var label_td = $("td:eq(1)", row[0]);
	  var label = label_td.text();
	  var l7_proto_id = l7_proto_id_td.text();
          var num_flows = parseInt($("td:eq(4)", row[0]).text().replace(/[^0-9]/g, ''));

          populateHistoricalDbExplorerLink(label_td, '', l7_proto_id);

	  label_td.append('&nbsp;<a onclick="populateFlowsPerHostsPairTable(\'' + peer1 +'\',\'' + peer2 +'\',\'' + l7_proto_id +'\',\'' + num_flows +'\');"><i class="fa fa-tasks" title="]] print(i18n("db_explorer.app_flows_between", {app="' + label + '", peer1="' + peer1 + '", peer2="' + peer2 + '"})) print[["></i></a>');
	  return row;
	},
	columns:
	[
	  {title: "]] print(i18n("db_explorer.protocol_id")) print[[", field: "column_application", hidden: true},
	  {title: "]] print(i18n("application")) print[[", field: "column_label", sortable: false},
	  {title: "]] print(i18n("db_explorer.total_traffic")) print[[", field: "column_bytes", sortable: true, css: {textAlign:'right'}},
	  {title: "]] print(i18n("packets")) print[[", field: "column_packets", sortable: true, css: {textAlign:'right'}},]]
	print(printFlowsCountColumn())
	print[[
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
    enableAllDropdownsAndTabs();
  } else {   // load the table only if it is the first time we've been called
    disableAllDropdownsAndTabs();
    $(div_id).attr("loaded", 1);
    $(div_id).attr("peer1", peer1);
    $(div_id).attr("peer2", peer2);
    $(div_id).attr("l7_proto_id", l7_proto_id);
    $(div_id).datatable({
	title: "",]]
	print("url: '"..ntop.getHttpPrefix().."/lua/get_db_flows.lua?ifid="..tostring(ifId)..interface_talkers_url_params.."&peer1=' + peer1 + '&peer2=' + peer2 + '&l7_proto_id=' + l7_proto_id")

	if not useAggregatedFlows() and not allowedNetworksRestrictions() then
	   -- speed up by passing the number of flows that is already calculated when browsing raw flows
	   print("+ '&limit=' + num_flows")
	end

	print(",")
  if preference ~= "" then print ('perPage: '..preference.. ",\n") end
  -- Automatic default sorted. NB: the column must be exists.
	print [[
	post: {totalRows: function(){ return $(div_id).attr("total_rows");} },
	showFilter: true,
	showPagination: true,
totalRows: 100,
	sort: [ [ "BYTES","desc"] ],
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);enableAllDropdownsAndTabs();},
	columns:
	[
	  {title: "]] print(i18n("key")) print[[",         field: "idx",            hidden: true},
	  {title: "",            field: "FLOW_URL",       sortable:false, css:{textAlign:'center'}},
	  {title: "]] print(i18n("application")) print[[", field: "L7_PROTO",       sortable: true, css:{textAlign:'center'}},
	  {title: "]] print(i18n("db_explorer.l4_proto")) print[[",    field: "PROTOCOL",       sortable: true, css:{textAlign:'center'}},
	  {title: "]] print(i18n("client")) print[[",      field: "CLIENT",         sortable: false},
	  {title: "]] print(i18n("server")) print[[",      field: "SERVER",         sortable: false},
	  {title: "]] print(i18n("begin")) print[[",       field: "FIRST_SWITCHED", sortable: true, css:{textAlign:'center'}},
	  {title: "]] print(i18n("end")) print[[",         field: "LAST_SWITCHED",  sortable: true, css:{textAlign:'center'}},
	  {title: "]] print(i18n("traffic")) print[[",     field: "BYTES",          sortable: true, css:{textAlign:'right'}},
	  {title: "]] print(i18n("info")) print[[",        field: "INFO",           sortable: true, css:{textAlign:'right'}},
	  {title: "]] print(i18n("db_explorer.average_throughput")) print[[",    field: "AVG_THROUGHPUT", sortable: false, css:{textAlign:'right'}}
	]
    });
  }
};

// executes when the talkers tab is focused
$('a[href="#historical-top-talkers"]').on('shown.bs.tab', function (e) {
  if ($('a[href="#historical-top-talkers"]').attr("loaded") == 1){
    // do nothing if the tabs have already been computed and populated
    enableAllDropdownsAndTabs();
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

function historicalTopApplicationsTable(ifid, epoch_begin, epoch_end, host, vlan, profile)
   local breadcrumb_root = "interface"
   local container_params = ' epoch_begin="" epoch_end="" host="" peer="" l7_proto_id="" l7_proto="" l4_proto_id="" l4_proto="" '
   local top_apps_url_params=""
   local isv6 = isIPv6Address(host)

   top_apps_url_params = top_apps_url_params.."&epoch_begin="..epoch_begin
   top_apps_url_params = top_apps_url_params.."&epoch_end="..epoch_end
   
   if vlan ~= "" and vlan ~= nil and tonumber(vlan) ~= nil then
      top_apps_url_params = top_apps_url_params.."&vlan="..tostring(vlan)
      container_params = container_params..' vlan="'..(tostring(vlan) or '')..'"'
   else
      container_params = container_params..' vlan=0 '
   end

   if profile ~= "" and profile ~= nil then
      top_apps_url_params = top_apps_url_params.."&profile="..profile
      container_params = container_params..' profile="'..(profile or '')..'"'
   end

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

<div id="historical-apps-container" ]] print(container_params) print[[>

  <div class="row">
    <div class="form-group">
    <div class='col-md-3'>
      <form name="top_apps_faves">
	<i class="fa fa-heart"></i> &nbsp;]] print(i18n("protocols")) print[[ <span style="float:right"><small><a onclick="removeAllFavourites('top_applications', 'app', 'top_applications_app')"><i class="fa fa-trash"></i> ]] print(i18n("db_explorer.all")) print[[ </a></small></span>
	<select name="top_applications_app" id="top_applications_app" class="form-control">
	</select>
    </div>
    <div class='col-md-6'>
	 <i class="fa fa-heart"></i> &nbsp; host peers by protocol <span style="float:right"><small><a onclick="removeAllFavourites('top_applications', 'host_peers_by_app', 'top_applications_host_peers_by_app')"><i class="fa fa-trash"></i> ]] print(i18n("db_explorer.all")) print[[ </a></small></span>
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

]] historicalDownloadButtonsBar("pcap-button-top-protocols", "historical-apps-container", not(isv6), isv6)

if allowedNetworksRestrictions() then
   print("<b>"..i18n("notes").."</b>")
   print("<li>"..i18n("note_flow_search_allowed_networks",{nets=ntop.getAllowedNetworks()}).."</li>")
   print("<li>"..i18n("note_flow_search_allowed_networks_ipv6").."</li>")
   print("<li>"..i18n("note_flow_search_allowed_networks_applications").."</li>")
end

print [[

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
    $("#bc-apps").append('<li><a onclick="populateInterfaceTopAppsTable();">]] print(i18n("interface_ifname", {ifname=getInterfaceName(ifId)})) print[[</a></li>');
    $("#bc-apps").append('<li><a onclick="populateAppTopTalkersTable(\'' + proto_id + '\');">]] print(i18n("db_explorer.app_talkers", {app="' + app + '"})) print[[</a></li>');

    // append two li: one is to be shown when the favourites has not been added;
    // the other is shown when the favourites has been added

    // first li: there is no existing favorited peer --> app pair saved
    var bc_apps_text = ']] print(i18n("db_explorer.app_talkers_with", {app="' + app + '", peer="' + peer1 + '"})) print[[';
    if (typeof peer2 !== "undefined"){
      bc_apps_text = '<a onclick="populatePeersPerHostByApplication(\'' + peer1 + '\',\'' + proto_id + '\');">' + bc_apps_text + '</a>';
    }

    $("#bc-apps").append('<li class="bc-app-item-add host-peers-by-app">' + bc_apps_text + ' <a onclick="addToFavourites(\'historical-apps-container\', \'top_applications\', \'host_peers_by_app\', \'top_applications_host_peers_by_app\');"><i class="fa fa-heart-o" title="]] print(i18n("save")) print[["></i></a> </li>');

    // second li: there is an already existing favorited peer --> app pair saved
    $("#bc-apps").append('<li class="bc-app-item-remove host-peers-by-app"> ' + bc_apps_text + ' <a onclick="removeFromFavourites(\'historical-apps-container\', \'top_applications\', \'host_peers_by_app\', \'top_applications_host_peers_by_app\');"><i class="fa fa-heart" title="]] print(i18n("db_explorer.unsave")) print[["></i></a> </li>');

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
    $("#bc-apps").append('<li>]] print(i18n("db_explorer.protocol_flows_between", {proto="' + $(\"#historical-apps-container\").attr(\"l7_proto\") + '", peer1="' + peer1 + '", peer2="' + peer2 + '"})) print[[</li>');
  }
  addObservationPeriodToBreadCrumb(']] print(top_apps_url_params) print[[', '#bc-apps');
}

var populateInterfaceTopAppsTable = function(){
  emptyAppsBreadCrumb();
  $('#historical-apps-container').removeAttr("host");
  $("#bc-apps").append('<li>]] print(i18n("interface_ifname", {ifname=getInterfaceName(ifId)})) print[[</li>');
  addObservationPeriodToBreadCrumb(']] print(top_apps_url_params) print[[', '#bc-apps');

  hideAll("app-talkers");
  hideAll("peers-by-app");
  hideAll('flows-per-host-pair-by-app-container');
  showOne('historical-interface-apps', 'historical-interface-top-apps-table');

  if ($('#historical-interface-top-apps-table').attr("loaded") == 1) {
    enableAllDropdownsAndTabs();
  } else {
    disableAllDropdownsAndTabs();
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
      tableCallback: function(){$('#historical-interface-top-apps-table').attr("total_rows", this.options.totalRows);enableAllDropdownsAndTabs();},
      rowCallback: function(row){
	var proto_id_td = $("td:eq(0)", row[0]);
	var proto_label_td = $("td:eq(1)", row[0]);
	var proto_id = proto_id_td.text();
	var proto_label = proto_label_td.text();

        populateHistoricalDbExplorerLink(proto_label_td, '', proto_id);

	proto_label_td.append('&nbsp;<a onclick="$(\'#historical-apps-container\').attr(\'l7_proto_id\', \'' + proto_id + '\');$(\'#historical-apps-container\').attr(\'l7_proto\', \'' + proto_label + '\');populateAppTopTalkersTable(\'' + proto_id +'\');"><i class="fa fa-pie-chart" title="]] print(i18n("db_explorer.get_proto_talkers")) print[["></i></a>');
	  return row;
	},
      columns:
	[
	  {title: "]] print(i18n("db_explorer.protocol_id")) print[[", field: "column_application", hidden: true},
	  {title: "]] print(i18n("application")) print[[", field: "column_label", sortable: false},
	  {title: "]] print(i18n("db_explorer.total_traffic")) print[[", field: "column_bytes", sortable: true, css: {textAlign:'right'}},
	  {title: "]] print(i18n("packets")) print[[", field: "column_packets", sortable: true, css: {textAlign:'right'}},]]
print(printFlowsCountColumn())
print[[
	]
    });
  }
};


var populateAppTopTalkersTable = function(proto_id){
  emptyAppsBreadCrumb();
  $('#historical-apps-container').removeAttr("host");
  var app = $('#historical-apps-container').attr("l7_proto");

  // UPDATE THE BREADCRUMB
  $("#bc-apps").append('<li><a onclick="populateInterfaceTopAppsTable();">]] print(i18n("interface_ifname", {ifname=getInterfaceName(ifId)})) print[[</a></li>');

  // add two li: show the first li when no favourite has been added; show the second li in the other case
  $("#bc-apps").append('<li class="bc-app-item-add app"> ]] print(i18n("db_explorer.app_talkers", {app="' + app + '"})) print[[ <a onclick="addToFavourites(\'historical-apps-container\', \'top_applications\', \'app\', \'top_applications_app\');"><i class="fa fa-heart-o" title="]] print(i18n("save")) print[["></i></a> </li>');
  $("#bc-apps").append('<li class="bc-app-item-remove app"> ]] print(i18n("db_explorer.app_talkers", {app="' + app + '"})) print[[ <a onclick="removeFromFavourites(\'historical-apps-container\', \'top_applications\', \'app\', \'top_applications_app\');"><i class="fa fa-heart" title="]] print(i18n("db_explorer.unsave")) print[["></i></a> </li>');

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
  addObservationPeriodToBreadCrumb(']] print(top_apps_url_params) print[[', '#bc-apps');

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
    enableAllDropdownsAndTabs();
  } else {
    disableAllDropdownsAndTabs();
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
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);enableAllDropdownsAndTabs();},
	rowCallback: function(row){
	  var addr_td = $("td:eq(1)", row[0]);
	  var label_td = $("td:eq(0)", row[0]);
	  var addr = addr_td.text();

          populateHistoricalDbExplorerLink(label_td, addr, proto_id);

	  label_td.append('&nbsp;<a onclick="populatePeersPerHostByApplication(\'' + addr +'\',\'' + proto_id +'\');"><i class="fa fa-exchange" title="]] print(i18n("db_explorer.app_talkers_with", {app="' + app + '", peer="' + addr +'"})) print[["></i></a>');
	  return row;
	},
	columns:
	[
	  {title: "]] print(i18n("db_explorer.host_name")) print[[", field: "column_label", sortable: true},
	  {title: "]] print(i18n("ip_address")) print[[", field: "column_addr", hidden: false, sortable: true},
	  {title: "]] print(i18n("db_explorer.traffic_sent")) print[[",    field: "column_bytes_sent", sortable: true,css: {textAlign:'right'}},
	  {title: "]] print(i18n("db_explorer.traffic_received")) print[[",field: "column_bytes_rcvd", sortable: true,css: {textAlign:'right'}},
	  {title: "]] print(i18n("db_explorer.total_traffic")) print[[", field: "column_bytes", sortable: true,css: {textAlign:'right'}},
	  {title: "]] print(i18n("packets")) print[[", field: "column_packets", sortable: true, css: {textAlign:'right'}},]]
	print(printFlowsCountColumn())
	print[[
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
    enableAllDropdownsAndTabs();
  } else {
    disableAllDropdownsAndTabs();
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
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);enableAllDropdownsAndTabs();},
	rowCallback: function(row){
	  var addr_td = $("td:eq(1)", row[0]);
	  var label_td = $("td:eq(0)", row[0]);
	  var addr = addr_td.text();

          populateHistoricalDbExplorerLink(label_td, addr);

          var num_flows = parseInt($("td:eq(6)", row[0]).text().replace(/[^0-9]/g, ''));
          label_td.append('&nbsp;<a onclick="$(\'#historical-apps-container\').attr(\'l7_proto_id\', \'' + proto_id + '\');populateFlowsPerHostPairByApplicationTable(\'' + host +'\',\'' + addr + '\',\'' + proto_id + '\',\'' + num_flows +'\');"><i class="fa fa-tasks" title="]] print(i18n("db_explorer.protocol_flows_between", {proto="' + $(\"#historical-apps-container\").attr(\"l7_proto\") + '", peer1="' + host + '", peer2="' + addr + '"})) print[["></i></a>');
	  return row;
	},
	columns:
	[
	  {title: "]] print(i18n("db_explorer.host_name")) print[[", field: "column_label", sortable: true},
	  {title: "]] print(i18n("ip_address")) print[[", field: "column_addr", hidden: false, sortable: true},
	  {title: "]] print(i18n("db_explorer.traffic_sent")) print[[",    field: "column_bytes_sent", sortable: true,css: {textAlign:'right'}},
	  {title: "]] print(i18n("db_explorer.traffic_received")) print[[",field: "column_bytes_rcvd", sortable: true,css: {textAlign:'right'}},
	  {title: "]] print(i18n("db_explorer.total_traffic")) print[[", field: "column_bytes", sortable: true,css: {textAlign:'right'}},
	  {title: "]] print(i18n("packets")) print[[", field: "column_packets", sortable: true, css: {textAlign:'right'}},]]
	print(printFlowsCountColumn())
	print[[
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
    enableAllDropdownsAndTabs();
  } else {   // load the table only if it is the first time we've been called
    disableAllDropdownsAndTabs();
    $(div_id).attr("loaded", 1);
    $(div_id).attr("peer1", peer1);
    $(div_id).attr("peer2", peer2);
    $(div_id).attr("l7_proto_id", l7_proto_id);
    $(div_id).datatable({
	title: "",]]
	print("url: '"..ntop.getHttpPrefix().."/lua/get_db_flows.lua?ifid="..tostring(ifId)..top_apps_url_params.."&peer1=' + peer1 + '&peer2=' + peer2 + '&l7_proto_id=' + l7_proto_id")
	
	if not useAggregatedFlows() and not allowedNetworksRestrictions() then
	   -- speed up by passing the number of flows that is already calculated when browsing raw flows
	   print("+ '&limit=' + num_flows")
	end

	print(",")

	if preference ~= "" then print ('perPage: '..preference.. ",\n") end
  -- Automatic default sorted. NB: the column must be exists.
	print [[
	post: {totalRows: function(){ return $(div_id).attr("total_rows");} },
	showFilter: true,
	showPagination: true,
totalRows: 100,
	sort: [ [ "BYTES","desc"] ],
	tableCallback: function(){$(div_id).attr("total_rows", this.options.totalRows);enableAllDropdownsAndTabs();},
	columns:
	[
	  {title: "]] print(i18n("key")) print[[",         field: "idx",            hidden: true},
	  {title: "",            field: "FLOW_URL",       sortable:false, css:{textAlign:'center'}},
	  {title: "]] print(i18n("application")) print[[", field: "L7_PROTO",       sortable: true, css:{textAlign:'center'}},
	  {title: "]] print(i18n("db_explorer.l4_proto")) print[[",    field: "PROTOCOL",       sortable: true, css:{textAlign:'center'}},
	  {title: "]] print(i18n("client")) print[[",      field: "CLIENT",         sortable: false},
	  {title: "]] print(i18n("server")) print[[",      field: "SERVER",         sortable: false},
	  {title: "]] print(i18n("begin")) print[[",       field: "FIRST_SWITCHED", sortable: true, css:{textAlign:'center'}},
	  {title: "]] print(i18n("end")) print[[",         field: "LAST_SWITCHED",  sortable: true, css:{textAlign:'center'}},
	  {title: "]] print(i18n("traffic")) print[[",     field: "BYTES",          sortable: true, css:{textAlign:'right'}},
	  {title: "]] print(i18n("info")) print[[",        field: "INFO",           sortable: true, css:{textAlign:'right'}},
	  {title: "]] print(i18n("db_explorer.average_throughput")) print[[",    field: "AVG_THROUGHPUT", sortable: false, css:{textAlign:'right'}}
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
  addObservationPeriodToBreadCrumb(']] print(top_apps_url_params) print[[', '#bc-apps');

  // remove the favourite top apps dropdowns
  $('#top_applications_app').parent().closest('div').detach();
  $('#top_applications_host_peers_by_app').parent().closest('div').detach();

  hideAll("app-talkers");
  hideAll("peers-by-app");
  hideAll('flows-per-host-pair-by-app-container');
  showOne('historical-interface-apps', 'historical-interface-top-apps-table');

  if ($('#historical-interface-top-apps-table').attr("loaded") == 1) {
    enableAllDropdownsAndTabs();
  } else {
    disableAllDropdownsAndTabs();
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
      tableCallback: function(){$('#historical-interface-top-apps-table').attr("total_rows", this.options.totalRows);enableAllDropdownsAndTabs();},
	rowCallback: function(row){
	var proto_id_td = $("td:eq(0)", row[0]);
	var proto_label_td = $("td:eq(1)", row[0]);
	var proto_id = proto_id_td.text();
	var proto_label = proto_label_td.text();
        var num_flows = parseInt($("td:eq(4)", row[0]).text().replace(/[^0-9]/g, ''));

        populateHistoricalDbExplorerLink(proto_label_td, '', proto_id);

	proto_label_td.append('&nbsp;<a onclick="$(\'#historical-apps-container\').attr(\'l7_proto_id\', \'' + proto_id + '\');$(\'#historical-apps-container\').attr(\'l7_proto\', \'' + proto_label + '\');populatePeersPerHostByApplication(\'' + host +'\',\'' + proto_id +'\');"><i class="fa fa-exchange" title="]] print(i18n("db_explorer.hosts_talking_proto_with", {proto="' + proto_id + '", host="' + host + '"})) print[["></i></a>');
	  return row;
	},
      columns:
	[
	  {title: "]] print(i18n("db_explorer.protocol_id")) print[[", field: "column_application", hidden: true},
	  {title: "]] print(i18n("application")) print[[", field: "column_label", sortable: false},
	  {title: "]] print(i18n("db_explorer.total_traffic")) print[[", field: "column_bytes", sortable: true, css: {textAlign:'right'}},
	  {title: "]] print(i18n("packets")) print[[", field: "column_packets", sortable: true, css: {textAlign:'right'}},]]
print(printFlowsCountColumn())
print[[
	]
    });
  }
};


/*
This event is triggered every time the user focuses the "Protocols" tab.

The Protocols tab can be focused from two different pages:
- from the historical interface chart (e.g., http://localhost:3000/lua/if_stats.lua?if_name=en4&page=historical), and;
- from the historical host chart (e.g., http://localhost:3000/lua/host_details.lua?ifid=0&host=192.168.2.130&page=historical)

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
    enableAllDropdownsAndTabs();
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
  window.open("https://"+url+"/ntop-bin/run.cgi?script=n2disk_filemanager.cgi&opt=download_pcap&dir=/storage/n2disk/&pcap_name=/storage/n2disk/"+task_id+".pcap", "_blank");
}

var populatePcapsTable = function(){
  $("#table-pcaps").datatable({
    title: "]] print(i18n("db_explorer.pcaps")) print[[",
    url: "]] print (ntop.getHttpPrefix()) print [[/lua/get_nbox_data.lua?nbox_action=status" ,
    title: "]] print(i18n("db_explorer.pcap_requests_and_status")) print[[",
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
			     title: "]] print(i18n("db_explorer.task_id")) print[[",
				 field: "column_task_id",
				 sortable: true,
			     css: {
				textAlign: 'left'
			     }
				 },
			     {
			     title: "]] print(i18n("db_explorer.filter_bpf")) print[[",
				 field: "column_bpf",
				 sortable: true,
			     css: {
				textAlign: 'left'
			     }
				 },
			     {
			     title: "]] print(i18n("status")) print[[",
				 field: "column_status",
				 sortable: true,
			     css: {
				textAlign: 'center'
			     }

				 },
			     {
			     title: "]] print(i18n("actions")) print[[",
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
    enableAllDropdownsAndTabs();
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

-- ##########################################

function historicalFlowsTab(ifId, host, epoch_begin, epoch_end, l7proto, l4proto, port, info, vlan, profile)
   -- prepare some attributes that will be attached to divs
   local div_data = ""

   if ifId ~= "" and ifId ~= nil then
      _GET["ifid"] = ifId
      div_data = div_data..' ifid="'..tostring(ifId)..'" '
   end
   if epoch_begin ~= "" and epoch_begin ~= nil then
      _GET["epoch_begin"] = epoch_begin
      div_data = div_data..' epoch_begin="'..tostring(epoch_begin)..'" '
   end
   if epoch_end ~= "" and epoch_end ~= nil then
      _GET["epoch_end"] = epoch_end
      div_data = div_data..' epoch_end="'..tostring(epoch_end)..'" '
   end
   if host ~= "" and host ~= nil then
      _GET["host"] = host
      div_data = div_data..' host="'..tostring(host)..'" '
   end
   if l7proto ~= "" and l7proto ~= nil and not string.starts(tostring(l7proto), 'all') then
      if not isnumber(l7proto) then
	 local id = interface.getnDPIProtoId(l7proto)
	 if id ~= -1 then
	    l7proto = id
	 else
	    l7proto = ""
	 end
      end
      _GET["protocol"] = l7proto
      div_data = div_data..' l7_proto_id="'..l7proto..'" '
   end
   if l4proto ~= "" and l4proto ~= nil then
      _GET["l4proto"] = l4proto
      div_data = div_data..' l4_proto_id="'..l4proto..'" '
   end
   if port ~= "" and port ~= nil then
      _GET["port"] = port
      div_data = div_data..' port="'..port..'" '
   end
   if vlan ~= "" and vlan ~= nil then
      _GET["vlan"] = vlan
      div_data = div_data..' vlan="'..vlan..'" '
   end
   if profile ~= "" and profile ~= nil then
      _GET["profile"] = profile
      div_data = div_data..' profile="'..profile..'" '
   end

   print[[

<br>
<div class="container-fluid" id="historical-flows-container">
  <ul class="nav nav-tabs" role="tablist">
    <li class="active"> <a href="#historical-flows-summary" role="tab" data-toggle="tab"> ]] print(i18n("db_explorer.summary")) print[[ </a> </li>
]]

   print '<li id="tab-ipv4-li" style="display: none;"> <a href="#tab-ipv4" role="tab"> ' print(i18n("ipv4")) print' </a> </li>'
   print '<li id="tab-ipv6-li" style="display: none;"> <a href="#tab-ipv6" role="tab"> ' print(i18n("ipv6")) print' </a> </li>'

print [[
  </ul>

  <div class="tab-content">

    <div class="tab-pane fade in active" id="historical-flows-summary">
      <br>
      <div class="panel panel-default" id="historical-flows-summary-div">
        <div class="panel-heading"> <h3 class="panel-title">]] print(i18n("flow_search_results")) print[[&nbsp;<span id="results-from-aggregated-flows"></span></h3> </div>
        <div class="panel-body" id="historical-flows-summary-body" style="display:true;">
          <div id="flows-summary-too-slow" style="display:none;" class="alert alert-warning"></div>
          <div id="flows-summary-wait" style="display:true;">
            <img src="]] print(ntop.getHttpPrefix()) print[[/img/loading.gif"\>&nbsp;
            ]] print(i18n("db_explorer.query_in_progress")) print[[
            <button class="btn btn-danger btn-xs" type="button" onclick="abortQuery();">]] print(i18n("db_explorer.abort")) print[[</button>
          </div>
        </div>
        <table border=0 class="table table-bordered table-striped" id="flows-summary-table" style="display:none;">
           <tr>
             <th>&nbsp;</th>]]

if not useAggregatedFlows() then -- pointless to show counters for aggregations to the user
   print[[<th>]] print(i18n("db_explorer.total_flows"))print[[</th>]]
end

print[[<th>]] print(i18n("db_explorer.traffic_volume")) print[[</th>
             <th>]] print(i18n("db_explorer.total_packets")) print[[</th><th>]] print(i18n("db_explorer.traffic_rate")) print[[</th><th>]] print(i18n("db_explorer.packet_rate")) print[[</th>
           </tr>
        </table>
      </div>
]]

print[[
    </div>
]]

   print [[
    <div class="tab-pane fade" id="tab-ipv4" num_flows=0 ]] print(div_data) print[[>
      <div id="table-flows4"></div>
]] historicalDownloadButtonsBar('flows_v4', 'tab-ipv4',
				true,
				false) print[[
    </div>
]]

   print [[
    <div class="tab-pane fade" id="tab-ipv6" num_flows=0 ]] print(div_data) print[[>
      <div id="table-flows6"></div>
]] historicalDownloadButtonsBar('flows_v6', 'tab-ipv6',
				false,
				true
			       ) print[[
    </div>
]]

if allowedNetworksRestrictions() then
   print("<b>"..i18n("notes").."</b>")
   print("<li>"..i18n("note_flow_search_allowed_networks",{nets=ntop.getAllowedNetworks()}).."</li>")
   print("<li>"..i18n("note_flow_search_allowed_networks_ipv6").."</li>")
   print("<li>"..i18n("note_flow_search_allowed_networks_counter").."</li>")
end

print [[
  </div>
</div>

]]

print[[
<script type="text/javascript">

var xhr;

var abortQuery = function(){
  if(xhr && xhr.readyState != 4){
    xhr.abort();
  }
  // error message is populated in the ajax error callback
}

$('a[href="#historical-flows"]').on('shown.bs.tab', function (e) {
  if ($('a[href="#historical-flows"]').attr("loaded") == 1){
    enableAllDropdownsAndTabs();
    // do nothing if the tabs have already been computed and populated
    return;
  }

  var target = $(e.target).attr("href"); // activated tab
  $('a[href="#historical-flows"]').attr("loaded", 1);

  // disable all tabs
  $("#historical-flows-container").find("li").addClass("disabled").find("a").removeAttr("data-toggle");

  xhr = $.ajax({
    type: 'GET',]]
print("url: '"..ntop.getHttpPrefix().."/lua/get_db_data.lua?ifid="..tostring(_GET["ifid"]).."', ")
print("data: "..json.encode(_GET, nil)..",")
print[[
    complete: function() {
      $("#flows-summary-wait").hide()
    },
    error: function() {
      var err_msg = "."

      if(xhr.responseText && xhr.responseText !== "")
        err_msg = ": " + xhr.responseText + err_msg

      if(xhr.statusText === "error")
        err_msg = "An error occurred. Check database connections status" + err_msg
      else if(xhr.statusText === "abort")
        err_msg = "Query aborted" + err_msg
      else
        err_msg = "Query failed with an unknown status " + xhr.statusText + err_msg

      $("#historical-flows-summary-body").html(err_msg).show()
    },
    success: function(msg){
      if(msg.status !== "ok") {
        $("#historical-flows-summary-body").html('<H5><i class="fa fa-exclamation-triangle fa-2x"></i> ' + msg.statusText  + '</H5>').show()
        return;
      } else if(msg.count.IPv4.tot_flows <= 0 && msg.count.IPv6.tot_flows <= 0) {
        $("#historical-flows-summary-body").html('<H5><i class="fa fa-exclamation-triangle fa-2x"></i>&nbsp;]]print(i18n("error_no_search_results"))print[[</H5>').show()
        return;
      }

      // re-enable all tabs
      $("#historical-flows-container").find("li").removeClass("disabled").find("a").attr("data-toggle", "tab");

      // populate the number of flows
      $("#tab-ipv4").attr("num_flows", msg.count.IPv4.tot_flows)
      $("#tab-ipv6").attr("num_flows", msg.count.IPv6.tot_flows)

      // show tabs only if they have results
      if(msg.count.IPv4.tot_bytes > 0) {
        $("#tab-ipv4-li").show();
      }
      if(msg.count.IPv6.tot_bytes > 0) {
        $("#tab-ipv6-li").show();
      }

      var tr=""
      $.each(msg.count, function(ipvers, item){
        if(item.tot_bytes <= 0) {
          return true; // continue
        }

        tr += "<tr><th>" + ipvers + "</th>"
]]

if not useAggregatedFlows() then -- only show flow counters when querying from raw flows
print[[
        tr += "<td align='right'>" + item.tot_flows + " Flows</td>"
]]
end

print[[
        tr += "<td align='right'>" + bytesToVolume(item.tot_bytes) + "</td>"
        tr += "<td align='right'>" + formatPackets(item.tot_packets) + "</td>"
        tr += "<td align='right'>" + fbits(item.tot_bytes * 8 / msg.timespan) + "</td>"
        tr += "<td align='right'>" + fpackets(item.tot_packets / msg.timespan) + "</td>"
        tr += "</tr>"
      });

//      if(msg.aggregated_flows) {
//        $("#results-from-aggregated-flows").html("]] print(i18n("flow_search_from_aggregated")) print[[");
//      }
      $("#flows-summary-table").append(tr)
      $("#historical-flows-summary-body").remove()
      $("#flows-summary-table").show();
    }
  });


  setInterval(function() {
    var too_slow = "The database is taking too long to produce results. Consider narrowing down the scope of the query"
    too_slow += " or tune the database for performance."
    $("#flows-summary-too-slow").html(too_slow).show()
  }, 15000)

});

</script>
]]
historicalFlowsTabTables(ifId, host, epoch_begin, epoch_end, l7proto, l4proto, port, info, vlan, profile)

end

-- ##########################################

function historicalFlowsTabTables(ifId, host, epoch_begin, epoch_end, l7proto, l4proto, port, info, vlan, profile)
   local url_update = ntop.getHttpPrefix().."/lua/get_db_flows.lua?ifid="..ifId.. "&peer1="..(host or '') .. "&epoch_begin="..(epoch_begin or '').."&epoch_end="..(epoch_end or '').."&l4proto="..(l4proto or '').."&port="..(port or '').."&info="..(info or '').."&vlan="..(vlan or '').."&profile="..(profile or '')

   if(l7proto ~= "") then
      if(not(isnumber(l7proto))) then
	 local id

	 -- io.write(l7proto.."\n")
	 id = interface.getnDPIProtoId(l7proto)

	 if(id ~= -1) then
	    l7proto = id
	    ipv4_title = i18n("db_explorer.top_proto_ipv4_flows", {proto=l7proto})
	    ipv6_title = i18n("db_explorer.top_proto_ipv6_flows", {proto=l7proto})
	 else
	    l7proto = ""
	    ipv4_title = ""
	    ipv6_title = ""
	 end
      end

      if(l7proto ~= "") then
	 url_update = url_update.."&l7proto="..l7proto
      end
   end


   if((host == "") and (l4proto == "") and (port == "")) then
      ipv4_title = i18n("db_explorer.top_flows_ipv4", {date_from=formatEpoch(epoch_begin), date_to=formatEpoch(epoch_end)})
      ipv6_title = i18n("db_explorer.top_flows_ipv6", {date_from=formatEpoch(epoch_begin), date_to=formatEpoch(epoch_end)})
   else
      ipv4_title = ""
      ipv6_title = ""
   end

print [[

      <script type="text/javascript">
      $('a[href="#tab-ipv4"]').on('shown.bs.tab', function (e) {
        if ($('a[href="#tab-ipv4"]').attr("loaded") == 1){
          // do nothing if the tab has already been computed and populated
          enableAllDropdownsAndTabs();
          return;
        }

        // if here, then we actually have to load the datatable
        disableAllDropdownsAndTabs();
        $('a[href="#tab-ipv4"]').attr("loaded", 1);

   ]]

print [[
  var url_update4 = "]] print(url_update) print [[&version=4]]

if not useAggregatedFlows() and not allowedNetworksRestrictions() then
   print[[&limit=" + $("#tab-ipv4").attr("num_flows")]]
else
   -- limit computed dynamically
   print('"')
end

print[[ ;
  var graph_options4 = {
  url: url_update4,
	       perPage: 5, ]]

			      if(ipv4_title ~= "") then print('title: "'..ipv4_title..'",\n') else print("title: '',\n") end

print [[
						    showFilter: true,
						    showPagination: true,
                                                    tableCallback: function(){enableAllDropdownsAndTabs();},
						    sort: [ [ "BYTES","desc"] ],
						    columns: [
						       {
							  title: "]] print(i18n("key")) print[[",
							  field: "idx",
							  hidden: true,
						       },
						 ]]

						 if(ntop.isPro()) then
						    print [[
						       {
							  title: "",
							  field: "FLOW_URL",
							  sortable: false,
							  css: {
							     textAlign: 'center'
							  }
						       },
						 ]]
					      end

print [[
						       {
							  title: "]] print(i18n("application")) print[[",
							  field: "L7_PROTO",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "]] print(i18n("db_explorer.l4_proto")) print[[",
							  field: "PROTOCOL",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "]] print(i18n("client")) print[[",
							  field: "CLIENT",
							  sortable: false,
						       },
						       {
							  title: "]] print(i18n("server")) print[[",
							  field: "SERVER",
							  sortable: false,
						       },
						       {
							  title: "]] print(i18n("begin")) print[[",
							  field: "FIRST_SWITCHED",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "]] print(i18n("end")) print[[",
							  field: "LAST_SWITCHED",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "]] print(i18n("db_explorer.traffic_sent")) print[[",
							  field: "IN_BYTES",
							  sortable: true,
							  css: {
							     textAlign: 'right'
							  }
						       },
						       {
							  title: "]] print(i18n("db_explorer.traffic_received")) print[[",
							  field: "OUT_BYTES",
							  sortable: true,
							  css: {
							     textAlign: 'right'
							  }
						       },
						       {
							  title: "]] print(i18n("db_explorer.total_traffic")) print[[",
							  field: "BYTES",
							  sortable: true,
							  css: {
							     textAlign: 'right'
							  }
						       },
						       {
							  title: "]] print(i18n("info")) print[[",
							  field: "INFO",
							  sortable: true,
							  css: {
							     textAlign: 'left'
							  }
						       },
						       {
							  title: "]] print(i18n("db_explorer.average_throughput")) print[[",
							  field: "AVG_THROUGHPUT",
							  sortable: false,
							  css: {
							     textAlign: 'right'
							  }
						       }
						    ]

						 };



	    var table4 = $("#table-flows4").datatable(graph_options4);
]]

print[[
      });  // closes the event handler on shown.bs.tab
      ]]

print [[
      $('a[href="#tab-ipv6"]').on('shown.bs.tab', function (e) {
        if ($('a[href="#tab-ipv6"]').attr("loaded") == 1){
          // do nothing if the tab has already been computed and populated
          enableAllDropdownsAndTabs();
          return;
        }

        // if here, then we actually have to load the datatable
        disableAllDropdownsAndTabs();
        $('a[href="#tab-ipv6"]').attr("loaded", 1);


	    var url_update6 = "]] print(url_update) print [[&version=6]]

if not useAggregatedFlows() and not allowedNetworksRestrictions() then
   print[[&limit=" + $("#tab-ipv6").attr("num_flows")]]
else
   -- limit computed dynamically
   print('"')
end

print[[ ;

	    var graph_options6 = {
						    url: url_update6,
						    perPage: 5, ]]

					      if(ipv6_title ~= "") then print('title: "'..ipv6_title..'",\n') else print("title: '',\n") end

print [[

						    showFilter: true,
						    showPagination: true,
                                                    tableCallback: function(){enableAllDropdownsAndTabs();},
						    sort: [ [ "BYTES","desc"] ],
						    columns: [
						       {
							  title: "]] print(i18n("key")) print[[",
							  field: "idx",
							  hidden: true,
						       },
						 ]]

						 if(ntop.isPro()) then
						    print [[
						       {
							  title: "",
							  field: "FLOW_URL",
							  sortable: false,
							  css: {
							     textAlign: 'center'
							  }
						       },
						 ]]
					      end

print [[
						       {
							  title: "]] print(i18n("application")) print[[",
							  field: "L7_PROTO",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "]] print(i18n("db_explorer.l4_proto")) print[[",
							  field: "PROTOCOL",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "]] print(i18n("client")) print[[",
							  field: "CLIENT",
							  sortable: false,
						       },
						       {
							  title: "]] print(i18n("server")) print[[",
							  field: "SERVER",
							  sortable: false,
						       },
						       {
							  title: "]] print(i18n("begin")) print[[",
							  field: "FIRST_SWITCHED",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "]] print(i18n("end")) print[[",
							  field: "LAST_SWITCHED",
							  sortable: true,
							  css: {
							     textAlign: 'center'
							  }
						       },
						       {
							  title: "]] print(i18n("db_explorer.traffic_sent")) print[[",
							  field: "IN_BYTES",
							  sortable: true,
							  css: {
							     textAlign: 'right'
							  }
						       },
						       {
							  title: "]] print(i18n("db_explorer.traffic_received")) print[[",
							  field: "OUT_BYTES",
							  sortable: true,
							  css: {
							     textAlign: 'right'
							  }
						       },
						       {
							  title: "]] print(i18n("db_explorer.total_traffic")) print[[",
							  field: "BYTES",
							  sortable: true,
							  css: {
							     textAlign: 'right'
							  }
						       },
						       {
							  title: "]] print(i18n("db_explorer.average_throughput")) print[[",
							  field: "AVG_THROUGHPUT",
							  sortable: false,
							  css: {
							     textAlign: 'right'
							  }
						       }
						    ]

						 };


	 var table6 = $("#table-flows6").datatable(graph_options6);
      }); // closes the event handler on shown.bs.tab
	 </script>
]]

end

-- ##########################################

function historicalProtoHostHref(ifId, host, l4_proto, ndpi_proto_id, info)
   if ntop.isPro() and ntop.getPrefs().is_dump_flows_to_mysql_enabled == true then
      local hist_url = ntop.getHttpPrefix().."/lua/pro/db_explorer.lua?search=true&ifid="..ifId
      local now    = os.time()
      local ago1h  = now - 3600

      hist_url = hist_url.."&epoch_end="..tostring(now)
      if((host ~= nil) and (host ~= "")) then hist_url = hist_url.."&"..hostinfo2url(host) end
      if((l4_proto ~= nil) and (l4_proto ~= "")) then
	 hist_url = hist_url.."&l4proto="..l4_proto
      end
      if((ndpi_proto_id ~= nil) and (ndpi_proto_id ~= "")) then hist_url = hist_url.."&protocol="..ndpi_proto_id end
      if((info ~= nil) and (info ~= "")) then hist_url = hist_url.."&info="..info end
      print('&nbsp;')
      -- print('<span class="label label-info">')
      print('<a href="'..hist_url..'&epoch_begin='..tostring(ago1h)..'" title="'..i18n("db_explorer.last_hour_flows")..'"><i class="fa fa-history fa-lg"></i></a>')
      -- print('</span>')
   end
end
