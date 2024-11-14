--
-- (C) 2024 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "check_redis_prefs"
local os_utils = require "os_utils"

-- ##############################################

local asset_management_utils = {}
local table_name = "asset_management"

-- ##############################################

-- @brief insert assetkey
function asset_management_utils.insert_host(entry)


    local insert_host = ""
    
    if hasClickHouseSupport() then
        insert_host = string.format(
            "INSERT INTO %s " ..
            "(type, key, ip, mac, vlan, network, name, device_type, manufacturer, first_seen, last_seen) " ..
            "SELECT '%s','%s','%s','%s', %u, %u, %s, %u, %s, %u, %u "..
            "WHERE NOT EXISTS ( SELECT 1 FROM %s WHERE key = '%s' )",
            table_name, 
            entry["type"],
            entry["key"],
            entry["ip"] or "",
            entry["mac"] or "",
            entry["vlan"] or 0,
            entry["network"] or 0,
            ternary(not isEmptyString(entry["name"]),string.format("'%s'",entry["name"]),"NULL"),
            entry["device_type"],
            ternary(not isEmptyString(entry["manufacturer"]),string.format("'%s'",entry["manufacturer"]), "NULL"),
            entry["first_seen"],
            entry["last_seen"],
            table_name,
            entry["key"]
        )
        local update_host = string.format("ALTER TABLE `%s` UPDATE `last_seen` = %u WHERE `key`='%s'",
            table_name,
            entry["last_seen"],
            entry["key"]
        )
        interface.alert_store_query(insert_host)
        return interface.alert_store_query(update_host)
    else
        insert_host = string.format(
            "INSERT INTO %s " ..
            "(type, key, ip, mac, vlan, network, name, device_type, manufacturer, first_seen, last_seen) " ..
            "VALUES ('%s','%s','%s','%s', %u, %u, %s, %u, %s, %u, %u) "..
            "ON CONFLICT(key) DO UPDATE SET last_seen = %u;",
            table_name, 
            entry["type"],
            entry["key"],
            entry["ip"],
            entry["mac"] or "",
            entry["vlan"] or 0,
            entry["network"] or 0,
            ternary(not isEmptyString(entry["name"]),string.format("'%s'",entry["name"]),"NULL"),
            entry["device_type"],
            ternary(not isEmptyString(entry["manufacturer"]),string.format("'%s'",entry["manufacturer"]), "NULL"),
            entry["first_seen"],
            entry["last_seen"],
            entry["last_seen"]
        )

	-- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_host)	
        return interface.alert_store_query(insert_host)
    end
end

function asset_management_utils.insert_mac(entry)
    if hasClickHouseSupport() then
        local insert_mac = string.format(
            "INSERT INTO %s " ..
            "(type, key, mac, manufacturer, vlan, device_type, first_seen, last_seen) " ..
            "SELECT '%s','%s','%s','%s','%d', %u, %u, %u "..
            "WHERE NOT EXISTS ( SELECT 1 FROM %s WHERE key = '%s' )",
            table_name, 
            entry["type"],
            entry["key"],
            entry["mac"],
	    entry["manufacturer"],
	    0, -- VLAN
            entry["device_type"],
            entry["first_seen"],
            entry["last_seen"],
            table_name,
            entry["mac"]
        )
        local update_mac = string.format("ALTER TABLE `%s` UPDATE `last_seen` = %u WHERE `key`='%s'",
            table_name,
            entry["last_seen"],
            entry["key"]
        )

        --tprint(insert_mac)
	interface.alert_store_query(insert_mac)
        return interface.alert_store_query(update_mac)
    else
        local insert_mac = string.format(
            "INSERT INTO %s " ..
            "(type, key, mac, manufacturer, vlan, device_type, first_seen, last_seen) " ..
            "VALUES ('%s','%s','%s','%s', %u, %u, %u, %u) "..
            "ON CONFLICT(key) DO UPDATE SET last_seen = %u ;",
            table_name, 
            entry["type"],
            entry["key"],
            entry["mac"],
	    entry["manufacturer"],
	    0,
            entry["device_type"],
            entry["first_seen"],
            entry["last_seen"],
            entry["last_seen"]
        )
	
        return interface.alert_store_query(insert_mac)
    end
    -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_mac)

