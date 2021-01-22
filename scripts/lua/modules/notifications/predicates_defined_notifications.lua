--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local pools                     = require("pools")
local user_script_utils         = require("user_scripts")
local endpoint_configs          = require("notification_configs")
local recipients_manager        = require("recipients")
local page_utils                = require('page_utils')
local telemetry_utils           = require("telemetry_utils")
local notification_ui           = require("notification_ui")
local prefs_factory_reset_utils = require ("prefs_factory_reset_utils")

local info = ntop.getInfo()
local prefs = ntop.getPrefs()

local NotificationLevels = notification_ui.NotificationLevels

-- Constants
local ALARM_THRESHOLD_LOW = 60
local ALARM_THRESHOLD_HIGH = 90
local IS_ADMIN = isAdministrator()
local IS_SYSTEM_INTERFACE = page_utils.is_system_view()
local UNEXPECTED_PLUGINS_ENABLED_CACHE_KEY = "ntopng.cache.user_scripts.unexpected_plugins_enabled"

local predicates = {}

-- ###############################################################

local function create_DHCP_range_missing_notification(notification)

    local title = i18n("about.configure_dhcp_range")
    local description = i18n("about.dhcp_range_missing_warning", {
        name = i18n("prefs.toggle_host_tskey_title"),
        url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=config",
        dhcp_url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=dhcp"
    })

    return notification_ui:create(notification.id, title, description, NotificationLevels.WARNING, nil, notification.dismissable)

end

-- ###############################################################

local function create_DCHP_monitoring_notification(notification)

    local title = i18n("about.dhcp_monitoring_title")
    local description = i18n("about.host_identifier_warning", {
        name = i18n("prefs.toggle_host_tskey_title"),
        url = ntop.getHttpPrefix().."/lua/if_stats.lua?page=config"
    })

    return notification_ui:create(notification.id, title, description, NotificationLevels.WARNING, nil, notification.dismissable)

end

-- ###############################################################

local function create_geo_ip_notification_ui(notification)

    local title = i18n("geolocation_unavailable_title")
    local description = i18n("geolocation_unavailable", {
        url = "https://github.com/ntop/ntopng/blob/dev/doc/README.geolocation.md",
        target = "_blank",
        icon = "fas fa-external-link-alt"
    })

    return notification_ui:create(notification.id, title, description, NotificationLevels.WARNING, nil, notification.dismissable)
end

-- ###############################################################

local function create_contribute_notification_ui(notification)

    local title = i18n("about.contribute_to_project")
    local description = i18n("about.telemetry_data_opt_out_msg", {
        tel_url = ntop.getHttpPrefix() .. "/lua/telemetry.lua",
        ntop_org = "https://www.ntop.org/"
    })

    local action = {
        url = ntop.getHttpPrefix() .. '/lua/admin/prefs.lua?tab=telemetry',
        title = i18n("configure")
    }

    return notification_ui:create(notification.id, title, description, NotificationLevels.INFO, action, notification.dismissable)
end


-- ###############################################################

local function create_forced_community_notification(notification)

    local title = i18n("about.licence")
    local description = i18n("about.forced_community_notification")

    return notification_ui:create(notification.id, title, description, NotificationLevels.INFO, nil --[[ no action --]], notification.dismissable)
end

-- ###############################################################

local function create_tempdir_notification_ui(notification)

    local title = i18n("warning")
    local description = i18n("about.datadir_warning")
    local action = {
        url = "https://www.ntop.org/support/faq/migrate-the-data-directory-in-ntopng/",
        title = i18n("details.details")
    }

    return notification_ui:create(notification.id, title, description, NotificationLevels.WARNING, action, notification.dismissable)
end

-- ###############################################################

local function create_update_ntopng_notification(notification, body)

    local title = i18n("update")
    return notification_ui:create(notification.id, title, body, NotificationLevels.INFO, nil, notification.dismissable)
end

-- ###############################################################

local function create_too_many_flows_notification(notification, level)

    local title = i18n("too_many_flows")
    local desc = i18n("about.you_have_too_many_flows",
                      {product = info["product"]})

    return notification_ui:create(notification.id, title, desc, level, nil, notification.dismissable)
end

-- ###############################################################

local function create_too_many_hosts_notification(notification, level)

    local title = i18n("too_many_hosts")
    local desc = i18n("about.you_have_too_many_hosts",
                      {product = info["product"]})

    return notification_ui:create(notification.id, title, desc, level, nil, notification.dismissable)
end

-- ###############################################################

local function create_remote_probe_clock_drift_notification(notification, level)

    local title = i18n("remote_probe_clock_drift")
    local desc = i18n("about.you_need_to_sync_remote_probe_time",
                      {url = ntop.getHttpPrefix() .. "/lua/if_stats.lua"})

    return notification_ui:create(notification.id, title, desc, level, nil, notification.dismissable)
