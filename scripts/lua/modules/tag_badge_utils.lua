--
-- (C) 2013-26 - ntop.org
--

require "ntop_utils"

local tag_badge_utils = {}

-- ##############################################

-- Built-in host tags (bits 0-31).
-- Keep in sync with include/ntop_defines.h
tag_badge_utils.builtin_tags = {
    [0]  = { i18n = "asset_details.dns_server"      }, -- HOST_TAG_DNS_SERVER
    [1]  = { i18n = "asset_details.ntp_server"      }, -- HOST_TAG_NTP_SERVER
    [2]  = { i18n = "asset_details.dhcp_server"     }, -- HOST_TAG_DHCP_SERVER
    [3]  = { i18n = "asset_details.smtp_server"     }, -- HOST_TAG_SMTP_SERVER
    [4]  = { i18n = "asset_details.network_gateway" }, -- HOST_TAG_NETWORK_GATEWAY
    [5]  = { i18n = "asset_details.imap_server"     }, -- HOST_TAG_IMAP_SERVER
    [6]  = { i18n = "asset_details.pop_server"      }, -- HOST_TAG_POP_SERVER
    [7]  = { i18n = "asset_details.http_server"     }, -- HOST_TAG_HTTP_SERVER
    [8]  = { i18n = "asset_details.ssh_server"      }, -- HOST_TAG_SSH_SERVER
    [9]  = { i18n = "asset_details.rdp_server"      }, -- HOST_TAG_RDP_SERVER
    [10] = { i18n = "asset_details.modbus_server"   }, -- HOST_TAG_MODBUS_SERVER
    [11] = { i18n = "asset_details.s7comm_server"   }, -- HOST_TAG_S7COMM_SERVER
    [12] = { i18n = "asset_details.profinet_server"    }, -- HOST_TAG_PROFINET_SERVER
    [13] = { i18n = "asset_details.non_pqc_compliant"  }, -- HOST_TAG_NON_PQC_COMPLIANT
}

-- ##############################################

local function get_redis_key()
    return "ntopng.prefs.tags"
end

-- ##############################################

local function get_default_tags_table()
    local tags = {}

    -- Bits 0-31: ntop built-in tags (read-only, auto-assigned by ntopng)
    for id, entry in pairs(tag_badge_utils.builtin_tags) do
        local name = i18n(entry.i18n)
        if name == nil then
            traceError(TRACE_WARNING, TRACE_CONSOLE,
                "tag_badge_utils: i18n key not found: " .. entry.i18n)
        end
        tags[id] = {
            id          = id,
            color       = "#0d6efd",
            description = "",
            name        = name,
            reserved    = "true",
            protocols   = {},
            risks       = {}
        }
    end

    -- Bits 32-63: user-customizable tags
    for i = 32, 63 do
        tags[i] = {
            id          = i,
            color       = "#000000",
            description = "",
            name        = "Customizable_Tag_" .. i,
            reserved    = "false",
            protocols   = {},
            risks       = {}
        }
    end
    return tags
end

-- ##############################################

-- Sanitize a list of numeric ids (nDPI application ids or flow risk ids) bound
-- to a tag. Both a table and a comma separated string (as sent by the REST) are accepted
local function normalize_ids(ids)
    local res = {}

    if type(ids) == "string" then
        ids = split(ids, ",")
    end

    if type(ids) == "table" then
        for _, value in pairs(ids) do
            local id = tonumber(value)
            if id then
                res[#res + 1] = id
            end
        end
    end
    return res
end

-- ##############################################

local function get_tags_from_cache()
    return ntop.getHashAllCache(get_redis_key()) or {}
end

-- ##############################################

local function get_tags()
    local json = require "dkjson"
    local tags = get_default_tags_table()
    local existing_tags = get_tags_from_cache()
    for _, tag_json in pairs(existing_tags) do
        local tag = json.decode(tag_json)
        if tag then
            tag.protocols = normalize_ids(tag.protocols)
            tag.risks = normalize_ids(tag.risks)
            tags[tag.id] = tag
        end
    end
    return tags
end

-- ##############################################

-- Returns true if the tag is a ntopng built-in (read-only) tag
function tag_badge_utils.isReservedTag(id)
    return tag_badge_utils.builtin_tags[tonumber(id)] ~= nil
end

-- ##############################################

-- Returns true if flow risks can be bound to the tags (Enterprise L or above)
function tag_badge_utils.areTagRisksSupported()
    return (ntop.isEnterpriseL and ntop.isEnterpriseL()) or false
end

-- ##############################################

-- Returns all the tags
function tag_badge_utils.getTags()
    local tags = get_tags()

    local result = {}
    for _,tag in pairs(tags) do
        local record = {}
        record["id"] = tag.id
        record["name"] = tag.name
        record["color"] = tag.color
        record["description"] = tag.description
        record["reserved"] = tag.reserved
        result[#result + 1] = tag
    end
    table.sort(result, function(a, b)
        return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
    end)
    return result
end

-- ##############################################

-- Updates the tag passed as a parameter
-- id: id of the tag to update
-- name: new name of the tag to update
-- color: new color of the tag to update (string containing a HEX value)
-- description: new description of the tag to update
-- protocols: array of nDPI application ids bound to the tag (custom tags only)
-- risks: array of flow risk ids bound to the tag (all tags, Enterprise L only)
function tag_badge_utils.editTag(id, name, color, description, reserved, protocols, risks)
    local json = require "dkjson"

    if tag_badge_utils.areTagRisksSupported() then
        risks = normalize_ids(risks)
    else
        -- Without the license the risks cannot be changed: keep the saved ones
        local current = get_tags()[tonumber(id)]
        risks = (current and current.risks) or {}
    end

    local tag = {
        id = id,
        name = name,
        color = color,
        description = description,
        reserved = reserved,
        -- Applications can only be bound to user-defined (custom) tags
        protocols = (not tag_badge_utils.isReservedTag(id)) and normalize_ids(protocols) or {},
        -- Flow risks can be bound to any tag, built-in ones included
        risks = risks
    }
    ntop.setHashCache(get_redis_key(), id, json.encode(tag))

    ntop.reloadTagsMapping()
end

-- ##############################################

function tag_badge_utils.deleteTag(id)
    local tags = get_tags_from_cache()

    -- Validate and normalize ID
    if id then
        id = tostring(id)
    else
        return false, "Invalid ID"
    end
    -- Check if tag exists before deletion
    if tags[id] then
        -- Remove tag from Redis
        ntop.delHashCache(get_redis_key(), id)
    else
        return false, "Invalid ID"
    end

    local success_msg = "Tag deleted successfully"
    return true, success_msg
end

return tag_badge_utils
