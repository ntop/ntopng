--
-- (C) 2013-26 - ntop.org
--

require "ntop_utils"
require "locales_utils" -- i18n(): it came by chance from asset_utils, which now loads discover_utils lazily

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
    [14] = { i18n = "asset_details.powershell_server"  }, -- HOST_TAG_POWERSHELL_SERVER
    [15] = { i18n = "asset_details.ftp_server"         }, -- HOST_TAG_FTP_SERVER
    [16] = { i18n = "asset_details.windows_domain_controller"         }, -- HOST_TAG_WINDOWS_DOMAIN_CONTROLLER
    -- Operating System of the host: at most one of them is set
    [27] = { i18n = "asset_details.os_freebsd"         }, -- HOST_TAG_OS_FREEBSD
    [28] = { i18n = "asset_details.os_linux"           }, -- HOST_TAG_OS_LINUX
    [29] = { i18n = "asset_details.os_android"         }, -- HOST_TAG_OS_ANDROID
    [30] = { i18n = "asset_details.os_apple"           }, -- HOST_TAG_OS_APPLE
    [31] = { i18n = "asset_details.os_windows"         }, -- HOST_TAG_OS_WINDOWS
}

-- Maximum Time To Live (in days) of a tag, 0 means the tag never expires
tag_badge_utils.MAX_TAG_TTL = 365

-- ##############################################

local function get_redis_key()
    return "ntopng.prefs.tags"
end

-- ##############################################

