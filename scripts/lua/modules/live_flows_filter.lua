--
-- (C) 2013-26 - ntop.org
--

-- getFlowsFilter(): the filter of the live flows lists, read from _GET. Split from
-- flow_utils (which loads ~15 more modules: template, voip, snmp, graphs...) so the live
-- flows REST (active_list, geomap) can use it without flow_utils.
-- NOTE: flow_utils requires this module, the function is still global

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils" -- tablePreferences(), getDefaultTable*(), split()
local alert_consts = require "alert_consts"

function getFlowsFilter()
    -- Pagination
    local sortColumn = _GET["sortColumn"]
    local sortOrder = _GET["sortOrder"]
    local currentPage = _GET["currentPage"]
    local perPage = _GET["perPage"]

    -- Other Filters
    local port = _GET["port"]
    local application = _GET["application"]
    local category = _GET["category"]
    local network_id = _GET["network"]
    local traffic_profile = _GET["traffic_profile"]
    local traffic_type = _GET["traffic_type"]
    local flowhosts_type = _GET["flowhosts_type"]
    local ipversion = _GET["version"]
    local l4proto = _GET["l4proto"]
    local vlan = _GET["vlan"]
    local qoe = _GET["qoe"]
    local username = _GET["username"]
    local host = _GET["host"]
    local ip_filter = _GET["ip"]
    if not isEmptyString(ip_filter) and isEmptyString(host) then
        host = split(ip_filter, ";")[1]
    end
    local pid_name = _GET["pid_name"]
    local container = _GET["container"]
    local pod = _GET["pod"]
    local icmp_type = _GET["icmp_type"]
    local icmp_code = _GET["icmp_cod"]
    local dscp_filter = _GET["dscp"]
    local wlan_ssid_filter = _GET["wlan_ssid"]
    local transit_as_filter = _GET["transit_as_filter"]
    local src_asn = _GET["src_asn"]
    local dst_asn = _GET["dst_asn"]
    local host_pool = _GET["host_pool_id"]
    local flow_status = _GET["flow_status"]
    local flow_status_severity = _GET["flow_status_severity"]
    local status = _GET["status"]
    local flow_risk = _GET["flow_risk"]
    local alert_type_severity = _GET["alert_type_severity"]
    local deviceIP = _GET["deviceIP"]
    local inIfIdx = _GET["inIfIdx"]
    local outIfIdx = _GET["outIfIdx"]
    local ifIndex = _GET["ifIdx"]
    local asn = _GET["asn"]
    local talking_with = _GET["talking_with"]
    local client = _GET["client"]
    local server = _GET["server"]
    local flow_info = _GET["flow_info"]
    local interface_role = _GET["interface_role"]
    local iface_index = tonumber(_GET["interface_filter"] or -1)
    local site_id = tonumber(_GET["site_id"])

    if sortColumn == nil or sortColumn == "column_" or sortColumn == "" then
        sortColumn = getDefaultTableSort("flows")
    elseif sortColumn ~= "column_" and sortColumn ~= "" then
        tablePreferences("sort_flows", sortColumn)
    else
        sortColumn = "column_client"
    end

    if sortOrder == nil then
        sortOrder = getDefaultTableSortOrder("flows")
    elseif sortColumn ~= "column_" and sortColumn ~= "" then
        tablePreferences("sort_order_flows", sortOrder)
    end

    if currentPage == nil then
        currentPage = 1
    else
        currentPage = tonumber(currentPage)
    end

    if perPage == nil then
        perPage = getDefaultTableSize()
    else
        perPage = tonumber(perPage)
        tablePreferences("rows_number", perPage)
    end

    if port ~= nil then
        port = tonumber(port)
    end

    if network_id ~= nil then
        network_id = tonumber(network_id)
    end

    if qoe then
        qoe = tonumber(qoe)
    end

    local to_skip = (currentPage - 1) * perPage

    local a2z = false
    if sortOrder == "desc" then
        a2z = false
    else
        a2z = true
    end

    local pageinfo = {
        ["perPage"] = perPage,
        ["currentPage"] = currentPage,
        ["sortOrder"] = sortOrder or "",
        ["sortColumn"] = sortColumn or "",
        ["toSkip"] = to_skip,
        ["maxHits"] = perPage,
        ["a2zSortOrder"] = a2z,
        ["hostFilter"] = host,
        ["portFilter"] = port,
        ["qoeFilter"] = qoe,
        ["LocalNetworkFilter"] = network_id,
        ["ifaceIndex"] = iface_index,
        ["siteId"] = site_id
    }

    if application ~= nil and application ~= "" then
        local param = string.split(application, "%.")

        if param and #param == 2 then
            -- Example 5.26
            pageinfo["l7protoFilter"] = application
        else
            if not tonumber(application) then
                pageinfo["l7protoFilter"] = interface.getnDPIProtoId(application)
            else
                pageinfo["l7protoFilter"] = tonumber(application)
            end
        end
    end

    if category ~= nil and category ~= "" then
        if tonumber(category) then
            pageinfo["l7categoryFilter"] = tonumber(category)
        else
            pageinfo["l7categoryFilter"] = interface.getnDPICategoryId(category)
        end
    end

    if traffic_profile ~= nil then
        pageinfo["trafficProfileFilter"] = traffic_profile
    end

    if not isEmptyString(flowhosts_type) then
        if flowhosts_type == "local_origin_remote_target" then
            pageinfo["clientMode"] = "local"
            pageinfo["serverMode"] = "remote"
        elseif flowhosts_type == "local_only" then
            pageinfo["clientMode"] = "local"
            pageinfo["serverMode"] = "local"
        elseif flowhosts_type == "remote_origin_local_target" then
            pageinfo["clientMode"] = "remote"
            pageinfo["serverMode"] = "local"
        elseif flowhosts_type == "remote_only" then
            pageinfo["clientMode"] = "remote"
            pageinfo["serverMode"] = "remote"
        end
    end

    if not isEmptyString(traffic_type) then
        if traffic_type:contains("unicast") then
            pageinfo["unicast"] = true
        else
            pageinfo["unicast"] = false
        end

        if traffic_type:contains("one_way") then
            pageinfo["unidirectional"] = true
        end
    end

    if not isEmptyString(status) then
        -- Inside the status there are the TCP Flow states, AS Transit and alerts
        if status == "direct" or
            status == "transit" then -- AS Transit
            pageinfo["transitAS"] = status
        elseif status == "connecting" or
            status == "closed" or
            status == "established" or
            status == "reset" then -- TCP Flow State
            pageinfo["tcpFlowStateFilter"] = status
        elseif status == "normal" then -- Alerts
            pageinfo["alertedFlows"] = false
            pageinfo["filteredFlows"] = false
        elseif status == "alerted" then
            pageinfo["alertedFlows"] = true
        elseif status == "periodic" then
            pageinfo["periodicFlows"] = true
            pageinfo["filteredFlows"] = false
        elseif status == "filtered" then
            pageinfo["filteredFlows"] = true
        else
            pageinfo["statusFilter"] = tonumber(status) or status
        end
    end

    if not isEmptyString(flow_risk) then
        pageinfo["riskFilter"] = tonumber(flow_risk)
    end

    if not isEmptyString(alert_type_severity) then
        local s = alert_consts.severity_groups[alert_type_severity]

        if s then
            pageinfo["statusSeverityFilter"] = s.severity_group_id
        end
    end

    if not isEmptyString(ipversion) then
        pageinfo["ipVersion"] = tonumber(ipversion)
    end

    if not isEmptyString(l4proto) then
        pageinfo["L4Protocol"] = tonumber(l4proto)
    end

    if not isEmptyString(vlan) then
        pageinfo["vlanIdFilter"] = tonumber(vlan)
    end

    if not isEmptyString(username) then
        pageinfo["usernameFilter"] = username
    end

    if not isEmptyString(pid_name) then
        pageinfo["pidnameFilter"] = pid_name
    end

    if not isEmptyString(container) then
        pageinfo["container"] = container
    end

    if not isEmptyString(pod) then
        pageinfo["pod"] = pod
    end

    if not isEmptyString(deviceIP) then
        pageinfo["deviceIpFilter"] = deviceIP

        if not isEmptyString(inIfIdx) then
            pageinfo["inIndexFilter"] = tonumber(inIfIdx)
        end

        if not isEmptyString(ifIndex) then
            pageinfo["exporterIfaceIndex"] = tonumber(ifIndex)
        end

        if not isEmptyString(outIfIdx) then
            pageinfo["outIndexFilter"] = tonumber(outIfIdx)
        end
    end

    if not isEmptyString(asn) then
        pageinfo["asnFilter"] = tonumber(asn)
    end

    pageinfo["icmp_type"] = tonumber(icmp_type)
    pageinfo["icmp_code"] = tonumber(icmp_code)

    if not isEmptyString(dscp_filter) then
        pageinfo["dscpFilter"] = tonumber(dscp_filter)
    end

    if not isEmptyString(wlan_ssid_filter) then
        pageinfo["wlanSSIDFilter"] = wlan_ssid_filter
    end

    if not isEmptyString(transit_as_filter) then
        pageinfo["transitASFilter"] = transit_as_filter
    end

    if not isEmptyString(src_asn) then
        pageinfo["asnSrcFilter"] = tonumber(src_asn)
    end

    if not isEmptyString(dst_asn) then
        pageinfo["asnDstFilter"] = tonumber(dst_asn)
    end

    if not isEmptyString(talking_with) then
        pageinfo["talkingWith"] = talking_with
    end

    if not isEmptyString(host_pool) then
        pageinfo["poolFilter"] = tonumber(host_pool)
    end

    if not isEmptyString(client) then
        pageinfo["client"] = client
    end

    if not isEmptyString(server) then
        pageinfo["server"] = server
    end

    if not isEmptyString(flow_info) then
        pageinfo["flow_info"] = flow_info
    end

    if not isEmptyString(interface_role) then
        pageinfo["interface_role"] = interface_role
    end

    return pageinfo
end
