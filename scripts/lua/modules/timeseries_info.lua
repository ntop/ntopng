--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/handlers/?.lua;" .. package.path
if ntop.isPro() then
    package.path = dirs.installdir .. "/scripts/lua/pro/modules/timeseries/handlers/?.lua;" .. package.path
end

local ts_utils = require "ts_utils"
require "lua_utils_generic"
require "label_utils"
require "lua_utils_get"

local timeseries_info = {}

-- #################################

local timeseries_id = {
    iface = "iface",
    host = "host",
    mac = "mac",
    network = "subnet",
    asn = "asn",
    country = "country",
    os = "os",
    vlan = "vlan",
    host_pool = "host_pool",
    pod = "pod",
    container = "container",
    hash_state = "ht",
    system = "system",
    profile = "profile",
    redis = "redis",
    influxdb = "influxdb",
    active_monitoring = "am",
    snmp_interface = "snmp_interface",
    snmp_device = "snmp_device",
    observation_point = "obs_point",
    flow_dev = "flowdev",
    flow_port = "flowdev_port",
    nedge = "nedge",
    sflow_dev = "sflowdev",
    sflow_port = "sflowdev_port",
    vulnerability_scan = "am_vuln_scan",
    flow   = "flow",
    flow_aggr = "flow_aggr",
}

-- #################################

local function getTimeseriesFromModules(tags, prefix, ts_options)
    local module_to_use = nil
    if prefix == timeseries_id.iface then
        module_to_use = require "ts_interface"
    elseif prefix == timeseries_id.host then
        module_to_use = require "ts_host"
    elseif prefix == timeseries_id.mac then
        module_to_use = require "ts_mac"
    elseif prefix == timeseries_id.network then
        module_to_use = require "ts_network"
    elseif prefix == timeseries_id.asn then
        module_to_use = require "ts_asn"
    elseif prefix == timeseries_id.country then
        module_to_use = require "ts_country"
    elseif prefix == timeseries_id.os then
        module_to_use = require "ts_os"
    elseif prefix == timeseries_id.vlan then
        module_to_use = require "ts_vlan"
    elseif prefix == timeseries_id.host_pool then
        module_to_use = require "ts_host_pool"
    elseif prefix == timeseries_id.pod then
        module_to_use = require "ts_pod"
    elseif prefix == timeseries_id.container then
        module_to_use = require "ts_container"
    elseif prefix == timeseries_id.hash_state then
        module_to_use = require "ts_hash_state"
    elseif prefix == timeseries_id.system then
        module_to_use = require "ts_system"
    elseif prefix == timeseries_id.profile then
        module_to_use = require "ts_profile"
    elseif prefix == timeseries_id.redis then
        module_to_use = require "ts_redis"
    elseif prefix == timeseries_id.influxdb then
        module_to_use = require "ts_influxdb"
    elseif prefix == timeseries_id.active_monitoring then
        module_to_use = require "ts_active_monitoring"
    elseif prefix == timeseries_id.snmp_interface then
        module_to_use = require "ts_snmp_interface"
    elseif prefix == timeseries_id.snmp_device then
        module_to_use = require "ts_snmp_device"
    elseif prefix == timeseries_id.observation_point then
        module_to_use = require "ts_observation_point"
    elseif prefix == timeseries_id.flow_dev then
        module_to_use = require "ts_flow_device"
    elseif prefix == timeseries_id.flow_port then
        module_to_use = require "ts_flow_device_port"
    elseif prefix == timeseries_id.nedge then
        module_to_use = require "ts_nedge"
    elseif prefix == timeseries_id.sflow_dev then
        module_to_use = require "ts_sflow_device"
    elseif prefix == timeseries_id.sflow_port then
        module_to_use = require "ts_sflow_device_port"
    elseif prefix == timeseries_id.vulnerability_scan then
        module_to_use = require "ts_vulnerability_scan"
    elseif prefix == timeseries_id.flow then
        module_to_use = require "ts_flow"
    elseif prefix == timeseries_id.flow_aggr then
        module_to_use = require "ts_flow_aggr"
    end
    if module_to_use then
        return module_to_use.getTimeseries(tags, ts_options) or {}
    end
    return {}