end

-- ##################################################################

local function create_flow_dump_notification_ui(notification)

    local title = i18n("flow_dump_not_working_title")
    local description = i18n("flow_dump_not_working", {
        icon = "fas fa-external-link-alt"
    })

    return notification_ui:create(notification.id, title, description, NotificationLevels.WARNING, nil, notification.dismissable)
end

-- ##################################################################

local function create_restart_required_notification(notification)

    local title = i18n("restart.restart_required")
    local description = i18n("manage_configurations.after_reset_request", {
        product = ntop.getInfo()["product"]
    })

    local action = nil
    -- only the ntop packed can be restarted
    if IS_ADMIN and ntop.isPackage() and not ntop.isWindows() then
        action = {
            title = i18n("restart.restart_now"),
            additional_classes = "restart-service",
            url = "#"
        }
    end

    return notification_ui:create(notification.id, title, description, NotificationLevels.DANGER, action, notification.dismissable)

end

-- ##################################################################

--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.restart_required(notification, container)

    if prefs_factory_reset_utils.is_prefs_factory_reset_requested() then
        table.insert(container, create_restart_required_notification(notification))
    end

end

--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.DHCP(notification, container)

    -- In System Interface we can't collect the required data
    if (IS_SYSTEM_INTERFACE) then return false end
    local ifs = interface.getStats()
    local is_pcap_dump = interface.isPcapDumpInterface()
    local is_packet_interface = interface.isPacketInterface()

    if (not(ifs.has_seen_dhcp_addresses and IS_ADMIN and (not is_pcap_dump) and is_packet_interface)) then
        return
    end

    local lbd_serialize_by_mac = (_POST["lbd_hosts_as_macs"] == "1") or
                                     (ntop.getPref(string.format("ntopng.prefs.ifid_%u.serialize_local_broadcast_hosts_as_macs",ifs.id)) == "1")

    if (not lbd_serialize_by_mac) and
        (ntop.getPref(string.format("ntopng.prefs.ifid_%u.disable_host_identifier_message", ifs.id)) ~= "1") then

        table.insertIfNotPresent(container, create_DCHP_monitoring_notification(notification), function(n) return n.id == notification.id end)

    elseif isEmptyString(_POST["dhcp_ranges"]) then

        local dhcp_utils = require("dhcp_utils")
        local ranges = dhcp_utils.listRanges(ifs.id)

        if (table.empty(ranges)) then
            table.insertIfNotPresent(container, create_DHCP_range_missing_notification(notification), function(n) return n.id == notification.id end)
        end
    end

end

--- Create an instance for the geoip alert notification
--- if the user doesn't have geoIP installed
--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.geo_ip(notification, container)
    if IS_ADMIN and not ntop.hasGeoIP() then
        table.insert(container, create_geo_ip_notification_ui(notification))
    end
end

--- Create an instance for the temp working directory alert
--- if ntopng is running inside /var/tmp
--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.temp_working_dir(notification, container)
    if (dirs.workingdir == "/var/tmp/ntopng") then
        table.insert(container, create_tempdir_notification_ui(notification))
    end
end

--- Create an instance for contribute alert notification
--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.contribute(notification, container)
    if (not info.oem) and (not telemetry_utils.dismiss_notice()) then
        table.insert(container, create_contribute_notification_ui(notification))
    end
end

--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.update_ntopng(notification, container)
    -- check if ntopng is oem and the user is an Administrator
    local is_not_oem_and_administrator = IS_ADMIN and not info.oem
    local message = check_latest_major_release()

    if is_not_oem_and_administrator and not isEmptyString(message) then
        table.insert(container, create_update_ntopng_notification(notification, message))
    end
end

--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.too_many_hosts(notification, container)

    -- In System Interface we can't get the hosts number from `interface.getNumHosts()`
    if (IS_SYSTEM_INTERFACE) then return end

    local level = nil
    local hosts = interface.getNumHosts()
    local hosts_pctg = math.floor(1 + ((hosts * 100) / prefs.max_num_hosts))

    if (hosts_pctg >= ALARM_THRESHOLD_LOW and hosts_pctg <= ALARM_THRESHOLD_HIGH) then
        level = NotificationLevels.WARNING
    elseif (hosts_pctg > ALARM_THRESHOLD_HIGH) then
        level = NotificationLevels.DANGER
    end

    if (level ~= nil) then
        table.insert(container, create_too_many_hosts_notification(notification, level))
    end
end

