--
-- (C) 2013-26 - ntop.org
--
--
-- This script is executed once at startup similar to /etc/rc.local on Unix
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" ..
                   package.path
package.path = dirs.installdir ..
                   "/scripts/lua/modules/active_scan/?.lua;" ..
                   package.path

-- Important: load this before any other alert related module
require "prefs_utils"
local checks = require "checks"
local radius_handler = require "radius_handler"
checks.loadChecks()

local recipients = require "recipients"
recipients.initialize()

local alert_utils = require "alert_utils"
local discover_utils = require "discover_utils"
local host_pools_nedge = require "host_pools_nedge"
local os_utils = require "os_utils"
local lists_utils = require "lists_utils"
local recovery_utils = require "recovery_utils"
local delete_data_utils = require "delete_data_utils"
local ts_utils = require "ts_utils"
local presets_utils = require "presets_utils"
local blog_utils = require("blog_utils")
local ascan_utils = require "ascan_utils"
local drop_host_pool_utils = require "drop_host_pool_utils"
local json = require "dkjson"
local cache_utils = require "cache_utils"
local demo_utils = require "demo_utils"

-- ##################################################################

traceError(TRACE_NORMAL, TRACE_CONSOLE,
           "Processing startup.lua: please hold on...")

if ntop.isPro and ntop.isPro() then
    package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" ..
                       package.path
    require("startup")
end

-- ##################################################################

local function migrate_script_config(conf, proto_name)
    local config = conf.config.flow["unexpected_" .. proto_name]
    local ret = false

    if (config ~= nil) then
        if (config.all.enabled) then
            local value = config.all.script_conf.items

            if (value ~= nil) then
                -- tprint(value)
                local new_key = "ntopng.prefs.nw_config_" .. proto_name ..
                                    "_list"
                local new_value = ""

                for k, v in pairs(value) do
                    if (k == 1) then
                        new_value = v
                    else
                        new_value = new_value .. "," .. v
                    end
                end

                if (new_value ~= "") then
                    --  tprint(new_key.." = "..new_value)
                    ntop.setCache("ntopng.prefs.nw_config_" .. proto_name ..
                                      "_list", new_value)
                    ret = true
                end

                config.all.script_conf.items = nil -- remove value from config
            end
        end
    end

    return ret
end

local function migrate_unexpected_proto_config()
    local key = "ntopng.prefs.checks.configset_v1"
    local conf = json.decode(ntop.getCache(key))
    local modified
    local rc = false

    rc = rc or migrate_script_config(conf, "dns")
    rc = rc or migrate_script_config(conf, "ntp")
    rc = rc or migrate_script_config(conf, "dhcp")
    rc = rc or migrate_script_config(conf, "smtp")

    if (rc == true) then
        -- something has been migrated
        ntop.setCache(key, json.encode(conf))
    end
end

-- ##################################################################

if ntop.isAppliance() then
    package.path = dirs.installdir ..
                       "/scripts/lua/modules/system_config/?.lua;" ..
                       package.path

    -- Discard any pending, unfinished, unsaved configuration
    local appliance_config = require("appliance_config"):create(true):discard()

    -- Load the actual valid configuration
    appliance_config = require("appliance_config"):create(false)

    -- Apply some config prefs
    local vlan_trunk = appliance_config:isBridgeOverVLANTrunkEnabled()
    ntop.setPref("ntopng.prefs.enable_vlan_trunk_bridge",
                 ternary(vlan_trunk, "1", "0"))

    -- Load possibly changed prefs
    ntop.reloadPreferences()
end

if ntop.isnEdge and ntop.isnEdge() then
    host_pools_nedge.initPools()
    radius_handler.deleteAllKeys()
end

if (ntop.isPro and ntop.isPro()) then
    shaper_utils = require "shaper_utils"
    shaper_utils.initShapers()
end

-- ##################################################################

local has_pcap_dump_interface = false

