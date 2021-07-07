--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local pools                     = require("pools")
local check_utils         = require("checks")
local endpoint_configs          = require("endpoints")
local recipients_manager        = require("recipients")
local page_utils                = require('page_utils')
local telemetry_utils           = require("telemetry_utils")
local toast_ui                  = require("toast_ui")
local stats_utils               = require("stats_utils")
local delete_data_utils         = require("delete_data_utils")
local prefs_factory_reset_utils = require("prefs_factory_reset_utils")
local configuration_utils       = require "configuration_utils"

local info = ntop.getInfo()
local prefs = ntop.getPrefs()

local ToastLevel = toast_ui.ToastLevels

-- Constants
local ALARM_THRESHOLD_LOW = 60
local ALARM_THRESHOLD_HIGH = 90
local IS_ADMIN = isAdministrator()
local IS_SYSTEM_INTERFACE = page_utils.is_system_view()
local IS_PCAP_DUMP = interface.isPcapDumpInterface()
local IS_PACKET_INTERFACE = interface.isPacketInterface()
local UNEXPECTED_PLUGINS_ENABLED_CACHE_KEY = "ntopng.cache.checks.unexpected_plugins_enabled"

local predicates = {}

-- ###############################################################

local function create_DHCP_range_missing_notification(toast)
    local title = i18n("about.configure_dhcp_range")
    local description = i18n("about.dhcp_range_missing_warning", {
        name = i18n("prefs.toggle_host_tskey_title"),
        url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=config",
        dhcp_url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=dhcp"
    })

    return toast_ui:new(toast.id, title, description, ToastLevel.WARNING, nil, toast.dismissable)

end

-- ###############################################################

local function create_DCHP_monitoring_toast(toast)
    local title = i18n("about.dhcp_monitoring_title")
    local description = i18n("about.host_identifier_warning", {
        name = i18n("prefs.toggle_host_tskey_title"),
        url = ntop.getHttpPrefix().."/lua/if_stats.lua?page=config"
    })

    local action = {
       url = ntop.getHttpPrefix().."/lua/if_stats.lua?page=config",
       title = i18n("configure")
    }

    return toast_ui:new(toast.id, title, description, ToastLevel.WARNING, action, toast.dismissable)
end

-- ###############################################################

local function create_DHCP_range_missing_toast(toast)
    local title = i18n("about.dhcp_monitoring_title")
    local description = i18n("about.dhcp_range_missing_warning", {
        name = i18n("prefs.toggle_host_tskey_title"),
        url = ntop.getHttpPrefix().."/lua/if_stats.lua?page=config",
        dhcp_url = ntop.getHttpPrefix().."/lua/if_stats.lua?page=dhcp"
    })

    local action = {
       url = ntop.getHttpPrefix().."/lua/if_stats.lua?page=dhcp",
       title = i18n("configure")
    }

    return toast_ui:new(toast.id, title, description, ToastLevel.WARNING, action, toast.dismissable)

end

-- ###############################################################

local function create_geo_ip_toast_ui(toast)
    local title = i18n("geolocation_unavailable_title")
    local description = i18n("geolocation_unavailable", {
        url = "https://github.com/ntop/ntopng/blob/dev/doc/README.geolocation.md",
        target = "_blank",
        icon = "fas fa-external-link-alt"
    })

    return toast_ui:new(toast.id, title, description, ToastLevel.WARNING, nil, toast.dismissable)
end

-- ###############################################################

local function create_contribute_toast_ui(toast)
    local title = i18n("about.contribute_to_project")
    local description = i18n("about.telemetry_data_opt_out_msg", {
        tel_url = ntop.getHttpPrefix() .. "/lua/telemetry.lua",
        ntop_org = "https://www.ntop.org/"
    })

    local action = {
        url = ntop.getHttpPrefix() .. '/lua/admin/prefs.lua?tab=telemetry',
        title = i18n("configure")
    }

    return toast_ui:new(toast.id, title, description, ToastLevel.INFO, action, toast.dismissable)
end


-- ###############################################################

local function create_forced_community_toast(toast)
    local title = i18n("about.licence")
    local description = i18n("about.forced_community_notification")

    return toast_ui:new(toast.id, title, description, ToastLevel.WARNING, nil --[[ no action --]], toast.dismissable)
