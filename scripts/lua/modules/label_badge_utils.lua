--
-- (C) 2013-26 - ntop.org
--

require "ntop_utils"

local label_badge_utils = {}

-- ##############################################

local function get_redis_key()
    return "ntopng.prefs.labels"
end

-- ##############################################

local function get_default_labels_table()
    labels = {}

    for i = 16, 31 do
        labels[i] = {
            id = i,
            color = "#000000",
            description = "",
            name = "Customizable_Label",
            reserved = "false"
        }
    end
    return labels
end

-- ##############################################

local function get_labels_from_cache()
    return ntop.getHashAllCache(get_redis_key()) or {}
end

-- ##############################################

local function get_labels()
    local json = require "dkjson"
    local labels = get_default_labels_table()
    local existing_labels = get_labels_from_cache()
    for _, label_json in pairs(existing_labels) do
        local label = json.decode(label_json)
        if label then
            labels[label.id] = label
        end
    end
    return labels
end

-- ##############################################

-- Returns all the labels
function label_badge_utils.getLabels()
    local labels = get_labels()

    local result = {}
    for _,label in pairs(labels) do
        local record = {}
        record["id"] = label.id
        record["name"] = label.name
        record["color"] = label.color 
        record["description"] = label.description
        record["reserved"] = label.reserved
        result[#result + 1] = label
    end
    return result
end

-- ##############################################

-- Updates the label passed as a parameter
-- id: id of the label to update 
-- name: new name of the label to update
-- color: new color of the label to update (string containing a HEX value)
-- description: new description of the label to update
function label_badge_utils.editLabel(id, name, color, description, reserved)
    local json = require "dkjson"
    local label = {
        id = id, 
        name = name, 
        color = color,
        description = description, 
        reserved = reserved
    }
    ntop.setHashCache(get_redis_key(), id, json.encode(label))
    --tprint(old_name .. " " .. name .. " " .. color .. " " .. description)
end

-- ##############################################

function label_badge_utils.deleteLabel(id)
    local labels = get_labels_from_cache()

    -- Validate and normalize ID
    if id then
        id = tostring(id)
    else
        return false, "Invalid ID"
    end
    -- Check if label exists before deletion
    if labels[id] then
        -- Remove label from Redis
        ntop.delHashCache(get_redis_key(), id)
    else
        return false, "Invalid Site"
    end

    local success_msg = "Label deleted successfully"
    return true, success_msg
end

return label_badge_utils