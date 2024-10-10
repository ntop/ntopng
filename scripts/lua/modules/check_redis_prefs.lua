--
-- (C) 2019-24 - ntop.org
--
require "ntop_utils"

-- ###########################################

-- NOTE: '~= "0"' is used for prefs which are enabled by default
function areInterfaceTimeseriesEnabled(ifid)
    return ((ntop.getPref("ntopng.prefs.interface_rrd_creation") ~= "0"))
end

-- ###########################################

function areInterfaceL7TimeseriesEnabled(ifid)
    return (areInterfaceTimeseriesEnabled(ifid) and
               (ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation") ~= "per_category"))
end

-- ###########################################

function areInterfaceCategoriesTimeseriesEnabled(ifid)
    local rv = ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation")

    -- note: categories are disabled by default
    return (areInterfaceTimeseriesEnabled(ifid) and ((rv == "per_category") or (rv == "both")))
end

-- ###########################################

function areHostTimeseriesEnabled()
    local rv = ntop.getPref("ntopng.prefs.hosts_ts_creation")
    if isEmptyString(rv) then
        rv = "light"
    end

    return ((rv == "light") or (rv == "full"))
end

-- ###########################################

function areHostL7TimeseriesEnabled(ifid)
    local rv = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")

    -- note: host protocols are disabled by default
    return ((ntop.getPref("ntopng.prefs.hosts_ts_creation") == "full") and ((rv == "per_protocol") or (rv == "both")))
end

-- ###########################################

function areHostCategoriesTimeseriesEnabled(ifid)
    local rv = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")

    -- note: host protocols are disabled by default
    return ((ntop.getPref("ntopng.prefs.hosts_ts_creation") == "full") and ((rv == "per_category") or (rv == "both")))
end

-- ###########################################

function areSystemTimeseriesEnabled()
    return (ntop.getPref("ntopng.prefs.system_probes_timeseries") ~= "0")
end

-- ###########################################

function areHostPoolsTimeseriesEnabled(ifid)
    return (ntop.isPro() and (ntop.getPref("ntopng.prefs.host_pools_rrd_creation") == "1"))
end

-- ###########################################

function areASTimeseriesEnabled(ifid)
    return (ntop.getPref("ntopng.prefs.asn_rrd_creation") == "1")
end

-- ###########################################

function areInternalTimeseriesEnabled(ifid)
    -- NOTE: no separate preference so far
    return (areSystemTimeseriesEnabled())
end

-- ###########################################

function areCountryTimeseriesEnabled(ifid)
    return ((ntop.getPref("ntopng.prefs.country_rrd_creation") == "1"))
end

-- ###########################################

function areOSTimeseriesEnabled(ifid)
    return ((ntop.getPref("ntopng.prefs.os_rrd_creation") == "1"))
end

-- ###########################################

function areVlanTimeseriesEnabled(ifid)
    return (ntop.getPref("ntopng.prefs.vlan_rrd_creation") == "1")
end

-- ###########################################

function areMacsTimeseriesEnabled(ifid)
    return (ntop.getPref("ntopng.prefs.l2_device_rrd_creation") == "1")
end

-- ###########################################

function areContainersTimeseriesEnabled(ifid)
    -- NOTE: no separate preference so far
    return (true)
end

-- ###########################################

function areSnmpTimeseriesEnabled(device, port_idx)
    return (ntop.getPref("ntopng.prefs.snmp_devices_rrd_creation") == "1")
end

-- ###########################################

function areFlowdevTimeseriesEnabled()
    return (ntop.getPref("ntopng.prefs.flow_device_port_rrd_creation") == "1")
end

-- ###########################################

function highExporterTimeseriesResolution()
    return (ntop.getPref("ntopng.prefs.exporters_ts_resolution") == "60")
end

-- ###########################################

function areAlertsEnabled()
    if (__alert_enabled == nil) then
        -- Not too nice as changes will be read periodically as new VMs are reloaded
        -- but at least we avoid breaking up the performance
        __alert_enabled = (ntop.getPref("ntopng.prefs.disable_alerts_generation") ~= "1")
    end

    return (__alert_enabled)
end

-- ##########################################

function get5MinTSConfig()
    local config = {}

    config.host_ts_creation = ntop.getPref("ntopng.prefs.hosts_ts_creation")
    config.host_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")
    config.l2_device_rrd_creation = ntop.getPref("ntopng.prefs.l2_device_rrd_creation")
    config.l2_device_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.l2_device_ndpi_timeseries_creation")
    config.flow_devices_rrd_creation = ntop.getPref("ntopng.prefs.flow_device_port_rrd_creation")
    config.host_pools_rrd_creation = ntop.getPref("ntopng.prefs.host_pools_rrd_creation")
    config.snmp_devices_rrd_creation = ntop.getPref("ntopng.prefs.snmp_devices_rrd_creation")
    config.asn_rrd_creation = ntop.getPref("ntopng.prefs.asn_rrd_creation")
    config.obs_point_rrd_creation = ntop.getPref("ntopng.prefs.observation_points_rrd_creation")
    config.country_rrd_creation = ntop.getPref("ntopng.prefs.country_rrd_creation")
    config.os_rrd_creation = ntop.getPref("ntopng.prefs.os_rrd_creation")
    config.vlan_rrd_creation = ntop.getPref("ntopng.prefs.vlan_rrd_creation")
    config.ndpi_flows_timeseries_creation = ntop.getPref("ntopng.prefs.ndpi_flows_rrd_creation")
    config.interface_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation")

    -- ########################################################
    -- Populate some defaults
    if (tostring(config.flow_devices_rrd_creation) == "1" and ntop.isEnterpriseM() == false) then
        config.flow_devices_rrd_creation = "0"
    end

    if (tostring(config.snmp_devices_rrd_creation) == "1" and not (ntop.isEnterpriseM() or ntop.isnEdgeEnterprise())) then
        config.snmp_devices_rrd_creation = "0"
    end

    -- Local hosts RRD creation is on, with no nDPI rrd creation
    if isEmptyString(config.host_ts_creation) then
        config.host_ts_creation = "light"
    end
    if isEmptyString(config.host_ndpi_timeseries_creation) then
        config.host_ndpi_timeseries_creation = "none"
    end

    -- Devices RRD creation is OFF, as OFF is the nDPI rrd creation
    if isEmptyString(config.l2_device_rrd_creation) then
        config.l2_device_rrd_creation = "0"
    end
    if isEmptyString(config.l2_device_ndpi_timeseries_creation) then
        config.l2_device_ndpi_timeseries_creation = "none"
    end

    -- Interface RRD creation is on, with per-protocol nDPI, Pref used by Observation Points
    if isEmptyString(config.interface_ndpi_timeseries_creation) then
        config.interface_ndpi_timeseries_creation = "per_protocol"
    end

    return config
end

-- ###########################################

function getMinTSConfig()
    local config = {}
    local prefs = ntop.getPrefs() -- runtime ntopng preferences

    config.interface_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation")
    config.ndpi_flows_timeseries_creation = ntop.getPref("ntopng.prefs.ndpi_flows_rrd_creation")
    config.internals_rrd_creation = ntop.getPref("ntopng.prefs.internals_rrd_creation") == "1"
    config.is_dump_flows_enabled = ntop.getPrefs()["is_dump_flows_enabled"]
    config.flow_devices_rrd_creation = ntop.getPref("ntopng.prefs.flow_device_port_rrd_creation")
    
    -- Interface RRD creation is on, with per-protocol nDPI
    if isEmptyString(config.interface_ndpi_timeseries_creation) then
        config.interface_ndpi_timeseries_creation = "per_protocol"
    end

    return config
end

-- ##############################################

-- Get from redis the throughput type bps or pps
function getThroughputType()
    local throughput_type = ntop.getCache("ntopng.prefs.thpt_content")
    if throughput_type == "" then
        throughput_type = "bps"
    end

    return throughput_type
end

-- ##############################################

function hasClickHouseSupport()
    if not ntop.isClickHouseEnabled() then
        return false
    end

    local auth = require "auth"

    if not (ntop.isPro() or ntop.isnEdgeEnterprise()) or ntop.isWindows() then
        return false
    end

    -- Don't allow historical flows for unauthorized users
    if not auth.has_capability(auth.capabilities.historical_flows) then
        return false
    end

    return true
end

-- ##############################################

-- NOTE: global nindex support may be enabled but some disable on some interfaces
function interfaceHasClickHouseSupport()
    require "check_redis_prefs"
    return hasClickHouseSupport()
end

-- ##############################################

function isAllowedSystemInterface()
    return ntop.isAllowedInterface(tonumber(getSystemInterfaceId()))
end
