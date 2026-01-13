--
-- (C) 2013-26 - ntop.org
--

require "ntop_utils"

local label_badge_utils = {}

-- ##############################################

-- Returns all the labels
function label_badge_utils.getLabels()
    local labels = {}

    -- IMPLEMENT
    record1 = {name = "Prova1", color = "#11ab3a", description = "test1", reserved = "false"}
    record2 = {name = "Prova2", color = "#de4323", description = "test2", reserved = "false"}
    record3 = {name = "test", color = "#2765a3", description = "test3", reserved = "true"}
    labels[#labels + 1] = record1
    labels[#labels + 1] = record2
    labels[#labels + 1] = record3
    -- 

    local result = {}
    for _,label in pairs(labels) do
        local record = {}
        record["name"] = label.name
        record["color"] = label.color 
        record["description"] = label.description
        record["reserved"] = label.reserved
        result[#result + 1] = label
    end
    return result
end

-- ##############################################

-- IMPLEMENT
-- Updates the label passed as a parameter
-- old_name: previous name of the label to use for identification 
-- name: new name of the label to update
-- color: new color of the label to update (string containing a HEX value)
-- description: new description of the label to update
function label_badge_utils.editLabel(old_name, name, color, description)
    --tprint(old_name .. " " .. name .. " " .. color .. " " .. description)
end

return label_badge_utils