end

-- ###############################################################

local function create_tempdir_toast_ui(toast)
    local title = i18n("warning")
    local description = i18n("about.datadir_warning")
    local action = {
        url = "https://www.ntop.org/support/faq/migrate-the-data-directory-in-ntopng/",
        title = i18n("details.details"),
    }

    return toast_ui:new(toast.id, title, description, ToastLevel.WARNING, action, toast.dismissable)
end

-- ###############################################################

local function create_update_ntopng_toast(toast, body)

    local title = i18n("update")
    return toast_ui:new(toast.id, title, body, ToastLevel.INFO, nil, toast.dismissable)
end

-- ###############################################################

local function create_too_many_flows_toast(toast, level)
    local info = ntop.getInfo()
    local title = i18n("too_many_flows")
    local desc = i18n("about.you_have_too_many_flows",
                      {product = info["product"]})

    local action = {
        url = "#",
        additional_classes = "toast-config-change-flows",
        title = i18n("alert_messages.too_many_flows_title"),
        js = "toast-config-change-flows.js",
        dialog = {
            id = 'toast-config-change-modal-flows',
            action = 'toastConfigFlowChanges()',
            title = i18n("too_many_flows"),
	    err_msg = i18n("alert_messages.too_many_flows_err"),
            message = i18n("alert_messages.too_many_flows_details"),
            custom_alert_class = 'alert alert-danger',
            confirm = i18n('double_num_flows_hosts'),
            confirm_button = 'btn-danger'
        }
    }

    return toast_ui:new(toast.id, title, desc, level, action, toast.dismissable)
end

-- ###############################################################

local function create_too_many_hosts_toast(toast, level)
    local info = ntop.getInfo()
    local title = i18n("too_many_hosts")
    local desc = i18n("about.you_have_too_many_hosts",
                      {product = info["product"]})
    local action = {
       url = "#",
       additional_classes = "toast-config-change-hosts",
       title = i18n("alert_messages.too_many_hosts_title"),
       js = "toast-config-change-hosts.js",
       dialog = {
        id = 'toast-config-change-modal-hosts',
        action = 'toastConfigHostChanges()',
        title = i18n("too_many_hosts"),
	err_msg = i18n("alert_messages.too_many_hosts_err"),
        message = i18n("alert_messages.too_many_hosts_details"),
        custom_alert_class = 'alert alert-danger',
        confirm = i18n('double_num_flows_hosts'),
        confirm_button = 'btn-danger'
       }
    }

    return toast_ui:new(toast.id, title, desc, level, action, toast.dismissable)
end

-- ###############################################################

local function create_remote_probe_clock_drift_toast(toast, level)
    local title = i18n("remote_probe_clock_drift")
    local desc = i18n("about.you_need_to_sync_remote_probe_time",
                      {url = ntop.getHttpPrefix() .. "/lua/if_stats.lua"})

    return toast_ui:new(toast.id, title, desc, level, nil, toast.dismissable)
end

-- ##################################################################

local function create_flow_dump_toast_ui(toast)
    local title = i18n("flow_dump_not_working_title")
    local description = i18n("flow_dump_not_working", {
        icon = "fas fa-external-link-alt"
    })

    return toast_ui:new(toast.id, title, description, ToastLevel.WARNING, nil, toast.dismissable)
end

-- ##################################################################

--- 
local function create_restart_required_toast(toast, description)
    local title = i18n("restart.restart_required")
    local action = nil
    -- only the ntop packed can be restarted
    if IS_ADMIN and ntop.isPackage() and not ntop.isWindows() then
        action = {
            title = i18n("restart.restart_now"),
            additional_classes = "restart-service",
            url = "#"
        }
    end

    return toast_ui:new(toast.id, title, description, ToastLevel.DANGER, action, toast.dismissable)

end

-- ##################################################################

