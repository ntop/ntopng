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
function stats_utils.collapse_stats(stats, min_slices)

    local collapsed = {}

    local total = table.foldr(stats, function(sum, stat) return sum + stat.value end, 0)
    -- set the bound to the total / 100 (1%)
    local bound = (total / 100)

    local other = {label = i18n("other"), value = 0}
    -- set the counter to min_slice so we know when we have to start collapsing
    local counter = min_slices

    for _, stat in pairsByField(stats, 'value', rev) do

        if counter == 0 then

            if stat.value < bound then
                other.value = other.value + stat.value
            else
                collapsed[#collapsed+1] = stat
            end

        else
            collapsed[#collapsed+1] = stat
            counter = counter - 1
        end

    end

    -- if we reached the minum slices to collapse the statistics inside the Other element
    if counter == 0 then
        -- add the other element
        collapsed[#collapsed+1] = other
    end

    return collapsed
end

return stats_utils
