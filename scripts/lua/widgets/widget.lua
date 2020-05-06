--
-- (C) 2020 - ntop.org
--

--
-- This is the main widget entrypoint that renders all widgets
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require ("lua_utils")

local dkjson = require("dkjson")
local datasources_utils = require("datasources_utils")
local widgets_utils = require("widgets_utils")

local function reportError(msg)
    print(dkjson.encode({ success = false, message = msg }))
 end

-- ###############################################

local json = _GET["JSON"]

local widget_data = {}

if (json ~= nil) then
   widget_data = dkjson.decode(json)
end

sendHTTPContentTypeHeader('application/json')

if (widget_data.widget_key == nil) then
   reportError("Missing widget_key parameter")
   return
end

local widget = widgets_utils.get_widget(widget_data.widget_key)
if (widget == nil) then
    reportError("The requested widget was not found")
    return
end

widget.type = widget_data.widget_type or widget.type
-- Generate the widget response
print(widgets_utils.generate_response(widget, widget_data))
