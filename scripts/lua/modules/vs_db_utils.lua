--
-- (C) 2014-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- ####################################################################################
-- Requires

require "template"
require "lua_utils"

local json = require("dkjson")
local format_utils = require("format_utils")
-- ####################################################################################

local vs_db_utils = {}
local debug_me = false

local data_table_name               = "vulnerability_scan_data"
local report_table_name             = "vulnerability_scan_report"

vs_db_utils.report_type = {
    single_scan = 1,
    scan_all = 2,
    periodic_scan = 3
 }

-- ####################################################################################
-- Function to save data of single scan on db
function vs_db_utils.save_vs_result(scan_type, host, end_epoch, json_info, scan_result)

    if debug_me then
        traceError(TRACE_NORMAL,TRACE_CONSOLE, "Saving on DB HOST: ".. host .. " SCAN_TYPE: " .. scan_type .. " ENDEPOCH: "..end_epoch.." \n")
    end

    local sql = string.format("INSERT INTO %s (HOST, SCAN_TYPE, LAST_SCAN, JSON_INFO, VS_RESULT_FILE) Values",data_table_name)
    -- it's necessary replace the ' character with a common character like |
    scan_result = scan_result:gsub("%'","|")

    sql = string.format("%s ('%s', '%s', %s, '%s', '%s');", sql, host, scan_type, end_epoch, json_info, scan_result)
    
    return(interface.execSQLQuery(sql))
    
end

-- ####################################################################################
-- Function to retrieve nmap result from DB
function vs_db_utils.retrieve_scan_result(scan_type, host, end_epoch) 
    local sql = "SELECT VS_RESULT_FILE FROM %s WHERE HOST = '%s' AND SCAN_TYPE = '%s' AND LAST_SCAN = %u;"
    sql = string.format(sql, data_table_name, host, scan_type, tonumber(end_epoch))
    local res = interface.execSQLQuery(sql)
    local response = ""
    -- replace back all the "|" with "'"
    for _, item in ipairs(res) do
        if (isEmptyString(item.VS_RESULT_FILE)) then
            response = "Empty response"
        else
            response = item.VS_RESULT_FILE:gsub("%|","'")
        end
    end

    if (debug_me) then
        tprint(sql)
        tprint(res)
    end
    return response

end

-- ####################################################################################
-- Function to retrieve all reports from DB
function vs_db_utils.retrieve_reports(sort_item, epoch)

    if (isEmptyString(sort_item) or sort_item == 'DATE') then
        sort_item = 'REPORT_DATE'
    else
        sort_item = 'REPORT_NAME'
    end

    local sql = "SELECT REPORT_NAME, toInt32(REPORT_DATE) REPORT_DATE, REPORT_JSON_INFO, "
                .."NUM_SCANNED_HOSTS,NUM_CVES, NUM_TCP_PORTS,NUM_UDP_PORTS " ..
                "FROM %s "

    if (not isEmptyString(epoch)) then
        local WHERE = "WHERE position('"..epoch.."' IN REPORT_NAME) > 0 "
        sql = sql .. WHERE
    end
    sql = sql .. " ORDER BY %s;"
    
    sql = string.format(sql,report_table_name, sort_item)

    local query_result = interface.execSQLQuery(sql)
    local result = {}

    -- format data
    for _,item in ipairs(query_result) do
        local report_name = item.REPORT_NAME
        report_name = report_name:gsub("_"," ")
        result[#result+1] = {
            name = report_name,
            epoch = item.REPORT_DATE,
            report_date = format_utils.formatEpoch(item.REPORT_DATE),
            cves = item.NUM_CVES,
            tcp_ports = item.NUM_TCP_PORTS,
            udp_ports = item.NUM_UDP_PORTS,
            num_hosts = item.NUM_SCANNED_HOSTS
        }
    end
    return(result)

end

