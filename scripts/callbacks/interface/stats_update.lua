--
-- (C) 2013 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- ########################################################

interface.periodicStatsUpdate()

-- ########################################################

