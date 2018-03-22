--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path
  pcall(require, 'minute')
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

ntop.tsFlush(tonumber(60))
