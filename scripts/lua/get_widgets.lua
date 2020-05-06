--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local widgets_utils = require("widgets_utils")
local json = require "dkjson"

sendHTTPContentTypeHeader('application/json')

local widgets = widgets_utils.get_all_widgets()
print(json.encode(widgets))
