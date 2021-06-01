--
-- (C) 2020-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local template_utils = require("template_utils")

local ui_utils = {}

function ui_utils.render_configuration_footer(item,page)
   local ret = template_utils.gen('pages/components/manage-configuration-link.template', {item = item})

   if(((page == "host") or (page == nil))
      and (item == "pool") and (ntop.isPro() or ntop.isEnterpriseM() or ntop.isEnterpriseL())) then
      ret = ret .. template_utils.gen('pages/components/export-policy-configuration-link.template')
   end
   
   return ret
end

--- Single note element: { content = 'note description', hidden = true|false }
function ui_utils.render_notes(notes_items, title, is_ordered)

    if notes_items == nil then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "The notes table is nil!")
        return ""
    end

    return template_utils.gen("pages/components/notes.template", {
        notes = notes_items,
        is_ordered = is_ordered,
        title = title
    })
end

function ui_utils.render_breadcrumb(title, items, icon)
    return template_utils.gen("pages/components/breadcrumb.template", {
        items = items,
        i18n_title = title,
        breadcrumb_icon = icon
    })
end

function ui_utils.render_pools_dropdown(pools_instance, member, key)

    if (pools_instance == nil) then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "The pools instance is nil!")
        return ""
    end

    if (member == nil) then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "The member is nil!")
        return ""
    end

    local selected_pool = pools_instance:get_pool_by_member(member)
    local selected_pool_id = selected_pool and selected_pool.pool_id or pools_instance.DEFAULT_POOL_ID

    local all_pools = pools_instance:get_all_pools()

    return template_utils.gen("pages/components/pool-select.template", {
        pools = all_pools,
        selected_pool_id = selected_pool_id,
        key = key,
    })
end

function ui_utils.create_navbar_title(title, subpage, title_link)
    if isEmptyString(subpage) then return title end
    return "<a href='".. title_link .."'>".. title .. "</a>&nbsp;/&nbsp;<span>"..subpage.."</span>"
end

---Render a Date Range Picker box.
---@param options table The options contains the following fields: `presets`, `tags`, `buttons`, `records`, `max_delta_in`, `max_delta_out`.
---                     The field `presets` it's a table containing {day: bool, week: bool, month: bool, year: bool}
---                     The field `buttons` it's a table containing {permalink: bool, download: bool}
---                     The field `tags` it's a table containing {disabled: bool, values: array}
---                     The field `records` it's an array containing numbers {10, 25, 50, 100}
---@return string
function ui_utils.render_datetime_range_picker(options)

    local presets = { day = true, week = true, month = true, year = true }
    local buttons = { permalink = false, download = false }
    local tags = { enabled = true, values = {}}
    local tags_localization = {}

    options = options or {}

    options.json = json

    options.default = options.default or "5min"

    options.presets = ternary(options.presets ~= nil, table.merge(presets, options.presets), presets)
    options.buttons = ternary(options.buttons ~= nil, table.merge(buttons, options.buttons), buttons)
    options.max_delta_in = ternary(options.max_delta_in ~= nil, options.max_delta_in, 300)
    options.max_delta_out = ternary(options.max_delta_in ~= nil, options.max_delta_in, 43200)
    options.tags = ternary(options.tags ~= nil, table.merge(tags, options.tags), tags)
    options.tags.localization = ternary(options.tags.i18n ~= nil, table.merge(tags_localization, options.tags.i18n), tags_localization)
    options.tags.view_only = ternary(options.tags.view_only ~= nil, options.tags.view_only, false)

    return template_utils.gen("pages/components/range-picker.template", options)
end

--- Shortcut function to print a togglw switch inside the requested page
function ui_utils.print_toggle_switch(context)
    print(template_utils.gen("on_off_switch.html", context))
end

function ui_utils.render_table_picker(name, context, modals)
    template_utils.render("pages/table_picker.template", {
        ui_utils = ui_utils,
        json = json,
        template_utils = template_utils,
        modals = modals or {},
        datasource = context.datasource, -- the data provider
        datatable = {
            name = name, -- the table name
            columns = context.table.columns, -- the columns to print inside the table
            js_columns = context.table.js_columns, -- a custom javascript code to format the columns
        }
    })
end

---Render a Tags Input box.
--@param name The component unique name
---@param tags A table containing the values
---@return string
function ui_utils.render_tag_input(name, tags)
    local options = {
       instance_name = name,
       json = json,
       tags = tags or {}, -- initial tags
    }

    return template_utils.gen("pages/components/tag-input.template", options)
end

return ui_utils
