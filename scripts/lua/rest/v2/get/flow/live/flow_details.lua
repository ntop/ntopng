--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/llm/?.lua;" .. package.path

require "http_lint"
require "lua_utils_gui"
local rest_utils = require "rest_utils"
local live_flow_info = require "live_flow_info"

-- ################################################

local ifid = _GET["ifid"] or interface.getId()
local flow_key = _GET["flow_key"]
local flow_hash_id = _GET["flow_hash_id"]

if isEmptyString(flow_key) or isEmptyString(flow_hash_id) then
    return rest_utils.answer(rest_utils.consts.err.bad_content)
end

-- ################################################

local rsp = live_flow_info.get_flow(tostring(ifid), tostring(flow_key), tostring(flow_hash_id))

if type(rsp) == "string" then
    return rest_utils.answer(rest_utils.consts.err.bad_content, {error = rsp})
end

rest_utils.answer(rest_utils.consts.success.ok, rsp)
