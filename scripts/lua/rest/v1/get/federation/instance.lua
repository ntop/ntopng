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

local id     = _GET["id"]

if isEmptyString(id) then
    -- TODO: return all the instances
    res = {
        {id = 0, alias = "Firenze ntopng", user = "admin", token = "1e0c611168c63bc9bae9fd32cb269bdf", url = "http://ntopng.gabriele.it:3000"},
        {id = 1, alias = "Prato ntopng", user = "admin", token = "1e0c611168c63bc9bae9fd32cb269bdf", url = "http://ntopng.gabriele.it:3000"},
        {id = 2, alias = "Pisa ntopng", user = "admin", token = "1e0c611168c63bc9bae9fd32cb269bdf", url = "http://ntopng.gabriele.it:3000"},
    }
else
    -- TODO: return the instance identified by the id
    res = {id = 0, alias = "Firenze ntopng", username = "admin", password = "gabriele", url = "http://ntopng.gabriele.it:3000"}
end

rest_utils.answer(rc, res)
