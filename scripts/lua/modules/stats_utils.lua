--
-- (C) 2020-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Light requires instead of lua_utils: this module is used by periodic REST endpoints
require "ntop_utils" -- pairsByField(), rev(), table.len()
require "lua_utils_generic" -- table.foldr()
require "locales_utils" -- i18n()
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
function stats_utils.collapse_stats(stats, min_slices, threshold)

    threshold = threshold or 1

    local collapsed = {}

    local total = table.foldr(stats, function(sum, stat) return sum + stat.value end, 0)
    -- set the bound to the total / 100 (1%)
    local bound = ((total * threshold) / 100)

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

function stats_utils.collapse_top_stats(stats, threshold)
    local top_res = {}
    local other_total = 0

    for i, entry in ipairs(stats) do
        if i <= threshold then
            top_res[#top_res + 1] = entry
        else
            other_total = other_total + entry.value
        end
    end

    if other_total > 0 then
        top_res[#top_res + 1] = {
            label = i18n("other"),
            value = other_total,
        }
   end
    
    return top_res
end

-- ###############################################

function stats_utils.get_severity_by_export_drops(export_drops, total_exports)
   if export_drops and total_exports then
      local drops_fraction = export_drops / (export_drops + total_exports + 1)
      if drops_fraction <= stats_utils.UPPER_BOUND_INFO_EXPORTS then
	 return "INFO"
      elseif drops_fraction <= stats_utils.UPPER_BOUND_WARNING_EXPORTS then
	 return "WARNING"
      elseif drops_fraction > stats_utils.UPPER_BOUND_WARNING_EXPORTS then
      return "DANGER"
      end
   end

   return "INFO"
end

-- ###############################################

function stats_utils.computeL7Stats(stats, show_breed, show_ndpi_category)
    local _ifstats = {}

    if table.len(stats) == 0 then
        return _ifstats
    end

    if (show_breed) then
        local breed_stats = {}

        for key, value in pairs(stats["ndpi"]) do
            local b = stats["ndpi"][key]["breed"]

            local traffic = stats["ndpi"][key]["bytes.sent"] + stats["ndpi"][key]["bytes.rcvd"]

            if (breed_stats[b] == nil) then
                breed_stats[b] = traffic
            else
                breed_stats[b] = breed_stats[b] + traffic
            end
        end

        for key, value in pairs(breed_stats) do
            _ifstats[key] = value
        end

    elseif (show_ndpi_category) then
        local ndpi_category_stats = {}

        require "lua_utils_get" -- getCategoryLabel()

        for key, value in pairs(stats["ndpi_categories"]) do
            key = getCategoryLabel(key, value.category)
            local traffic = value["bytes"]

            if (ndpi_category_stats[key] == nil) then
                ndpi_category_stats[key] = traffic
            else
                ndpi_category_stats[key] = ndpi_category_stats[key] + traffic
            end
        end

        for key, value in pairs(ndpi_category_stats) do
            _ifstats[key] = value
        end

    else
        -- Add ARP to stats
        local arpBytes = 0
        if (stats["eth"] ~= nil) then
            arpBytes = stats["eth"]["ARP_bytes"]
            if (arpBytes > 0) then
                _ifstats["ARP"] = arpBytes
            end
        end

        for key, value in pairs(stats["ndpi"]) do
            local traffic = value["bytes.sent"] + value["bytes.rcvd"]
            if (key == "Unknown") then
                traffic = traffic - arpBytes
            end

            if (traffic > 0) then
                if (show_breed) then
                    _ifstats[value["breed"]] = traffic
                else
                    _ifstats[key] = traffic
                end
            end
        end
    end

    return _ifstats
end

-- ###############################################

return stats_utils
