--
-- (C) 2013-26 - ntop.org
--
require "lua_utils_gui"
local json = require "dkjson"

local historical_format_utils = {}

-- #######################################

-- This function is us
function historical_format_utils.parseInfoJson(info, flow)
    local info_field = {}
    -- The field is serialized as a json, first deserialize then parse and format
    if info and not isEmptyString(info) then
        info = json.decode(info)
        info_field = info
    else
        info = {}
        info_field = {}
    end

    -- The requested server name (SNI) is stored in the REQUESTED_SERVER_NAME column now,
    -- while it used to be in the json field (client_requested_server_name)
    if flow and not isEmptyString(flow["REQUESTED_SERVER_NAME"]) then
        info.proto = info.proto or {}
        info.proto.tls = info.proto.tls or {}
        info.proto.tls.client_requested_server_name = flow["REQUESTED_SERVER_NAME"]
        info_field = info
    end

    if (info.proto) and (table.len(info.proto) > 0) then
        info_field.proto = format_proto_info({}, info.proto)
    end

    if not (ntop.isnEdge and ntop.isnEdge()) then
        info_field.verdict = nil
    end
    
    return info_field
end

-- #######################################

return historical_format_utils
