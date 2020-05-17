--
-- (C) 2020 - ntop.org
--
-- 

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")

local rest_utils = {}

rest_utils.consts_ok                = 0
rest_utils.consts_not_found         = -1
rest_utils.consts_invalid_interface = -2

local rc_str_consts = {
   [rest_utils.consts_ok] = "OK",
   [rest_utils.consts_not_found] = "NOT_FOUND",
   [rest_utils.consts_invalid_interface] = "INVALID_INTEFACE",
}

function rest_utils.rc(ret_code, response)
   local client_rsp = { rc = ret_code, rc_str = rc_str_consts[ret_code], rsp = response or {} }
   return(json.encode(client_rsp))
end


return rest_utils
