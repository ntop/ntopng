--
-- (C) 2020-21 - ntop.org
--
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")

local rest_utils = {
   consts = {
      success = {
         ok                                         = { http_code = 200, rc = 0, str = "OK" },
         snmp_device_deleted                        = { http_code = 200, rc = 0, str = "SNMP_DEVICE_DELETED_SUCCESSFULLY"},
         snmp_device_added                          = { http_code = 200, rc = 0, str = "SNMP_DEVICE_ADDED_SUCCESSFULLY"},
         snmp_device_edited                         = { http_code = 200, rc = 0, str = "SNMP_DEVICE_EDITED_SUCCESSFULLY"},
         pool_deleted                               = { http_code = 200, rc = 0, str = "POOL_DELETED_SUCCESSFULLY"},
         pool_added                                 = { http_code = 200, rc = 0, str = "POOL_ADDED_SUCCESSFULLY"},
         pool_edited                                = { http_code = 200, rc = 0, str = "POOL_EDITED_SUCCESSFULLY"},
         pool_member_bound                          = { http_code = 200, rc = 0, str = "POOL_MEMBER_BOUND_SUCCESSFULLY"},
         -- infrastructure Dashboard
         infrastructure_instance_added                  = { http_code = 200, rc = 0, str = "INFRASTRUCTURE_INSTANCE_ADDED"},
         infrastructure_instance_edited                 = { http_code = 200, rc = 0, str = "INFRASTRUCTURE_INSTANCE_EDITED"},
         infrastructure_instance_deleted                = { http_code = 200, rc = 0, str = "INFRASTRUCTURE_INSTANCE_DELETED"},
      },
      err = {
         not_found                                  = { http_code = 404, rc =  -1, str = "NOT_FOUND"},
         invalid_interface                          = { http_code = 400, rc =  -2, str = "INVALID_INTERFACE"},
         not_granted                                = { http_code = 401, rc =  -3, str = "NOT_GRANTED"},
         invalid_host                               = { http_code = 400, rc =  -4, str = "INVALID_HOST"},
         invalid_args                               = { http_code = 400, rc =  -5, str = "INVALID_ARGUMENTS"},
         internal_error                             = { http_code = 500, rc =  -6, str = "INTERNAL_ERROR"},
         bad_format                                 = { http_code = 400, rc =  -7, str = "BAD_FORMAT"},
         bad_content                                = { http_code = 400, rc =  -8, str = "BAD_CONTENT"},
         resolution_failed                          = { http_code = 400, rc =  -9, str = "NAME_RESOLUTION_FAILED"},
         snmp_device_already_added                  = { http_code = 409, rc = -10, str = "SNMP_DEVICE_ALREADY_ADDED"},
         snmp_device_unreachable                    = { http_code = 400, rc = -11, str = "SNMP_DEVICE_UNREACHABLE"},
         snmp_device_no_device_discovered           = { http_code = 400, rc = -12, str = "NO_SNMP_DEVICE_DISCOVERED"},
         add_pool_failed                            = { http_code = 409, rc = -13, str = "ADD_POOL_FAILED"},
         edit_pool_failed                           = { http_code = 409, rc = -14, str = "EDIT_POOL_FAILED"},
         delete_pool_failed                         = { http_code = 409, rc = -15, str = "DELETE_POOL_FAILED"},
         pool_not_found                             = { http_code = 409, rc = -16, str = "POOL_NOT_FOUND"},
         bind_pool_member_failed                    = { http_code = 409, rc = -17, str = "BIND_POOL_MEMBER_FAILED"},
         bind_pool_member_already_bound             = { http_code = 409, rc = -18, str = "BIND_POOL_MEMBER_ALREADY_BOUND"},
         password_mismatch                          = { http_code = 400, rc = -19, str = "PASSWORD_MISMATCH"},
         add_user_failed                            = { http_code = 409, rc = -20, str = "ADD_USER_FAILED"},
         delete_user_failed                         = { http_code = 409, rc = -21, str = "DELETE_USER_FAILED"},
         snmp_unknown_device                        = { http_code = 400, rc = -22, str = "SNMP_UNKNOWN_DEVICE"},
         user_already_existing                      = { http_code = 409, rc = -23, str = "USER_ALREADY_EXISTING"},
         user_does_not_exist                        = { http_code = 409, rc = -24, str = "USER_DOES_NOT_EXIST"},
         edit_user_failed                           = { http_code = 400, rc = -25, str = "EDIT_USER_FAILED"},
	 snmp_device_interface_status_change_failed = { http_code = 400, rc = -26, str = "SNMP_DEVICE_INTERFACE_STATUS_CHANGE_FAILED"},
         configuration_file_mismatch                = { http_code = 400, rc = -27, str = "CONFIGURATION_FILE_MISMATCH" },
         partial_import                             = { http_code = 409, rc = -28, str = "PARTIAL_IMPORT" },

         -- Infrastructure Dashboard
         add_infrastructure_instance_failed         = { http_code = 409, rc = -29, str = "ADD_INFRASTRUCTURE_INSTANCE_FAILED"},
         edit_infrastructure_instance_failed        = { http_code = 409, rc = -30, str = "EDIT_INFRASTRUCTURE_INSTANCE_FAILED"},
         delete_infrastructure_instance_failed      = { http_code = 409, rc = -31, str = "DELETE_INFRASTRUCTURE_INSTANCE_FAILED"},
         infrastructure_instance_not_found          = { http_code = 404, rc = -32, str = "INFRASTRUCTURE_INSTANCE_NOT_FOUND"},

         infrastructure_instance_empty_id           = { http_code = 409, rc = -33, str = "INFRASTRUCTURE_INSTANCE_EMPTY_ID"},
         infrastructure_instance_empty_alias        = { http_code = 409, rc = -34, str = "INFRASTRUCTURE_INSTANCE_EMPTY_ALIAS"},
         infrastructure_instance_empty_url          = { http_code = 409, rc = -35, str = "INFRASTRUCTURE_INSTANCE_EMPTY_URL"},
         infrastructure_instance_empty_token        = { http_code = 409, rc = -36, str = "INFRASTRUCTURE_INSTANCE_EMPTY_TOKEN"},
         infrastructure_instance_empty_rtt_threshold         = { http_code = 409, rc = -37, str = "INFRASTRUCTURE_INSTANCE_EMPTY_RTT_THRESHOLD"},

         infrastructure_instance_same_id            = { http_code = 409, rc = -38, str = "INFRASTRUCTURE_INSTANCE_SAME_ID"},
         infrastructure_instance_same_alias         = { http_code = 409, rc = -39, str = "INFRASTRUCTURE_INSTANCE_SAME_ALIAS"},
         infrastructure_instance_same_url           = { http_code = 409, rc = -40, str = "INFRASTRUCTURE_INSTANCE_SAME_URL"},
         infrastructure_instance_same_token         = { http_code = 409, rc = -41, str = "INFRASTRUCTURE_INSTANCE_SAME_TOKEN"},

         infrastructure_instance_already_existing   = { http_code = 409, rc = -42, str = "INFRASTRUCTURE_INSTANCE_ALREADY_EXISTING"},

         infrastructure_instance_check_failed       = { http_code = 409, rc = -43, str = "INFRASTRUCTURE_INSTANCE_CHECK_FAILED"},
         infrastructure_instance_check_not_found    = { http_code = 409, rc = -44, str = "INFRASTRUCTURE_INSTANCE_CHECK_NOT_FOUND"},
         infrastructure_instance_check_invalid_rsp  = { http_code = 409, rc = -45, str = "INFRASTRUCTURE_INSTANCE_CHECK_INVALID_RESPONSE"},
         infrastructure_instance_check_auth_failed  = { http_code = 409, rc = -46, str = "INFRASTRUCTURE_INSTANCE_CHECK_AUTH_FAILED"},
         infrastructure_instance_empty_bandwidth_threshold   = { http_code = 409, rc = -47, str = "INFRASTRUCTURE_INSTANCE_EMPTY_BANDWIDTH_THRESHOLD"},

	 --Widgets
	 widgets_missing_transformation = { http_code = 409, rc = -48, str = "WIDGETS_MISSING_TRANSFORMATION"},
	 widgets_missing_datasources = { http_code = 409, rc = -49, str = "WIDGETS_MISSING_DATASOURCES"},
	 widgets_missing_datasource_type = { http_code = 409, rc = -50, str = "WIDGETS_MISSING_DATASOURCE_TYPE"},
	 widgets_unknown_datasource_type = { http_code = 409, rc = -51, str = "WIDGETS_UNKNOWN_DATASOURCE_TYPE"},
	 widgets_missing_datasource_params = { http_code = 409, rc = -52, str = "WIDGETS_MISSING_DATASOURCE_PARAMS"},
      },
   }
}

