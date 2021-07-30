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

local rc = rest_utils.consts.success.ok

local curr = epoch_begin

-- 1 hour is 60*60=3600
local datasets = {}
local labels = {}

for i = 1, num_records, 1 do

    if (curr < epoch_end) then

        local key = os.date("%x", curr)
        if datasets[key] == nil then
            datasets[key] = 0
        end

        -- add an hour?
        datasets[key] = datasets[key] + 1

        curr = curr + 3600 -- ad an hour
    else
        break
    end

end

local flatten = {}
local i = 1

for k, d in pairsByKeys(datasets) do 

    flatten[i] = d
    labels[i] = k

    i = i + 1
end

rest_utils.answer(rc, {
    data = {
        labels = labels,
        datasets = {
            {data = flatten, label = "Hours in a day", backgroundColor = "#f83a5dfa"}
        }
    },
    options = {
        maintainAspectRatio = false
    },
    redirect_url = ntop.getHttpPrefix() 
})
