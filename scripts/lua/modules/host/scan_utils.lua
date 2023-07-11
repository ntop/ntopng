--
-- (C) 2013-23 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path


local host_to_scan_key            = "ntopng.prefs.host_to_scan"
local json = require("dkjson")

local debug = false
--debug = true

local scan_utils = {}

function scan_utils.save_host_to_scan(scan_type, scan_params, ip, scan_result, time) 

    local saved_hosts_string = ntop.getCache(host_to_scan_key) 
    local saved_hosts = {}
    if not isEmptyString(saved_hosts_string) then
        saved_hosts = json.decode(saved_hosts_string)
        local index_to_remove = 0
        for index,value in ipairs(saved_hosts) do
            if value.host == ip and value.scan_type == scan_type then
                index_to_remove = index
            end
        end

        if index_to_remove ~= 0 then
            table.remove(saved_hosts, index_to_remove)
        end
        
    end 

    
    local new_item = {
        host=ip,
        scan_type=scan_type,
        
    }

    if time then 
        local user = _SESSION["user"]

        local date_format_type = ntop.getPref("ntopng.user." .. user .. ".date_format")
        local date_format = "%m/%d/%Y %X"
        if (date_format_type == "little_endian") then 
            date_format = "%d/%m/%Y %X"
        elseif (date_format_type == "middle_endian") then 
            date_format = "%m/%d/%Y %X"
        else
            date_format = "%Y/%m/%d %X"
        end

        new_item.last_scan  = {
            epoch = time,
            time  = os.date(date_format, time)
        }
    end
    if not isEmptyString(scan_params) then
        new_item.scan_params = scan_params
    end

    if not isEmptyString(scan_result) then
        new_item.scan_result = scan_result
    end

    saved_hosts[#saved_hosts+1] = new_item

    ntop.setCache(host_to_scan_key, json.encode(saved_hosts))
end

function scan_utils.retrieve_hosts_to_scan(debug) 
    local res_string = ntop.getCache(host_to_scan_key)

    if not isEmptyString(res_string) and res_string ~= "[[]]" and res_string ~= "[]" then
        if debug then
            tprint(json.decode(res_string))
        end
        return json.decode(res_string)
    else
        return {}
    end
end


function scan_utils.retrieve_hosts_scan_result(host, scan_type) 
    local res_string = ntop.getCache(host_to_scan_key)

    if not isEmptyString(res_string) and res_string ~= "[[]]" and res_string ~= "[]" then
        if debug then
            tprint(json.decode(res_string))
        end
        local scan_info = json.decode(res_string)

        for _, info in ipairs(scan_info) do
            if info.host == host and info.scan_type == scan_type then
                
                if not isEmptyString(info.scan_result) then
                    return info.scan_result
                end
            end
        end
    end

    return ""
end

return scan_utils