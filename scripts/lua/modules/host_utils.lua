--
-- (C) 2014-24 - ntop.org
--
require "label_utils"
require "ntop_utils"
require "check_redis_prefs"

local consts = require "consts"

-- ##############################################

local host_utils = {}

-- ##############################################

-- @brief Implements the logic to decide whether to show or not the url for a given `host_info`
local function hostdetails_exists(host_info, hostdetails_params)
    if not hostdetails_params then
        hostdetails_params = {}
    end

    if hostdetails_params["page"] ~= "historical" and not hostdetails_params["ts_schema"] then
        -- If the requested host_details.lua page is not the "historical" page
        -- and if no ts_schema has been requested
        -- then we check for host existance in memory, to make sure the page host_details.lua
        -- won't bring to an empty page.
        if not host_info["ipkey"] then
            -- host_info hasn't been generated with Host::lua so we can try and
            -- see if the host is active
            local active_host = interface.getHostInfo(hostinfo2hostkey(host_info))
            if not active_host then
                return false
            end
        end
    else
        -- If the requested page is the "historical" page, or if a ts_schema has been requested,
        -- then we assume page host_details.lua
        -- exists if the timeseries are enabled and if the requested timeseries exists for the host
        if not hostdetails_params["ts_schema"] then
            -- Default schema for hosts
            hostdetails_params["ts_schema"] = "host:traffic"
        end

        -- A ts_schema has been requested, let's see if it exists
        local ts_utils = require("ts_utils_core")
        local tags = table.merge(host_info, hostdetails_params)
        if not tags["ifid"] then
            tags["ifid"] = interface.getId()
        end

        if not interfaceHasClickHouseSupport() and not ts_utils.exists(hostdetails_params["ts_schema"], tags) then
            -- If here, the requested schema, along with its hostdetails_params doesn't exist
            return false
        end
    end
    return true
end

-- ##############################################

function host_utils.flow2hostinfo(host_info, host_type)
    local host_name
    local res = interface.getHostMinInfo(host_info[host_type .. ".ip"])

    if ((res == nil) or (res["name"] == nil)) then
        host_name = host_info[host_type .. ".ip"]
    else
        host_name = res["name"]
    end

    return ({
        host = host_info[host_type .. ".ip"],
        vlan = host_info[host_type .. ".vlan"],
        name = host_name
    })
end

-- ##############################################

--
-- Catch the main information about an host from the host_info table and return the corresponding url.
-- Example:
--          hostinfo2url(host_key), return an url based on the host_key
--          hostinfo2url(host[key]), return an url based on the host value
--          hostinfo2url(flow[key],"cli"), return an url based on the client host information in the flow table
--          hostinfo2url(flow[key],"srv"), return an url based on the server host information in the flow table
--

function host_utils.hostinfo2url(host_info, host_type, novlan)
    local rsp = ''
    -- local version = 0
    local version = 1

    if (host_type == "cli") then
        if (host_info["cli.ip"] ~= nil) then
            rsp = rsp .. 'host=' .. hostinfo2hostkey(host_utils.flow2hostinfo(host_info, "cli"))
        end

    elseif (host_type == "srv") then
        if (host_info["srv.ip"] ~= nil) then
            rsp = rsp .. 'host=' .. hostinfo2hostkey(host_utils.flow2hostinfo(host_info, "srv"))
        end
    else

        if ((type(host_info) ~= "table")) then
            host_info = hostkey2hostinfo(host_info)
        end

        if (host_info["host"] ~= nil) then
            rsp = rsp .. 'host=' .. host_info["host"]
        elseif (host_info["ip"] ~= nil) then
            rsp = rsp .. 'host=' .. host_info["ip"]
        elseif (host_info["mac"] ~= nil) then
            rsp = rsp .. 'host=' .. host_info["mac"]
            -- Note: the host'name' is not supported (not accepted by lint)
            -- elseif(host_info["name"] ~= nil) then
            --  rsp = rsp..'host='..host_info["name"]
        end
    end

    if (novlan == nil) then
        if ((host_info["vlan"] ~= nil) and (tonumber(host_info["vlan"]) ~= 0)) then
            if (version == 0) then
                rsp = rsp .. '&vlan=' .. tostring(host_info["vlan"])
            elseif (version == 1) then
                rsp = rsp .. '@' .. tostring(host_info["vlan"])
            end
        end
    end

    return rsp
end

-- ##############################################

-- @brief Generates an host_details.lua url (if available)
-- @param host_info A lua table containing at least keys `host` and `vlan` or a full lua table generated with Host::lua
-- @param href_params A lua table containing params host_details.lua params, e.g., {page = "historical"}
-- @param href_check Performs existance checks on the link to avoid generating links to inactive hosts or hosts without timeseries
-- @return A string containing the url (if available) or an empty string when the url is not available
function host_utils.hostinfo2detailsurl(host_info, href_params, href_check)
    local res = ''

    if not href_check or hostdetails_exists(host_info, href_params) then
        local auth = require "auth"
        local url_params = table.tconcat(href_params or {}, "=", "&")

        -- Alerts pages for the host are in alert_stats.lua (Alerts menu)
        if href_params and href_params.page == "engaged-alerts" then
            if auth.has_capability(auth.capabilities.alerts) then
                res = string.format("%s/lua/alert_stats.lua?page=host&status=engaged&ip=%s%s%s", ntop.getHttpPrefix(),
                    hostinfo2hostkey(host_info), consts.SEPARATOR, "eq")
            end
        elseif href_params and href_params.page == "alerts" then
            if auth.has_capability(auth.capabilities.alerts) then
                res = string.format("%s/lua/alert_stats.lua?page=host&status=historical&ip=%s%s%s",
                    ntop.getHttpPrefix(), hostinfo2hostkey(host_info), consts.SEPARATOR, "eq")
            end
            -- All other pages are in host_details.lua
        else
            res = string.format("%s/lua/host_details.lua?%s%s%s", ntop.getHttpPrefix(), hostinfo2url(host_info),
                isEmptyString(url_params) and '' or '&', url_params)
        end
    end

    return res
end

-- ##############################################

return host_utils
