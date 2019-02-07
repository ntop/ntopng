--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local remote_assistance = require "remote_assistance"

-- ########################################################

remote_assistance.checkExpiration()
