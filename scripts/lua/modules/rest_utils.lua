--
-- (C) 2020 - ntop.org
--
-- 

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")

local rest_utils = {
   consts = {
      success = {
         ok                   =  {rc = 0, str = "OK"},
	 snmp_device_deleted  =  {rc = 0, str = "SNMP_DEVICE_DELETED_SUCCESSFULLY"},
	 snmp_device_added    =  {rc = 0, str = "SNMP_DEVICE_ADDED_SUCCESSFULLY"},
	 snmp_device_edited   =  {rc = 0, str = "SNMP_DEVICE_EDITED_SUCCESSFULLY"},
	 pool_deleted         =  {rc = 0, str = "POOL_DELETED_SUCCESSFULLY"},
	 pool_added           =  {rc = 0, str = "POOL_ADDED_SUCCESSFULLY"},
	 pool_edited          =  {rc = 0, str = "POOL_EDITED_SUCCESSFULLY"},
	 pool_member_bound    =  {rc = 0, str = "POOL_MEMBER_BOUND_SUCCESSFULLY"},
      },
      err = {
         not_found                        = {rc =  -1, str = "NOT_FOUND"},
         invalid_interface                = {rc =  -2, str = "INVALID_INTERFACE"},
         not_granted                      = {rc =  -3, str = "NOT_GRANTED"},
         invalid_host                     = {rc =  -4, str = "INVALID_HOST"},
         invalid_args                     = {rc =  -5, str = "INVALID_ARGUMENTS"},
         internal_error                   = {rc =  -6, str = "INTERNAL_ERROR"},
         bad_format                       = {rc =  -7, str = "BAD_FORMAT"},
         bad_content                      = {rc =  -8, str = "BAD_CONTENT"},
         resolution_failed                = {rc =  -9, str = "NAME_RESOLUTION_FAILED"},
         snmp_device_already_added        = {rc = -10, str = "SNMP_DEVICE_ALREADY_ADDED"},
         snmp_device_unreachable          = {rc = -11, str = "SNMP_DEVICE_UNREACHABLE"},
         snmp_device_no_device_discovered = {rc = -12, str = "NO_SNMP_DEVICE_DISCOVERED"},
         add_pool_failed                  = {rc = -13, str = "ADD_POOL_FAILED"},
         edit_pool_failed                 = {rc = -14, str = "EDIT_POOL_FAILED"},
         delete_pool_failed               = {rc = -15, str = "DELETE_POOL_FAILED"},
         pool_not_found                   = {rc = -16, str = "POOL_NOT_FOUND"},
         bind_pool_member_failed          = {rc = -17, str = "BIND_POOL_MEMBER_FAILED"},
         bind_pool_member_already_bound   = {rc = -18, str = "BIND_POOL_MEMBER_ALREADY_BOUND"},
         password_mismatch                = {rc = -19, str = "PASSWORD_MISMATCH"},
         add_user_failed                  = {rc = -20, str = "ADD_USER_FAILED"},
         delete_user_failed               = {rc = -21, str = "DELETE_USER_FAILED"},
         snmp_unknown_device              = {rc = -22, str = "SNMP_UNKNOWN_DEVICE"},
         user_already_existing            = {rc = -23, str = "USER_ALREADY_EXISTING"},
         user_does_not_exist              = {rc = -24, str = "USER_DOES_NOT_EXIST"},
         edit_user_failed                 = {rc = -25, str = "EDIT_USER_FAILED"},
      },
   }
}

function rest_utils.rc(ret_const, response)
   local ret_code = ret_const.rc
   local rc_str   = ret_const.str  -- String associated to the return code
   local rc_str_hr -- String associated to the retrun code, human readable

   -- Prepare the human readable string
   rc_str_hr = i18n("rest_consts."..rc_str) or "Unknown"

   local client_rsp = {
      rc = ret_code,
      rc_str = rc_str,
      rc_str_hr = rc_str_hr,
      rsp = response or {}
   }

   return json.encode(client_rsp)
end


return rest_utils
