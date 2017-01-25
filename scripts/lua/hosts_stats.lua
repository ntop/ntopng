--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

protocol     = _GET["protocol"]
net          = _GET["net"]
asn          = _GET["asn"]
vlan         = _GET["vlan"]
network      = _GET["network"]
country      = _GET["country"]
mac          = _GET["mac"]
os_          = _GET["os"]
community    = _GET["community"]
pool         = _GET["pool"]

mode = _GET["mode"]
if(mode == nil) then mode = "all" end

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
local filter_base_url = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua"
local filter_url_params = {}

filter_url_params["mode"] = mode
filter_url_params["os"] = os_
filter_url_params["net"] = net
filter_url_params["asn"] = asn
filter_url_params["community"] = community
filter_url_params["vlan"] = vlan
filter_url_params["country"] = country
filter_url_params["mac"] = mac
filter_url_params["pool"] = pool

if(protocol ~= nil) then
   -- Example HTTP.Facebook
   dot = string.find(protocol, '%.')
   if(dot ~= nil) then
      protocol = string.sub(protocol, dot+1)
   end

   filter_url_params["protocol"] = protocol
end

if(network ~= nil) then
   filter_url_params["network"] = network
   network_name = ntop.getNetworkNameById(tonumber(network))
else
   network_name = ""
end

function getPageUrl(params, base_url)
   local base_url = base_url or filter_base_url
   return base_url .. "?" .. table.tconcat(params, "=", "&")
end

print [[
      <div id="table-hosts"></div>
	 <script>
	 var url_update = "]] print(getPageUrl(filter_url_params, ntop.getHttpPrefix() .. "/lua/get_hosts_data.lua")) print[[";]]

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

if(_GET["asn"] ~= nil) then 
	asninfo = " for AS ".._GET["asn"] 
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

if(mode == "all") then
	if ( country ~= "" ) then print('title: "All '..protocol..' '..network_name..' Hosts'..country..'",\n')
	elseif ( asninfo ~= "" ) then print('title: "All '..protocol..' '..network_name..' Hosts'..asninfo..'",\n')
	elseif ( mac ~= "" ) then print('title: "All local '..protocol..' '..network_name..' Hosts'..mac..'",\n')
	elseif ( os_ ~= "" ) then print('title: "All '..os_..' Hosts",\n') 
	else print('title: "All '..protocol..' '..network_name..' Hosts'..asninfo..'",\n')
	end
elseif(mode == "local") then
	if ( country ~= "" ) then print('title: "Local '..protocol..' '..network_name..' Hosts'..country..'",\n')
	elseif ( asninfo ~= "" ) then print('title: "Local '..protocol..' '..network_name..' Hosts'..asninfo..'",\n')
	elseif ( mac ~= "" ) then print('title: "Local local '..protocol..' '..network_name..' Hosts'..mac..'",\n')
	elseif ( os_ ~= "" ) then print('title: "Local Hosts'..os_..' Hosts",\n') 
	else  print('title: "Local '..protocol..' '..network_name..' Hosts'..country..'",\n')
	end
elseif(mode == "remote") then
	if ( country ~= "" ) then print('title: "Remote '..protocol..' '..network_name..' Hosts'..country..'",\n')
	elseif ( asninfo ~= "" ) then print('title: "Remote '..protocol..' '..network_name..' Hosts'..asninfo..'",\n')
	elseif ( mac ~= "" ) then print('title: "Remote local '..protocol..' '..network_name..' Hosts'..mac..'",\n')
	elseif ( os_ ~= "" ) then print('title: "Remote '..os_..' Hosts",\n') 
	else print('title: "Remote '..protocol..' '..network_name..' Hosts'..country..'",\n')
	end
else
   print('title: "Local Networks'..country..'",\n')
end
print ('rowCallback: function ( row ) { return host_table_setID(row); },')


-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("hosts") ..'","' .. getDefaultTableSortOrder("hosts").. '"] ],')

print [[    showPagination: true, ]]

if(filter_url_params.network == nil) then
   local hosts_filter_params = table.clone(filter_url_params)

   print('buttons: [ \'<div class="btn-group pull-right"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Filter Hosts<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" style="min-width: 90px;"><li><a href="')

   hosts_filter_params.mode = nil
   print (getPageUrl(hosts_filter_params))
   print ('">All Hosts</a></li><li><a href="')

   hosts_filter_params.mode = "local"
   print (getPageUrl(hosts_filter_params))
   print ('">Local Hosts Only</a></li><li><a href="')

   hosts_filter_params.mode = "remote"
   print (getPageUrl(hosts_filter_params))
   print ('">Remote Hosts Only</a></li>')
   print("</ul></div>' ],")
else
   print('buttons: [ \'')

   print('<A HREF='..ntop.getHttpPrefix()..'/lua/network_details.lua?page=historical&network='..network..'><i class=\"fa fa-area-chart fa-lg\"></i></A>')
   print('\' ],')
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

if(asn ~= "0") then
   print ("<i class=\"fa fa-info-circle fa-lg\" aria-hidden=\"true\"></i> <A HREF=https://stat.ripe.net/AS"..asn..">More Information about AS"..asn.."</A>  <i class=\"fa fa-external-link\"></i>")
end
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