--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.too_many_flows(notification, container)

    -- In System Interface we can't get the flows number from `interface.getNumFlows()`
    if (IS_SYSTEM_INTERFACE) then return end

    local level = nil
    local flows = interface.getNumFlows()
    local flows_pctg = math.floor(1 + ((flows * 100) / prefs.max_num_flows))

    if (flows_pctg >= ALARM_THRESHOLD_LOW and flows_pctg <= ALARM_THRESHOLD_HIGH) then
        level = NotificationLevels.WARNING
    elseif (flows_pctg > ALARM_THRESHOLD_HIGH) then
        level = NotificationLevels.DANGER
    end

    if (level ~= nil) then
        table.insert(container, create_too_many_flows_notification(notification, level))
    end
end

--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.remote_probe_clock_drift(notification, container)

    -- In System Interface we can't collect the stats from `interface.getStats()`
    if (IS_SYSTEM_INTERFACE) then return end

    local ifstats = interface.getStats()

    if ifstats["probe.remote_time"] ~= nil and 
       ifstats["probe.local_time"] ~= nil then

        local tdiff = math.abs(ifstats["probe.local_time"] - ifstats["probe.remote_time"])
        local level = nil

        if (tdiff >= 10 and tdiff <= 30) then
            level = NotificationLevels.WARNING
        elseif (tdiff > 30) then
            level = NotificationLevels.DANGER
        end

        if (level ~= nil) then
            table.insert(container, create_remote_probe_clock_drift_notification(notification, level))
        end
    end
end

--- Create an instance for the nIndex alert notification
--- if nIndex is not able to start/run/dump
--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.flow_dump(notification, container)

    -- In System Interface we can't collect the stats from `interface.getStats()`
    if (IS_SYSTEM_INTERFACE) then return end

    local ifstats = interface.getStats()

    if IS_ADMIN and prefs.is_dump_flows_enabled and
        prefs.is_dump_flows_runtime_enabled and not ifstats.isFlowDumpDisabled and
        not ifstats.isFlowDumpRunning and not ifstats.isViewed then

        table.insert(container, create_flow_dump_notification_ui(notification))
    end
end

--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.about_page(notification, container)

    if (_POST["ntopng_license"] ~= nil) then

        ntop.setCache('ntopng.license', trimSpace(_POST["ntopng_license"]))
        ntop.checkLicense()
        ntop.setCache('ntopng.cache.force_reload_plugins', '1') -- housekeeping.lua will reload plugins

        info = ntop.getInfo()

        if (info["version.enterprise_l_edition"] and info["pro.license"] ~= "") then
           table.insert(container,
            notification_ui:create(notification.id, i18n("info"), i18n("about.create_license_l"), NotificationLevels.INFO, {
                url = "https://www.ntop.org/support/faq/what-is-included-in-ntopng-enterprise-l/",
                title = i18n("details.details")
            })
        )
        elseif (not info["version.enterprise_l_edition"] and info["pro.license"] ~= "") then
           table.insert(container, notification_ui:create(notification.id, i18n("info"), i18n("about.create_license"), NotificationLevels.INFO))
        end

     end
end

--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.hosts_geomap(notification, container)

    local hosts_stats = interface.getHostsInfo()
    local num = hosts_stats["numHosts"]
    if (num > 0) then
        table.insert(container,
            notification_ui:create(notification.id, i18n("warning"), i18n("geo_map.warning_accuracy"), NotificationLevels.WARNING, nil, notification.dismissable)
        )
    end
end

--- This is a simple placeholder for new notifications
--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.empty(notification, container)
    -- do nothing!
end

--- Generate two notifications if the SNMP ratio is not available for exporters
--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.exporters_SNMP_ratio_column(notification, container)

    if not ntop.isPro() then return end

    local snmp_utils = require "snmp_utils"
    local snmp_cached_dev = require "snmp_cached_dev"

    local flow_device_ip = _GET["ip"]
    if (isEmptyString(flow_device_ip)) then return end

    local cached_device = snmp_cached_dev:create(flow_device_ip)

    local is_ratio_available = snmp_utils.is_snmp_ratio_available(cached_device)

    if (is_ratio_available) then return end

    local title = i18n("flow_devices.enable_flow_ratio")
    local body
    local action = nil

    -- Did the user add the device to the SNMP overview page?
    local device_exists = not(cached_device == nil)
    -- Are SNMP Timeseries enabled?
    local snmp_dev_creation = ntop.getPref("ntopng.prefs.snmp_devices_rrd_creation") == "1"
    -- Are Flow Devices Timseries enabled?
    local flow_dev_creation = ntop.getPref("ntopng.prefs.flow_device_port_rrd_creation") == "1"

    if not device_exists then
        -- Build the message to show
        local message_snmp = i18n("flow_devices.flow_ratio_snmp_instructions", {
            href = ntop.getHttpPrefix() .. "/lua/pro/enterprise/snmpdevices_stats.lua"
        })

        body = message_snmp

    elseif not flow_dev_creation or not snmp_dev_creation then
       -- Build the message to show
       local message_timeseries = i18n("flow_devices.flow_ratio_timeseries_instructions")

        body = message_timeseries
        action = {
            url = '#',
            title = i18n("enable_them"),
        }
   end

    if body then
       table.insert(container, notification_ui:create(notification.id, title, body, NotificationLevels.INFO, action, notification.dismissable))
    end

