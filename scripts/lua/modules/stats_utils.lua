--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Stats Utils is a module with some utilities to manipolate statistics data
local stats_utils = {}

require("lua_utils")

--- Collapse the collected statistics inside an 'Other' entry if
--- there are stats less than 1% and these stats are greater or equal `min_slices`
--- @param stats table Stats to collapse
--- @param min_slices number How many slices less than 1% there must to be for collapsing
--- @param build_data function Function to build data returned from collapse_stats
--- @param iterator function Function to iterate data inside the stats table
--- @param order function Function to sort data
function stats_utils.collapse_stats(stats, min_slices, build_data, iterator, order)

    -- if there are multiple slices <= 1% then merge them inside other
    local UPPER_BOUND = 1

    -- set min_slices variable to 0 if it's negative
    min_slices = (min_slices <= 0 and 0 or min_slices)
    -- the ipairs function is the default iterator
    iterator = (iterator or ipairs)
    order = (order or asc)

    local greater_than_upper_bound = {}
    -- hold values less than the UPPER_BOUND variable
    local less_than_upper_bound = {}

    for key, value in iterator(stats, order) do

        -- invoke build_data function to build data
        local data = build_data(key, value)

        local value_pctg = data.value * UPPER_BOUND / 100

        -- if the value is less than the UPPER_BOUND then put the data
        -- inside less_than_upper_bound table
        if (value_pctg <= UPPER_BOUND) then
            less_than_upper_bound[#less_than_upper_bound + 1] = data
        else
            -- otherwise, add the data in the result directly
            greater_than_upper_bound[#greater_than_upper_bound + 1] = data
        end
    end

    -- if min_slices is reached then collapse the data into other
    if (#less_than_upper_bound >= min_slices) then

        -- merge the slices inside the other data
        local res = greater_than_upper_bound
        local sum = table.foldr(less_than_upper_bound,
                                function(a, d) return a + d.value end, 0)
        local other = {label = i18n("other"), value = sum}
        -- add other to the results
        res[#res + 1] = other

        return res
    end

    -- otherwise, merge the two tables
    return table.merge(greater_than_upper_bound, less_than_upper_bound)
end

return stats_utils
