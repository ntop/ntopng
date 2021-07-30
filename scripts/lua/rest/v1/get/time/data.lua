--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

local epoch_begin   = tonumber(_GET["epoch_begin"])
local epoch_end     = tonumber(_GET["epoch_end"])
local num_records   = tonumber(_GET["totalRows"]) or 24


local curr = epoch_begin
local records = {}

-- 1 hour is 60*60=3600

local start = os.time()

for i = 1, num_records, 1 do

    if (curr < epoch_end) then
        records[#records+1] = {index = i, date = os.date("%c", curr)}
        curr = curr + 3600
    else
        break
    end

end

rest_utils.answer(rest_utils.consts.success.ok, {
    time = os.time() - start,
    records = records
})