--
-- (C) 2024 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "check_redis_prefs"
require "lua_utils_generic"
local json = require "dkjson"

-- ##############################################

local asset_management_utils = {}
local table_name = "assets"

-- ##############################################

local function getAssetInfo(ifid, key, type)
    if isEmptyString(key) then
        return nil
    end
    local query = string.format(
        "SELECT type, key, ifid, ip, mac, vlan, network, name, device_type, manufacturer, %s , %s, gateway_mac, json_info %s FROM %s WHERE key='%s' AND ifid=%d AND type='%s'",
        ternary(hasClickHouseSupport(), "toUnixTimestamp(last_seen) as last_seen", "last_seen"),
        ternary(hasClickHouseSupport(), "toUnixTimestamp(first_seen) as first_seen", "first_seen"),
        ternary(hasClickHouseSupport(), ", version", ""),
        table_name,
        key,
        ifid,
        type
    )
    local res = interface.alert_store_query(query)
    return res
end

-- ##############################################

-- This function is used to update entry and merge those info with in DB informations
-- e.g. in case an host was already into the DB just update those data
local function updateData(entry, ifid, type)
    local data = getAssetInfo(ifid, entry.key, type)
    if data and table.len(data) > 0 then
        data = data[1]
        entry.first_seen = data.first_seen -- Keep the old first_seen
        local data_json_info = json.decode(data.json_info or "") or {}
        local entry_json_info = json.decode(entry.json_info or "") or {}
        entry.json_info = json.encode(table.merge(data_json_info, entry_json_info)) -- Merge the json_info field
    end
    return entry
end

-- ##############################################

local function updateJsonField(fields, new_fields)
    if fields then
        local json_info = json.decode(fields.json_info) or {}
        for field_name, field_value in pairs(new_fields or {}) do
            json_info[field_name] = field_value
        end
        fields.json_info = json.encode(json_info)
    end
    return fields
end

-- ##############################################

local function getAssetData(ifid, order, sort, start, length, filters, asset_type, check_last_seen)
    if not ifid then
        ifid = interface.getId()
    end

    if sort == "ip" and hasClickHouseSupport() then
        sort = "IPv4StringToNum(ip)"
    end
    local where = ""

    for key, value in pairs(filters or {}) do
        where = where .. "AND"
        if tonumber(value) then
            value = tonumber(value)
        else
            value = string.format("'%s'", value)
        end

        where = string.format("%s %s=%s ", where, key, value)
    end

    local sort_query = ""
    local limit_query = ""

    if sort and order then
        sort_query = string.format("ORDER BY %s %s", sort, order)
    end

    if start and length then
        limit_query = string.format("LIMIT %s, %s", start, length)
    end

    local query = nil

    if hasClickHouseSupport() then
        query = string.format("SELECT a.type, a.key, a.ifid, a.ip, a.mac, a.vlan, a.network, a.name, a.device_type, a.manufacturer, %s, %s, a.gateway_mac, a.json_info, a.version" ..
            " FROM %s a INNER JOIN (SELECT type, key, MAX(version) AS max_version FROM %s WHERE type='%s' %s AND ifid=%d %s GROUP BY type, key) AS latest" ..
            " ON a.type = latest.type AND a.key = latest.key AND a.version = latest.max_version %s %s",
            ternary(hasClickHouseSupport(), "toUnixTimestamp(a.last_seen) as last_seen", "a.last_seen"),
            ternary(hasClickHouseSupport(), "toUnixTimestamp(a.first_seen) as first_seen", "a.first_seen"),
            table_name,
            table_name,
            asset_type,                                       -- Only hosts here
            ternary(check_last_seen, 'AND last_seen!=0', ''), -- 0 Because by default an host that is still in memory has a last_seen 0
            tonumber(ifid),
            where,
            sort_query,
            limit_query
        )
    else
        query = string.format("SELECT type, key, ifid, ip, mac, vlan, network, name, device_type, manufacturer, last_seen, first_seen, gateway_mac, json_info" ..
            " FROM %s WHERE type='%s' %s AND ifid=%d %s %s %s",
            table_name,
            asset_type,                                       -- Only hosts here
            ternary(check_last_seen, 'AND last_seen!=0', ''), -- 0 Because by default an host that is still in memory has a last_seen 0
            tonumber(ifid),
            where,
            sort_query,
            limit_query
        )
    end
    return interface.alert_store_query(query)
end

-- ##############################################

