--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("containers_stats.containers"))

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local page_params = {
  pod = _GET["pod"],
}

-- #######################################################

local title = ternary(isEmptyString(page_params.pod), i18n("containers_stats.containers_list"), i18n("containers_stats.containers_of_pod", {pod=page_params.pod}))

print [[
  <hr>
  <div id="table-pods"></div>
  <script>
  var url_update = "]] print(getPageUrl(ntop.getHttpPrefix() .. "/lua/get_containers_data.lua", page_params)) print[[";]]

print [[
    $("#table-pods").datatable({
      title: "]] print(title) print[[",
      url: url_update,
      columns: [
        {
          title: "]] print(i18n("containers_stats.container")) print[[",
          field: "column_container",
          sortable: true,
          css: {
            textAlign: 'left'
          }
        }, ]]

dofile(dirs.installdir .. "/scripts/lua/inc/container_columns.lua")

print[[
      ]
    });
  </script>
]]

-- #######################################################


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
