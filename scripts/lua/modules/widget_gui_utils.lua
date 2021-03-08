--
-- (C) 2013-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require("lua_trace")
require("lua_utils")

local json = require("dkjson")
local template_utils = require("template_utils")

local widget_gui_utils = {}

-- a table with registered widgets to render
local registered_widgets = {
    charts = {
        -- [widgetName] = registeredWidget
    }
}

local function build_query_params(params)

    local query = "?"
    local t = {}
 
    for key, value in pairs(params) do
        t[#t+1] = string.format("%s=%s", key, value)
    end
    
    return query .. table.concat(t, '&')
end

local function build_css_styles(css_styles)

    local style = {}
    
    for name, value in pairs(css_styles) do 
        style[#style+1] = string.format("%s:%s", name, value)
    end

    return table.concat(style, ";")

end

function widget_gui_utils.register_chart_widget(name, type, update_time, datasources, additional_params)

    -- check if exists a widget with the same name
    if table.has_key(registered_widgets, name) then
        traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Overriding existing [%s] widget...", name))
    end

    registered_widgets.charts[name] = {
        type = type,
        update_time = update_time,
        datasources = datasources,
        params = additional_params
    }

end

--- Shortcut Functions

function widget_gui_utils.register_bubble_chart(name, update_time, datasources, additional_params)
    widget_gui_utils.register_chart_widget(name, 'bubble', update_time, datasources, additional_params)
end

function widget_gui_utils.register_pie_chart(name, update_time, datasources, additional_params)
    widget_gui_utils.register_chart_widget(name, 'pie', update_time, datasources, additional_params)
end

function widget_gui_utils.register_doughnut_chart(name, update_time, datasources, additional_params)
    widget_gui_utils.register_chart_widget(name, 'doughnut', update_time, datasources, additional_params)
end

---Render all registered chart widgets.
---@return string
function widget_gui_utils.render_chart_widgets()

    local template_buff = {}

    for widget_name, widget in pairs(registered_widgets.charts) do

        local rendered_html = template_utils.gen("widgets/chart-widget.template", {
            widget_name = widget_name, widget = widget, json = json
        })

        template_buff[#template_buff + 1] = rendered_html
    end

    return table.concat(template_buff, "\n")
end

---Get an array of chart widgets registered
---@return table
function widget_gui_utils.get_registered_chart_names()

    local names = {}
    
    for name, _ in pairs(registered_widgets.charts) do
        names[#names+1] = name
    end

    return names
end

---Render a chart widget into a string
---@param widget_name string The widget's name to render
---@param additional_params table Additional paramaters used to customize the widgets {css_styles = {...}, displaying_label = '...'}
---@return string The chart widget template rendered
function widget_gui_utils.render_chart(widget_name, additional_params)

    local displaying_label = additional_params.displaying_label or widget_name
    local css_styles = additional_params.css_styles or {}

    if not (table.has_key(registered_widgets.charts, widget_name)) then
        return ""
    end

    local widget = registered_widgets.charts[widget_name]

    local rendered_html = template_utils.gen("widgets/chart-widget.template", {
        json = json, 
        widget_name = widget_name, 
        widget = widget, 
        css_styles = build_css_styles(css_styles),
        displaying_label = displaying_label
    })

    return rendered_html
end

function widget_gui_utils.datasource(name, params)
    return { endpoint = name .. build_query_params(params) }
end

return widget_gui_utils