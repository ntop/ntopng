--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()

require "lua_utils"
local template_utils = require("template_utils")
local alert_notification = require("alert_notification")
local menu_alert_notifications = require("menu_alert_notifications")

local ui_utils = {}

function ui_utils.render_configuration_footer(item)
    return template_utils.gen('pages/components/manage-configuration-link.template', {item = item})
end

--- Single note element: { content = 'note description', hidden = true|false }
function ui_utils.render_notes(notes_items)

    if notes_items == nil then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "The notes table is nil!")
        return ""
    end

    return template_utils.gen("pages/components/notes.template", {
        notes = notes_items
    })
end

function ui_utils.render_pools_dropdown(pools_instance, member, key)

    if (pools_instance == nil) then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "The pools instance is nil!")
        return ""
    end

    if (member == nil) then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "The member is nil!")
        return ""
    end

    local selected_pool = pools_instance:get_pool_by_member(member)
    local selected_pool_id = selected_pool and selected_pool.pool_id or pools_instance.DEFAULT_POOL_ID

    local all_pools = pools_instance:get_all_pools()

    return template_utils.gen("pages/components/pool-select.template", {
        pools = all_pools,
        selected_pool_id = selected_pool_id,
        key = key,
    })
end

function ui_utils.create_navbar_title(title, subpage, title_link)

    if isEmptyString(subpage) then return title end
    return "<a href='".. title_link .."'>".. title .. "</a>&nbsp;/&nbsp;<span>"..subpage.."</span>"
end

--- Generate two notifications if the SNMP ratio is not available for exporters
--- @param cached_device The SNMP device
function ui_utils.alert_user_snmp_ratio(cached_device)

    -- Does the user have dismissed the notification?
    -- TODO: change the redis key for notifications, there is a reference inside update_prefs.lua

    -- Debug
    -- ntop.setPref("ntopng.prefs.notifications.flow_snmp_ratio", "0")

    local notification_dismissed = ntop.getPref("ntopng.prefs.notifications.flow_snmp_ratio") == "1"
    -- If the user has dismiseed the notification then return the function
    if (notification_dismissed) then return end

    -- Check the missing steps to enable it
    local notifications = {}
    local notification_title = i18n("flow_devices.enable_flow_ratio")

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

        table.insert(notifications, 
            alert_notification:create("snpm-device", notification_title, message_snmp, "info", {}, '', {
                dismissable = true,
                pref = 'flow_snmp_ratio'
            })
        )

    elseif not flow_dev_creation or not snmp_dev_creation then

        -- Are flow device and SNMP timeseries both disabled?
        local both_disabled = (not snmp_dev_creation and not flow_dev_creation)

        -- Build the message to show
        local message_timeseries = i18n("flow_devices.flow_ratio_timeseries_instructions", {
            enable = ternary(
                both_disabled, 
                i18n("flow_devices.snmp_flow_to_enable"),
                ternary(not snmp_dev_creation, i18n("flow_devices.snmp_to_enable"), i18n("flow_devices.flow_to_enable"))
            )
        })

        table.insert(notifications, 
            alert_notification:create(
                "timeseries", notification_title, message_timeseries, "info", 
                {
                    url = '#',
                    title = ternary(both_disabled, i18n("enable_them"), i18n("enable_it"))
                }, 
                nil, 
                {
                    dismissable = true,
                    pref = 'flow_snmp_ratio'
                }
            )
        )
   end

   menu_alert_notifications.render_notifications("flow-ratio-notifications", notifications)
end

return ui_utils