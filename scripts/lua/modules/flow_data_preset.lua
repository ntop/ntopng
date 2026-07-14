--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "lua_utils_get"
local format_utils = require "format_utils"
local flow_data_preset = {}
-- This table contains the mapping to the live and historical flows,
-- if the column has to be used as key (except bytes/packets everything should be a key)
-- and the formatter
local columns = {
    asn = {filters = {"src_asn", "dst_asn"}},
    src_asn = {
        column_id = "SRC_ASN",
        is_key = true,
        filters = "SRC_ASN",
        formatter = {
            funct = format_utils.formatASN,
            generateLink = generateASNLink
        }
    },
    dst_asn = {
        column_id = "DST_ASN",
        is_key = true,
        filters = "DST_ASN",
        formatter = {
            funct = format_utils.formatASN,
            generateLink = generateASNLink
        }
    },
    src_peer_asn = {
        column_id = "SRC_PEER_ASN",
        is_key = true,
        hide_if_value = "0",
        formatter = {
            funct = format_utils.formatASN,
            generateLink = generateASNLink
        }
    },
    dst_peer_asn = {
        column_id = "DST_PEER_ASN",
        is_key = true,
        hide_if_value = "0",
        formatter = {
            funct = format_utils.formatASN,
            generateLink = generateASNLink
        }
    },
    in_device = {
        column_id = "PROBE_IP",
        is_key = true,
        filters = "PROBE_IP",
        db_formatting_fun = {
            historical = "IPv6NumToString"
        },
        formatter = {
            funct = getExporterName,
            generateLink = generateExporterLink
        }
    },
    out_device = {
        column_id = "PROBE_IP",
        is_key = true,
        db_formatting_fun = {
            historical = "IPv6NumToString"
        },
        filters = "PROBE_IP",
        formatter = {
            funct = getExporterName,
            generateLink = generateExporterLink
        }
    },
    device = {
        column_id = "PROBE_IP",
        is_key = true,
        filters = "PROBE_IP",
        db_formatting_fun = {
            historical = "IPv6NumToString"
        },
        formatter = {
            funct = getExporterName,
            generateLink = generateExporterLink
        }
    },
    in_iface_index = {
        column_id = "INPUT_SNMP",
        filters = "INPUT_SNMP",
        is_key = true,
        formatter = {
            funct = format_portidx_name,
            column_dependent = "in_device",
            generateLink = generateExporterInterfaceLink
        }
    },
    out_iface_index = {
        column_id = "OUTPUT_SNMP",
        filters = "OUTPUT_SNMP",
        is_key = true,
        formatter = {
            funct = format_portidx_name,
            column_dependent = "in_device",
            generateLink = generateExporterInterfaceLink
        }
    },
    out_iface_index2 = {
        column_id = "OUTPUT_SNMP",
        filters = "OUTPUT_SNMP",
        is_key = true,
        formatter = {
            funct = format_portidx_name,
            column_dependent = "out_device",
            generateLink = generateExporterInterfaceLink
        }
    },
    interface = {
        formatter = {
            funct = format_portidx_name,
            column_dependent = "device",
            generateLink = generateExporterInterfaceLink
        },
        filters = {"in_iface_index", "out_iface_index"}
    },
    bytes_sent = {
        column_id = "SUM(SRC2DST_BYTES)",
        column_id_no_fun = "SRC2DST_BYTES",
        invert_with = "bytes_rcvd"
    },
    bytes_rcvd = {
        column_id = "SUM(DST2SRC_BYTES)",
        column_id_no_fun = "DST2SRC_BYTES",
        invert_with = "bytes_sent"
    },
    total_bytes = {
        column_id = "SUM(TOTAL_BYTES)",
        column_id_no_fun = "TOTAL_BYTES"
    },
    as = {
        formatter = {
            funct = format_utils.formatASN,
            generateLink = generateASNLink
        }
    },
    customer = {
        formatter = {
            funct = format_utils.formatASN,
            generateLink = generateASNLink
        }
    },
    transit_as = {
        formatter = {
            funct = format_utils.formatASN,
            generateLink = generateASNLink
        }
    },
    src_transit_as = {
        formatter = {
            funct = format_utils.formatASN,
            generateLink = generateASNLink
        }
    },
    dst_transit_as = {
        formatter = {
            funct = format_utils.formatASN,
            generateLink = generateASNLink
        }
    },
    src_peer_asn_1 = {
        formatter = {
            funct = format_utils.formatASN,
            generateLink = generateASNLink
        }
    },
    dst_peer_asn_1 = {
        formatter = {
            funct = format_utils.formatASN,
            generateLink = generateASNLink
        }
    },
    src_peer_asn_2 = {
        formatter = {
            funct = format_utils.formatASN,
            generateLink = generateASNLink
        }
    },
    dst_peer_asn_2 = {
        formatter = {
            funct = format_utils.formatASN,
            generateLink = generateASNLink
        }
    },
    ifid = {column_id = "INTERFACE_ID"},
    first_seen = {column_id = "FIRST_SEEN"},
    last_seen = {column_id = "LAST_SEEN"}
}

