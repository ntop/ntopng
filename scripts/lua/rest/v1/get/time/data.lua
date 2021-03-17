--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

local begin_epoch   = tonumber(_GET["begin_epoch"])
local end_epoch     = tonumber(_GET["end_epoch"])
local num_records   = tonumber(_GET["totalRows"]) or 24


local curr = begin_epoch
local records = {}

-- 1 hour is 60*60=3600

local start = os.time()

for i = 1, num_records, 1 do

    if (curr < end_epoch) then
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