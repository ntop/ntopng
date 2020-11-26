--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
-- Stats Utils is a module with some utilities to manipolate statistics data
local stats_utils = {

    -- Upper bounds to get severity for the export drops
    UPPER_BOUND_INFO_EXPORTS = 0.10,
    UPPER_BOUND_WARNING_EXPORTS = 0.20
}

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

-- ###############################################

function stats_utils.get_severity_by_export_drops(drops, total_flows)

    local drops_pctg = (drops / total_flows)
    if drops_pctg <= stats_utils.UPPER_BOUND_INFO_EXPORTS then return "INFO" end
    if drops_pctg <= stats_utils.UPPER_BOUND_WARNING_EXPORTS then return "WARNING" end

    return "DANGER"
end

-- ###############################################

return stats_utils
