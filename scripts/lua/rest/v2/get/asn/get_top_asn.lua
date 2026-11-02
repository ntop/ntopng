--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local as_utils = require "as_utils"
local rest_utils = require "rest_utils"

local ifid = _GET["ifid"]
local epoch_begin = _GET["epoch_begin"] or 0
local epoch_end = _GET["epoch_end"] or 0
local is_live = toboolean(_GET["is_live"] or true)
local selected_asn = _GET["show_as"]
local interface_role = _GET["interface_role"]

-- interface.select silently falls back to an allowed interface: check it
if not isEmptyString(ifid) then
    interface.select(tostring(ifid))
    if tostring(interface.getId()) ~= tostring(ifid) then
        rest_utils.answer(rest_utils.consts.err.invalid_interface)
        return
    end
end

if not is_live and not hasClickHouseSupport() then
    rest_utils.answer(rest_utils.consts.err.clickhouse_missing)
    return 
end

local options = {
    -- The selected interface, never the raw parameter (used in the historical query)
    ifid = interface.getId(),
    epoch_begin = epoch_begin,
    epoch_end = epoch_end,
    selected_asn = selected_asn,
    interface_role = interface_role,
}

local as_info = {}

if is_live == true then
    as_info = as_utils.getTopASLive(options)
else
    as_info = as_utils.getTopASHistorical(options)
end

rest_utils.answer(rest_utils.consts.success.ok, as_info)
