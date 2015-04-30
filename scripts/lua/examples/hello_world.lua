--
-- (C) 2013 - ntop.org
--

-- Hello world

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

print('<html><head><title>ntop</title></head><body>Hello ' .. os.date("%d.%m.%Y"))

-- Print _GET variable
for key, value in pairs(_GET) do 
   print(key.."="..value.."<p>\n")
end

rsp = ntop.httpGet("http://www.google.com")
print(rsp)
print('</body></html>\n')




