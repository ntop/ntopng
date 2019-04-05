--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require("dkjson")

local host_info = url2hostinfo(_GET)
local ip = host_info["host"]
sendHTTPContentTypeHeader('text/html')
local info = interface.getHostInfo(ip)
if info and info["mac"] then



    local mac = info["mac"]
    print[[
    <!DOCTYPE html>    
    <html>
    <body>
    
    <script>      
        window.onload = function(){
            var url = window.location.href;
            var segements = url.split("/");
            segements[segements.length - 1] = "mac_details.lua?host=]] print(mac) print[[";
            window.location.href = segements.join("/");
        }

        
    </script>
    
    </body>
    </html> 
    ]]
else
    
    print("error")

end
--TODO: prendi i nomi?

--tskey string fe80::5e2e:4b27:7f84:97a7
--names.dhcp string fra-AspireV15
--ip string fe80::5e2e:4b27:7f84:97a7
--name string DESKTOP-4DGATJJ
--mac string 98:E7:F4:2F:5C:23
--names.resolved string pc-pellegrini.iit.cnr.it
--ipkey number 2452644127


--print("window.location.href = mac_details.lua?host="..mac)


