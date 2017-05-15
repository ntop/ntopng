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

print [[
      <hr>
      <div id="table-os"></div>
	 <script>
	 var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_grouped_hosts_data.lua?grouped_by=os]]

print ('";')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/os_stats_id.inc")

print [[
	 $("#table-os").datatable({
                        title: "OS List",
			url: url_update ,
	 ]]

print('title: "' .. i18n("os_stats.hosts_by_operating_system") .. '",\n')
print ('rowCallback: function ( row ) { return os_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("os") ..'","' .. getDefaultTableSortOrder("os").. '"] ],')


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
			     title: "]] print(i18n("name")) print[[",
				 field: "column_id",
				 sortable: true,
                             css: {
			        textAlign: 'left'
			     }

				 },
			  ]]


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/os_stats_top.inc")

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/hosts_stats_bottom.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
