--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local host_to_scan_key            = "ntopng.prefs.host_to_scan"

local rest_utils = require "rest_utils"
local json = require("dkjson")


local host = _GET["host"]
local scan_type = _GET["scan_type"]

if isEmptyString(host) or isEmptyString(scan_type) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
end


local function delete_host_to_scan(ip, scan_type) 

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


    ntop.setCache(host_to_scan_key, json.encode(saved_hosts))

    return 1
end

local del_result = delete_host_to_scan(host,scan_type)

if del_result == 1 then
    rest_utils.answer(rest_utils.consts.success.ok)
else
    rest_utils.answer(rest_utils.consts.err.internal_error)
end