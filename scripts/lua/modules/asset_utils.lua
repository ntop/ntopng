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

local asset_utils = {}
local table_name = "assets"

-- ##############################################

local function partiallyFormatInfo(res)
    local res_formatted = {}
    for _, res_unformatted in pairs(res or {}) do
        local tmp = res_unformatted
        local json_info = json.decode(res_unformatted.json_info or "") or {}
        tmp["is_dns_server"] = ((json_info["dns_server"] or "false") == "true")
        tmp["is_dhcp_server"] = ((json_info["dhcp_server"] or "false") == "true")
        tmp["is_smtp_server"] = ((json_info["smtp_server"] or "false") == "true")
        tmp["is_ntp_server"] = ((json_info["ntp_server"] or "false") == "true")
        tmp["is_imap_server"] = ((json_info["imap_server"] or "false") == "true")
        tmp["is_pop_server"] = ((json_info["pop_server"] or "false") == "true")

        if tmp["is_dns_server"] then
            json_info["dns_server"] = nil
        end
        if tmp["is_dhcp_server"] then
            json_info["dhcp_server"] = nil
        end
        if tmp["is_smtp_server"] then
            json_info["smtp_server"] = nil
        end
        if tmp["is_ntp_server"] then
            json_info["ntp_server"] = nil
        end
        if tmp["is_imap_server"] then
            json_info["imap_server"] = nil
        end
        if tmp["is_pop_server"] then
            json_info["pop_server"] = nil
        end

        if json_info["os_type"] then
            tmp["os_type"] = json_info["os_type"]
            json_info["os_type"] = nil
        end

        local resolved_names = {}
        if table.len(json_info) > 0 then
            resolved_names["mdns_name"] = json_info["mdns_name"]
            resolved_names["dhcp_name"] = json_info["dhcp_name"]
            resolved_names["mdns_txt_name"] = json_info["mdns_txt_name"]
            resolved_names["netbios_name"] = json_info["netbios_name"]
            resolved_names["tls_name"] = json_info["tls_name"]
            resolved_names["http_name"] = json_info["http_name"]
            resolved_names["dns_name"] = json_info["dns_name"]

            if resolved_names["mdns_name"] then
                json_info["mdns_name"] = nil
            end
            if resolved_names["dhcp_name"] then
                json_info["dhcp_name"] = nil
            end
            if resolved_names["mdns_txt_name"] then
                json_info["mdns_txt_name"] = nil
            end
            if resolved_names["netbios_name"] then
                json_info["netbios_name"] = nil
            end
            if resolved_names["tls_name"] then
                json_info["tls_name"] = nil
            end
            if resolved_names["http_name"] then
                json_info["http_name"] = nil
            end
            if resolved_names["dns_name"] then
                json_info["dns_name"] = nil
            end
            tmp["names"] = resolved_names
        end

        tmp.json_info = json_info

        res_formatted[#res_formatted + 1] = tmp
    end
    return res_formatted
end

-- ##############################################

local function getAssetInfo(ifid, key, type)
    if isEmptyString(key) then
        return nil
    end
    local query = string.format(
        "SELECT type, key, ifid, ip, mac, vlan, network, name, device_type, manufacturer, %s , %s, gateway_mac, json_info %s FROM %s WHERE key='%s' AND ifid=%d AND type='%s'",
        ternary(hasClickHouseSupport(), "toUnixTimestamp(last_seen) as last_seen", "last_seen"),
        ternary(hasClickHouseSupport(), "toUnixTimestamp(first_seen) as first_seen", "first_seen"),
        ternary(hasClickHouseSupport(), ", version", ""), table_name, key, ifid, type)
    local res = interface.alert_store_query(query)
    res = partiallyFormatInfo(res)
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
        -- Merge the json_info field, note, that in case of duplicates, the data from
        -- entry table are used.
        entry.json_info = json.encode(table.merge(data.json_info or {}, entry.json_info or {}))
    end

    -- Remove the single quote from the manufacturer, it can mess up the query
    if entry.manufacturer then
        entry.manufacturer = string.gsub(entry.manufacturer, "'", "-")
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

    -- Exception for the status filter, it's last_seen = 0 or last_seen != 0
    local status_filter = filters["status"]
    filters["status"] = nil

    for key, value in pairs(filters or {}) do
        where = where .. "AND"
        if tonumber(value) then
            value = tonumber(value)
        else
            value = string.format("'%s'", value)
        end

        where = string.format("%s %s=%s ", where, key, value)
    end

    if status_filter then
        where = string.format("%s AND %s%s%s", where, "last_seen", ternary(status_filter == "0", "=", "!="), "0")
    end
    filters["status"] = status_filter

    local sort_query = ""
    local limit_query = ""

    if sort and order then
        if sort == "last_seen" then
            -- Set last seen = 0 at start or end
            sort_query = string.format("ORDER BY (%s = 0) %s, %s %s", sort, order, sort, order)
        else
            sort_query = string.format("ORDER BY %s %s", sort, order)
        end
    end

    if start and length then
        limit_query = string.format("LIMIT %s, %s", start, length)
    end

    local query = nil

    if hasClickHouseSupport() then
        query = string.format(
            "SELECT a.type, a.key, a.ifid, a.ip, a.mac, a.vlan, a.network, a.name, a.device_type, a.manufacturer, %s, %s, a.gateway_mac, a.json_info, a.version" ..
                " FROM %s a INNER JOIN (SELECT type, key, MAX(version) AS max_version FROM %s WHERE type='%s' AND ifid=%d %s GROUP BY type, key) AS latest" ..
                " ON a.type = latest.type AND a.key = latest.key AND a.version = latest.max_version %s %s",
            ternary(hasClickHouseSupport(), "toUnixTimestamp(a.last_seen) as last_seen", "a.last_seen"),
            ternary(hasClickHouseSupport(), "toUnixTimestamp(a.first_seen) as first_seen", "a.first_seen"), table_name,
            table_name, asset_type, -- Only hosts here
            tonumber(ifid), where, sort_query, limit_query)
    else
        query = string.format(
            "SELECT type, key, ifid, ip, mac, vlan, network, name, device_type, manufacturer, last_seen, first_seen, gateway_mac, json_info" ..
                " FROM %s WHERE type='%s' AND ifid=%d %s %s %s", table_name, asset_type, -- Only hosts here
            tonumber(ifid), where, sort_query, limit_query)
    end
    return interface.alert_store_query(query)
end

-- ##############################################

local function getNumAssets(ifid, filters, asset_type, check_last_seen)
    if not ifid then
        ifid = interface.getId()
    end
    local where = ""
    -- Exception for the status filter, it's last_seen = 0 or last_seen != 0
    local status_filter = filters["status"]
    filters["status"] = nil

    for key, value in pairs(filters) do
        where = where .. "AND"
        if tonumber(value) then
            value = tonumber(value)
        else
            value = string.format("'%s'", value)
        end

        where = string.format("%s %s=%s ", where, key, value)
    end

    if status_filter then
        where = string.format("%s AND %s%s%s", where, "last_seen", ternary(status_filter == "0", "=", "!="), "0")
    end
    filters["status"] = status_filter

    local query = nil
    if hasClickHouseSupport() then
        query = string.format(
            "SELECT count(*) as count FROM %s a INNER JOIN (SELECT type, key, MAX(version) AS max_version FROM %s WHERE type='%s' AND ifid=%d %s GROUP BY type, key) AS latest" ..
                " ON a.type = latest.type AND a.key = latest.key AND a.version = latest.max_version", table_name,
            table_name, asset_type, -- Only hosts here
            tonumber(ifid), where)
    else
        query = string.format("SELECT COUNT(*) as count " .. "FROM %s WHERE type='%s' %s AND ifid=%d", table_name,
            asset_type, where, ifid)
    end

    return interface.alert_store_query(query)
end

-- ##############################################

local function get_mac_serialization_key(mac, ifid)
    return tostring(ifid) .. "_" .. mac
end

-- ##############################################

-- @brief insert assetkey
function asset_utils.getLastVersion(ifid)
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
function asset_utils.insertHost(entry, version, ifid)
    local query = nil
    entry = updateData(entry, ifid, "host")

    if hasClickHouseSupport() then
        query = string.format("INSERT INTO %s " ..
                                  "(type, key, ifid, ip, mac, vlan, network, name, device_type, manufacturer, first_seen, last_seen, version, json_info) " ..
                                  "VALUES ('%s','%s', %u, '%s', '%s', %u, %u, %s, %u, %s, %u, %u, %u, '%s')",
            table_name, entry["type"], entry["key"], ifid, entry["ip"] or "", entry["mac"] or "", entry["vlan"] or 0,
            entry["network"] or 0, ternary(not isEmptyString(entry["name"]), string.format("'%s'", entry["name"]),
                "NULL"), entry["device_type"], ternary(not isEmptyString(entry["manufacturer"]),
                string.format("'%s'", entry["manufacturer"]), "NULL"), entry["first_seen"], entry["last_seen"] or 0,
            version, entry["json_info"] or "")
    else
        query = string.format("INSERT INTO %s " ..
                                  "(type, key, ifid, ip, mac, vlan, network, name, device_type, manufacturer, first_seen, last_seen, json_info) " ..
                                  "VALUES ('%s','%s', %u, '%s','%s', %u, %u, %s, %u, %s, %u, %u, '%s') " ..
                                  "ON CONFLICT(key) DO UPDATE SET last_seen = %u, first_seen = %u;", table_name,
            entry["type"], entry["key"], ifid, entry["ip"], entry["mac"] or "", entry["vlan"] or 0,
            entry["network"] or 0, ternary(not isEmptyString(entry["name"]), string.format("'%s'", entry["name"]),
                "NULL"), entry["device_type"], ternary(not isEmptyString(entry["manufacturer"]),
                string.format("'%s'", entry["manufacturer"]), "NULL"), entry["first_seen"], entry["last_seen"] or 0,
            entry["json_info"] or "", entry["last_seen"] or 0, entry["first_seen"] or 0)
    end

    return interface.alert_store_query(query)
end

function asset_utils.insertMac(entry, version, ifid)
    local query = nil
    entry = updateData(entry, ifid, "mac")
    if hasClickHouseSupport() then
        query = string.format("INSERT INTO %s " ..
                                  "(type, key, ifid, mac, manufacturer, vlan, device_type, first_seen, last_seen, version, json_info) " ..
                                  "SELECT '%s','%s', %u, '%s','%s', %u, %u, %u, %u, %u, '%s'", table_name,
            entry["type"], entry["key"], tonumber(ifid), entry["mac"], entry["manufacturer"], 0, -- VLAN
            tonumber(entry["device_type"]), tonumber(entry["first_seen"]), tonumber(entry["last_seen"] or 0),
            tonumber(version), entry["json_info"] or "")
    else
        query = string.format("INSERT INTO %s " ..
                                  "(type, key, ifid, mac, manufacturer, device_type, first_seen, last_seen, json_info) " ..
                                  "VALUES ('%s','%s', %u, '%s','%s', %u, %u, %u, '%s') " ..
                                  "ON CONFLICT(key) DO UPDATE SET last_seen = %u, first_seen = %u;", table_name,
            entry["type"], entry["key"], tonumber(ifid), entry["mac"], entry["manufacturer"],
            tonumber(entry["device_type"] or 0), tonumber(entry["first_seen"] or 0), tonumber(entry["last_seen"] or 0),
            entry["json_info"] or "", tonumber(entry["last_seen"] or 0), tonumber(entry["first_seen"]))
    end

    return interface.alert_store_query(query)
end

-- ##############################################

function asset_utils.getDevicesAssets(ifid, order, sort, start, length, filters)
    return getAssetData(ifid, order, sort, start, length, filters, "mac" --[[ Asset Type ]] , false)
end

-- ##############################################

-- Return the lists of inactive hosts from the DB
function asset_utils.getHostsAssets(ifid, order, sort, start, length, filters)
    return getAssetData(ifid, order, sort, start, length, filters, "host" --[[ Asset Type ]] , true)
end

-- ##############################################

-- Return the lists of inactive hosts from the DB
function asset_utils.getNumDevices(ifid, filters)
    return getNumAssets(ifid, filters, "mac", false)
end

-- ##############################################

-- Return the lists of inactive hosts from the DB
function asset_utils.getNumAssets(ifid, filters)
    return getNumAssets(ifid, filters, "host", true)
end

-- ##############################################

-- Return the lists of inactive hosts from the DB
function asset_utils.getFilters(ifid)
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
                                    "FROM %s where type='host' AND ifid=%d GROUP BY network", table_name, ifid,
        ternary(hasClickHouseSupport(), "CAST(device_type, 'String')", "CAST(device_type AS CHAR)"), table_name, ifid,
        ternary(hasClickHouseSupport(), "CAST(vlan, 'String')", "CAST(vlan AS CHAR)"), table_name, ifid, ternary(
            hasClickHouseSupport(), "CAST(network, 'String')", "CAST(network AS CHAR)"), table_name, ifid)
    local res = interface.alert_store_query(query)
    return res
