--
-- (C) 2013-17 - ntop.org
--


local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path

if ntop.isnEdge() then
   package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/?.lua;" .. package.path
   local ping_utils = require('ping_utils')
   ping_utils.check_status()
end