--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.restart_required(toast, container)
   if not IS_ADMIN or not ntop.isPackage() or ntop.isWindows() then return end

    -- ifname is defined globally
    local delete_active_interface_requested = delete_data_utils.delete_active_interface_data_requested(ifname)
    if delete_active_interface_requested then
        table.insert(container, create_restart_required_toast(toast, i18n("delete_data.restart_product_toast", {
            product = ntop.getInfo()["product"]
        })))
    end
    if prefs_factory_reset_utils.is_prefs_factory_reset_requested() then
        table.insert(container, create_restart_required_toast(toast, i18n("manage_configurations.after_reset_request", {
            product = ntop.getInfo()["product"]
        })))
    end
    if configuration_utils.restart_required() then
        table.insert(container, create_restart_required_toast(toast, i18n("manage_configurations.after_reset_request", {
            product = ntop.getInfo()["product"]
        })))
    end

end

--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.DHCP(toast, container)
    if not IS_ADMIN then return end

    -- In System Interface we can't collect the required data
    if (IS_SYSTEM_INTERFACE) then return false end

    local ifs = interface.getStats()

    if (not(ifs.has_seen_dhcp_addresses and IS_ADMIN and (not IS_PCAP_DUMP) and IS_PACKET_INTERFACE)) then
        return
    end

    local lbd_serialize_by_mac = (_POST["lbd_hosts_as_macs"] == "1") or
       (ntop.getPref(string.format("ntopng.prefs.ifid_%u.serialize_local_broadcast_hosts_as_macs",ifs.id)) == "1")

    if (not lbd_serialize_by_mac) and
        (ntop.getPref(string.format("ntopng.prefs.ifid_%u.disable_host_identifier_message", ifs.id)) ~= "1") then

        table.insertIfNotPresent(container, create_DCHP_monitoring_toast(toast), function(n) return n.id == toast.id end)

    elseif isEmptyString(_POST["dhcp_ranges"]) then

        local dhcp_utils = require("dhcp_utils")
        local ranges = dhcp_utils.listRanges(ifs.id)

        if (table.empty(ranges)) then
            table.insertIfNotPresent(container, create_DHCP_range_missing_toast(toast), function(n) return n.id == toast.id end)
        end
    end

end

--- Create an instance for the geoip alert toast
--- if the user doesn't have geoIP installed
--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.geo_ip(toast, container)
    if IS_ADMIN and not ntop.hasGeoIP() then
        table.insert(container, create_geo_ip_toast_ui(toast))
    end
end

--- Create an instance for the temp working directory alert
--- if ntopng is running inside /var/tmp
--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.temp_working_dir(toast, container)
   if not IS_ADMIN or ntop.isWindows() then return end

    if (dirs.workingdir == "/var/tmp/ntopng") then
        table.insert(container, create_tempdir_toast_ui(toast))
    end
end

--- Create an instance for contribute alert toast
--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.contribute(toast, container)
    if not IS_ADMIN then return end

    if (not info.oem) and (not telemetry_utils.dismiss_notice()) then
        table.insert(container, create_contribute_toast_ui(toast))
    end
end

--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.update_ntopng(toast, container)
   if not IS_ADMIN or not ntop.isPackage() or ntop.isWindows() then return end

    -- check if ntopng is oem and the user is an Administrator
    local is_not_oem_and_administrator = IS_ADMIN and not info.oem
    local message = check_latest_major_release()

    if is_not_oem_and_administrator and not isEmptyString(message) then
        table.insert(container, create_update_ntopng_toast(toast, message))
    end
end

--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.too_many_hosts(toast, container)
   if not IS_ADMIN or not ntop.isPackage() or ntop.isWindows() then return end

    -- In System Interface we can't get the hosts number from `interface.getNumHosts()`
    if (IS_SYSTEM_INTERFACE) then return end

    local level = nil
    local hosts = interface.getNumHosts()
    local hosts_pctg = math.floor(1 + ((hosts * 100) / prefs.max_num_hosts))

    if (hosts_pctg >= ALARM_THRESHOLD_LOW and hosts_pctg <= ALARM_THRESHOLD_HIGH) then
        level = ToastLevel.WARNING
    elseif (hosts_pctg > ALARM_THRESHOLD_HIGH) then
        level = ToastLevel.DANGER
    end

    if (level ~= nil) then
        table.insert(container, create_too_many_hosts_toast(toast, level))
    end
end