local function getNumAssets(ifid, filters, asset_type, check_last_seen)
    if not ifid then
        ifid = interface.getId()
    end
    local where = ""

    for key, value in pairs(filters) do
        where = where .. "AND"
        if tonumber(value) then
            value = tonumber(value)
        else
            value = string.format("'%s'", value)
        end

        where = string.format("%s %s=%s ", where, key, value)
    end
    
    local query = nil
    if hasClickHouseSupport() then
        query = string.format("SELECT count(*) as count FROM %s a INNER JOIN (SELECT type, key, MAX(version) AS max_version FROM %s WHERE type='%s' %s AND ifid=%d %s GROUP BY type, key) AS latest" ..
            " ON a.type = latest.type AND a.key = latest.key AND a.version = latest.max_version",
            table_name,
            table_name,
            asset_type,                                       -- Only hosts here
            ternary(check_last_seen, 'AND last_seen!=0', ''), -- 0 Because by default an host that is still in memory has a last_seen 0
            tonumber(ifid),
            where
        )
    else
        query = string.format("SELECT COUNT(*) as count " ..
            "FROM %s WHERE type='%s' %s %s AND ifid=%d",
            table_name,
            asset_type,
            where,
            ternary(check_last_seen, 'AND last_seen!=0', ''), -- 0 Because by default an host that is still in memory has a last_seen 0
            ifid
        )
    end 

    return interface.alert_store_query(query)
end

-- ##############################################

local function get_mac_serialization_key(mac, ifid)
    return tostring(ifid) .. "_" .. mac
end

-- ##############################################

-- @brief insert assetkey
function asset_management_utils.getLastVersion(ifid)
    local query = string.format("SELECT version FROM %s WHERE ifid=%d ORDER BY version DESC LIMIT 1", table_name, ifid)
    local last_version = interface.alert_store_query(query)
    if table.len(last_version) == 0 then
        last_version = 0
    else
        last_version = last_version[1].version
    end
    return last_version
end

-- ##############################################

-- @brief insert assetkey
function asset_management_utils.insertHost(entry, version, ifid)
    local query = nil
    entry = updateData(entry, ifid, "host")

    if hasClickHouseSupport() then
        query = string.format(
            "INSERT INTO %s " ..
            "(type, key, ifid, ip, mac, vlan, network, name, device_type, manufacturer, first_seen, last_seen, version, json_info) " ..
            "VALUES ('%s','%s', %u, '%s', '%s', %u, %u, %s, %u, %s, %u, %u, %u, '%s')",
            table_name,
            entry["type"],
            entry["key"],
            ifid,
            entry["ip"] or "",
            entry["mac"] or "",
            entry["vlan"] or 0,
            entry["network"] or 0,
            ternary(not isEmptyString(entry["name"]), string.format("'%s'", entry["name"]), "NULL"),
            entry["device_type"],
            ternary(not isEmptyString(entry["manufacturer"]), string.format("'%s'", entry["manufacturer"]), "NULL"),
            entry["first_seen"],
            entry["last_seen"] or 0,
            version,
            entry["json_info"] or ""
        )
    else
        query = string.format(
            "INSERT INTO %s " ..
            "(type, key, ifid, ip, mac, vlan, network, name, device_type, manufacturer, first_seen, last_seen, json_info) " ..
            "VALUES ('%s','%s', %u, '%s','%s', %u, %u, %s, %u, %s, %u, %u, '%s') " ..
            "ON CONFLICT(key) DO UPDATE SET last_seen = %u, first_seen = %u;",
            table_name,
            entry["type"],
            entry["key"],
            ifid,
            entry["ip"],
            entry["mac"] or "",
            entry["vlan"] or 0,
            entry["network"] or 0,
            ternary(not isEmptyString(entry["name"]), string.format("'%s'", entry["name"]), "NULL"),
            entry["device_type"],
            ternary(not isEmptyString(entry["manufacturer"]), string.format("'%s'", entry["manufacturer"]), "NULL"),
            entry["first_seen"],
            entry["last_seen"] or 0,
            entry["json_info"] or "",
            entry["last_seen"] or 0,
            entry["first_seen"] or 0
        )
    end

    return interface.alert_store_query(query)
end

function asset_management_utils.insertMac(entry, version, ifid)
    local query = nil
    entry = updateData(entry, ifid, "mac")
    if hasClickHouseSupport() then
        query = string.format(
            "INSERT INTO %s " ..
            "(type, key, ifid, mac, manufacturer, vlan, device_type, first_seen, last_seen, version, json_info) " ..
            "SELECT '%s','%s', %u, '%s','%s', %u, %u, %u, %u, %u, '%s'",
            table_name,
            entry["type"],
            entry["key"],
            tonumber(ifid),
            entry["mac"],
            entry["manufacturer"],
            0, -- VLAN
            tonumber(entry["device_type"]),
            tonumber(entry["first_seen"]),
            tonumber(entry["last_seen"] or 0),
            tonumber(version),
            entry["json_info"] or ""
        )
    else
        query = string.format(
            "INSERT INTO %s " ..
            "(type, key, ifid, mac, manufacturer, device_type, first_seen, last_seen, json_info) " ..
            "VALUES ('%s','%s', %u, '%s','%s', %u, %u, %u, '%s') " ..
            "ON CONFLICT(key) DO UPDATE SET last_seen = %u, first_seen = %u;",
            table_name,
            entry["type"],
            entry["key"],
            tonumber(ifid),
            entry["mac"],
            entry["manufacturer"],
            tonumber(entry["device_type"] or 0),
            tonumber(entry["first_seen"] or 0),
            tonumber(entry["last_seen"] or 0),
            entry["json_info"] or "",
            tonumber(entry["last_seen"] or 0),
            tonumber(entry["first_seen"])
        )
    end

    return interface.alert_store_query(query)
