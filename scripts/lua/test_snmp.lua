--
-- (C) 2013-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path

-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"
require "snmp_utils"
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if true then
   local ts_dump = require "ts_5min_dump_utils"
   local when = os.time()
   local config = ts_dump.getConfig()
   local time_threshold = when - (when % 60) + 60 - 10 -- safe margin
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   require "snmp_utils"

   local res = snmp_walk_table("192.168.2.169", "ntop", "1.3.6.1.6.3.16.1.2.1.3.1", 2, 3600)
   tprint(res)
else
   community = _GET["community"]
   host      = _GET["host"]
   
   print('Host: '..host.."<p>\n")
   print('Community: '..community.."<p>\n")
   
   print('<table class="table table-bordered table-striped">\n')
   
   sysname    = "1.3.6.1.2.1.1.1.0"
   syscontact = "1.3.6.1.2.1.1.4.0"
   sysdescr   = "1.3.6.1.2.1.1.5.0"

   rsp = ntop.snmpget(host, community, sysname, syscontact, sysdescr)
   if (rsp ~= nil) then
      for k, v in pairs(rsp) do
	 print('<tr><th width=35%>'..k..'</th><td colspan=2>'.. v..'</td></tr>\n')
      end
   end

   if(false) then
      rsp = ntop.snmpgetnext(host, community, syscontact)
      if (rsp ~= nil) then
	 for k, v in pairs(rsp) do
	    print('<tr><th width=35%>'..k..'</th><td colspan=2>'.. v..'</td></tr>\n')
	 end
      end
   end

   print('</table>\n')
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
