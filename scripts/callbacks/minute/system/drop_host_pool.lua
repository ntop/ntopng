--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

-- #######################################

if ntop.isPro() then
    local drop_host_pool_utils = require "drop_host_pool_utils"
 
    drop_host_pool_utils.check_periodic_hosts_list()
    drop_host_pool_utils.check_pre_banned_hosts_to_add()
 end
