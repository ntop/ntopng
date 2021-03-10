--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local widget_gui_utils = require "widget_gui_utils"

local Datasource = widget_gui_utils.datasource

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("about.about_x", { product = ":)" }))

if not isAdministrator() then return end

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

widget_gui_utils.render_table_picker('my-table', {
    datasource = Datasource("/lua/rest/v1/get/time/data.lua", {begin_epoch = os.time() - 3600, end_epoch = os.time(), totalRows = 10}),
    table = {
        columns = {'Index', 'Date'},
        js_columns = ([[
            [{data: 'index', width: '100px'}, {data: 'date'}]
        ]])
    }
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

