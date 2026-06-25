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
        return {}
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