--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.too_many_flows(toast, container)
   if not IS_ADMIN or not ntop.isPackage() or ntop.isWindows() then return end

    -- In System Interface we can't get the flows number from `interface.getNumFlows()`
    if (IS_SYSTEM_INTERFACE) then return end

    local level = nil
    local flows = interface.getNumFlows()
    local flows_pctg = math.floor(1 + ((flows * 100) / prefs.max_num_flows))

    if (flows_pctg >= ALARM_THRESHOLD_LOW and flows_pctg <= ALARM_THRESHOLD_HIGH) then
        level = ToastLevel.WARNING
    elseif (flows_pctg > ALARM_THRESHOLD_HIGH) then
        level = ToastLevel.DANGER
    end

    if (level ~= nil) then
        table.insert(container, create_too_many_flows_toast(toast, level))
    end
end

--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.remote_probe_clock_drift(toast, container)
   if not IS_ADMIN then return end

    -- In System Interface we can't collect the stats from `interface.getStats()`
    if (IS_SYSTEM_INTERFACE) then return end

    local ifstats = interface.getStats()

    if ifstats["probe.remote_time"] ~= nil and 
       ifstats["probe.local_time"] ~= nil then

        local tdiff = math.abs(ifstats["probe.local_time"] - ifstats["probe.remote_time"])
        local level = nil

        if (tdiff >= 10 and tdiff <= 30) then
            level = ToastLevel.WARNING
        elseif (tdiff > 30) then
            level = ToastLevel.DANGER
        end

        if (level ~= nil) then
            table.insert(container, create_remote_probe_clock_drift_toast(toast, level))
        end
    end
end

--- Create an instance for the nIndex alert toast
--- if nIndex is not able to start/run/dump
--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.flow_dump(toast, container)
   if not IS_ADMIN or not ntop.isPackage() or ntop.isWindows() then return end

    -- In System Interface we can't collect the stats from `interface.getStats()`
    if (IS_SYSTEM_INTERFACE) then return end

    local ifstats = interface.getStats()

    if IS_ADMIN and prefs.is_dump_flows_enabled and
        prefs.is_dump_flows_runtime_enabled and not ifstats.isFlowDumpDisabled and
        not ifstats.isFlowDumpRunning and not ifstats.isViewed then

        table.insert(container, create_flow_dump_toast_ui(toast))
    end
end

--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.about_page(toast, container)
    if not IS_ADMIN then return end

    if (_POST["ntopng_license"] ~= nil) then

        ntop.setCache('ntopng.license', trimSpace(_POST["ntopng_license"]))
        ntop.checkLicense()
        ntop.setCache('ntopng.cache.force_reload_plugins', '1') -- housekeeping.lua will reload plugins

        info = ntop.getInfo()

        if (info["version.enterprise_l_edition"] and info["pro.license"] ~= "") then
           table.insert(container,
            toast_ui:new(toast.id, i18n("info"), i18n("about.create_license_l"), ToastLevel.INFO, {
                url = "https://www.ntop.org/support/faq/what-is-included-in-ntopng-enterprise-l/",
                title = i18n("details.details")
            })
        )
        elseif (not info["version.enterprise_l_edition"] and info["pro.license"] ~= "") then
           table.insert(container, toast_ui:new(toast.id, i18n("info"), i18n("about.create_license"), ToastLevel.INFO))
        end

     end
end

--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.hosts_geomap(toast, container)
    if not IS_ADMIN then return end

    local hosts_stats = interface.getHostsInfo()
    local num = hosts_stats["numHosts"]
    if (num > 0) then
        table.insert(container,
            toast_ui:new(toast.id, i18n("warning"), i18n("geo_map.warning_accuracy"), ToastLevel.WARNING, nil, toast.dismissable)
        )
    end
end

--- This is a simple placeholder for new toasts
--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.empty(toast, container)
    -- do nothing!
end 

--- Generate two toasts if the SNMP ratio is not available for exporters
--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.exporters_SNMP_ratio_column(toast, container)
    if not IS_ADMIN or not ntop.isPro() then return end

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
       table.insert(container, toast_ui:new(toast.id, title, body, ToastLevel.INFO, action, toast.dismissable))
    end

end

-- ###############################################

