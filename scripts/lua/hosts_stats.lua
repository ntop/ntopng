--
-- (C) 2013-16 - ntop.org
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
antenna_mac  = _GET["antenna_mac"]
mac          = _GET["mac"]
os_   	     = _GET["os"]
community    = _GET["community"]

mode = _GET["mode"]
if(mode == nil) then mode = "all" end

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

prefs = ntop.getPrefs()

ifstats = aggregateInterfaceStats(interface.getStats())

print [[
      <hr>
      <div id="table-hosts"></div>
	 <script>
	 var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_hosts_data.lua?mode=]]
print(mode)

if(protocol ~= nil) then
   -- Example HTTP.Facebook
   dot = string.find(protocol, '%.')
   if(dot ~= nil) then
      protocol = string.sub(protocol, dot+1)
   end

   print('&protocol='..protocol)
end

if(os_ ~= nil) then
   print('&os='..os_)
end

if(net ~= nil) then
   print('&net='..net)
end

if(asn ~= nil) then
   print('&asn='..asn)
end

if(community ~= nil) then
   print('&community='..community)
end

if(vlan ~= nil) then
   print('&vlan='..vlan)
end

if(country ~= nil) then
   print('&country='..country)
end

if(network ~= nil) then
   network_url='&network='..network
   print(network_url)
   network_name = ntop.getNetworkNameById(tonumber(network))
else
   network_name = ""
   network_url  = ""
end

if(antenna_mac ~= nil) then
   print('&antenna_mac='..antenna_mac)
end

if(mac ~= nil) then
   print('&mac='..mac)
end

print ('";')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/hosts_stats_id.inc")

if ((ifstats.vlan)) then show_vlan = true else show_vlan = false end

-- Set the host table option
if(prefs.is_categorization_enabled) then print ('host_rows_option["categorization"] = true;\n') end
if(prefs.is_httpbl_enabled) then print ('host_rows_option["httpbl"] = true;\n') end
if(show_vlan) then print ('host_rows_option["vlan"] = true;\n') end

if(antenna_mac ~= nil) then
   am = "antenna_mac="..antenna_mac
   am_str = " [Antenna "..antenna_mac.."]"
else
   am = nil
   am_str = ""
end

print [[
	 host_rows_option["ip"] = true;
	 $("#table-hosts").datatable({
			title: "Hosts List]] print(am_str) print [[",
			url: url_update ,
	 ]]

if(protocol == nil) then protocol = "" end

if(_GET["asn"] ~= nil) then 
	asn = " for AS ".._GET["asn"] 
else 
	asn = "" 
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
	elseif ( asn ~= "" ) then print('title: "All '..protocol..' '..network_name..' Hosts'..asn..'",\n')
	elseif ( mac ~= "" ) then print('title: "All local '..protocol..' '..network_name..' Hosts'..mac..'",\n')
	elseif ( os_ ~= "" ) then print('title: "All '..os_..' Hosts",\n') 
	elseif ( am_str ~= "" ) then print('title: "All '..os_..' Hosts'..am_str..'",\n') 
	else print('title: "All '..protocol..' '..network_name..' Hosts'..asn..'",\n')
	end
elseif(mode == "local") then
	if ( country ~= "" ) then print('title: "Local '..protocol..' '..network_name..' Hosts'..country..'",\n')
	elseif ( asn ~= "" ) then print('title: "Local '..protocol..' '..network_name..' Hosts'..asn..'",\n')
	elseif ( mac ~= "" ) then print('title: "Local local '..protocol..' '..network_name..' Hosts'..mac..'",\n')
	elseif ( os_ ~= "" ) then print('title: "Local Hosts'..os_..' Hosts",\n') 
	elseif ( am_str ~= "" ) then print('title: "Local '..protocol..' '..network_name..' Hosts'..country..am_str..'",\n')
	else  print('title: "Local '..protocol..' '..network_name..' Hosts'..country..'",\n')
	end
elseif(mode == "remote") then
	if ( country ~= "" ) then print('title: "Remote '..protocol..' '..network_name..' Hosts'..country..'",\n')
	elseif ( asn ~= "" ) then print('title: "Remote '..protocol..' '..network_name..' Hosts'..asn..'",\n')
	elseif ( mac ~= "" ) then print('title: "Remote local '..protocol..' '..network_name..' Hosts'..mac..'",\n')
	elseif ( os_ ~= "" ) then print('title: "Remote '..os_..' Hosts",\n') 
	elseif ( am_str ~= "" ) then print('title: "Remote '..protocol..' '..network_name..' Hosts'..country..am_str..'",\n')
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

if(network_url == "") then
   print('buttons: [ \'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Filter Hosts<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" style="min-width: 90px;"><li><a href="')
   print (ntop.getHttpPrefix())
   print ('/lua/hosts_stats.lua">All Hosts</a></li><li><a href="')
   print (ntop.getHttpPrefix())
   print ('/lua/hosts_stats.lua?mode=local">Local Only</a></li><li><a href="')
   print (ntop.getHttpPrefix())
   print ('/lua/hosts_stats.lua?mode=remote">Remote Only</a></li><li>&nbsp;</li><li><a href="')
   print (ntop.getHttpPrefix())
   print ('/lua/network_stats.lua">Local Networks</a></li></ul>')
   print ("</div>' ],")
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

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/hosts_stats_top.inc")

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

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
