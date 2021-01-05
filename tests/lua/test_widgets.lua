--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/datasources/?.lua;" .. package.path

require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo() 
local page_utils = require("page_utils")
local alerts_api = require("alerts_api")
local format_utils = require("format_utils")
local json = require "dkjson"
local rest_utils = require "rest_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("about.about_x", { product=info.product }))

if not isAdministrator() then
  return
end

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local packet_distro = require "interface.packet_distro"
local datasource = packet_distro:new()

-- Read data from the REST endpoint bound to the datasource
-- NOTE: Host is hardcoded here for test purposes, it will vary depending on what will be specified when creating the datasource
-- NOTE: The auth token will be necessary as well
local url = "http://127.0.0.1:3000"..datasource.meta.rest_endpoint
local rsp = ntop.httpGet(url)

-- Deserialize the response into the datasource
datasource:deserialize(rsp)

-- Apply wanted transformations
local table_transf = datasource:transform("table")
local donut_transf = datasource:transform("donut")
local multibar_transf = datasource:transform("multibar")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

