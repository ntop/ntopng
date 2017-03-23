--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local host_pools_utils = require "host_pools_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

protocol     = _GET["protocol"]
asn          = _GET["asn"]
vlan         = _GET["vlan"]
network      = _GET["network"]
country      = _GET["country"]
mac          = _GET["mac"]
os_          = _GET["os"]
community    = _GET["community"]
pool         = _GET["pool"]
ipversion    = _GET["version"]

local base_url = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua"
local page_params = {}

mode = _GET["mode"]
if isEmptyString(mode) then
   mode = "all"
else
   page_params["mode"] = mode
end

hosts_filter = ''

if ((mode ~= "all") or (not isEmptyString(pool))) then
   hosts_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

prefs = ntop.getPrefs()

ifstats = interface.getStats()

print [[
      <hr>
]]

if(asn ~= nil) then
print [[
<div class="container-fluid">
  <ul class="nav nav-tabs">
    <li class="active"><a data-toggle="tab" href="#home">Hosts</a></li>
]]

if(asn ~= "0") then
print [[
    <li><a data-toggle="tab" href="#asinfo">AS Info</a></li>
    <li><a data-toggle="tab" href="#aspath">AS Path</a></li>
    <li><a data-toggle="tab" href="#geoloc">AS Geolocation</a></li>
    <li><a data-toggle="tab" href="#prefix">AS Prefixes</a></li>
    <li><a data-toggle="tab" href="#bgp">BGP Updates</a></li>
]]
end
end

print("</ul>")

