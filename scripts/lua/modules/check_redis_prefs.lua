--
-- (C) 2019-26 - ntop.org
--
require "ntop_utils"

-- ###########################################

-- NOTE: '~= "0"' is used for prefs which are enabled by default
function areInterfaceTimeseriesEnabled(ifid)
    return ((ntop.getPref("ntopng.prefs.interface_rrd_creation") ~= "0"))
end

-- ###########################################

-- Check If ASN Mode is enable
function isASNModeEnabled()
    local is_zmq_interface = toboolean(interface.isZMQInterface())

    return toboolean((ntop.getPref("ntopng.prefs.toggle_asn_mode") ~= "0") and (is_zmq_interface))
end

-- ###########################################

function areInterfaceL7TimeseriesEnabled(ifid)
    local l7proto_ts = ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation")
    return (areInterfaceTimeseriesEnabled(ifid) and
               (l7proto_ts ~= "per_category" and l7proto_ts ~= "none"))
end

-- ###########################################

function areInterfaceCategoriesTimeseriesEnabled(ifid)
    local rv = ntop.getPref("ntopng.prefs.interface_ndpi_timeseries_creation")

    -- note: categories are disabled by default
    return (areInterfaceTimeseriesEnabled(ifid) and
               ((rv == "per_category") or (rv == "both")))
end

-- ###########################################

function areHostTimeseriesEnabled()
    local rv = ntop.getPref("ntopng.prefs.hosts_ts_creation")
    if isEmptyString(rv) then rv = "light" end

    return ((rv == "light") or (rv == "full"))
end

-- ###########################################

function areHostL7TimeseriesEnabled(ifid)
    local rv = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")

    -- note: host protocols are disabled by default
    return ((ntop.getPref("ntopng.prefs.hosts_ts_creation") == "full") and
               ((rv == "per_protocol") or (rv == "both")))
end

-- ###########################################

function areHostCategoriesTimeseriesEnabled(ifid)
    local rv = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")

    -- note: host protocols are disabled by default
    return ((ntop.getPref("ntopng.prefs.hosts_ts_creation") == "full") and
               ((rv == "per_category") or (rv == "both")))
end

-- ###########################################

function areSystemTimeseriesEnabled()
    return (ntop.getPref("ntopng.prefs.system_probes_timeseries") ~= "0")
end

-- ###########################################

function areExportersTimeseriesPerApplicationEnabled()
    return ((ntop.getPref("ntopng.prefs.exporters_ndpi_ts_creation") or "") ==
               "per_protocol")
end

-- ###########################################

function areHostPoolsTimeseriesEnabled(ifid)
    return (ntop.isPro and ntop.isPro() and
               (ntop.getPref("ntopng.prefs.host_pools_rrd_creation") == "1"))
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

function areSnmpTimeseriesEnabled()
    return (ntop.getPref("ntopng.prefs.snmp_devices_rrd_creation") == "1")
end

-- ###########################################

function areFlowdevTimeseriesEnabled()
    return (ntop.getPref("ntopng.prefs.flow_device_port_rrd_creation") == "1")
end

-- ###########################################

function areSNMPExporterTimeseriesDisabled()
    return (ntop.getPref("ntopng.prefs.snmp_devices_exporters_rrd") == "0")
end

-- ###########################################

function highSNMPExporterTimeseriesResolution()
    local resolution = ntop.getPref("ntopng.prefs.snmp_devices_exporters_rrd")
    return (resolution == "60" or isEmptyString(resolution))
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
        __alert_enabled =
            (ntop.getPref("ntopng.prefs.disable_alerts_generation") ~= "1")
    end

    return (__alert_enabled)
end

-- ##########################################

