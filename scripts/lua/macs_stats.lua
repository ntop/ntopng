--
-- (C) 2013-23 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local discover = require("discover_utils")
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.devices)

if (group_col == nil) then
   group_col = "mac"
end

local have_nedge = ntop.isnEdge()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local base_url = ntop.getHttpPrefix() .. "/lua/macs_stats.lua"
local page_params = {}

local devices_mode = ""
local devices_mode_filter = ""

if(not isEmptyString(_GET["devices_mode"])) then
   devices_mode = _GET["devices_mode"]
   page_params["devices_mode"] = _GET["devices_mode"]
   devices_mode_filter = '<span class="fas fa-filter"></span>'
end

local manufacturer = nil
local manufacturer_filter = ""
if(not isEmptyString(_GET["manufacturer"])) then
   manufacturer = _GET["manufacturer"]
   page_params["manufacturer"] = manufacturer
   manufacturer_filter = '<span class="fas fa-filter"></span>'
end

local device_type = nil
local devtype_filter = ""
if(not isEmptyString(_GET["device_type"])) then
   device_type = tonumber(_GET["device_type"])
   page_params["device_type"] = device_type
   devtype_filter = '<span class="fas fa-filter"></span>'
end

page_utils.print_page_title('Mac List')

print [[
      <div id="table-mac"></div>
         <script>
         var url_update = "]]

local manufacturers

if((devices_mode == "inactive_macs_only") and ntop.isEnterpriseL()) then
  local ifid = interface.getId()
  local base_key = "ntopng.serialized_macs.ifid_".. ifid .."_"
  local keys = base_key .."*"
  local keys_len = string.len(keys)
  local macs_list = ntop.getKeysCache(keys)
  local macs_stats = {}
  local active_macs_stats = interface.getActiveMacs()
  local active_macs = {}

  for _,item in pairs(active_macs_stats) do
    active_macs[item] = true
  end

  manufacturers = {}
  if(macs_list ~= None) then
    for item,_ in pairs(macs_list) do
      local mac = string.sub(item, keys_len)

      if(active_macs[mac] == None) then
        local m = get_manufacturer_mac(mac)

        if(m ~= "") then
         if(manufacturers[m] == None) then
           manufacturers[m] = 1
         else
           manufacturers[m] = manufacturers[m] + 1
        end
       end
      end
    end
  end

  print(getPageUrl(ntop.getHttpPrefix().."/lua/enterprise/get_inactive_macs_data.lua", page_params))
else
  print(getPageUrl(ntop.getHttpPrefix().."/lua/get_macs_data.lua", page_params))
   manufacturers = interface.getMacManufacturers(nil, nil, device_type)
end

print ('";')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/mac_stats_id.inc")

print [[
           $("#table-mac").datatable({
                  title: '',
                        url: url_update ,
]]

local title

if devices_mode == "source_macs_only" then
   if device_type then
      title = i18n("mac_stats.layer_2_dev_devices", {device_type=discover.devtype2string(device_type)})
   else
      title = i18n("mac_stats.layer_2_source_devices", {device_type=""})
   end
elseif devices_mode == "inactive_macs_only" then
   title = i18n("mac_stats.inactive_macs")
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


print ('rowCallback: function ( row ) { return mac_table_setID(row); },')
print[[
        tableCallback: function()  { $("#dt-bottom-details > .float-left > p").first().append('. ]]
print(i18n('mac_stats.idle_devices_not_listed'))
print[['); },]]

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("macs") ..'","' .. getDefaultTableSortOrder("macs").. '"] ],')

print('buttons: [')

   -- Filter MACS
   -- table.clone needed to modify some parameters while keeping the original unchanged
   local macs_params = table.clone(page_params)
   macs_params.devices_mode = nil
   print('\'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">'..i18n("mac_stats.filter_macs")..devices_mode_filter..'<span class="caret"></span></button> <ul class="dropdown-menu scrollable-dropdown" role="menu" style="min-width: 90px;"><li><a class="dropdown-item" href="')
   print(getPageUrl(base_url, macs_params))
   print('">'..i18n("mac_stats.all_devices")..'</a></li>')

   -- Source MACs only
   print('<li><a class="dropdown-item '.. (devices_mode == "source_macs_only" and 'active' or '') ..'" href="')
   macs_params.devices_mode = "source_macs_only"
   print(getPageUrl(base_url, macs_params))
   print('">'..i18n("mac_stats.source_macs")..'</a></li>')

   -- Inactive MACs only
   if(ntop.isEnterpriseL()) then
     print('<li><a class="dropdown-item '.. (devices_mode == "inactive_macs_only" and 'active' or '') ..'" href="')
     macs_params.devices_mode = "inactive_macs_only"
     print(getPageUrl(base_url, macs_params))
     print('">'..i18n("mac_stats.inactive_macs")..'</a></li>')
   end
   
   print("</div>'")

   -- Filter Manufacturers
   -- table.clone needed to modify some parameters while keeping the original unchanged
   local manufacturer_params = table.clone(page_params)
   manufacturer_params.manufacturer = nil
   print[[, '\
       <div class="btn-group float-right">\
       <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("mac_stats.manufacturer")) print(manufacturer_filter) print[[<span class="caret"></span></button>\
       <ul class="dropdown-menu scrollable-dropdown" role="menu" id="flow_dropdown">\
          <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, manufacturer_params)) print[[">]] print(i18n("mac_stats.all_manufacturers")) print[[</a></li>\
   ]]

for manuf, count in pairsByKeys(manufacturers, asc) do
   local _manuf = string.gsub(string.gsub(manuf, "'", "&#39;"), "\"", "&quot;")
      manufacturer_params.manufacturer = manuf
      print('<li><a class="dropdown-item '.. (manufacturer == manuf and 'active' or '') ..'" href="'..getPageUrl(base_url, manufacturer_params)..'">'.._manuf..' ('..count..')'..'</a></li>')
   end
   print[[
       </ul>\
    </div>\
   ']]

   -- Filter Device Type
   -- table.clone needed to modify some parameters while keeping the original unchanged
   local devicetype_params = table.clone(page_params)
   devicetype_params.device_type = nil
   print[[, '\
       <div class="btn-group float-right">\
       <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">]] print(i18n("details.device_type")) print(devtype_filter) print[[<span class="caret"></span></button>\
       <ul class="dropdown-menu scrollable-dropdown" role="menu" id="flow_dropdown">\
          <li><a class="dropdown-item" href="]] print(getPageUrl(base_url, devicetype_params)) print[[">]] print(i18n("mac_stats.all_devices")) print[[</a></li>\
   ]]

   for typeidx, count in pairsByKeys(interface.getMacDeviceTypes(nil, nil, manufacturer, device_type), asc) do
      devicetype_params.device_type = typeidx
      print('<li><a class="dropdown-item '.. (typeidx == device_type and 'active' or '') ..'" href="'..getPageUrl(base_url, devicetype_params)..'">'.. discover.devtype2string(typeidx) ..' ('..count..')'..'</a></li>')
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
                             },
                             {
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