end

-- ##############################################

function asset_utils.getInactiveHostInfo(ifid, key)
    return getAssetInfo(ifid, key, "host")
end

-- ##############################################

function asset_utils.getMacInfo(ifid, key)
    return getAssetInfo(ifid, key, "mac")
end

-- ##############################################

-- Edit a list of macs with the specified trigger_alert value

function asset_utils.editMacList(device_list, trigger_alert, ifid)
    for _, device in pairs(device_list) do
        asset_utils.editMac(device, trigger_alert, "allowed", ifid)
    end
end

-- ##############################################

function asset_utils.editMac(device, trigger_alert, mac_status, ifid)
    if isMacAddress(device) then
        local key = get_mac_serialization_key(device, ifid)
        local fields = asset_utils.getMacInfo(ifid, key)
        if fields and table.len(fields) > 0 then
            fields = fields[1]
            fields = updateJsonField(fields, {
                device_status = mac_status,
                trigger_alert = trigger_alert
            })
            if hasClickHouseSupport() then
                asset_utils.insertMac(fields, tonumber(fields.version) + 1, tonumber(ifid))
            else
                local update_query = string.format(
                    "UPDATE %s SET `json_info`='%s' WHERE type='mac' AND ifid=%d AND key='%s'", table_name,
                    fields.json_info, fields.ifid, fields.key)
                interface.alert_store_query(update_query)
            end
        end
    end