function get5MinTSConfig()
    local config = {}

    config.host_ts_creation = ntop.getPref("ntopng.prefs.hosts_ts_creation")
    config.host_ndpi_timeseries_creation = ntop.getPref(
                                               "ntopng.prefs.host_ndpi_timeseries_creation")
    config.l2_device_rrd_creation = ntop.getPref(
                                        "ntopng.prefs.l2_device_rrd_creation")
    config.l2_device_ndpi_timeseries_creation = ntop.getPref(
                                                    "ntopng.prefs.l2_device_ndpi_timeseries_creation")
    config.flow_devices_rrd_creation = ntop.getPref(
                                           "ntopng.prefs.flow_device_port_rrd_creation")
    config.host_pools_rrd_creation = ntop.getPref(
                                         "ntopng.prefs.host_pools_rrd_creation")
    config.snmp_devices_rrd_creation = ntop.getPref(
                                           "ntopng.prefs.snmp_devices_rrd_creation")
    config.asn_rrd_creation = ntop.getPref("ntopng.prefs.asn_rrd_creation")
    config.obs_point_rrd_creation = ntop.getPref(
                                        "ntopng.prefs.observation_points_rrd_creation")
    config.country_rrd_creation = ntop.getPref(
                                      "ntopng.prefs.country_rrd_creation")
    config.os_rrd_creation = ntop.getPref("ntopng.prefs.os_rrd_creation")
    config.vlan_rrd_creation = ntop.getPref("ntopng.prefs.vlan_rrd_creation")
    config.ndpi_flows_timeseries_creation = ntop.getPref(
                                                "ntopng.prefs.ndpi_flows_rrd_creation")
    config.interface_ndpi_timeseries_creation = ntop.getPref(
                                                    "ntopng.prefs.interface_ndpi_timeseries_creation")

    -- ########################################################
    -- Populate some defaults
    if (tostring(config.flow_devices_rrd_creation) == "1" and
        ntop.isEnterpriseM and ntop.isEnterpriseM() == false) then
        config.flow_devices_rrd_creation = "0"
    end

    if (tostring(config.snmp_devices_rrd_creation) == "1" and
        not ((ntop.isEnterpriseM and ntop.isEnterpriseM()) or (ntop.isnEdgeEnterprise and ntop.isnEdgeEnterprise()))) then
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

-- This function returns true if the ndpi timeseries for the interface
-- are requested with bytes_sent and rcvd, otherwise returns false
function ifaceFullnDPITs()
    return (ntop.getPref("ntopng.prefs.split_ts_direction") == "rx_tx")
end

function getIfacenDPITsName()
    local full_ts = ifaceFullnDPITs()
    local id = 'iface:ndpi'
    if full_ts then id = 'iface:ndpi_full' end
    return id
end

-- ###########################################

function getMinTSConfig()
    local config = {}
    local prefs = ntop.getPrefs() -- runtime ntopng preferences

    config.interface_ndpi_timeseries_creation = ntop.getPref(
                                                    "ntopng.prefs.interface_ndpi_timeseries_creation")
    config.ndpi_flows_timeseries_creation = ntop.getPref(
                                                "ntopng.prefs.ndpi_flows_rrd_creation")
    config.internals_rrd_creation = ntop.getPref(
                                        "ntopng.prefs.internals_rrd_creation") ==
                                        "1"
    config.is_dump_flows_enabled = ntop.getPrefs()["is_dump_flows_enabled"]
    config.flow_devices_rrd_creation = ntop.getPref(
                                           "ntopng.prefs.flow_device_port_rrd_creation")
    config.interface_ndpi_timeseries_full = ifaceFullnDPITs()

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
    if throughput_type == "" then throughput_type = "bps" end

    return throughput_type
end

-- ##############################################

function hasClickHouseSupport()
    if not ntop.isClickHouseEnabled() then return false end

    local auth = require "auth"

    if not ((ntop.isPro and ntop.isPro()) or (ntop.isnEdgeEnterprise and ntop.isnEdgeEnterprise())) or ntop.isWindows() then
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

-- ##############################################

-- Added caching in order to not search in redis when
-- new multiple SNMP interfaces appear
local excluded = nil
function areNewInterfacesExcludedFromUsage()
    if excluded == nil then
        excluded = ntop.getCache(
                            "ntopng.prefs.toggle_snmp_excluded_from_usage")
        if not isEmptyString(excluded) and excluded == "1" then
            excluded = true
        else
            excluded = false
        end
    end
    return excluded
end

-- ##############################################

-- This function returns two parameters, the first one indicating
-- if the ntopng is an infrastructure_view or not, the second one, in case
-- the first one is true, returns the list of the viewed infrastructures
function isInfrastructureView()
    local infrastructure_view = false
    local infrastructure_instances = {}

    if ntop.isEnterpriseL and ntop.isEnterpriseL() then
        local infrastructure_utils = require("infrastructure_utils")
        for _, v in pairs(infrastructure_utils.get_all_instances()) do
            infrastructure_instances[v.id] = {name = v.alias, url = v.url}
        end
        local view = _GET["view"] or false

        infrastructure_view = (view and view == 'infrastructure' and
                                table.len(infrastructure_instances) > 0)
    end

    return infrastructure_view, infrastructure_instances
end

-- ##############################################

-- This preference checks all the conditions to enable the assets inventory;
-- Enterprise M license, preference enabled and not Windows
function assetsInventoryEnabled()
    local is_infrastructure = isInfrastructureView()
    if not (ntop.isEnterpriseM and ntop.isEnterpriseM()) then
        return false
    end
    if (ntop.isWindows()) then
        return false
    end
    if interface.isViewed() then
        return false
    end
    if is_infrastructure then
        return false
    end
    return ntop.assetsEnabled()
end
