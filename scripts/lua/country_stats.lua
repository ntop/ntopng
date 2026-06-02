--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "ntop_utils"

local page_utils = require "page_utils"
local json = require "dkjson"
local template_utils = require("template_utils")
local page = _GET["page"]

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.countries)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

page_utils.print_navbar(i18n("countries"), ntop.getHttpPrefix() .. "/lua/country_stats.lua", {{
    active = page == "overview" or not page,
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
        i18n("countries") .. "\"></i>"
}})

local graph_utils = require "graph_utils"
local date_fmt, date_fmt_picker = graph_utils.get_date_formats()
local context = {
    ifid = interface.getId(),
    show_historical = areCountryTimeseriesEnabled(interface.getId()),
    date_format = date_fmt,
    date_format_range_picker = date_fmt_picker,
}

local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
    vue_page_name = "PageCountryStats",
    page_context = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")


