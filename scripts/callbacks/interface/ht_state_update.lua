--
-- (C) 2013 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Keep it in sync with HT_STATE_UPDATE_SCRIPT_PATH periodicity in PeriodicActivities.cpp
-- that is, with the frequency of execution of this script.
local HT_STATE_UPDATE_FREQ = 5 

-- ########################################################

local deadline = os.time() + HT_STATE_UPDATE_FREQ
interface.periodicHTStateUpdate(deadline)

-- ########################################################

