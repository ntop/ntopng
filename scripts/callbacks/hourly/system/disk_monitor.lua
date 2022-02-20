--
-- (C) 2019-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local storage_utils = require("storage_utils")

-- ##############################################

storage_utils.storageInfo(true --[[ refresh cache ]], 120 --[[ Allow a couple of minutes --]])
 