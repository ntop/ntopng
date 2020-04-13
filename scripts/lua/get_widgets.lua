--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local widget_utils = require("widget_utils")
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

local widgets = widget_utils.get_all_widgets()
print(json.encode(widgets))