local function cleanupIfname(ifname, ifid)
    interface.select(ifname)
    local ifid = getInterfaceId(ifname)

    if interface.isPcapDumpInterface() then has_pcap_dump_interface = true end

    local alerts_status_path = os_utils.fixPath(
                                   dirs.workingdir .. "/" .. ifid .. "/json/")
    ntop.rmdir(alerts_status_path)

    -- Remove network discovery request on startup
    discover_utils.clearNetworkDiscovery(ifid)

    -- Clean old InfluxDB export cache
    local export_dir = os_utils.fixPath(dirs.workingdir .. "/" .. ifid ..
                                            "/ts_export")
    ntop.rmdir(export_dir)

    -- Clean redis queue used to push host filters to pfring
    ntop.delCache("pfring." .. ifname .. ".filter.host.queue")

    -- Check the preference if the interface is mirrored or not
    -- In case it is, force the serialization key to IP
    local is_mirrored_traffic = false
    if not (ntop.isnEdge and ntop.isnEdge()) and is_packet_interface then
        local is_mirrored_traffic_pref = string.format(
                                             "ntopng.prefs.ifid_%d.is_traffic_mirrored",
                                             interface.getId())
        is_mirrored_traffic = ternary(ntop.getPref(is_mirrored_traffic_pref) ==
                                          '1', true, false)
    end

    -- If it's mirrored or if it's a ZMQ Interface, force the serialization key to IP
    if is_mirrored_traffic or interface.isZMQInterface() then
        local serialize_by_mac_key = string.format(
                                        "ntopng.prefs.ifid_%u.serialize_local_broadcast_hosts_as_macs",
                                        interface.getId())
        -- In case of mirrored traffic, force the key to IP
        ntop.setPref(serialize_by_mac_key, false)
        interface.updateLbdIdentifier()
    end
end

-- Remove the json dumps previously needed for alerts generation
for ifid, ifname in pairs(interface.getIfNames()) do cleanupIfname(ifname, ifid) end

cleanupIfname(getSystemInterfaceName(), getSystemInterfaceId())

-- Also flush the export queue
ntop.delCache("ntopng.influx_file_queue")

-- Also flush the alert queue
ntop.delCache("ntopng.trace_error.alert_queue")

-- ##################################################################

local recording_utils = require "recording_utils"
recording_utils.checkAvailable()

-- ##################################################################

local companion_interface_utils = require "companion_interface_utils"
companion_interface_utils.initCompanions()

-- ##################################################################

lists_utils.startup()

-- ##################################################################

traceError(TRACE_NORMAL, TRACE_CONSOLE, "Initializing device polices...")

-- Initialize device policies (presets)
-- NOTE: Must go after lists_utils initialization and reload
-- as new custom protocols can be set by lists utils
presets_utils.init()
presets_utils.reloadAllDevicePolicies()

-- TODO: migrate custom re-arm settings

-- this will retrieve host pools and policers configurtions via HTTP if enabled
if ntop.isnEdge and ntop.isnEdge() then
    local http_bridge_conf_utils = require "http_bridge_conf_utils"
    http_bridge_conf_utils.configureBridge()
end

traceError(TRACE_NORMAL, TRACE_CONSOLE, "Initializing alerts...")
alert_utils.notify_ntopng_start()

if not recovery_utils.check_clean_shutdown() then
    package.path = dirs.installdir .. "/scripts/callbacks/system/?.lua;" ..
                       package.path
end

recovery_utils.unmark_clean_shutdown()

traceError(TRACE_NORMAL, TRACE_CONSOLE, "Initializing timeseries...")
-- Need to run setup at startup since the schemas may be changed
ts_utils.setupAgain()

-- Migrate "iface:ndpi_categories" under the correct folder
if (ntop.getCache("ntopng.cache.rrd_category_migration") ~= "1") then
    for ifid, ifname in pairs(delete_data_utils.list_all_interfaces()) do
        ntop.mkdir(dirs.workingdir .. "/" .. ifid .. "/rrd/ndpi_categories")

        for cat_name, cat_id in pairs(interface.getnDPICategories()) do
            local old_path = os_utils.fixPath(
                                 dirs.workingdir .. "/" .. ifid .. "/rrd/" ..
                                     cat_name .. ".rrd")

            if ntop.exists(old_path) then
                local new_path = os_utils.fixPath(
                                     dirs.workingdir .. "/" .. ifid ..
                                         "/rrd/ndpi_categories/" .. cat_name ..
                                         ".rrd")

                traceError(TRACE_INFO, TRACE_CONSOLE,
                           "Migrating Category RRD: " .. old_path)
                os.rename(old_path, new_path)
            end
        end
    end

    -- do not perform migration again
    ntop.setCache("ntopng.cache.rrd_category_migration", "1")
