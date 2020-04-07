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

local cmd = "/usr/local/bin/speedtest -f json"
local _rsp,rc = osExecute(cmd)

-- io.write(_rsp.."\n")   

if(rc == 0) then
   local rsp = json.decode(_rsp)
   
   print('<table class="table table-bordered table-sm">')
   printRow("ISP", rsp.isp)
   printRow("External IP", rsp.interface.externalIp)
   printRow("Upload", string.format("%.2f Mbit", (rsp.upload.bandwidth*8)/(1024*1024)))
   printRow("Download", string.format("%.2f Mbit", (rsp.download.bandwidth*8)/(1024*1024)))
   printRow("Ping", string.format("%.2f msec (%.2f msec jitter)", rsp.ping.latency, rsp.ping.jitter))
   
   print('</table>\n')

   -- tprint(rsp)
else
   print("<font color=red><b>Error during test. Is https://www.speedtest.net/apps/cli installed ?</b></font><p>")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
