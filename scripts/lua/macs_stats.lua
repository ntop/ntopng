--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local discover = require("discover_utils")

sendHTTPContentTypeHeader('text/html')

if (group_col == nil) then
   group_col = "mac"
end

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

local have_nedge = ntop.isnEdge()

active_page = "hosts"

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local base_url = ntop.getHttpPrefix() .. "/lua/macs_stats.lua"
local page_params = {}

local devices_mode = ""
local devices_mode_filter = ""
local dhcp_macs_only = false

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

local device_type = nil
local devtype_filter = ""
if(not isEmptyString(_GET["device_type"])) then
   device_type = tonumber(_GET["device_type"])
   page_params["device_type"] = device_type
   devtype_filter = '<span class="glyphicon glyphicon-filter"></span>'
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

if devices_mode == "source_macs_only" then
   if device_type then
      title = i18n("mac_stats.layer_2_dev_devices", {device_type=discover.devtype2string(device_type)})
   else
      title = i18n("mac_stats.layer_2_source_devices", {device_type=""})
   end
elseif devices_mode == "dhcp_macs_only" then
   dhcp_macs_only = true
   if device_type then
      title = i18n("mac_stats.layer_2_dev_devices", {device_type=discover.devtype2string(device_type).." DHCP"})
   else
      title = i18n("mac_stats.layer_2_source_devices", {device_type=" DHCP"})
   end
else
   if device_type then
      title = i18n("mac_stats.dev_layer_2_devices", {device_type=discover.devtype2string(device_type)})
   else
      title = i18n("mac_stats.all_layer_2_devices", {device_type=""})
   end
end

if manufacturer ~= nil then
 title = i18n("mac_stats.layer_2_devices_with_manufacturer",{title=title, manufacturer=manufacturer})
end

print('title: "'..title..'",\n')

print ('rowCallback: function ( row ) { return mac_table_setID(row); },')
print[[
        tableCallback: function()  { $("#dt-bottom-details > .pull-left > p").first().append('. ]]
print(i18n('mac_stats.idle_devices_not_listed'))
print[['); },]]

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("macs") ..'","' .. getDefaultTableSortOrder("macs").. '"] ],')

print('buttons: [')

   -- Filter MACS
   local macs_params = table.clone(page_params)
   macs_params.devices_mode = nil
   print('\'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..i18n("mac_stats.filter_macs")..devices_mode_filter..'<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" style="min-width: 90px;"><li><a href="')
   print(getPageUrl(base_url, macs_params))
   print('">'..i18n("mac_stats.all_devices")..'</a></li>')

   -- Source MACs only
   print('<li')
   if devices_mode == "source_macs_only" then print(' class="active"') end
   print('><a href="')
   macs_params.devices_mode = "source_macs_only"
   print(getPageUrl(base_url, macs_params))
   print('">'..i18n("mac_stats.source_macs")..'</a></li>')

   -- DHCP MACs only
   print('<li')
   if devices_mode == "dhcp_macs_only" then print(' class="active"') end
   print('><a href="')
   macs_params.devices_mode = "dhcp_macs_only"
   print(getPageUrl(base_url, macs_params))
   print('">'..i18n("mac_stats.dhcp_only")..'</a></li>')
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

for manuf, count in pairsByKeys(interface.getMacManufacturers(nil, nil, device_type), asc) do
   local _manuf = string.gsub(string.gsub(manuf, "'", "&#39;"), "\"", "&quot;")
      manufacturer_params.manufacturer = manuf
      print('<li')
      if manufacturer == manuf then print(' class="active"') end
      print('><a href="'..getPageUrl(base_url, manufacturer_params)..'">'.._manuf..' ('..count..')'..'</a></li>')
   end
   print[[
       </ul>\
    </div>\
   ']]

   -- Filter Device Type
   local devicetype_params = table.clone(page_params)
   devicetype_params.device_type = nil
   print[[, '\
       <div class="btn-group pull-right">\
       <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("details.device_type")) print(devtype_filter) print[[<span class="caret"></span></button>\
       <ul class="dropdown-menu" role="menu" id="flow_dropdown">\
          <li><a href="]] print(getPageUrl(base_url, devicetype_params)) print[[">]] print(i18n("mac_stats.all_devices")) print[[</a></li>\
   ]]

   for typeidx, count in pairsByKeys(interface.getMacDeviceTypes(nil, nil, manufacturer, device_type), asc) do
      devicetype_params.device_type = typeidx
      print('<li')
      if typeidx == device_type then print(' class="active"') end
      print('><a href="'..getPageUrl(base_url, devicetype_params)..'">'.. discover.devtype2string(typeidx) ..' ('..count..')'..'</a></li>')
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
			     {
			     title: "]] print(i18n("details.device_type")) print[[",
				 field: "column_device_type",
				 sortable: false,
				 },{
			     title: "]] print(i18n("name")) print[[",
				 field: "column_name",
				 sortable: false,
	 	             css: {
			        textAlign: 'left'
			     }

				 },{
			     title: "]] print(i18n("hosts_stats.hosts")) print[[",
				 field: "column_hosts",
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }

				 },
			     {
			     title: "]] print(i18n("mac_stats.arp_total")) print[[",
				 field: "column_arp_total",
             hidden: ]] print(ternary(have_nedge, "true", "false")) print[[,
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }

				 },
			     {
			     title: "]] print(i18n("seen_since")) print[[",
				 field: "column_since",
				 sortable: true,
                             css: {
			        textAlign: 'center'
			     }

				 },
]]

print [[
			     {
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
			     title: "]] print(i18n("traffic")) print[[",
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

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
