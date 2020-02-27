--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local system_utils = require "system_utils"

-- ########################################################

system_utils.compute_cpu_states()

-- ########################################################

