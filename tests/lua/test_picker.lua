--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local ui_utils = require "ui_utils"
local json = require "dkjson"
local template_utils = require "template_utils"
local widget_gui_utils = require "widget_gui_utils"
local Datasource = widget_gui_utils.datasource

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("about.about_x", { product = ":)" }))

if not isAdministrator() then return end

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local begin_epoch = _GET["begin_epoch"] or (os.time() - 3600)
local end_epoch = _GET["end_epoch"] or (os.time())
local totalRows = _GET["totalRows"] or 10

-- register an example of bar chart
widget_gui_utils.register_bar_chart('example', 0, {
    Datasource("/lua/rest/v1/charts/time/data.lua", {begin_epoch = begin_epoch, end_epoch = end_epoch, totalRows = totalRows})
}, {})

template_utils.render("pages/table-picker.template", {
    ui_utils = ui_utils,
    json = json,
    template_utils = template_utils,
    modals = {},
    range_picker = {},
    chart = {
        html = widget_gui_utils.render_chart('example', {
            displaying_label = '',
            css_styles = {
                width = '100%',
                height = '16rem'
            }
        }),
        name = 'example'
    },
    datatable = {
        datasource = Datasource("/lua/rest/v1/get/time/data.lua", {begin_epoch = begin_epoch, end_epoch = end_epoch, totalRows = totalRows}),
        name = 'my-table', -- the table name
        columns = {'Index', 'Date'}, -- the columns to print inside the table
        js_columns = ([[ [{data: 'index', width: '100px'}, {data: 'date'}] ]]), -- a custom javascript code to format the columns
    }
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

