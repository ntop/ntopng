--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.pods)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page_params = {}

-- #######################################################

print [[
  <div id="table-pods"></div>
  <script>
  var url_update = "]] print(getPageUrl(ntop.getHttpPrefix() .. "/lua/get_pods_data.lua", page_params)) print[[";]]

print [[
    $("#table-pods").datatable({
      title: "]] print(i18n("containers_stats.pods_list")) print[[",
      url: url_update,
      columns: [
        {
          title: "",
          field: "column_info",
          sortable: true,
          css: {
            textAlign: 'center'
          }
        }, {
          title: "]] print(i18n("containers_stats.pod")) print[[",
          field: "column_pod",
          sortable: true,
          css: {
            textAlign: 'left'
          }
        }, {
          title: "]] print(i18n("containers_stats.containers")) print[[",
          field: "column_num_containers",
          sortable: false,
          css: {
            textAlign: 'center'
          }
        }, ]]

dofile(dirs.installdir .. "/scripts/lua/inc/container_columns.lua")

print[[
      ], tableCallback: function() {
        datatableInitRefreshRows($("#table-pods"), "column_pod", 10000);
      }
    });
  </script>
]]

-- #######################################################


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