end

-- ###############################################

--- Create an instance for forced community notification
--- @param notification table The notification is the logic model defined in defined_notifications
--- @param container table Is the table where to put the new notification ui
function predicates.forced_community(notification, container)
   if(ntop.getInfo()["pro.forced_community"] and ntop.exists("/etc/ntopng.license")) then
        table.insert(container, create_forced_community_notification(notification))
    end
end

-- ###############################################

--- Did the user create an non builtin endpoint?
local function user_has_created_endpoint()
    return ntop.getCache(endpoint_configs.FIRST_ENDPOINT_CREATED_CACHE_KEY) == "1"
end

--- Did the user create a recipient?
local function user_has_created_recipient()
    return ntop.getCache(recipients_manager.FIRST_RECIPIENT_CREATED_CACHE_KEY) == "1"
end

--- Did the user bind a recipient to a pool?
local function user_has_bound_recipient()
    return ntop.getCache(pools.FIRST_RECIPIENT_BOUND_CACHE_KEY) == "1"
end

--- Generate a notification to adive the user about notification endpoints
function predicates.create_endpoint(notification, container)

    if (not IS_ADMIN) then return end
    if (user_has_created_endpoint()) then return end

    local title = i18n("endpoint_notifications.hints.create_endpoint.title")
    local body = i18n("endpoint_notifications.hints.create_endpoint.body", {
        link = "https://www.ntop.org/guides/ntopng/plugins/alert_endpoints.html"
    })
    local action = {
        title = i18n("endpoint_notifications.hints.create_endpoint.action"),
        url = ntop.getHttpPrefix() .. "/lua/admin/endpoint_notifications_list.lua"
    }

    local hint = notification_ui:create(notification.id, title, body, NotificationLevels.INFO, action, notification.dismissable)

    table.insert(container, hint)

end

-- Generate a second notification to inform the user to create a recipient for the new endpoint
function predicates.create_recipients_for_endpoint(notification, container)

    if (not IS_ADMIN) then return end

    -- Did the user created a new endpoint? If not then return
    if (not user_has_created_endpoint()) then return end
    -- Did the user created the new recipient? If yes then return
    if (user_has_created_recipient()) then return end

    local title = i18n("endpoint_notifications.hints.create_recipients.title")
    local body = i18n("endpoint_notifications.hints.create_recipients.body", {
        link = "https://www.ntop.org/guides/ntopng/plugins/alert_endpoints.html"
    })
    local action = {
        url = ntop.getHttpPrefix() .. "/lua/admin/recipients_list.lua",
        title = i18n("create")
    }

    local hint = notification_ui:create(notification.id, title, body, NotificationLevels.INFO, action, notification.dismissable)
    table.insert(container, hint)
end

--- Generate a third notificiation to inform the user to bind the new recipients to a pool
function predicates.bind_recipient_to_pools(notification, container)

    if (not IS_ADMIN) then return end
    if (not user_has_created_endpoint()) then return end
    if (not user_has_created_recipient()) then return end
    if (user_has_bound_recipient()) then return end

    local title = i18n("endpoint_notifications.hints.bind_pools.title")
    local body = i18n("endpoint_notifications.hints.bind_pools.body")
    local action = {
        url = ntop.getHttpPrefix() .. "/lua/admin/manage_pools.lua",
        title = i18n("bind")
    }

    local hint = notification_ui:create(notification.id, title, body, NotificationLevels.INFO, action, notification.dismissable)
    table.insert(container, hint)

end

--- Check if unexpected plugins are disabled and notifiy the user
--- about their existance
function predicates.unexpected_plugins(notification, container)

    if (not IS_ADMIN) then return end
    if not isEmptyString(ntop.getCache(UNEXPECTED_PLUGINS_ENABLED_CACHE_KEY)) then return end

    local url = ntop.getHttpPrefix() .. "/lua/admin/edit_configset.lua?confset_id=0&subdir=flow&search_script=unexpected#disabled"

    -- TODO: missing documentation links
    local title = i18n("user_scripts.hint.title")
    local body = i18n("user_scripts.hint.body", {
        link_DHCP = "https://ntop.org",
        link_SMTP = "https://ntop.org",
        link_DNS = "https://ntop.org",
        link_NTP = "https://ntop.org",
        product = info["product"]
    })
    local action = { url = url, title = i18n("configure")}

    local hint = notification_ui:create(notification.id, title, body, NotificationLevels.INFO, action, notification.dismissable)
    table.insert(container, hint)
end

-- ###############################################

return predicates
