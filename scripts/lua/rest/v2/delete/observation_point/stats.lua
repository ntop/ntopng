--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path


local rest_utils = require "rest_utils"
local endpoints = require("endpoints")
local recipients = require "recipients"

local ifid = _POST["ifid"] or "-1"
local rc = rest_utils.consts.success.ok
local obs_point = _POST["observation_point"]
local res = {}

-- Invalid Interface
if(ifid == -1) then
	rest_utils.answer(rest_utils.consts.err.invalid_interface)
	return
end

-- Not enought "power"
if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- No Observation Point given
if not obs_point then
	rest_utils.answer(rest_utils.consts.err.invalid_args)
	return
end

obs_point = tonumber(obs_point)

interface.select(ifid)

interface.prepareDeleteObsPoint(obs_point)

rest_utils.answer(rest_utils.consts.success.ok)