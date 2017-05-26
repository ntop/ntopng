--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

if (group_col == nil) then
   group_col = "mac"
end

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "devices_stats"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local base_url = ntop.getHttpPrefix() .. "/lua/mac_stats.lua"
local page_params = {}

local devices_mode = ""
local devices_mode_filter = ""

if(not isEmptyString(_GET["devices_mode"])) then
   devices_mode = _GET["devices_mode"]
   page_params["devices_mode"] = _GET["devices_mode"]
   devices_mode_filter = '<span class="glyphicon glyphicon-filter"></span>'
end


local manufacturer = nil
local manufacturer_filter = ""
if(not isEmptyString(_GET["manufacturer"])) then
   manufacturer = _GET["manufacturer"]
   page_params["manufacturer"] = manufacturer
   manufacturer_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

print [[
      <hr>
      <div id="table-mac"></div>
	 <script>
	 var url_update = "]]

print(getPageUrl(ntop.getHttpPrefix().."/lua/get_macs_data.lua", page_params))

print ('";')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/mac_stats_id.inc")

print [[ 
           $("#table-mac").datatable({
                        title: "Mac List",
			url: url_update , 
]]

local title

if devices_mode == "host_macs_only" then
   title = i18n("mac_stats.layer_2_host_devices")
else
   title = i18n("mac_stats.all_layer_2_devices")
end

if manufacturer ~= nil then
 title = i18n("mac_stats.layer_2_devices_with_manufacturer",{title=title, manufacturer=manufacturer})
end

print('title: "'..title..'",\n')

print ('rowCallback: function ( row ) { return mac_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("macs") ..'","' .. getDefaultTableSortOrder("macs").. '"] ],')

print('buttons: [')

   -- Filter MACS
   local hosts_macs_params = table.clone(page_params)
   hosts_macs_params.devices_mode = nil
   print('\'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..i18n("mac_stats.filter_macs")..devices_mode_filter..'<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" style="min-width: 90px;"><li><a href="')
   print(getPageUrl(base_url, hosts_macs_params))
   print('">'..i18n("mac_stats.all_devices")..'</a></li>')

   -- Host MACs only
   print('<li')
   if devices_mode == "host_macs_only" then print(' class="active"') end
   print('><a href="')
   hosts_macs_params.devices_mode = "host_macs_only"
   print(getPageUrl(base_url, hosts_macs_params))
   print('">'..i18n("mac_stats.hosts_only")..'</a></li>')
   print("</div>'")

   -- Filter Manufacturers
   local manufacturer_params = table.clone(page_params)
   manufacturer_params.manufacturer = nil
   print[[, '\
       <div class="btn-group pull-right">\
       <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("mac_stats.manufacturer")) print(manufacturer_filter) print[[<span class="caret"></span></button>\
       <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
          <li><a href="]] print(getPageUrl(base_url, manufacturer_params)) print[[">]] print(i18n("mac_stats.all_manufacturers")) print[[</a></li>\
   ]]

   for manuf, count in pairsByKeys(interface.getMacManufacturers(), asc) do
      manufacturer_params.manufacturer = manuf
      print('<li')
      if manufacturer == manuf then print(' class="active"') end
      print('><a href="'..getPageUrl(base_url, manufacturer_params)..'">'..manuf..' ('..count..')'..'</a></li>')
   end
   
   print[[
       </ul>\
    </div>\
   ']]

   print(" ],")

print [[
	       showPagination: true,
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
			     title: "]] print(i18n("mac_address")) print[[",
				 field: "column_mac",
				 sortable: true,
                             css: {
			        textAlign: 'left'
			     }
				 },
                         {
			     title: "]] print(i18n("mac_stats.manufacturer")) print[[",
				 field: "column_manufacturer",
				 sortable: true,
                             css: {
			        textAlign: 'left'
			     }
				 },
			  ]]


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/mac_stats_top.inc")

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/mac_stats_bottom.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
