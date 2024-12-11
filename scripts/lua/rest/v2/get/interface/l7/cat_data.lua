--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local categories_utils = require "categories_utils"

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

local ifstats = interface.getStats()
if ifstats and ifstats.ndpi_categories then
    local total_bytes = 0
    for _, value in pairs(ifstats.ndpi_categories or {}) do
        -- calculate the total
        local bytes_in = value["bytes.rcvd"]
        local bytes_out = value["bytes.sent"]
        total_bytes = total_bytes + bytes_in + bytes_out
    end
    for protocol, value in pairs(ifstats.ndpi_categories or {}) do
        local bytes_in = value["bytes.rcvd"]
        local bytes_out = value["bytes.sent"]
        res[#res + 1] = {
            category = {
                name = protocol,
                id = value.category
            },
            bytes = {
                rcvd = bytes_in,
                sent = bytes_out,
                total = bytes_in + bytes_out,
                percentage = math.floor(1 + (bytes_in + bytes_out) * 100 / total_bytes)
            },
            applications_list = categories_utils.get_category_protocols_list(value.category)
        }
    end
end

rest_utils.answer(rc, res)