-- ###########################################

-- @brief Given a list of ids in an array format, returns the
-- name of the data in case of live flows or historical
-- @param columns_id Array, containing a list of columns ids
-- @return a list of matching ids for the requested type (live or historical)
function flow_data_preset.retrieveColumns(columns_id)
    local id_list = {}

    for position, id in pairs(columns_id or {}) do
        if columns[id] then
            local column_info = columns[id]
            column_info["key"] = column_info["column_id"]
            column_info["id"] = id
            id_list[position] = column_info
        end
    end

    return id_list
end

-- ###########################################

-- @brief given a column_id returns the info about that column
-- @param columns_id String, containing a list of columns ids
-- @return a list of matching ids for the requested type (live or historical)
function flow_data_preset.getColumn(column_id)
    local column_info = {}

    if columns[column_id] then
        column_info = columns[column_id]
        column_info["id"] = column_id
    end

    return column_info
end

-- ###########################################

-- @brief Given a list of filters, returns a list of particular conditions for each filter if available
-- @param where Array, containing a list of ids for the where
-- @param available_filters List, containing a list filters, key is the key of the filter, value is the value
-- @return a list of filters, key - value
function flow_data_preset.convertFilters(where, available_filters, isHistorical)
    local where_query = {}

    if (not available_filters) or (table.len(available_filters) == 0) then
        return where_query
    end

    for _, key in pairs(where or {}) do
        if (columns[key] and columns[key]["filters"]) then
            local filter = columns[key]["filters"]
            -- Multiple filters requested, see asn
            if type(filter) == "table" then
                for _, or_filter in pairs(filter or {}) do
                    local new_filter = columns[or_filter]
                    new_filter.filter_value = available_filters[key]
                    new_filter.id = or_filter
                    new_filter.key = new_filter["filters"]
                    if not where_query[key] then
                        where_query[key] = {}
                    end
                    where_query[key][#where_query[key] + 1] = new_filter
                end
            else
                where_query[filter] = columns[key]
                where_query[filter].filter_value = available_filters[key]
            end
        end
    end

    -- Ifid filter is mandatory, add it in case it's missing, only in live data
    if isHistorical and not where_query["ifid"] and not where_query["INTERFACE_ID"] then
        local ifid = available_filters["ifid"] or interface.getId() -- Use current ifid
        where_query["INTERFACE_ID"] = ifid
    end

    return where_query
end

-- ###########################################

-- @brief Return the requested formatted data if a
--        formatting function is available
-- @param key String, key of the formatter to retrieve
-- @param value String, data to format
-- @return the formatted data
function flow_data_preset.getFormattedDataAndLink(key, value, values)
    local formatted_value = value
    local link = nil

    -- tprint(key .. " = " .. value)

    -- If key is empty or no formatter available return the value
    if isEmptyString(key) or isEmptyString(formatted_value) then
        return formatted_value, link
    end

    if (not columns[key]) or (not columns[key]["formatter"]) or
        (not columns[key]["formatter"]["funct"]) then
        return formatted_value, link
    end

    -- Get the formatter function
    local formatter = columns[key]["formatter"]["funct"]
    local link_formatter = columns[key]["formatter"]["generateLink"]

    -- See if there is some column from which is dependent,
    -- e.g. SNMP Interface needs the SNMP IP
    if columns[key]["formatter"]["column_dependent"] then
        local dependent_values = split(value, "|")

        if (#dependent_values > 1) then
            -- TODO: Now it's limited to a single column, add multiple columns	 
            formatted_value = formatter(dependent_values[1], dependent_values[2])

            if link_formatter then
                link = link_formatter(dependent_values[1], dependent_values[2])
            end
        else
            -- new code
            local dependency =
                values[columns[key]["formatter"]["column_dependent"]]

            if (dependency ~= nil) then
                formatted_value = formatter(dependency, value)

                if link_formatter then
                    link = link_formatter(dependency, value)
                end
            end

            return formatted_value, link
        end
    else
        formatted_value = formatter(formatted_value)
        if link_formatter then
            link = link_formatter(value)
        end
    end

    if not link and columns[key]["formatter"]["link"] then
        link = string.format(columns[key]["formatter"]["link"], value)
    end

    return formatted_value, link
end

-- ###########################################

return flow_data_preset
