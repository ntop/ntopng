--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json          = require("dkjson")
local rest_utils    = require("rest_utils")
local tracker       = require("tracker")

local rc = rest_utils.consts.success.ok
local res = {}

if not haveAdminPrivileges() then
   rest_utils.answer(rest_utils.consts.err.not_granted, res)
   return
end

local id       = _POST["id"]
local url      = _POST["url"]
local user     = _POST["username"]
local alias    = _POST["alias"]
local token    = _POST["token"]

-- TODO: edit fedeteration instance
rest_utils.answer(rc, res)
