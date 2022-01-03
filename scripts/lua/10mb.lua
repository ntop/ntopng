--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPContentTypeHeader('text/plain;charset=UTF-8')

str = "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
tot = 10 * (1024 * 1024) / string.len(str)

for i=1,tot do
   print(str)   
end