function rest_utils.rc(ret_const, payload, additional_response_param, format)
   local ret_code = ret_const.rc
   local rc_str   = ret_const.str  -- String associated to the return code
   local rc_str_hr -- String associated to the return code, human readable

   -- Prepare the human readable string
   rc_str_hr = i18n("rest_consts."..rc_str) or "Unknown"

   local client_rsp = {
      rc = ret_code,
      rc_str = rc_str,
      rc_str_hr = rc_str_hr,
      rsp = payload or {}
   }

   if (additional_response_param ~= nil) then
      client_rsp = table.merge(additional_response_param, client_rsp)
   end

   if (format) and (format == 'txt') then
      return client_rsp
   else
      return json.encode(client_rsp)
   end
end

function rest_utils.answer(ret_const, payload, extra_headers)
   sendHTTPHeader('application/json', nil, extra_headers, ret_const.http_code)
   print(rest_utils.rc(ret_const, payload))
end

function rest_utils.extended_answer(ret_const, payload, additional_response_param, extra_headers, format)
   local rsp_format = 'application/json'

   if (format) and (format == 'txt') then
      rsp_format = 'text/plain'
   end
   
   sendHTTPHeader(rsp_format, nil, extra_headers, ret_const.http_code)
   print(rest_utils.rc(ret_const, payload, additional_response_param, format))
end

function rest_utils.vanilla_payload_response(ret_const, payload, content_type)
   if content_type == nil then
      content_type = "text/plain"
   end
   sendHTTPHeader(content_type, nil, {}, ret_const.http_code)
   print(payload)
end

return rest_utils
