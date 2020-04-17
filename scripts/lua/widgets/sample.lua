--
-- (C) 2020 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require ("lua_utils")

local dkjson = require("dkjson")
local datasources_utils = require("datasources_utils")
local widget_utils = require("widget_utils")

local function reportError(msg)
    print(json.encode({ success = false, message = msg }))
 end

-- ###############################################

local json = _GET["JSON"]
local widget_data = dkjson.decode(json)

local ifid              = widget_data["ifid"]
local key_ip            = widget_data["keyIP"]
local key_mac           = widget_data["keyMAC"]
local key_asn           = widget_data["keyASN"]
local key_metric        = widget_data["keyMetric"]
local widget_key        = widget_data["widgetKey"]

sendHTTPContentTypeHeader('application/json')

local widget = widget_utils.get_widget(widget_key)
if (widget == nil) then
    reportError("The requested widget was not found")
    return
end

-- sample response for table widget
print(widget_utils.generate_response(widget))