end

-- ##############################################

-- Return the lists of inactive hosts from the DB 
function asset_management_utils.get_inactive_hosts(ifid, order, sort, start, length, filters)
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

    if sort and order then
        where = string.format("%s ORDER BY %s %s", where, sort, order)
    end

    if start and length then
        where = string.format("%s LIMIT %s, %s", where, start, length)
    end

    local query = string.format("SELECT key, ip, mac, vlan, network, name, device_type, manufacturer, %s, %s " ..
        "FROM %s WHERE type='%s' AND last_seen!=%d %s",
        ternary(hasClickHouseSupport(), "toUnixTimestamp(last_seen) as last_seen", "last_seen"),
        ternary(hasClickHouseSupport(), "toUnixTimestamp(first_seen) as first_seen", "first_seen"),
        table_name,
        "host", -- Only hosts here
        0, -- 0 Because by default an host that is still in memory has a last_seen 0
        where
    )
    local res = interface.alert_store_query(query)
    return res
end

-- ##############################################

-- Return the lists of inactive hosts from the DB 
function asset_management_utils.get_total_inactive_hosts(ifid, filters)
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

    local query = string.format("SELECT COUNT(*) as count " ..
        "FROM %s WHERE type='%s' %s AND last_seen!=%d",
        table_name,
        "host", -- Only hosts here,
        where,
        0 -- 0 Because by default an host that is still in memory has a last_seen 0
    )
    local res = interface.alert_store_query(query)
    return res
end

-- ##############################################

-- Return the lists of inactive hosts from the DB 
function asset_management_utils.get_filters(ifid)
    if not ifid then
        ifid = interface.getId()
    end

    local query = string.format("SELECT 'manufacturer' AS filter, manufacturer AS value, COUNT(*) AS count " ..
        "FROM %s where type='host' GROUP BY manufacturer UNION ALL " ..
        "SELECT 'device_type' AS filter, %s AS value, COUNT(*) AS count " ..
        "FROM %s where type='host' GROUP BY device_type UNION ALL " ..
        "SELECT 'vlan' AS filter, %s AS value, COUNT(*) AS count " ..
        "FROM %s where type='host' GROUP BY vlan UNION ALL " ..
        "SELECT 'network' AS filter, %s AS value, COUNT(*) AS count " ..
        "FROM %s where type='host' GROUP BY network",
        table_name,
        ternary(hasClickHouseSupport(), "CAST(device_type, 'String')", "CAST(device_type AS CHAR)"),
        table_name,
        ternary(hasClickHouseSupport(), "CAST(vlan, 'String')", "CAST(vlan AS CHAR)"),
        table_name,
        ternary(hasClickHouseSupport(), "CAST(network, 'String')", "CAST(network AS CHAR)"),
        table_name
    )
    local res = interface.alert_store_query(query)
    return res
end

-- ##############################################

-- Return the lists of inactive hosts from the DB 
function asset_management_utils.get_inactive_host_info(ifid, key)
    if isEmptyString(key) then
        return nil
    end
    local query = string.format("SELECT key, ip, mac, vlan, network, name, device_type, manufacturer, %s , %s FROM %s WHERE key='%s'", 
        ternary(hasClickHouseSupport(), "toUnixTimestamp(last_seen) as last_seen", "last_seen"),
        ternary(hasClickHouseSupport(), "toUnixTimestamp(first_seen) as first_seen", "first_seen"),
        table_name, 
        key
    )
    local res = interface.alert_store_query(query)
    return res
end

-- ##############################################

return asset_management_utils