if(asn ~= nil) then
print [[
  <div class="tab-content">
<div id="home" class="tab-pane fade in active">
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
   network_name = ntop.getNetworkNameById(tonumber(network))
else
   network_name = ""
end

if not isEmptyString(ipversion) then
   page_params["version"] = ipversion
end

print [[
      <div id="table-hosts"></div>
	 <script>
	 var url_update = "]] print(getPageUrl(ntop.getHttpPrefix() .. "/lua/get_hosts_data.lua", page_params)) print[[";]]

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/hosts_stats_id.inc")

if ((ifstats.vlan)) then show_vlan = true else show_vlan = false end

-- Set the host table option
if(prefs.is_categorization_enabled) then print ('host_rows_option["categorization"] = true;\n') end
if(prefs.is_httpbl_enabled) then print ('host_rows_option["httpbl"] = true;\n') end
if(show_vlan) then print ('host_rows_option["vlan"] = true;\n') end

print [[
	 host_rows_option["ip"] = true;
	 $("#table-hosts").datatable({
			title: "Hosts List",
			url: url_update ,
	 ]]

if(protocol == nil) then protocol = "" end

if(asn ~= nil) then 
	asninfo = " for AS "..asn 
else 
	asninfo = "" 
end

if(_GET["country"] ~= nil) then 
   country = " for Country ".._GET["country"] 
else 
   country = ""
end

if(_GET["mac"] ~= nil) then 
   mac = " with Mac ".._GET["mac"] 
else 
   mac = ""
end

if(_GET["os"] ~= nil) then 
   os_ = " ".._GET["os"] 
else 
   os_ = "" 
end

if(_GET["pool"] ~= nil) then
   pool_ = "for Pool "..host_pools_utils.getPoolName(ifstats.id, _GET["pool"])
else
   pool_ = ""
end

if(_GET["vlan"] ~= nil) then
  vlan_title = " [VLAN ".._GET["vlan"].."]"
else
  vlan_title = ""
end

local protocol_name = nil

if((protocol ~= nil) and (protocol ~= "")) then
   protocol_name = interface.getnDPIProtoName(tonumber(protocol))
end

if(protocol_name == nil) then protocol_name = protocol end

if(mode == "all") then
	if ( country ~= "" ) then print('title: "All '..protocol_name..' '..network_name..' Hosts'..country..vlan_title..'",\n')
	elseif ( asninfo ~= "" ) then print('title: "All '..protocol_name..' '..network_name..' Hosts'..asninfo..vlan_title..'",\n')
	elseif ( mac ~= "" ) then print('title: "All local '..protocol_name..' '..network_name..' Hosts'..mac..vlan_title..'",\n')
	elseif ( os_ ~= "" ) then print('title: "All '..os_..vlan_title..' Hosts",\n')
	elseif ( pool_ ~= "" ) then print('title: "All Hosts '..pool_..vlan_title..'",\n')
	else print('title: "All '..protocol_name..' '..network_name..' Hosts'..asninfo..vlan_title..'",\n')
	end
elseif(mode == "local") then
	if ( country ~= "" ) then print('title: "Local '..protocol_name..' '..network_name..' Hosts'..country..vlan_title..'",\n')
	elseif ( asninfo ~= "" ) then print('title: "Local '..protocol_name..' '..network_name..' Hosts'..asninfo..vlan_title..'",\n')
	elseif ( mac ~= "" ) then print('title: "Local local '..protocol_name..' '..network_name..' Hosts'..mac..vlan_title..'",\n')
	elseif ( os_ ~= "" ) then print('title: "Local Hosts'..os_..vlan_title..' Hosts",\n')
	elseif ( pool_ ~= "" ) then print('title: "Local Hosts '..pool_..vlan_title..'",\n')
	else  print('title: "Local '..protocol_name..' '..network_name..' Hosts'..country..vlan_title..'",\n')
	end
elseif(mode == "remote") then
	if ( country ~= "" ) then print('title: "Remote '..protocol_name..' '..network_name..' Hosts'..country..vlan_title..'",\n')
	elseif ( asninfo ~= "" ) then print('title: "Remote '..protocol_name..' '..network_name..' Hosts'..asninfo..vlan_title..'",\n')
	elseif ( mac ~= "" ) then print('title: "Remote local '..protocol_name..' '..network_name..' Hosts'..mac..vlan_title..'",\n')
	elseif ( os_ ~= "" ) then print('title: "Remote '..os_..vlan_title..' Hosts",\n')
	elseif ( pool_ ~= "" ) then print('title: "Remote Hosts '..pool_..vlan_title..'",\n')
	else print('title: "Remote '..protocol_name..' '..network_name..' Hosts'..country..vlan_title..'",\n')
	end
else
   print('title: "Local Networks'..country..vlan_title..'",\n')
end
print ('rowCallback: function ( row ) { return host_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("hosts") ..'","' .. getDefaultTableSortOrder("hosts").. '"] ],')

print [[    showPagination: true, ]]

if(page_params.network ~= nil) then
   print('buttons: [ \'')

   print('<A HREF="'..ntop.getHttpPrefix()..'/lua/network_details.lua?page=historical&network='..network..'"><i class=\"fa fa-area-chart fa-lg\"></i></A>')
   print('\' ],')
else
   print('buttons: [ ')

   local more_buttons
   if (page_params.pool ~= nil) and (isAdministrator()) and (pool ~= host_pools_utils.DEFAULT_POOL_ID) then
      more_buttons = '<A HREF="'..ntop.getHttpPrefix()..'/lua/if_stats.lua?page=pools&pool='..pool..'#manage"><i class=\"fa fa-users fa-lg\"></i></A>'
   else
      more_buttons = ''
   end

   -- Ip version selector
   print[['<div class="btn-group pull-right">]]
   printIpVersionDropdown(base_url, page_params)
   print[[</div>']]

   -- Hosts filter
   local hosts_filter_params = table.clone(page_params)

   print(', \'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Filter Hosts'..hosts_filter..'<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" style="min-width: 90px;"><li><a href="')

   hosts_filter_params.mode = nil
   hosts_filter_params.pool = nil
   print (getPageUrl(base_url, hosts_filter_params))
   print ('">All Hosts</a></li>')

   hosts_filter_params.mode = "local"
   print('<li')
   if mode == hosts_filter_params.mode then print(' class="active"') end
   print('><a href="')
   print (getPageUrl(base_url, hosts_filter_params))
   print ('">Local Hosts Only</a></li>')

   hosts_filter_params.mode = "remote"
   print('<li')
   if mode == hosts_filter_params.mode then print(' class="active"') end
   print('><a href="')
   print (getPageUrl(base_url, hosts_filter_params))
   print ('">Remote Hosts Only</a></li>')

   -- Host pools
   if not ifstats.isView then
      hosts_filter_params.mode = nil
      hosts_filter_params.pool = nil
      print('<li role="separator" class="divider"></li>')
      for _, _pool in ipairs(host_pools_utils.getPoolsList(ifstats.id)) do
        hosts_filter_params.pool = _pool.id
        print('<li')
        if pool == _pool.id then print(' class="active"') end
        print('><a href="'..getPageUrl(base_url, hosts_filter_params)..'">Host Pool '..(_pool.name)..'</li>')
      end
   end

   print('</ul></div>\'')
   
   print(' ],')
end

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

if(show_vlan) then
if(ifstats.sprobe) then
   print('{ title: "Source Id",\n')
else
   if(ifstats.vlan) then
     print('{ title: "VLAN",\n')
   end
end


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
			     title: "Location",
				 field: "column_location",
				 sortable: false,
	 	             css: { 
			        textAlign: 'center'
			     }

				 },			     
			     {
			     title: "Flows",
				 field: "column_num_flows",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			     }

				 },			     
]]

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/hosts_stats_top.inc")

print [[

			     {
			     title: "ASN",
				 field: "column_asn",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			     }

				 },

]]


if(prefs.is_httpbl_enabled) then
print [[
			     {
			     title: "HTTP:BL",
				 field: "column_httpbl",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			       }
			       },
		       ]]
end


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/hosts_stats_bottom.inc")

if(asn ~= nil) then
print [[
</div>

<script src="/js/ripe_widget_api.js"></script>

<div id="asinfo" class="tab-pane fade">
<div class="statwdgtauto"><script>ripestat.init("registry-browser",{"resource":"AS]] print(asn) print [["},null,{"disable":["controls"]})</script></div>
</div>

<div id="aspath" class="tab-pane fade">
<div class="statwdgtauto"><script>ripestat.init("as-path-length",{"resource":"AS]] print(asn) print [["},null,{"disable":["controls"]})</script></div>
</div>

<div id="geoloc" class="tab-pane fade">
<div class="statwdgtauto"><script>ripestat.init("geoloc",{"resource":"AS]] print(asn) print [["},null,{"disable":["controls"]})</script></div>
</div>

<div id="prefix" class="tab-pane fade">
<div class="statwdgtauto"><script>ripestat.init("announced-prefixes",{"resource":"AS]] print(asn) print [["},null,{"disable":["controls"]})</script></div>
</div>

<div id="bgp" class="tab-pane fade">
<div class="statwdgtauto"><script>ripestat.init("bgp-update-activity",{"resource":"AS]] print(asn) print [["},null,{"disable":["controls"]})</script></div>
</div>
</div>
]]

if(asn ~= nil and asn ~= "0") then
   -- direct html is not allowed in the title so we must place the link using javascript
   -- using datatable method tableCallback gives strange effects such as a quick blink of the link
   print[[
<script type="text/javascript">

          $('h2:contains("for AS")').append("<small>&nbsp;<i class=\"fa fa-info-circle fa-sm\" aria-hidden=\"true\"></i> <A HREF=\"https://stat.ripe.net/AS]] print(asn) print[[\"><i class=\"fa fa-external-link fa-sm\" title=\"More Information about AS ]] print(asn) print[[\"></i></A></small>");

</script>
]]
end



end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
