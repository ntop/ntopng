--
-- (C) 2013-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require("lua_trace")
require("lua_utils")

local json = require("dkjson")
local ui_utils = require("ui_utils")
local template_utils = require("template_utils")

local widget_gui_utils = {}

-- a table with registered widgets to render
local registered_widgets = {
    charts = {
        -- [widgetName] = registeredWidget
    },
}

local function build_css_styles(css_styles)

    local style = {}
    
    for name, value in pairs(css_styles) do 
        style[#style+1] = string.format("%s:%s", name, value)
    end

    return table.concat(style, ";")

end

local function check_widget_existance(widgets, name)
    -- check if exists a widget with the same name
    if table.has_key(registered_widgets.charts, name) then
        traceError(TRACE_WARNING, TRACE_CONSOLE, string.format("Overriding existing [%s] widget...", name))
    end
end

---Register a new Chart.js widget to be rendered
---@param name any
---@param type any
---@param update_time any
---@param datasources any
---@param additional_params any
function widget_gui_utils.register_chart_widget(name, type, update_time, datasources, additional_params)

    additional_params = additional_params or {}

    check_widget_existance(registered_widgets.charts, name)

    registered_widgets.charts[name] = {
        type = type,
        update_time = update_time,
        datasources = datasources,
        additional_params = additional_params
    }

end

--- Shortcut Functions

function widget_gui_utils.register_bubble_chart(name, update_time, datasources, additional_params)
    widget_gui_utils.register_chart_widget(name, 'bubble', update_time, datasources, additional_params)
end

function widget_gui_utils.register_bar_chart(name, update_time, datasources, additional_params)
    widget_gui_utils.register_chart_widget(name, 'bar', update_time, datasources, additional_params)
end

function widget_gui_utils.register_timeseries_area_chart(name, update_time, datasources)
    widget_gui_utils.register_chart_widget(name, 'area', update_time, datasources, {
        apex = {
            legend = {
                show = true,
            },
            chart = {
                type = "area",
                width = "100%",
                height = "100%",
--                foreColor = "#999",
                stacked = true,
                toolbar = {
                    tools = {
                        selection = false,
                        zoomin = false,
                        zoomout = false,
                        reset = false,
                        pan = false,
                        -- set the zoom field to a space to hide the len icon
                        zoom = " ",
                        download = false
                    }
                }
            },
            dataLabels = {
                enabled = false
            },
	    stroke = {
	       show = false,
	       curve = 'smooth',
	    },
	    fill = {
	       type = "solid"
	    },
            xaxis = {
                type = "datetime",
                labels = {
                    datetimeUTC = false,
                },
                axisBorder = {
                    show = true
                },
                axisTicks = {
		   			show = false
                },
                tooltip={
                	enabled=false
                },
            },
            yaxis = {
                show = true,
            },
            grid = {
               show = false,
            },
            tooltip = {
                x = {
                    format = "dd MMM yyyy HH:mm:ss"
                },
            },
        }
    })
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
        return string.format("Chart %s not found!", widget_name)
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
    return { endpoint = name .. build_query_params(params or {}), name = name, params = params }
end

return widget_gui_utils