end

-- Clear the unused DHCP cache keys
for ifid, ifname in pairs(delete_data_utils.list_all_interfaces()) do
    ntop.delCache("ntopng.dhcp." .. ifid .. ".cache")
end

-- Remove notification cache
local notifications = ntop.getKeysCache("ntopng.cache.alerts.notification.*") or
                          {}
for k, _ in pairs(notifications) do ntop.delCache(k) end

if (has_pcap_dump_interface) then
    -- Load the lists at the very beginning in order to avoid misclassification
    -- when reading from PCAP dump. This can take some time.
    traceError(TRACE_NORMAL, TRACE_CONSOLE, "Loading category lists...")
    lists_utils.checkReloadLists()
    traceError(TRACE_NORMAL, TRACE_CONSOLE, "Loading category lists done")
end

-- Show the warning at most 1 time per run
ntop.delCache("ntopng.cache.rrd_format_change_warning_shown")

-- Check if there is a local file to run
local local_startup_file =
    "/usr/share/ntopng/local/scripts/callbacks/system/startup.lua"
if (ntop.exists(local_startup_file)) then
    traceError(TRACE_NORMAL, TRACE_CONSOLE, "Running " .. local_startup_file)
    dofile(local_startup_file)
end

if (ntop.isPro and ntop.isPro()) then
    -- In case of the alert enabled, clean the list of all the elements
    drop_host_pool_utils.clean_list()
end

-- Fetch latest ntop blog posts
if not (ntop.isnEdge and ntop.isnEdge()) then
    -- Note: On nEdge they are fetched in a dayly/delayed callback as connectivity
    -- may be not yet up at this stage
    blog_utils.fetchLatestPosts()
end
if ntop.isnEdge and ntop.isnEdge() then
    interface.select(tostring(interface.getFirstInterfaceId()))
    host_pools_nedge.startupCheckResetPoolsQuotas()
    interface.select(getSystemInterfaceId())
end

-- Cleanup old influxdb files (if any)
local influxdb_dir = dirs.workingdir .. "/tmp/influxdb"
if (ntop.exists(influxdb_dir)) then
    local files = ntop.readdir(influxdb_dir)

    if (files ~= nil) then
        for _, name in pairs(files) do
            if (ends(name, ".tmp") == true) then
                local fname = influxdb_dir .. "/" .. name

                -- io.write("[InfluxDB] Deleting file "..fname.."\n")
                ntop.unlink(fname)
            end
        end
    end
end

-- Vulnerability scan activities
ascan_utils.migrate_keys()
ascan_utils.restore_host_to_scan()

-- migrate unexpected dns/ntp/dhcp/smtp scripts to /lua/admin/network_configuration.lua
migrate_unexpected_proto_config()

-- Reload Alert Exclusions
ntop.reloadAlertExclusions()

-- Removing limits exceeded key, it's used just for the badges in the gui
ntop.delCache("ntopng.limits.exporters")

-- Handle full ClickHouse purge, right after interfaces have been initialized
-- and thus ClickHouse connection established, but before tables are populated.
if delete_data_utils.purge_all_clickhouse_data_requested() then
    traceError(TRACE_NORMAL, TRACE_CONSOLE, "Purging all ClickHouse data...")

    delete_data_utils.purge_all_clickhouse_data()
    delete_data_utils.clear_purge_all_clickhouse_data_request()

    traceError(TRACE_NORMAL, TRACE_CONSOLE, "ClickHouse purge done.")
end

-- initialization of mitre attack matrix informations
local mitre_utils = require "mitre_utils"
local mitre_table = mitre_utils.insertDBMitreInfo()

-- initialize the nDPI protocol lookup table used by ClickHouse / Grafana queries
local ndpi_utils = require "ndpi_utils"
ndpi_utils.insertDBProtocols()

ntop.reloadServersConfiguration()
ntop.reloadASNConfiguration()
ts_utils.runFirstSetup()

cache_utils.initialize()

-- Seed demo tour progress for existing users so a demo added by an update
-- shows on next login instead of never triggering for pre-existing accounts
demo_utils.seed_missing_progress()

ntop.startPollingBGPPrefixChanges()

traceError(TRACE_NORMAL, TRACE_CONSOLE, "Completed startup.lua")
