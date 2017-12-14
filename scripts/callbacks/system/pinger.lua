--
-- (C) 2013-17 - ntop.org
--


local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path

if (ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path
   require('pinger')
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end