-- ####################################################################################
-- Function to retrieve single report from DB
function vs_db_utils.retrieve_report(epoch)
    local sql = "SELECT REPORT_NAME,toInt32(REPORT_DATE) REPORT_DATE, REPORT_JSON_INFO, "
                .."NUM_SCANNED_HOSTS,NUM_CVES, NUM_TCP_PORTS,NUM_UDP_PORTS " ..
                "FROM %s " ..
                "WHERE REPORT_DATE = %u"
    sql = string.format(sql,report_table_name, tonumber(epoch))

    local query_result = interface.execSQLQuery(sql)
    local result = {}
    local report_info

    -- format data
    for _,item in ipairs(query_result) do
        local report_name = item.REPORT_NAME
        report_name = report_name:gsub("_"," ")
        result[#result+1] = {
            report_name = report_name,
            epoch = item.REPORT_DATE,
            report_date = format_utils.formatEpoch(item.REPORT_DATE),
            cves = item.NUM_CVES,
            tcp_ports = item.NUM_TCP_PORTS,
            udp_ports = item.NUM_UDP_PORTS,
            num_hosts = item.NUM_SCANNED_HOSTS,
            info = item.REPORT_JSON_INFO
        }
        report_info = json.decode(item.REPORT_JSON_INFO)
    end
    return result,report_info
end

-- ####################################################################################
-- Function to retrieve single report name from DB
function vs_db_utils.retrieve_report_name(epoch)
    local sql = "SELECT REPORT_NAME ".. 
                "FROM %s " ..
                "WHERE REPORT_DATE = %u"
    sql = string.format(sql,report_table_name, tonumber(epoch))

    local query_result = interface.execSQLQuery(sql)
    local report_name

    -- format data
    for _,item in ipairs(query_result) do
        report_name = item.REPORT_NAME
    end
    report_name = report_name:gsub("_"," ")

    return report_name
end

-- ####################################################################################
-- Function to save report on DB
function vs_db_utils.save_report_info(report_info)

    local report_name = report_info.name
    report_name = report_name:gsub(" ","_")
    local report_date = report_info.date
    local json_info = json.encode(report_info.all_data_details)
    local num_scanned_host = report_info.scanned_hosts or 0
    local num_cves = report_info.cves or 0
    local num_udp_ports = report_info.udp_ports or 0
    local num_tcp_ports = report_info.tcp_ports or 0

    local sql = string.format("INSERT INTO %s VALUES",report_table_name)
    local sql = string.format("%s ('%s', %s, '%s', %u, %u, %u, %u);",sql, report_name, report_date, json_info, num_scanned_host, num_cves, num_tcp_ports, num_udp_ports)

    return(interface.execSQLQuery(sql))
end

-- ####################################################################################
-- Function to delete single report from DB
function vs_db_utils.delete_report(epoch)

    local sql = string.format("DELETE FROM %s WHERE REPORT_DATE = %u;",report_table_name, tonumber(epoch))
    return(interface.execSQLQuery(sql))
end

-- ####################################################################################
-- Function to edit single report from DB
function vs_db_utils.edit_report(epoch, report_name)
    local sql = string.format("ALTER TABLE %s UPDATE REPORT_NAME = '%s' WHERE REPORT_DATE = %u;",report_table_name,report_name, tonumber(epoch))
    return(interface.execSQLQuery(sql))
end

function vs_db_utils.update_last_result(scan_result, scan_type, host, epoch, last_port)
    local db_current_scan_result = vs_db_utils.retrieve_scan_result(scan_type,host,epoch)

    scan_result = scan_result:gsub("%'","|")

    local merged_results = vs_db_utils.get_updated_vs_result(db_current_scan_result, scan_result, last_port)
    
    local sql = string.format("ALTER TABLE %s UPDATE VS_RESULT_FILE = '%s' WHERE HOST = '%s' AND SCAN_TYPE = '%s' AND LAST_SCAN = %u;",data_table_name,merged_results,host,scan_type, tonumber(epoch))
    return(interface.execSQLQuery(sql))
end

function vs_db_utils.get_updated_vs_result(current_gloal_result, last_single_scan, last_port)
    return(string.format("%s\n\n%s\n%s",current_gloal_result,i18n("hosts_stats.page_scan_hosts.inconsistency_state", {port =last_port}),last_single_scan))
end
-- ####################################################################################

return vs_db_utils
