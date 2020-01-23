--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local host_pools_utils = require "host_pools_utils"
local ts_utils = require("ts_utils")
local page_utils = require("page_utils")
local custom_column_utils = require("custom_column_utils")
local discover = require("discover_utils")
active_page = "hosts"
local have_nedge = ntop.isnEdge()

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("hosts"))

local protocol     = _GET["protocol"]
local asn          = _GET["asn"]
local vlan         = _GET["vlan"]
local network      = _GET["network"]
local cidr         = _GET["network_cidr"]
local country      = _GET["country"]
local mac          = _GET["mac"]
local os_          = _GET["os"]
local community    = _GET["community"]
local pool         = _GET["pool"]
local ipversion    = _GET["version"]
local traffic_type = _GET["traffic_type"]

local base_url = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua"
local page_params = {}
local charts_icon = ""

local mode = _GET["mode"]
if isEmptyString(mode) then
   mode = "all"
else
   page_params["mode"] = mode
end

local hosts_filter = ''

if ((mode ~= "all") or (not isEmptyString(pool))) then
   hosts_filter = '<span class="fas fa-filter"></span>'
end

local active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

prefs = ntop.getPrefs()

ifstats = interface.getStats()

if (_GET["page"] ~= "historical") then
   if(asn ~= nil) then
      print [[
<div class="container-fluid">
  <ul class="nav nav-tabs">
    <li class="nav-item" class="active"><a class="nav-link active" data-toggle="tab" href="#home">]] print(i18n("hosts_stats.hosts")) print[[</a></li>
]]

      if(asn ~= "0") then
	 print [[
    <li class="nav-item"><a class="nav-link" data-toggle="tab" href="#asinfo">]] print(i18n("hosts_stats.as_info")) print[[</a></li>
    <li class="nav-item"><a class="nav-link" data-toggle="tab" href="#aspath">]] print(i18n("hosts_stats.as_path")) print[[</a></li>
    <li class="nav-item"><a class="nav-link" data-toggle="tab" href="#geoloc">]] print(i18n("hosts_stats.as_geolocation")) print[[</a></li>
    <li class="nav-item"><a class="nav-link" data-toggle="tab" href="#prefix">]] print(i18n("hosts_stats.as_prefixes")) print[[</a></li>
    <li class="nav-item"><a class="nav-link" data-toggle="tab" href="#bgp">]] print(i18n("hosts_stats.bgp_updates")) print[[</a></li>
]]
      end
   end

   print("</ul>")

   if(asn ~= nil) then
      print [[
  <div class="tab-content">
<div id="home" class="tab-pane in active">
]]
   end

   -- build the current filter url

   page_params["os"] = os_
   page_params["asn"] = asn
   page_params["community"] = community
   page_params["vlan"] = vlan
   page_params["country"] = country
   page_params["mac"] = mac
   page_params["pool"] = pool
   page_params["network_cidr"] = cidr

   if(protocol ~= nil) then
      -- Example HTTP.Facebook
      dot = string.find(protocol, '%.')
      if(dot ~= nil) then
	 protocol = string.sub(protocol, dot+1)
      end

      page_params["protocol"] = protocol
   end

   if(network ~= nil) then
      page_params["network"] = network
      local network_key = ntop.getNetworkNameById(tonumber(network))
      network_name = getLocalNetworkAlias(network_key)

      if not isEmptyString(network_name) then
         local charts_available = ts_utils.exists("subnet:traffic", {ifid=ifstats.id, subnet=network_key})

         charts_icon = " <small><a href='".. ntop.getHttpPrefix() .."/lua/network_details.lua?network="..
            network .. "&page=config'><i class='fas fa-sm fa-cog'></i></a>"

         if charts_available then
            charts_icon = charts_icon.."&nbsp; <a href='".. ntop.getHttpPrefix() .."/lua/network_details.lua?network="..
               network .. "&page=historical'><i class='fas fa-sm fa-chart-area'></i></a>"
         end

         charts_icon = charts_icon.."</small>"
      else
         network_name = i18n("hosts_stats.remote")
      end
   else
      network_name = ""
   end

   local ipver_title
   if not isEmptyString(ipversion) then
      page_params["version"] = ipversion
      ipver_title = i18n("hosts_stats.ipver_title",{version_num=ipversion})
   else
      ipver_title = ""
   end

   local traffic_type_title
   if not isEmptyString(traffic_type) then
      page_params["traffic_type"] = traffic_type

      if traffic_type == "one_way" then
	 traffic_type_title = i18n("hosts_stats.traffic_type_one_way")
      elseif traffic_type == "bidirectional" then
	 traffic_type_title = i18n("hosts_stats.traffic_type_two_ways")
      end
   else
      traffic_type_title = ""
   end

   custom_column_utils.updateCustomColumn()
   local custom_name, custom_key, custom_align = custom_column_utils.getCustomColumnName()

   print [[
      <div id="table-hosts"></div>
	 <script>
	 var url_update = "]] print(getPageUrl(ntop.getHttpPrefix() .. "/lua/get_hosts_data.lua", page_params)) print[[";]]

   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/hosts_stats_id.inc")

   if ((ifstats.vlan)) then show_vlan = true else show_vlan = false end

   if(show_vlan) then print ('host_rows_option["vlan"] = true;\n') end

   print [[
	 host_rows_option["ip"] = true;
         host_rows_option["custom_column"] = "]] print(custom_key) print[[";
	 $("#table-hosts").datatable({
			title: "]] print(i18n("hosts_stats.hosts_list")) print[[",
			url: url_update ,
	 ]]

   if(protocol == nil) then protocol = "" end

   if(asn ~= nil) then 
      asninfo = " " .. i18n("hosts_stats.asn_title",{asn=asn}) ..
	 "<small>&nbsp;<i class='fas fa-info-circle fa-sm' aria-hidden='true'></i> <A HREF='https://stat.ripe.net/AS"..
	 asn .. "'><i class='fas fa-external-link-alt fa-sm' title=\\\"".. i18n("hosts_stats.more_info_about_as_popup_msg") ..
	 "\\\"></i></A></small>"
   end

   if(_GET["country"] ~= nil) then 
      country = " " .. i18n("hosts_stats.country_title",{country=_GET["country"]})
   end

   if(_GET["mac"] ~= nil) then 
      mac = " " .. i18n("hosts_stats.mac_title",{mac=_GET["mac"]})
   end

   if(_GET["os"] ~= nil) then 
      os_ = " ".._GET["os"] 
   end

   if(_GET["pool"] ~= nil) then
      local charts_available = ntop.getCache("ntopng.prefs.host_pools_rrd_creation") == "1" and ts_utils.exists("host_pool:traffic", {ifid=ifstats.id, pool=_GET["pool"]}) and ntop.isPro()
      local pool_edit = ""

      if (_GET["pool"] ~= host_pools_utils.DEFAULT_POOL_ID) or (have_nedge) then
	 local pool_link
    local title

	 if have_nedge then
	    pool_link = "/lua/pro/nedge/admin/nf_edit_user.lua?username=" ..
         ternary(_GET["pool"] == host_pools_utils.DEFAULT_POOL_ID, "", host_pools_utils.poolIdToUsername(_GET["pool"]))
       title = i18n("nedge.edit_user")
	 else
	    pool_link = "/lua/if_stats.lua?page=pools&pool=".._GET["pool"]
       title = i18n("host_pools.manage_pools")
	 end

	 pool_edit = "&nbsp; <A HREF='"..ntop.getHttpPrefix()..pool_link.."'><i class='fas fa-cog fa-sm' title='"..title .. "'></i></A>"

      end

      pool_ = " "..i18n(ternary(have_nedge, "hosts_stats.user_title", "hosts_stats.pool_title"),
			{poolname=host_pools_utils.getPoolName(ifstats.id, _GET["pool"])})
	 .."<small>".. pool_edit ..
	 ternary(charts_available, "&nbsp; <A HREF='"..ntop.getHttpPrefix().."/lua/pool_details.lua?page=historical&pool=".._GET["pool"].."'><i class='fas fa-chart-area fa-sm' title='"..i18n("chart") .. "'></i></A>", "")..
	 "</small>"
   end

   if(_GET["vlan"] ~= nil) then
      vlan_title = " ["..i18n("hosts_stats.vlan_title",{vlan=_GET["vlan"]}).."]"
   end

   local protocol_name = nil

   if((protocol ~= nil) and (protocol ~= "")) then
      protocol_name = interface.getnDPIProtoName(tonumber(protocol))
   end

   if(protocol_name == nil) then protocol_name = protocol end

   if not isEmptyString(protocol_name) then
      charts_icon = " <a href='".. ntop.getHttpPrefix() .."/lua/if_stats.lua?ifid="..
         ifstats.id .. "&page=historical&ts_schema=iface:ndpi&protocol=" .. protocol_name..
         "'><i class='fas fa-sm fa-chart-area'></i></a>"
   end

   function getPageTitle()
      local mode_label = ""

      if mode == "remote" then
	 mode_label = i18n("hosts_stats.remote")
      elseif mode == "local" then
	 mode_label = i18n("hosts_stats.local")
      elseif mode == "filtered" then
	 mode_label = i18n("hosts_stats.filtered")
      elseif mode == "blacklisted" then
	 mode_label = i18n("hosts_stats.blacklisted")
      elseif mode == "dhcp" then
	 mode_label = i18n("nedge.network_conf_dhcp")
      end

      -- Note: we must use the empty string as fallback. Multiple spaces will be collapsed into one automatically.
      return i18n("hosts_stats.hosts_page_title", {
		     all = isEmptyString(mode_label) and i18n("hosts_stats.all") or "",
		     traffic_type = traffic_type_title or "",
		     local_remote = mode_label,
		     protocol = protocol_name or "",
		     network = not isEmptyString(network_name) and i18n("hosts_stats.in_network", {network=network_name}) or "",
		     network_cidr = not isEmptyString(cidr) and i18n("hosts_stats.in_network", {network=cidr}) or "",
		     ip_version = ipver_title or "",
		     ["os"] = discover.getOsName(os_),
		     country_asn_or_mac = country or asninfo or mac or pool_ or "",
		     vlan = vlan_title or "",
      }) .. charts_icon
   end

   print('title: "'..getPageTitle()..'",\n')
   print ('rowCallback: function ( row ) { return host_table_setID(row); },')

   print [[
       tableCallback: function()  { $("#dt-bottom-details > .float-left > p").first().append('. ]]
   print(i18n('hosts_stats.idle_hosts_not_listed'))
   print[['); },
]]

   -- Set the preference table
   preference = tablePreferences("rows_number",_GET["perPage"])
   if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

   -- Automatic default sorted. NB: the column must exist.
   print ('sort: [ ["' .. getDefaultTableSort("hosts") ..'","' .. getDefaultTableSortOrder("hosts").. '"] ],')

   print [[    showPagination: true, ]]

   print('buttons: [ ')

   
   --[[ if((page_params.network ~= nil) and (page_params.network ~= "-1")) then
      print('\'<div class="btn-group float-right"><A HREF="'..ntop.getHttpPrefix()..'/lua/network_details.lua?page=historical&network='..network..'"><i class=\"fas fa-chart-area fa-lg\"></i></A></div>\', ')
      elseif (page_params.pool ~= nil) and (isAdministrator()) and (pool ~= host_pools_utils.DEFAULT_POOL_ID) then
      print('\'<div class="btn-group float-right"><A HREF="'..ntop.getHttpPrefix()..'/lua/if_stats.lua?page=pools&pool='..pool..'#manage"><i class=\"fas fa-users fa-lg\"></i></A></div>\', ')
      end]]

   -- Ip version selector
   print[['<div class="btn-group float-right">]]
   custom_column_utils.printCustomColumnDropdown(base_url, page_params)
   print[[</div>']]
   

   -- Ip version selector
   print[[, '<div class="btn-group float-right">]]
   printIpVersionDropdown(base_url, page_params)
   print[[</div>']]

   -- VLAN selector
   if ifstats.vlan then
      print[[, '<div class="btn-group float-right">]]
      printVLANFilterDropdown(base_url, page_params)
      print[[</div>']]
   end

   print[[, '<div class="btn-group float-right">]]
   printTrafficTypeFilterDropdown(base_url, page_params)
   print[[</div>']]

   -- Hosts filter
   local hosts_filter_params = table.clone(page_params)

   print(', \'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..i18n("hosts_stats.filter_hosts")..hosts_filter..'<span class="caret"></span></button> <ul class="dropdown-menu scrollable-dropdown" role="menu" style="min-width: 90px;"><li"><a class="dropdown-item" href="')

   hosts_filter_params.mode = nil
   hosts_filter_params.pool = nil
   print (getPageUrl(base_url, hosts_filter_params))
   print ('">'..i18n("hosts_stats.all_hosts")..'</a></li>')

   hosts_filter_params.mode = "local"
   print('<li ')
   print('"><a class="dropdown-item" href="')
   print (getPageUrl(base_url, hosts_filter_params))
   print ('">'..i18n("hosts_stats.local_hosts_only")..'</a></li>')

   hosts_filter_params.mode = "remote"
   print('<li ')
   print('"><a class="dropdown-item" href="')
   print (getPageUrl(base_url, hosts_filter_params))
   print ('">'..i18n("hosts_stats.remote_hosts_only")..'</a></li>')

   if interface.isPacketInterface() and not interface.isPcapDumpInterface() then
      hosts_filter_params.mode = "dhcp"
      print('<li ')
      print('"><a class="dropdown-item" href="')
      print (getPageUrl(base_url, hosts_filter_params))
      print ('">'..i18n("mac_stats.dhcp_only")..'</a></li>')

      hosts_filter_params.mode = "broadcast_domain"
      print('<li ')
      print('"><a class="dropdown-item" href="')
      print (getPageUrl(base_url, hosts_filter_params))
      print ('">'..i18n("hosts_stats.broadcast_domain_hosts_only")..'</a></li>')
   end

   hosts_filter_params.mode = "blacklisted"
   print('<li ')
   print('"><a class="dropdown-item" href="')
   print (getPageUrl(base_url, hosts_filter_params))
   print ('">'..i18n("hosts_stats.blacklisted_hosts_only")..'</a></li>')

   if isBridgeInterface(ifstats) then
      hosts_filter_params.mode = "filtered"
      print('<li ')
      print('"><a class="dropdown-item" href="')
      print (getPageUrl(base_url, hosts_filter_params))
      print ('">'..i18n("hosts_stats.filtered_hosts_only")..'</a></li>')
   end

   -- Host pools
   if not ifstats.isView then
      hosts_filter_params.mode = nil
      hosts_filter_params.pool = nil
      print('<li role="separator" class="divider"></li>')
      for _, _pool in ipairs(host_pools_utils.getPoolsList(ifstats.id)) do
	 hosts_filter_params.pool = _pool.id
	 print('<li ')
	 print('"><a class="dropdown-item" href="'..getPageUrl(base_url, hosts_filter_params)..'">'
		  ..i18n(ternary(have_nedge, "hosts_stats.user", "hosts_stats.host_pool"),
			 {pool_name=string.gsub(_pool.name, "'", "\\'")}) ..'</li>')
      end
   end

   print('</ul></div>\'')

   print(' ],')

   print [[
	        columns: [
	        	{
	        		title: "Key",
         			field: "key",
         			hidden: true,
         			css: {
                                  textAlign: 'center'
                                }
         		},{
			     title: "",
				 field: "column_info",
				 sortable: false,
	 	             css: {
			        textAlign: 'center'
			     }
         		},{
			     title: "]] print(i18n("ip_address")) print[[",
				 field: "column_ip",
				 sortable: true,
	 	             css: {
			        textAlign: 'left'
			     }
                        },
			  ]]

   if(show_vlan) then
      print('{ title: "'..i18n("vlan")..'",\n')
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
			     title: "]] print(i18n("hosts_stats.location")) print[[",
				 field: "column_location",
				 sortable: false,
	 	             css: { 
			        textAlign: 'center'
			     }

				 },			     
			     {
			     title: "]] print(i18n("flows")) print[[",
				 field: "column_num_flows",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			     }

				 },  {
			     title: "]] print(i18n("if_stats_overview.blocked_flows")) print[[",
				 field: "column_num_dropped_flows",
				 sortable: true,
                                 hidden: ]]
   if isBridgeInterface(ifstats) then
      print("false")
   else
      print("true")
   end
   print[[,
	 	             css: { 
			        textAlign: 'center'
			     }

				 },  {
			     title: "]]
   -- tprint({custom_name = custom_name, custom_key = custom_key, custom_align = custom_align})
   print(custom_name)
   print[[",
				 field: "column_]] print(custom_key) print[[",
				 sortable: true,
	 	             css: {
			        textAlign: ']] print(custom_align) print[['
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
				 }, {
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
			     title: "]] print(i18n("flows_page.total_bytes")) print[[",
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

   if(have_nedge) then
      print[[
<script>
  var block_host_csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

  function block_host(host_key, host_url) {
    var url = "]] print(ntop.getHttpPrefix()) print[[/lua/pro/nedge/toggle_block_host.lua?" + host_url;
    $.ajax({
      type: 'GET',
      url: url,
      cache: false,
      data: {
        csrf: block_host_csrf
      },
      success: function(content) {
        var data = jQuery.parseJSON(content);
        block_host_csrf = data.csrf;
        if (data.status == "BLOCKED") {
          $('#'+host_key+'_info').find('.block-badge')
            .removeClass('badge-secondary').addClass('badge-danger');
          $('#'+host_key+'_ip').find('a').css("text-decoration", "line-through");
        } else if (data.status == "UNBLOCKED") {
          $('#'+host_key+'_info').find('.block-badge')
            .removeClass('badge-danger').addClass('badge-secondary');
          $('#'+host_key+'_ip').find('a').css("text-decoration", "none");
        }
      },
      error: function(content) {
        console.log("error");
      }
    });
  }
</script>
]]
   end


   if(asn ~= nil) then
      print [[
</div>

<script src="/js/ripe_widget_api.js"></script>

<div id="asinfo" class="tab-pane"></div>
<div id="aspath" class="tab-pane"></div>
<div id="geoloc" class="tab-pane"></div>
<div id="prefix" class="tab-pane"></div>
<div id="bgp" class="tab-pane"></div>

</div>

<script>
   $(document).ready(function() {
      var tab_id_to_widget = {
         "#asinfo": "iana-registry-info",
         "#aspath": "as-path-length",
         "#geoloc": "geoloc",
         "#prefix": "announced-prefixes",
         "#bgp": "bgp-update-activity",
      };
      var loaded_widgets = {};

      function load_widget(tab_id) {
         var widget = tab_id_to_widget[tab_id];

         if((typeof(widget) === "undefined") || loaded_widgets[widget])
            return;

         var tab = $(tab_id);
         var script = $("<script>")
         var div = $('<div class="statwdgtauto"></div>');
         script.text('ripestat.init("' + widget + '",{"resource":"AS]] print(asn) print [["},null,{"disable":["controls"]});');
         script.appendTo(div);
         div.appendTo(tab);

         loaded_widgets[widget] = true;
      }

      $('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
         var target = $(e.target).attr("href") // activated tab
         load_widget(target);
      });
   });
</script>
]]
   end -- if(asn ~= nil)
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
