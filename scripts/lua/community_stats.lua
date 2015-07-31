--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
      <hr>
      <div id="table-communities"></div>
	 <script>
	 var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_community_data.lua]]

print ('";')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/community_stats_id.inc")

print [[
	 $("#table-communities").datatable({
                        title: "Communities List",
			url: url_update ,
	 ]]

print('title: "Communities",\n')
print ('rowCallback: function ( row ) { return community_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("column_id") ..'","' .. getDefaultTableSortOrder("column_id").. '"] ],')


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
			     title: "Community Name",
				 field: "column_id",
				 sortable: true,
                             css: {
			        textAlign: 'left'
			     }
				 },
			  ]]


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/community_stats_top.inc")

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/community_stats_bottom.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
