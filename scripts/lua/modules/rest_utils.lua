--
-- (C) 2020 - ntop.org
--
-- 

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")

local rest_utils = {}

rest_utils.consts_ok                               =  0
rest_utils.consts_not_found                        = -1
rest_utils.consts_invalid_interface                = -2
rest_utils.consts_not_granted                      = -3
rest_utils.consts_invalid_host                     = -4
rest_utils.consts_invalid_args                     = -5
rest_utils.consts_internal_error                   = -6
rest_utils.consts_bad_format                       = -7
rest_utils.consts_bad_content                      = -8
rest_utils.consts_resolution_failed                = -9
rest_utils.consts_snmp_device_already_added        = -10
rest_utils.consts_snmp_device_unreachable          = -11
rest_utils.consts_snmp_device_no_device_discovered = -12
rest_utils.consts_add_pool_failed                  = -13
rest_utils.consts_edit_pool_failed                 = -14
rest_utils.consts_delete_pool_failed               = -15
rest_utils.consts_pool_not_found                   = -16
rest_utils.consts_bind_pool_member_failed          = -17
rest_utils.consts_bind_pool_member_already_bound   = -18
rest_utils.consts_password_mismatch                = -19
rest_utils.consts_add_user_failed                  = -20
rest_utils.consts_delete_user_failed               = -21
rest_utils.consts_snmp_unknown_device              = -22

local rc_str_consts = {
   [rest_utils.consts_ok] = "OK",
   [rest_utils.consts_not_found] = "NOT_FOUND",
   [rest_utils.consts_invalid_interface] = "INVALID_INTERFACE",
   [rest_utils.consts_not_granted] = "NOT_GRANTED",
   [rest_utils.consts_invalid_host] = "INVALID_HOST",
   [rest_utils.consts_invalid_args] = "INVALID_ARGUMENTS",
   [rest_utils.consts_internal_error] = "INTERNAL_ERROR",
   [rest_utils.consts_bad_format] = "BAD_FORMAT",
   [rest_utils.consts_bad_content] = "BAD_CONTENT",
   [rest_utils.consts_resolution_failed] = "NAME_RESOLUTION_FAILED",
   [rest_utils.consts_snmp_device_already_added] = "SNMP_DEVICE_ALREADY_ADDED",
   [rest_utils.consts_snmp_device_unreachable] = "SNMP_DEVICE_UNREACHABLE",
   [rest_utils.consts_snmp_device_no_device_discovered] = "NO_SNMP_DEVICE_DISCOVERED",
   [rest_utils.consts_add_pool_failed] = "ADD_POOL_FAILED",
   [rest_utils.consts_edit_pool_failed] = "EDIT_POOL_FAILED",
   [rest_utils.consts_delete_pool_failed] = "DELETE_POOL_FAILED",
   [rest_utils.consts_pool_not_found] = "POOL_NOT_FOUND",
   [rest_utils.consts_bind_pool_member_failed] = "BIND_POOL_MEMBER_FAILED",
   [rest_utils.consts_bind_pool_member_already_bound] = "BIND_POOL_MEMBER_ALREADY_BOUND",
   [rest_utils.consts_password_mismatch] = "PASSWORD_MISMATCH",
   [rest_utils.consts_add_user_failed] = "ADD_USER_FAILED",
   [rest_utils.consts_delete_user_failed] = "DELETE_USER_FAILED",
   [rest_utils.consts_snmp_unknown_device] = "SNMP_UNKNOWN_DEVICE",
}

function rest_utils.rc(ret_code, response)
   local client_rsp = { rc = ret_code, rc_str = rc_str_consts[ret_code], rsp = response or {} }
   return(json.encode(client_rsp))
end


return rest_utils