end

-- ##############################################

function asset_utils.deleteAll(ifid, type)
    local query = ""
    if hasClickHouseSupport() then
        query = string.format("ALTER TABLE %s DELETE WHERE type='%s' and ifid=%d", table_name, type, tonumber(ifid))
    else
        query = string.format("DELETE FROM %s WHERE type='%s' and ifid=%d", table_name, type, tonumber(ifid))
    end
    interface.alert_store_query(query)
end

-- ##############################################

function asset_utils.deleteMac(device, ifid)
    local key = get_mac_serialization_key(device, ifid)
    local query = ""

    if hasClickHouseSupport() then
        query = string.format("ALTER TABLE %s DELETE WHERE key='%s' and type='mac'", table_name, key)
    else
        query = string.format("DELETE FROM %s WHERE key='%s' and type='mac'", table_name, key)
    end

    interface.alert_store_query(query)
end

-- ##############################################

function asset_utils.deleteHost(ifid, serial_key)
    local query = ""

    if hasClickHouseSupport() then
        query = string.format("ALTER TABLE %s DELETE WHERE key='%s' AND type='host' AND ifid=%s", table_name, serial_key, ifid)
    else
        query = string.format("DELETE FROM %s WHERE key='%s' and type='host' AND ifid=%s", table_name, serial_key, ifid)
    end

    interface.alert_store_query(query)
end

-- ##############################################

function asset_utils.deleteAllEntriesSince(ifid, type, last_seen)
    local query = ""

    if hasClickHouseSupport() then
        query = string.format("ALTER TABLE %s DELETE WHERE type='%s' AND ifid=%s AND last_seen<%s AND last_seen != 0", table_name, type, ifid, last_seen)
    else
        query = string.format("DELETE FROM %s WHERE type='%s' AND ifid=%s AND last_seen<%s AND last_seen != 0", table_name, type, ifid, last_seen)
    end

    interface.alert_store_query(query)
end

return asset_utils