end

-- ##############################################

function asset_management_utils.getDevices(ifid, order, sort, start, length, filters)
    return getAssetData(ifid, order, sort, start, length, filters, "mac" --[[ Asset Type ]], false)
end

-- ##############################################

-- Return the lists of inactive hosts from the DB
function asset_management_utils.getInactiveHosts(ifid, order, sort, start, length, filters)
    return getAssetData(ifid, order, sort, start, length, filters, "host" --[[ Asset Type ]], true)
end

-- ##############################################

-- Return the lists of inactive hosts from the DB
function asset_management_utils.getNumDevices(ifid, filters)
    return getNumAssets(ifid, filters, "mac", false)
end

-- ##############################################

-- Return the lists of inactive hosts from the DB
function asset_management_utils.getNumInactiveHosts(ifid, filters)
    return getNumAssets(ifid, filters, "host", true)
end

-- ##############################################

-- Return the lists of inactive hosts from the DB
function asset_management_utils.getFilters(ifid)
    if not ifid then
        ifid = interface.getId()
    end

    local query = string.format("SELECT 'manufacturer' AS filter, manufacturer AS value, COUNT(*) AS count " ..
        "FROM %s where type='host' AND ifid=%d GROUP BY manufacturer UNION ALL " ..
        "SELECT 'device_type' AS filter, %s AS value, COUNT(*) AS count " ..
        "FROM %s where type='host' AND ifid=%d GROUP BY device_type UNION ALL " ..
        "SELECT 'vlan' AS filter, %s AS value, COUNT(*) AS count " ..
        "FROM %s where type='host' AND ifid=%d GROUP BY vlan UNION ALL " ..
        "SELECT 'network' AS filter, %s AS value, COUNT(*) AS count " ..
        "FROM %s where type='host' AND ifid=%d GROUP BY network",
        table_name,
        ifid,
        ternary(hasClickHouseSupport(), "CAST(device_type, 'String')", "CAST(device_type AS CHAR)"),
        table_name,
        ifid,
        ternary(hasClickHouseSupport(), "CAST(vlan, 'String')", "CAST(vlan AS CHAR)"),
        table_name,
        ifid,
        ternary(hasClickHouseSupport(), "CAST(network, 'String')", "CAST(network AS CHAR)"),
        table_name,
        ifid
    )
    local res = interface.alert_store_query(query)
    return res
end

-- ##############################################

function asset_management_utils.getInactiveHostInfo(ifid, key)
    return getAssetInfo(ifid, key, "host")
end

-- ##############################################

function asset_management_utils.getMacInfo(ifid, key)
    return getAssetInfo(ifid, key, "mac")
end

-- ##############################################

-- Edit a list of macs with the specified trigger_alert value

function asset_management_utils.editMacList(device_list, trigger_alert, ifid)
    for _, device in pairs(device_list) do
        asset_management_utils.editMac(device, trigger_alert, "allowed", ifid)
    end
end

-- ##############################################

function asset_management_utils.editMac(device, trigger_alert, mac_status, ifid)
    if isMacAddress(device) then
        local key = get_mac_serialization_key(device, ifid)
        local fields = asset_management_utils.getMacInfo(ifid, key)
        if fields and table.len(fields) > 0 then
            fields = fields[1]
            fields = updateJsonField(fields, { device_status = mac_status, trigger_alert = trigger_alert })
            if hasClickHouseSupport() then
                asset_management_utils.insertMac(fields, tonumber(fields.version) + 1, tonumber(ifid))
            else
                local update_query = string.format("UPDATE %s SET `json_info`='%s' WHERE type='mac' AND ifid=%d AND key='%s'", table_name, fields.json_info, fields.ifid, fields.key)
                interface.alert_store_query(update_query)
            end
        end
    end
end

-- ##############################################

function asset_management_utils.deleteAll(ifid)
    local query = ""
    if hasClickHouseSupport() then
        query = string.format("ALTER TABLE %s DELETE WHERE type='mac' and ifid=%d", table_name, tonumber(ifid))
    else
        query = string.format("DELETE FROM %s WHERE type='mac' and ifid=%d", table_name, tonumber(ifid))
    end
    interface.alert_store_query(query)
end

-- ##############################################

function asset_management_utils.deleteMac(device, ifid)
    local key = get_mac_serialization_key(device, ifid)
    local query = ""

    if hasClickHouseSupport() then
        query = string.format("ALTER TABLE %s DELETE WHERE key='%s' and type='mac'", table_name, key)
    else
        query = string.format("DELETE FROM %s WHERE key='%s' and type='mac'", table_name, key)
    end

    interface.alert_store_query(query)
end

return asset_management_utils
