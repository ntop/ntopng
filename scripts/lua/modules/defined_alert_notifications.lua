--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
local info = ntop.getInfo()

local defined_alert_notifications = {}
local telemetry_utils = require("telemetry_utils")
local alert_notification = require("alert_notification")

local function create_geo_ip_alert_notification()

    local title = i18n("geo_map.geo_ip")
    local description = i18n("geolocation_unavailable", {url = "https://github.com/ntop/ntopng/blob/dev/doc/README.geolocation.md", target = "_blank", icon = "fas fa-external-link-alt"})

    return alert_notification:create("geoip_alert", title, description, "warning", nil)
end

local function create_contribute_alert_notification()

    local title = i18n("about.contribute_to_project")
    local description = i18n("about.telemetry_data_opt_out_msg", {tel_url=ntop.getHttpPrefix().."/lua/telemetry.lua", ntop_org="https://www.ntop.org/"})
    local action = {
        url = ntop.getHttpPrefix() .. '/lua/admin/prefs.lua?tab=telemetry',
        title = i18n("configure")
    }

    return alert_notification:create("contribute_alert", title, description, "info", action, 0, "/lua/admin/prefs.lua")

end

local function create_tempdir_alert_notification()

    local title = i18n("warning")
    local description = i18n("about.datadir_warning")
    local action = {
        url = "https://www.ntop.org/support/faq/migrate-the-data-directory-in-ntopng/"
    }

    return alert_notification:create("tempdir_alert", title, description, "warning", action, 0)

end

--- Create an instance for the geoip alert notification
--- if the user doesn't have geoIP installed
--- @param container table The table where the notification will be inserted
function defined_alert_notifications.geo_ip(container)

    if isAdministrator() and not ntop.hasGeoIP() then
        table.insert(container, create_geo_ip_alert_notification())
    end

end

--- Create an instance for the temp working directory alert
--- if ntopng is running inside /var/tmp
--- @param container table The table where the notification will be inserted
function defined_alert_notifications.temp_working_dir(container)

    if (dirs.workingdir == "/var/tmp/ntopng") then
        table.insert(container, create_tempdir_alert_notification())
    end

end

--- Create an instance for contribute alert notification
--- @param container table The table where the notification will be inserted
function defined_alert_notifications.contribute(container)

    if (not info.oem) and (not telemetry_utils.dismiss_notice()) then
        table.insert(container, create_contribute_alert_notification())
    end

end

return defined_alert_notifications