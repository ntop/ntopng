--
-- (C) 2013-23 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path


local host_to_scan_key            = "ntopng.prefs.host_to_scan"
local json = require("dkjson")

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
        last_scan = time
    }
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

return scan_utils