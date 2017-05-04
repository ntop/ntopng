--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local base_url = ntop.getHttpPrefix().."/lua/network_stats.lua"
local page_params = {}
page_params["grouped_by"] = "local_network"

if not isEmptyString(_GET["version"]) then
   page_params["version"] = _GET["version"]
end

function getPageTitle()
   local t = "Networks"

   if not isEmptyString(_GET["version"]) then
      t = t .. " with IPv" .. _GET["version"] .. " traffic"
   end

   return t
end

print [[
      <hr>
      <div id="table-network"></div>
	 <script>
	 var url_update = "]]
print(getPageUrl(ntop.getHttpPrefix().."/lua/get_grouped_hosts_data.lua", page_params))
print ('";')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/network_stats_id.inc")

print [[
	 $("#table-network").datatable({
                        title: "Network List",
			url: url_update ,
			buttons: ['<div class="btn-group pull-right">]]

printIpVersionDropdown(base_url, page_params)

print("</div>'],")

print('title: "'..getPageTitle()..'",\n')
print ('rowCallback: function ( row ) { return network_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("local_network") ..'","' .. getDefaultTableSortOrder("local_network").. '"] ],')


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
			     title: "Network Name",
				 field: "column_id",
				 sortable: true,
                             css: {
			        textAlign: 'left'
			     }
				 },
			  ]]


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/network_stats_top.inc")

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/network_stats_bottom.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