end

function timeseries_info.getAllTimeseries()
    local timeseries_list = {}
    for _, prefix in pairs(timeseries_id) do
        timeseries_list = table.merge(timeseries_list, timeseries_info.getTimeseries({}, prefix))
    end
    return timeseries_list
end

-- #################################

function timeseries_info.getTimeseries(tags, prefix)
    local timeseries = {}
    if not prefix then

        return timeseries
    end
    
    if ntop.isEnterprise() then
        -- Check for the infrastructure active monitoring
        if tags.host then
            if tags.host:find("metric:infrastructure") then
                local host = split(tags.host, ",")
                local am_utils = require("am_utils")
                local active_monitoring_hosts = am_utils.getHosts() or {}
                for key, info in pairs(active_monitoring_hosts or {}) do
                    if key:find(host[1]) then
                        local measurement_key = split(key, "@")[2]
                        tags.host = measurement_key .. ",metric:" .. info.measurement
                        timeseries = add_active_monitoring_timeseries(tags, timeseries)
                        timeseries[#timeseries].query = 'host:' .. tags.host
                        -- HTTP measurement has 2 timeseries, so add to both the query
                        if info.measurement == 'http' then
                            timeseries[#timeseries - 1].query = 'host:' .. tags.host
                        end
                    end
                end
                if table.len(timeseries) > 0 then
                    timeseries[1].default_visible = true
                end
                return timeseries
            end
        end
    end

    local timeseries_options = {
        is_asn_mode_enabled = isASNModeEnabled(),
        -- Only skip per-protocol queryTotal filtering when no epoch is available.
        -- When epoch is provided, let handlers enumerate actual series (e.g. per-protocol ndpi).
        emptyEpoch = not (tags.epoch_begin and tags.epoch_end),
        include_empty_ts = true
    }
    local timeseries_list = getTimeseriesFromModules(tags, prefix, timeseries_options)

    for _, info in pairs(timeseries_list) do
        -- Remove from nEdge the timeseries only for ntopng
        if (info.nedge_exclude) and (ntop.isnEdge()) then
            goto skip
        end

        -- Remove from ntopng the timeseries only for nEdge
        if (info.nedge_only) and (not ntop.isnEdge()) then
            goto skip
        end

        if (info.exclude_asn_mode) and (timeseries_options.is_asn_mode_enabled) then
            goto skip
        end

        timeseries[#timeseries + 1] = info

        ::skip::
    end

    return timeseries
end

-- #################################

function timeseries_info.get_traffic_rules_schema(rule_type)
    local timeseries_list = timeseries_info.getAllTimeseries()
    if rule_type == "host" then
        local host_ts_enabled = ntop.getCache("ntopng.prefs.host_ndpi_timeseries_creation")
        local has_top_protocols = (host_ts_enabled == "both" or host_ts_enabled == "per_protocol")
        local has_top_categories = (host_ts_enabled == "both" or host_ts_enabled == "per_category")

        local metric_list = {{
            title = i18n('graphs.traffic_rxtx'),
            group = i18n('generic_data'),
            label = i18n('graphs.traffic_rxtx'),
            id = 'host:traffic' --[[ here the ID is the schema ]] ,
            show_volume = true
        }, {
            title = i18n('graphs.traffic_rcvd'),
            group = i18n('generic_data'),
            label = i18n('graphs.traffic_rcvd'),
            id = 'host:traffic-RX' --[[ here the ID is the schema ]] ,
            show_volume = true
        }, {
            title = i18n('graphs.traffic_sent'),
            group = i18n('generic_data'),
            label = i18n('graphs.traffic_sent'),
            id = 'host:traffic-TX' --[[ here the ID is the schema ]] ,
            show_volume = true
        }, {
            title = i18n('score'),
            group = i18n('generic_data'),
            label = i18n('score'),
            id = 'host:score' --[[ here the ID is the schema ]] ,
            show_volume = false
        }}

        if has_top_protocols then
            local application_list = interface.getnDPIProtocols()
            for application, _ in pairsByKeys(application_list or {}, asc) do
                metric_list[#metric_list + 1] = {
                    label = application,
                    group = i18n('applications_long'),
                    title = application,
                    id = 'top:host:ndpi',
                    disable_perc_95_ts = true,
                    extra_metric = 'protocol:' .. application --[[ here the schema is the ID ]] ,
                    show_volume = true
                }
            end
        end

        if has_top_categories then
            local category_list = interface.getnDPICategories()
            for category, _ in pairsByKeys(category_list or {}, asc) do
                metric_list[#metric_list + 1] = {
                    label = category,
                    group = i18n('categories'),
                    title = category,
                    disable_perc_95_ts = true,
                    id = 'top:host:ndpi_categories',
                    extra_metric = 'category:' .. category --[[ here the schema is the ID ]] ,
                    show_volume = true
                }
            end
        end

        return metric_list
    elseif rule_type == "asn" then
        local ifname_ts_enabled = ntop.getCache("ntopng.prefs.ifname_ndpi_timeseries_creation")
        local has_top_protocols = ifname_ts_enabled == "both" or ifname_ts_enabled == "per_protocol" or
                                      ifname_ts_enabled ~= "0"

        local metric_list = {}
        for _, item in ipairs(timeseries_list) do
            if (item.id == timeseries_id.asn) then
                item.show_volume = false
                if (item.schema == "asn:traffic_rcvd" or item.schema == "asn:traffic_sent" or item.schema ==
                    "asn:traffic") then
                    item.show_volume = true
                    metric_list[#metric_list + 1] = item
                end
            end
        end
        if has_top_protocols then
            local id = 'top:asn:ndpi'
            local application_list = interface.getnDPIProtocols()
            for application, _ in pairsByKeys(application_list or {}, asc) do
                metric_list[#metric_list + 1] = {
                    label = application,
                    group = i18n('applications_long'),
                    title = application,
                    schema = id,
                    disable_perc_95_ts = true,
                    extra_metric = 'protocol:' .. application --[[ here the schema is the ID ]] ,
                    show_volume = true
                }
            end
        end
        return metric_list
    elseif rule_type == "interface" then
        local ifname_ts_enabled = ntop.getCache("ntopng.prefs.ifname_ndpi_timeseries_creation")
        local has_top_protocols = ifname_ts_enabled == "both" or ifname_ts_enabled == "per_protocol" or
                                      ifname_ts_enabled ~= "0"
        local has_top_categories = ifname_ts_enabled == "both" or ifname_ts_enabled == "per_category"

        local metric_list = {{
            title = i18n('graphs.traffic_rxtx'),
            group = i18n('generic_data'),
            label = i18n('graphs.traffic_rxtx'),
            id = 'iface:traffic_rxtx' --[[ here the ID is the schema ]] ,
            show_volume = true
        }, {
            title = i18n('graphs.traffic_rcvd'),
            group = i18n('generic_data'),
            label = i18n('graphs.traffic_rcvd'),
            id = 'iface:traffic_rxtx-rx' --[[ here the ID is the schema ]] ,
            show_volume = true
        }, {
            title = i18n('graphs.traffic_sent'),
            group = i18n('generic_data'),
            label = i18n('graphs.traffic_sent'),
            id = 'iface:traffic_rxtx-tx' --[[ here the ID is the schema ]] ,
            show_volume = true
        }, {
            title = i18n('score'),
            group = i18n('generic_data'),
            label = i18n('score'),
            id = 'iface:score' --[[ here the ID is the schema ]] ,
            show_volume = false
        }}

        if has_top_protocols then
            local id = getIfacenDPITsName()
            local application_list = interface.getnDPIProtocols()
            for application, _ in pairsByKeys(application_list or {}, asc) do
                metric_list[#metric_list + 1] = {
                    label = application,
                    group = i18n('applications_long'),
                    title = application,
                    id = id,
                    extra_metric = 'protocol:' .. application --[[ here the schema is the ID ]] ,
                    show_volume = true
                }
            end
        end

        if has_top_categories then
            local category_list = interface.getnDPICategories()
            for category, _ in pairsByKeys(category_list or {}, asc) do
                metric_list[#metric_list + 1] = {
                    label = category,
                    group = i18n('categories'),
                    title = category,
                    disable_perc_95_ts = true,
                    id = 'top:iface:ndpi_categories',
                    extra_metric = 'category:' .. category --[[ here the schema is the ID ]] ,
                    show_volume = true
                }
            end
        end

        return metric_list
    elseif rule_type == "exporter" then
        local metric_list = {{
            title = i18n('traffic'),
            group = i18n('generic_data'),
            label = i18n('traffic'),
            show_volume = true
        }, {
            title = i18n("graphs.usage"),
            group = i18n('generic_data'),
            label = i18n("graphs.usage"),
            id = 'flowdev_port:usage' --[[ here the ID is the schema ]] ,
            show_volume = false,
            type = 'flowdev_port'
        }}

        return metric_list
    elseif rule_type == "host_pool" then
        local metric_list = {}
        for _, item in ipairs(timeseries_list) do
            if (item.id == timeseries_id.host_pool) then
                metric_list[#metric_list + 1] = item
            end
        end

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.traffic_rcvd'),
            -- group = i18n('generic_data'),
            measure_unit = "bps",
            label = i18n('graphs.traffic_rcvd'),
            id = 'host_pool:traffic-RX' --[[ here the ID is the schema ]] ,
            schema = 'host_pool:traffic-RX',
            show_volume = true

        }

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.traffic_sent'),
            -- group = i18n('generic_data'),
            label = i18n('graphs.traffic_sent'),
            measure_unit = "bps",
            id = 'host_pool:traffic-TX' --[[ here the ID is the schema ]] ,
            schema = 'host_pool:traffic-TX',
            show_volume = true

        }

        return metric_list
    elseif rule_type == "CIDR" then
        local metric_list = {}
        for _, item in ipairs(timeseries_list) do
            if (item.schema == "subnet:traffic") then
                item.label = i18n("graphs.network_traffic.total")
            end
            if (item.schema == "subnet:broadcast_traffic") then
                item.label = i18n("graphs.network_broadcast_traffic.total")
            end
            if (item.id == timeseries_id.network) then
                metric_list[#metric_list + 1] = item
            end
        end

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.network_traffic.ingress'),
            -- group = i18n('generic_data'),
            measure_unit = "bps",
            label = i18n('graphs.network_traffic.ingress'),
            id = 'subnet:traffic-ingress' --[[ here the ID is the schema ]] ,
            schema = 'subnet:traffic-ingress',
            show_volume = true

        }

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.network_traffic.egress'),
            -- group = i18n('generic_data'),
            label = i18n('graphs.network_traffic.egress'),
            measure_unit = "bps",
            id = 'subnet:traffic-egress' --[[ here the ID is the schema ]] ,
            schema = 'subnet:traffic-egress',
            show_volume = true

        }

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.network_traffic.inner'),
            -- group = i18n('generic_data'),
            label = i18n('graphs.network_traffic.inner'),
            measure_unit = "bps",
            id = 'subnet:traffic-inner' --[[ here the ID is the schema ]] ,
            schema = 'subnet:traffic-inner',
            show_volume = true
        }

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.network_broadcast_traffic.ingress'),
            -- group = i18n('generic_data'),
            measure_unit = "bps",
            label = i18n('graphs.network_broadcast_traffic.ingress'),
            id = 'subnet:broadcast_traffic-ingress' --[[ here the ID is the schema ]] ,
            schema = 'subnet:broadcast_traffic-ingress',
            show_volume = true

        }

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.network_broadcast_traffic.egress'),
            -- group = i18n('generic_data'),
            label = i18n('graphs.network_broadcast_traffic.egress'),
            measure_unit = "bps",
            id = 'subnet:broadcast_traffic-egress' --[[ here the ID is the schema ]] ,
            schema = 'subnet:broadcast_traffic-egress',
            show_volume = true

        }

        metric_list[#metric_list + 1] = {

            title = i18n('graphs.network_broadcast_traffic.inner'),
            -- group = i18n('generic_data'),
            label = i18n('graphs.network_broadcast_traffic.inner'),
            measure_unit = "bps",
            id = 'subnet:broadcast_traffic-inner' --[[ here the ID is the schema ]] ,
            schema = 'subnet:broadcast_traffic-inner',
            show_volume = true

        }
        return metric_list
    elseif rule_type == 'vlan' then
        local metric_list = {}
        for _, item in ipairs(timeseries_list) do
            if (item.id == timeseries_id.vlan) then
                if (item.schema == "vlan:score") then
                    item.show_volume = false
                else
                    item.show_volume = true
                end
                metric_list[#metric_list + 1] = item
            end
        end
        return metric_list
    elseif rule_type == 'profiles' then
        local metric_list = {}
        for _, item in ipairs(timeseries_list) do
            if (item.id == timeseries_id.profile) then
                metric_list[#metric_list + 1] = item
            end
        end
        return metric_list
    end
end

-- #################################

-- Returns a catalog table keyed by entity name.
-- Each value is a list of simplified schema descriptors for the catalog endpoint.
-- entity_filter (optional): only return schemas for this entity prefix (e.g. "host")
function timeseries_info.getCatalog(entity_filter)
    local ts_utils = require "ts_utils"

    local entity_map = {
        iface            = "iface",
        host             = "host",
        mac              = "mac",
        network          = "subnet",
        asn              = "asn",
        country          = "country",
        os               = "os",
        vlan             = "vlan",
        host_pool        = "host_pool",
        pod              = "pod",
        container        = "container",
        system           = "system",
        active_monitoring = "am",
        snmp_interface   = "snmp_interface",
        flow             = "flow",
        flow_aggr        = "flow_aggr",
    }

    local function get_tags(schema_name)
        local s = ts_utils.getSchema(schema_name)
        if not s then return {} end
        local t = {}
        for _, tag in ipairs(s._tags or {}) do t[#t + 1] = tag end
        return t
    end

    local function get_metrics(entry_metrics)
        if not entry_metrics then return {} end
        local out = {}
        for id, info in pairs(entry_metrics) do
            local m = { id = id, label = info.label or id }
            if info.invert_direction then m.invert = true end
            out[#out + 1] = m
        end
        return out
    end

    local catalog = {}
    local tags = {}

    for entity_key, prefix in pairs(entity_map) do
        if entity_filter and entity_key ~= entity_filter then
            goto skip_entity
        end

        local ok, ts_list = pcall(timeseries_info.getTimeseries, tags, prefix)
        if ok and ts_list then
            local entries = {}
            for _, entry in ipairs(ts_list) do
                local schema_name = entry.schema or ""
                entries[#entries + 1] = {
                    schema          = schema_name,
                    label           = entry.label or schema_name,
                    description     = entry.description or "",
                    unit            = entry.measure_unit or "",
                    tags_required   = get_tags(schema_name),
                    metrics         = get_metrics(entry.timeseries),
                    default_visible = entry.default_visible or false,
                }
            end
            if #entries > 0 then
                catalog[entity_key] = entries
            end
        end
        ::skip_entity::
    end

    return catalog
end

-- #################################

return timeseries_info