-- no_i18n: the built-in tags carry their i18n key (name_i18n) instead of the name (i18n loads the locale)
local function get_default_tags_table(no_i18n)
    local tags = {}

    -- Bits 0-31: ntop built-in tags (read-only, auto-assigned by ntopng)
    for id, entry in pairs(tag_badge_utils.builtin_tags) do
        local name = (not no_i18n) and i18n(entry.i18n) or nil
        if name == nil and not no_i18n then
            traceError(TRACE_WARNING, TRACE_CONSOLE,
                "tag_badge_utils: i18n key not found: " .. entry.i18n)
        end
        tags[id] = {
            id          = id,
            color       = "#0d6efd",
            description = "",
            name        = name,
            name_i18n   = no_i18n and entry.i18n or nil,
            reserved    = "true",
            protocols   = {},
            risks       = {},
            ttl         = 0
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
            risks       = {},
            ttl         = 0
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

-- Sanitize the Time To Live (in days) of a tag: 0 (default) means the tag never
-- expires, otherwise the value is in the range 1..MAX_TAG_TTL
local function normalize_ttl(ttl)
    ttl = math.floor(tonumber(ttl) or 0)

    return math.max(0, math.min(ttl, tag_badge_utils.MAX_TAG_TTL))
end

-- ##############################################

local function get_tags_from_cache()
    return ntop.getHashAllCache(get_redis_key()) or {}
end

-- ##############################################

local function get_tags(no_i18n)
    local json = require "dkjson"
    local tags = get_default_tags_table(no_i18n)
    local existing_tags = get_tags_from_cache()
    for _, tag_json in pairs(existing_tags) do
        local tag = json.decode(tag_json)
        if tag then
            tag.protocols = normalize_ids(tag.protocols)
            tag.risks = normalize_ids(tag.risks)
            tag.ttl = normalize_ttl(tag.ttl)
            -- Changed by the user (the custom tags not configured are free slots, see addTag)
            tag.configured = true
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

-- Returns the bitmap of a list of tag ids (bit N = tag id N, bit 63 makes it negative), e.g. the
-- tags added to the alerts of a check or of an active monitoring measurement. Ids that are not
-- numbers (e.g. the empty string of an empty list) are skipped
function tag_badge_utils.getTagsBitmap(tag_ids)
    local bitmap = 0

    for _, tag_id in ipairs(tag_ids or {}) do
        local id = tonumber(tag_id)

        if id then
            bitmap = bitmap | (1 << id)
        end
    end

    return bitmap
end

-- ##############################################

-- Returns true if nDPI applications can be bound to the tags (Enterprise L or above)
function tag_badge_utils.areTagApplicationsSupported()
    return (ntop.isEnterpriseL and ntop.isEnterpriseL()) or false
end

-- ##############################################

-- Returns true if flow risks can be bound to the tags (Enterprise L or above)
function tag_badge_utils.areTagRisksSupported()
    return (ntop.isEnterpriseL and ntop.isEnterpriseL()) or false
end

-- ##############################################

-- Returns true if a Time To Live can be set on the tags (Enterprise L or above)
function tag_badge_utils.isTagTTLSupported()
    return (ntop.isEnterpriseL and ntop.isEnterpriseL()) or false
end

-- ##############################################

-- Returns all the tags
-- no_i18n: see get_default_tags_table (for the REST, the page translates name_i18n)
function tag_badge_utils.getTags(no_i18n)
    local tags = get_tags(no_i18n)

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
-- protocols: array of nDPI application ids bound to the tag (custom tags only, Enterprise L only)
-- risks: array of flow risk ids bound to the tag (all tags, Enterprise L only)
-- ttl: days after which the tag (associated to an asset) expires if not refreshed,
--      0 means it never expires (all tags, Enterprise L only)
-- The fields that are nil are left untouched (e.g. a rename only sends the name)
function tag_badge_utils.editTag(id, name, color, description, reserved, protocols, risks, ttl)
    local json = require "dkjson"
    local current = get_tags()[tonumber(id)] or {}

    -- Without the license applications, flow risks and TTL cannot be changed
    if protocols == nil or not tag_badge_utils.areTagApplicationsSupported() then
        protocols = current.protocols or {}
    else
        protocols = normalize_ids(protocols)
    end

    if risks == nil or not tag_badge_utils.areTagRisksSupported() then
        risks = current.risks or {}
    else
        risks = normalize_ids(risks)
    end

    if ttl == nil or not tag_badge_utils.isTagTTLSupported() then
        ttl = current.ttl
    end

    local tag = {
        id = id,
        name = name or current.name,
        color = color or current.color,
        description = description or current.description,
        reserved = reserved,
        -- Applications can only be bound to user-defined (custom) tags
        protocols = (not tag_badge_utils.isReservedTag(id)) and protocols or {},
        -- Flow risks can be bound to any tag, built-in ones included
        risks = risks,
        -- Days after which the tag expires, 0 means never
        ttl = normalize_ttl(ttl)
    }
    ntop.setHashCache(get_redis_key(), id, json.encode(tag))

    ntop.reloadTagsMapping()
end

-- ##############################################

-- Returns true if another tag (not the one with id except_id) already has this name (case insensitive)
function tag_badge_utils.isTagNameUsed(name, except_id)
    name = string.lower(name)

    for _, tag in pairs(get_tags()) do
        if tonumber(tag.id) ~= tonumber(except_id) and string.lower(tag.name or "") == name then
            return true
        end
    end

    return false
end

-- ##############################################

-- Creates a user-defined tag in the first free custom slot (bits 32-63): never configured, not
-- added to a check, an active monitoring measurement, a notification or an AI policy (a slot can be
-- picked without renaming it), not in selected_ids (the tags selected in the form, not saved yet)
-- Returns the id of the new tag, nil when all the slots are in use
function tag_badge_utils.addTag(name, color, selected_ids)
    local configured = get_tags_from_cache()
    local used = {}

    for _, id in ipairs(selected_ids or {}) do
        -- Not a number: the empty string of an empty list
        if tonumber(id) then
            used[tonumber(id)] = true
        end
    end

    for _, subdir_tags in pairs(require("checks").getConfigset().tags or {}) do
        for _, tag_ids in pairs(subdir_tags) do
            for _, id in ipairs(tag_ids) do
                used[tonumber(id)] = true
            end
        end
    end

    for _, host in pairs(require("am_utils").getHosts(true --[[ config only ]])) do
        for _, id in ipairs(host.tag_ids or {}) do
            used[tonumber(id)] = true
        end
    end

    package.path = ntop.getDirs().installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path
    for _, policy in ipairs(require("notification_policies").get_all_policies()) do
        for _, id in ipairs(policy.tags or {}) do
            used[tonumber(id)] = true
        end
    end

    if ntop.isPro() then
        package.path = ntop.getDirs().installdir .. "/pro/scripts/lua/modules/llm/?.lua;" .. package.path
        for _, id in ipairs(require("llm_redis_utils").get_used_tag_ids()) do
            used[tonumber(id)] = true
        end
    end

    for id = 32, 63 do
        if configured[tostring(id)] == nil and not used[id] then
            tag_badge_utils.editTag(id, name, color, "", "false")
            return id
        end
    end

    return nil
end

-- ##############################################

-- who: name of the user deleting the tag (for the journal of the assets)
function tag_badge_utils.deleteTag(id, who)
    local tags = get_tags_from_cache()

    -- Validate and normalize ID
    if id then
        id = tostring(id)
    else
        return false, "Invalid ID"
    end
    -- Check if tag exists before deletion
    if tags[id] then
        -- Name of the tag, for the journal of the assets (see below)
        local deleted_tag = require("dkjson").decode(tags[id] or "") or {}

        -- Remove tag from Redis
        ntop.delHashCache(get_redis_key(), id)

        ntop.reloadTagsMapping()

        -- Remove the tag from the assets.
        -- NOTE: built-in tags are not deleted, only their configuration is reset
        if ntop.isPro() and tag_badge_utils.isTagTTLSupported() and (not tag_badge_utils.isReservedTag(id)) then
            package.path = ntop.getDirs().installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
            local ok, asset_utils = pcall(require, "asset_utils")

            if ok and asset_utils.removeTagFromAssets then
                asset_utils.removeTagFromAssets(id, who, deleted_tag.name)
            end
        end

        -- Remove the tag from the checks, the active monitoring measurements, the notification
        -- policies and the AI policies, otherwise a new tag reusing the id would inherit them
        if not tag_badge_utils.isReservedTag(id) then
            require("checks").removeTagFromChecks(tonumber(id))
            require("am_utils").removeTag(tonumber(id))
            package.path = ntop.getDirs().installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path
            require("notification_policies").remove_filter_id("tags", id)

            if ntop.isPro() then
                package.path = ntop.getDirs().installdir .. "/pro/scripts/lua/modules/llm/?.lua;" .. package.path
                require("llm_redis_utils").remove_tag(tonumber(id))
            end
        end
    else
        return false, "Invalid ID"
    end

    local success_msg = "Tag deleted successfully"
    return true, success_msg
end

return tag_badge_utils
