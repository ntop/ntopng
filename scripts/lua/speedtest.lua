--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo()
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local os_utils = require "os_utils"
local json = require("dkjson")

-- ###################################################

local function osExecute(cmd)
   local fileHandle     = assert(io.popen(cmd, 'r'))
   local commandOutput  = assert(fileHandle:read('*a'))
   local returnTable    = {fileHandle:close()}
   return commandOutput,returnTable[3]            -- rc[3] contains returnCode
end

local function printRow(key, val)
   print("<tr><th>"..key.."</th><td align=left>"..val.."</td></tr>\n")
end

-- ###################################################

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.about, { product=info.product })
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print("Testing. Please be patient...<br>\n")

local rc = ntop.speedtest()

if(rc ~= nil) then
   print(rc)
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
