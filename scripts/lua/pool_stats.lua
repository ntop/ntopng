--
-- (C) 2017-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")

local have_nedge = ntop.isnEdge()

sendHTTPContentTypeHeader('text/html')


if not ntop.isnEdge() then
   page_utils.set_active_menu_entry(page_utils.menu_entries.host_pools)
else
   page_utils.set_active_menu_entry(page_utils.menu_entries.users)
end

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local title

if have_nedge then
    title = i18n("nedge.users_list") .. " <small><a title='".. i18n("manage_users.manage_users") .."' href='".. ntop.getHttpPrefix() .."/lua/pro/nedge/admin/nf_list_users.lua'><i class='fas fa-cog'></i></a></small>"
else
    title = i18n("pool_stats.host_pool_list")
end

page_utils.print_page_title(title)

print [[
    <div id="table-pool"></div>
    <script>
    var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_pools_data.lua]]

print ('";')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/pool_stats_id.inc")

print [[
    $("#table-pool").datatable({
        url: url_update ,
        ]]

print('title: "",\n')
print ('rowCallback: function ( row ) { return pool_table_setID(row); },')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("pool_id") ..'","' .. getDefaultTableSortOrder("pool_id").. '"] ],')


print [[
        showPagination: true,
        buttons: [
         '<a href="]] print(ntop.getHttpPrefix()) print[[/lua/if_stats.lua?ifid=8&page=pools#create" class="add-on btn"><i class="fas fa-plus" aria-hidden="true"></i></a>'
        ],
        columns: [
        {
            title: "Key",
            field: "key",
            hidden: true,
            css: {
                textAlign: 'center'
            }
        },{
            title: "]] print(i18n(ternary(have_nedge, "nedge.user", "host_pools.pool_name"))) print[[",
            field: "column_id",
            sortable: true,
            css: {
                textAlign: 'left'
            }
        },{
            title: "]] print(i18n("chart")) print[[",
            field: "column_chart",
]]
if not ntop.isPro() or not areHostPoolsTimeseriesEnabled(interface.getId()) then
   print('hidden: true,')
end
print[[
            sortable: false,
            css: {
                textAlign: 'center'
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
            title: "]] print(i18n("if_stats_overview.blocked_flows")) print[[",
            field: "column_num_dropped_flows",
            sortable: true,
            hidden: ]]
if isBridgeInterface(interface.getStats()) then
   print("false")
else
   print("true")
end
print[[,
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