--- Create an instance for forced community toast
--- @param toast table The toast is the logic model defined in defined_toasts
--- @param container table Is the table where to put the new toast ui
function predicates.forced_community(toast, container)
   if(ntop.getInfo()["pro.forced_community"] and ntop.exists("/etc/ntopng.license")) then
        table.insert(container, create_forced_community_toast(toast))
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

--- Generate a toast to adive the user about toast endpoints
function predicates.create_endpoint(toast, container)
    if (not IS_ADMIN) then return end
    if (user_has_created_endpoint()) then return end
    if IS_PCAP_DUMP then return end

    local title = i18n("endpoint_notifications.hints.create_endpoint.title")
    local body = i18n("endpoint_notifications.hints.create_endpoint.body", {
        link = "https://www.ntop.org/guides/ntopng/plugins/alert_endpoints.html"
    })
    local action = {
        title = i18n("endpoint_notifications.hints.create_endpoint.action"),
        url = ntop.getHttpPrefix() .. "/lua/admin/endpoint_notifications_list.lua"
    }

    local hint = toast_ui:new(toast.id, title, body, ToastLevel.INFO, action, toast.dismissable)

    table.insert(container, hint)

end

-- Generate a second toast to inform the user to create a recipient for the new endpoint
function predicates.create_recipients_for_endpoint(toast, container)
    if (not IS_ADMIN) then return end
    if IS_PCAP_DUMP then return end

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

    local hint = toast_ui:new(toast.id, title, body, ToastLevel.INFO, action, toast.dismissable)
    table.insert(container, hint)
end

--- Generate a third notificiation to inform the user to bind the new recipients to a pool
function predicates.bind_recipient_to_pools(toast, container)
    if (not IS_ADMIN) then return end
    if (not user_has_created_endpoint()) then return end
    if (not user_has_created_recipient()) then return end
    if (user_has_bound_recipient()) then return end
    if IS_PCAP_DUMP then return end

    local title = i18n("endpoint_notifications.hints.bind_pools.title")
    local body = i18n("endpoint_notifications.hints.bind_pools.body")
    local action = {
        url = ntop.getHttpPrefix() .. "/lua/admin/manage_pools.lua",
        title = i18n("bind")
    }

    local hint = toast_ui:new(toast.id, title, body, ToastLevel.INFO, action, toast.dismissable)
    table.insert(container, hint)

end

--- Check if unexpected plugins are disabled and notifiy the user
--- about their existance
function predicates.unexpected_plugins(toast, container)
    if (not IS_ADMIN) then return end
    if not isEmptyString(ntop.getCache(UNEXPECTED_PLUGINS_ENABLED_CACHE_KEY)) then return end

    local url = ntop.getHttpPrefix() .. "/lua/admin/edit_configset.lua?subdir=flow&search_script=unexpected#disabled"

    -- TODO: missing documentation links
    local title = i18n("checks.hint.title")
    local body = i18n("checks.hint.body", {
        link_DHCP = "https://ntop.org",
        link_SMTP = "https://ntop.org",
        link_DNS = "https://ntop.org",
        link_NTP = "https://ntop.org",
        product = info["product"]
    })
    local action = { url = url, title = i18n("configure")}

    local hint = toast_ui:new(toast.id, title, body, ToastLevel.INFO, action, toast.dismissable)
    table.insert(container, hint)
end

-- ###############################################

function predicates.export_drops(toast, container)
    if (IS_SYSTEM_INTERFACE) then return end
    local is_dump_flows_enabled = prefs.is_dump_flows_enabled
    
    if is_dump_flows_enabled then

        local ifstats = interface.getStats()
        local total_flows = ifstats.stats_since_reset.flow_export_count
        local flow_export_drops = ifstats.stats_since_reset.flow_export_drops
        local severity = ToastLevels[stats_utils.get_severity_by_export_drops(flow_export_drops, total_flows)]

        -- for the info severity don't show anything
        if severity == ToastLevels.INFO then return end

        local body = i18n("about.too_many_exports", {
            product = "<b>" .. info.product .. "</b>"
        })
        local hint = toast_ui:new(toast.id, i18n("too_many_exports"), body, severity, nil, toast.dismissable)
        table.insert(container, hint)
    end

end

-- ###############################################

return predicates
