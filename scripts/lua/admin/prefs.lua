--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/drivers/?.lua;" .. package.path -- for influxdb
if ((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then
    package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path
end
require "lua_utils"
require "prefs_utils"
local template = require "template_utils"
local recording_utils = require "recording_utils"
local data_retention_utils = require "data_retention_utils"
local page_utils = require("page_utils")
local ts_utils = require("ts_utils")
local influxdb = require("influxdb")
local script_manager = require("script_manager")
local info = ntop.getInfo()
local auth = require "auth"
local prefs = ntop.getPrefs()

local email_peer_pattern = [[^([a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*)$]]

sendHTTPContentTypeHeader('text/html')

local alerts_disabled = false
local product = ntop.getInfo().product
local message_info = ""
local message_severity = "alert-warning"

-- ###########################################

local function create_table(title)
    print('<form method="post">')
    print('<table class="table">')
end

local function add_section(title)
    print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. title .. '</th></tr></thead>')
end

-- ###########################################

local function end_table()
    print(
        '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
        i18n("save") .. '</button></th></tr>')

    print [[<input name="csrf" type="hidden" value="]]
    print(ntop.getRandomCSRFValue())
    print [[" />]]
    print [[  </form>]]
    print [[  </table>]]
end

-- ###########################################

-- NOTE: all the auth methods should be listed below
local auth_toggles = {
    ["local"] = "toggle_local_auth",
    ["ldap"] = "toggle_ldap_auth",
    ["http"] = "toggle_http_auth",
    ["authentication_log"] = "toggle_http_auth_log",
    ["radius"] = "toggle_radius_auth",
    ["menu_entries"] = {
        ["help"] = "toggle_menu_entry_help",
        ["developer"] = "toggle_menu_entry_developer"
    }
}

if auth.has_capability(auth.capabilities.preferences) then
    if not table.empty(_POST) then
        if _GET["tab"] == "auth" then
            local one_enabled = false

            for k, v in pairs(auth_toggles) do
                if _POST[v] == "1" then
                    one_enabled = true
                    break
                end
            end
        end
    end

    if (_GET["tab"] == "ext_alerts") then
        local available_endpoints = script_manager.getLoadedAlertEndpoints()

        for _, endpoint in ipairs(available_endpoints) do
            if (endpoint.handlePost) then
                local mi, ms = endpoint.handlePost()

                if mi then
                    message_info = mi
                end
                if ms then
                    message_severity = ms
                end
            end
        end
    end

    if (_POST["flows_and_alerts_data_retention_days"] and _POST["aggregated_flows_data_retention_days"]) then
        local aggregated = tonumber(_POST["aggregated_flows_data_retention_days"])
        local raw = tonumber(_POST["flows_and_alerts_data_retention_days"])

        if (aggregated <= raw) then
            _POST["aggregated_flows_data_retention_days"] = tostring(raw + 1)
        end
    end

    if (_POST["toggle_radius_auth"] == "1") and
        ((_POST["radius_server_address"] ~= ntop.getPref("ntopng.prefs.radius.radius_server_address")) or
            (_POST["radius_acct_server_address"] ~= ntop.getPref("ntopng.prefs.radius.radius_acct_server_address")) or
            (_POST["radius_secret"] ~= ntop.getPref("ntopng.prefs.radius.radius_secret")) or
            (_POST["radius_admin_group"] ~= ntop.getPref("ntopng.prefs.radius.radius_admin_group")) or
            (_POST["radius_auth_proto"] ~= ntop.getPref("ntopng.prefs.radius.radius_auth_proto")) or
            (_POST["radius_unpriv_capabilties_group"] ~=
                ntop.getPref("ntopng.prefs.radius.radius_unpriv_capabilties_group")) or
            (_POST["toggle_radius_accounting"] ~= ntop.getPref("ntopng.prefs.radius.accounting_enabled")) or
            (_POST["toggle_radius_external_auth_for_local_users"] ~=
                ntop.getPref("ntopng.prefs.radius.external_auth_for_local_users_enabled"))) then
        -- In the minute callback there is a periodic script that in case
        -- the auth changed, it's going to update the radius info
        ntop.setPref("ntopng.prefs.radius.radius_server_address", _POST["radius_server_address"])
        ntop.setPref("ntopng.prefs.radius.radius_acct_server_address", _POST["radius_acct_server_address"])
        ntop.setPref("ntopng.prefs.radius.radius_secret", _POST["radius_secret"])
        ntop.setPref("ntopng.prefs.radius.radius_auth_proto", _POST["radius_auth_proto"])
        ntop.setPref("ntopng.prefs.radius.radius_admin_group", _POST["radius_admin_group"])
        ntop.setPref("ntopng.prefs.radius.radius_unpriv_capabilties_group", _POST["radius_unpriv_capabilties_group"])
        ntop.setPref("ntopng.prefs.radius.toggle_radius_accounting", _POST["toggle_radius_accounting"])
        ntop.setPref("ntopng.prefs.radius.external_auth_for_local_users_enabled",
            _POST["toggle_radius_external_auth_for_local_users"])
        ntop.updateRadiusLoginInfo()
    end

    if (_POST["disable_alerts_generation"] == "1") then
        local alert_utils = require "alert_utils"
        alert_utils.disableAlertsGeneration()
    elseif (_POST["timeseries_driver"] == "influxdb") then
        local url = string.gsub(string.gsub(_POST["ts_post_data_url"], "http:__", "http://"), "https:__", "https://")

        if ntop.getPref("ntopng.prefs.timeseries_driver") ~= "influxdb" or
            (url ~= ntop.getPref("ntopng.prefs.ts_post_data_url")) or
            (_POST["influx_dbname"] ~= ntop.getPref("ntopng.prefs.influx_dbname")) or
            (_POST["influx_retention"] ~= ntop.getPref("ntopng.prefs.influx_retention")) or
            (_POST["toggle_influx_auth"] ~= ntop.getPref("ntopng.prefs.influx_auth_enabled")) or
            (_POST["influx_username"] ~= ntop.getPref("ntopng.prefs.influx_username")) or
            (_POST["influx_password"] ~= ntop.getPref("ntopng.prefs.influx_password")) then
            local username = nil
            local password = nil

            if _POST["toggle_influx_auth"] == "1" then
                username = _POST["influx_username"]
                password = _POST["influx_password"]
            end

            local ok, message = influxdb.init(_POST["influx_dbname"], url, tonumber(_POST["influx_retention"]),
                username, password, false --[[verbose]])
            if not ok then
                message_info = message
                message_severity = "alert-danger"

                -- reset driver to the old one
                _POST["timeseries_driver"] = nil
            elseif message then
                message_info = message
                message_severity = "alert-success"
            end
        end
    elseif (_POST["n2disk_license"] ~= nil) then
        recording_utils.setLicense(_POST["n2disk_license"])
    end

    if _POST["timeseries_driver"] or _POST["ts_and_stats_data_retention_days"] then
        if ntop.getPref("ntopng.prefs.timeseries_driver") == 'influxdb' then
            ntop.setCache("ntopng.influxdb.retention_changed", 1)
        end
        ts_utils.setupAgain()
    end

    if _POST["toggle_snmp_trap"] and ntop.isEnterpriseXL() then
        ntop.snmpToggleTrapCollection(toboolean(_POST["toggle_snmp_trap"]))
    end

    page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.preferences)

    dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

    prefs = ntop.getPrefs()

    if not isEmptyString(message_info) then
        print [[<div class="alert alert-dismissable ]]
        print(message_severity)
        print [[" role="alert">]]
        print(message_info)
        print [[<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>]]
        print [[</div>]]
    end

    local show_advanced_prefs = false

    local show_advanced_prefs_key = "ntopng.prefs.show_advanced_prefs"
    if _POST["show_advanced_prefs"] then
        show_advanced_prefs = toboolean(_POST["show_advanced_prefs"])
        ntop.setPref(show_advanced_prefs_key, _POST["show_advanced_prefs"])
        notifyNtopng(show_advanced_prefs_key, _POST["show_advanced_prefs"])
    else
        show_advanced_prefs = toboolean(ntop.getPref(show_advanced_prefs_key))
        if isEmptyString(show_advanced_prefs) then
            show_advanced_prefs = false
        end
    end

    if _GET['show_advanced_prefs'] ~= nil then
        show_advanced_prefs = (_GET['show_advanced_prefs'] == '1')
    end

    page_utils.print_page_title(i18n("prefs.runtime_prefs"))

    if (false) then
        io.write("------- SERVER ----------------\n")
        tprint(_SERVER)
        io.write("-------- GET ---------------\n")
        tprint(_GET)
        io.write("-------- POST ---------------\n")
        tprint(_POST)
        io.write("-----------------------\n")
    end

    if hasAlertsDisabled() then
        alerts_disabled = true
    end

    local subpage_active, tab = prefsGetActiveSubpage(show_advanced_prefs, _GET["tab"])

    -- ================================================================================

    function printInterfaces()
        print('<form method="post">')
        print('<table class="table">')

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.zmq_interfaces") ..
            '</th></tr></thead>')

        prefsInputFieldPrefs(subpage_active.entries["ignored_interfaces"].title,
            subpage_active.entries["ignored_interfaces"].description, "ntopng.prefs.", "ignored_interfaces", "", false,
            nil, nil, nil, {
                attributes = {
                    spellcheck = "false",
                    pattern = "^([0-9]+,)*[0-9]+$",
                    maxlength = 32
                }
            })

        prefsToggleButton(subpage_active, {
            field = "toggle_dst_with_post_nat_dst",
            default = "0",
            pref = "override_dst_with_post_nat_dst"
        })

        prefsToggleButton(subpage_active, {
            field = "toggle_src_with_post_nat_src",
            default = "0",
            pref = "override_src_with_post_nat_src"
        })

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')
        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
  </form> ]]
    end

    -- ================================================================================
    function printActiveMonitoring()
        print('<form method="post">')
        print('<table class="table">')
        print('<thead class="table-primary"><tr><th colspan=2 class="info">' ..
            i18n("active_monitoring_stats.active_monitoring") .. '</th></tr></thead>')

        prefsToggleButton(subpage_active, {
            field = "toggle_active_monitoring",
            default = "0",
            pref = "active_monitoring"
        })

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')
        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
        </form> ]]
    end

    function printAlerts()
        print('<form method="post">')
        print('<table class="table">')
        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("show_alerts.alerts") ..
            '</th></tr></thead>')

        local elementToSwitch = { "row_toggle_emit_flow_alerts", "row_toggle_emit_host_alerts", "max_entity_alerts",
            "max_num_secs_before_delete_alert", "row_alert_page_refresh_rate_enabled" }

        prefsToggleButton(subpage_active, {
            field = "disable_alerts_generation",
            default = "0",
            to_switch = elementToSwitch,
            on_value = "0", -- On  means alerts enabled and thus disable_alerts_generation == 0
            off_value = "1" -- Off for enabled alerts implies 1 for disable_alerts_generation
        })

        if ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1" then
            showElements = false
        else
            showElements = true
        end

        prefsToggleButton(subpage_active, {
            field = "toggle_emit_flow_alerts",
            default = "1",
            pref = "emit_flow_alerts",
            on_value = "1",  -- On  flow alerts are generated
            off_value = "0", -- Off NO flow alerts are generated
            hidden = not showElements
        })

        prefsToggleButton(subpage_active, {
            field = "toggle_emit_host_alerts",
            default = "1",
            pref = "emit_host_alerts",
            on_value = "1",  -- On  alerts are generated
            off_value = "0", -- Off NO alerts are generated
            hidden = not showElements
        })

        prefsInputFieldPrefs(subpage_active.entries["max_entity_alerts"].title,
            subpage_active.entries["max_entity_alerts"].description, "ntopng.prefs.", "max_entity_alerts",
            prefs.max_entity_alerts, "number", showElements, false, nil, {
                min = 1 --[[ TODO check min/max ]]
            })

        prefsInputFieldPrefs(subpage_active.entries["max_num_secs_before_delete_alert"].title,
            subpage_active.entries["max_num_secs_before_delete_alert"].description, "ntopng.prefs.",
            "max_num_secs_before_delete_alert", prefs.max_num_secs_before_delete_alert, "number", showElements, false,
            nil, {
                min = 1,
                tformat = "d" --[[ TODO check min/max ]]
            })

        prefsToggleButton(subpage_active, {
            field = "alert_page_refresh_rate_enabled",
            default = "0",
            to_switch = { "alert_page_refresh_rate" },
            on_value = "1",  -- Refresh rate set
            off_value = "0", -- Refresh rate not set
            hidden = not showElements
        })

        local showRefreshRate = false

        if ntop.getPref("ntopng.prefs.alert_page_refresh_rate_enabled") == "1" then
            showRefreshRate = showElements
        end

        prefsInputFieldPrefs(subpage_active.entries["alert_page_refresh_rate"].title,
            subpage_active.entries["alert_page_refresh_rate"].description, "ntopng.prefs.", "alert_page_refresh_rate",
            prefs.alert_page_refresh_rate, "number", showRefreshRate, false, nil, {
                min = 3,
                tformat = "m" --[[ TODO check min/max ]]
            })

        print('<tr><th colspan=2 style="text-align:right;">')
        print(
            '<button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' .. i18n("save") ..
            '</button>')
        print('</th></tr>')
        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
  </form>
  ]]
    end

    -- ================================================================================

    function printProtocolPrefs()
        print('<form method="post">')

        print('<table class="table">')

        print('<thead class="table-primary"><tr><th colspan=2 class="info">HTTP / TLS / QUIC / DNS</th></tr></thead>')

        prefsToggleButton(subpage_active, {
            field = "toggle_top_sites",
            pref = "host_top_sites_creation",
            default = "0"
        })

        prefsToggleButton(subpage_active, {
            field = "toggle_sites_collection",
            pref = "sites_collection",
            default = "0"
        })

        prefsToggleButton(subpage_active, {
            field = "toggle_dns_cache",
            pref = "dns_cache",
            default = "0"
        })

        print('<thead class="table-primary"><tr><th colspan=2 class="info">TLS / QUIC</th></tr></thead>')

        prefsToggleButton(subpage_active, {
            field = "toggle_tls_quic_hostnaming",
            pref = "tls_quic_hostnaming",
            default = "0"
        })

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')

        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
  </form> ]]
    end

    -- ================================================================================

    function printNetworkDiscovery()
        print('<form method="post">')
        print('<table class="table">')

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.network_discovery") ..
            '</th></tr></thead>')

        local elementToSwitch = { "toggle_periodic_network_discovery", "toggle_network_discovery_debug" }
        prefsToggleButton(subpage_active, {
            field = "toggle_network_discovery",
            default = "0",
            pref = "network_discovery",
            to_switch = elementToSwitch
        })

        elementToSwitch = { "network_discovery_interval" }
        prefsToggleButton(subpage_active, {
            field = "toggle_periodic_network_discovery",
            default = "0",
            pref = "is_periodic_network_discovery_enabled",
            to_switch = elementToSwitch
        })

        local showNetworkDiscoveryInterval = false
        if ntop.getPref("ntopng.prefs.is_periodic_network_discovery_enabled") == "1" then
            showNetworkDiscoveryInterval = true
        end

        local interval = ntop.getPref("ntopng.prefs.network_discovery_interval")

        if isEmptyString(interval) then -- set a default value
            interval = 15 * 60          -- 15 minutes
            ntop.setPref("ntopng.prefs.network_discovery_interval", tostring(interval))
        end

        prefsInputFieldPrefs(subpage_active.entries["network_discovery_interval"].title,
            subpage_active.entries["network_discovery_interval"].description, "ntopng.prefs.",
            "network_discovery_interval", interval, "number", showNetworkDiscoveryInterval, nil, nil, {
                min = 60 * 15,
                tformat = "mhd"
            })

        prefsToggleButton(subpage_active, {
            field = "toggle_network_discovery_debug",
            default = "0",
            pref = "network_discovery_debug"
        })

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')

        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
    </form>]]
    end

    -- ================================================================================

    function printRecording()
        local n2disk_info = recording_utils.getN2diskInfo()

        print('<form method="post">')
        print('<table class="table">')

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.license") ..
            '</th></tr></thead>')

        prefsInputFieldPrefs(subpage_active.entries["n2disk_license"].title,
            subpage_active.entries["n2disk_license"].description ..
            i18n("prefs.n2disk_license_description_enterprise_l") .. "<br>" ..
            ternary(n2disk_info.version ~= nil, i18n("prefs.n2disk_license_version", {
                version = n2disk_info.version
            }) .. "<br>", "") .. ternary(n2disk_info.systemid ~= nil, i18n("prefs.n2disk_license_systemid", {
                systemid = n2disk_info.systemid
            }), ""), "ntopng.prefs.", "n2disk_license", ternary(n2disk_info.license ~= nil, n2disk_info.license, ""),
            false, nil, nil, nil, {
                style = {
                    width = "25em;"
                },
                min = 50,
                max = 64,
                pattern = getLicensePattern(),
                disabled = ntop.isEnterpriseL()
            })

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("traffic_recording.settings") ..
            '</th></tr></thead>')

        prefsInputFieldPrefs(subpage_active.entries["max_extracted_pcap_bytes"].title,
            subpage_active.entries["max_extracted_pcap_bytes"].description, "ntopng.prefs.", "max_extracted_pcap_bytes",
            prefs.max_extracted_pcap_bytes, "number", true, nil, nil, {
                min = 10 * 1024 * 1024,
                format_spec = FMT_TO_DATA_BYTES,
                tformat = "mg"
            })

        -- ######################

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')
        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
    </form>]]
    end

    -- ================================================================================

    -- #####################

    local function printMenuEntriesPrefs()
        if ntop.isEnterpriseM() then
            print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.menu_entries") ..
                '</th></tr></thead>')
        end

        prefsToggleButton(subpage_active, {
            field = auth_toggles["menu_entries"]["help"],
            pref = "menu_entries.help",
            hidden = not ntop.isEnterpriseM(),
            default = "1"
        })

        prefsToggleButton(subpage_active, {
            field = auth_toggles["menu_entries"]["developer"],
            hidden = not ntop.isEnterpriseM(),

            pref = "menu_entries.developer",
            default = "1"
        })
    end

    -- #####################

    function printGUI()
        print('<form method="post">')
        print('<table class="table">')

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.web_user_interface") ..
            '</th></tr></thead>')

        if prefs.is_autologout_enabled == true then
            prefsToggleButton(subpage_active, {
                field = "toggle_autologout",
                default = "1",
                pref = "is_autologon_enabled"
            })
        end

        -- ######################

        local t_labels = { i18n("default"), i18n("white"), i18n("dark") }
        local t_values = { "default", "white", "dark" }
        local label = "toggle_theme"

        multipleTableButtonPrefs(subpage_active.entries[label].title, subpage_active.entries[label].description,
            t_labels, t_values, "default", "primary", label, "ntopng.user." .. _SESSION["user"] .. ".theme")

        -- ######################

        local d_labels = { i18n("little_endian"), i18n("middle_endian"), i18n("big_endian") }
        local d_values = { "little_endian", "middle_endian", "big_endian" }
        local d_label = "toggle_date_type"

        multipleTableButtonPrefs(subpage_active.entries[d_label].title, subpage_active.entries[d_label].description,
            d_labels, d_values, "middle_endian", "primary", d_label,
            "ntopng.user." .. _SESSION["user"] .. ".date_format")

        -- ######################

        prefsInputFieldPrefs(subpage_active.entries["max_ui_strlen"].title,
            subpage_active.entries["max_ui_strlen"].description, "ntopng.prefs.", "max_ui_strlen", prefs.max_ui_strlen,
            "number", nil, nil, nil, {
                min = 3,
                max = 128
            })

        prefsInputFieldPrefs(subpage_active.entries["mgmt_acl"].title, subpage_active.entries["mgmt_acl"].description,
            "ntopng.prefs.", "http_acl_management_port", "", false, nil, nil, nil, {
                style = {
                    width = "25em;"
                },
                attributes = {
                    spellcheck = "false",
                    maxlength = 512,
                    pattern = getACLPattern()
                }
            })

        -- #####################

        prefsToggleButton(subpage_active, {
            field = "toggle_interface_name_only",
            default = "0",
            pref = "is_interface_name_only"
        })

        -- #####################

        prefsInputFieldPrefs(subpage_active.entries["http_index_page"].title,
            subpage_active.entries["http_index_page"].description, "ntopng.prefs.", "http_index_page",
            prefs.http_index_page, false, nil, nil, nil, {
                style = {
                    width = "25em;"
                },
                attributes = {
                    spellcheck = "false",
                    maxlength = 518,
                    pattern = getURLPathPattern()
                }
            })

        printMenuEntriesPrefs()

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')
        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" /></form>]]
    end

    -- ######################

    function printMisc()
        print('<form method="post">')
        print('<table class="table">')

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.connectivity_check") ..
            '</th></tr></thead>')

        prefsInputFieldPrefs(subpage_active.entries["connectivity_check_url"].title,
            subpage_active.entries["connectivity_check_url"].description, "ntopng.prefs.", "connectivity_check_url", "",
            false, true, nil, nil, {
                attributes = {
                    spellcheck = "false"
                },
                pattern = getURLPattern(),
                required = false
            })

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.report") ..
            '</th></tr></thead>')

        local t_labels = { i18n("bytes"), i18n("packets") }
        local t_values = { "bps", "pps" }

        multipleTableButtonPrefs(subpage_active.entries["toggle_thpt_content"].title,
            subpage_active.entries["toggle_thpt_content"].description, t_labels, t_values, "bps", "primary",
            "toggle_thpt_content", "ntopng.prefs.thpt_content")

        -- ######################

        if ntop.isPro() then
            t_labels = { i18n("topk_heuristic.precision.disabled"), i18n("topk_heuristic.precision.more_accurate"),
                i18n("topk_heuristic.precision.less_accurate"), i18n("topk_heuristic.precision.aggressive") }
            t_values = { "disabled", "more_accurate", "accurate", "aggressive" }

            multipleTableButtonPrefs(subpage_active.entries["topk_heuristic_precision"].title,
                subpage_active.entries["topk_heuristic_precision"].description, t_labels, t_values, "more_accurate",
                "primary", "topk_heuristic_precision", "ntopng.prefs.topk_heuristic_precision")
        end

        -- ######################

        if (isAdministratorOrPrintErr()) then
            print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("hosts") ..
                '</th></tr></thead>')

            local h_labels = { i18n("prefs.no_host_mask"), i18n("prefs.local_host_mask"), i18n("prefs.remote_host_mask") }
            local h_values = { "0", "1", "2" }

            multipleTableButtonPrefs(subpage_active.entries["toggle_host_mask"].title,
                subpage_active.entries["toggle_host_mask"].description, h_labels, h_values, "0", "primary",
                "toggle_host_mask", "ntopng.prefs.host_mask")

            prefsToggleButton(subpage_active, {
                field = "toggle_use_mac_in_flow_key",
                default = "0",
                pref = "use_mac_in_flow_key"
            })

            prefsToggleButton(subpage_active, {
                field = "toggle_fingerprint_stats",
                default = "0",
                pref = "fingerprint_stats"
            })
        end

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.flow_table") ..
            '</th></tr></thead>')

        prefsToggleButton(subpage_active, {
            field = "toggle_flow_begin",
            default = "0",
            pref = "first_seen_set"
        })

        local h_labels = { i18n("prefs.duration"), i18n("prefs.last_seen") }
        local h_values = { "0", "1" }

        multipleTableButtonPrefs(subpage_active.entries["flow_table_time"].title,
            subpage_active.entries["flow_table_time"].description, h_labels, h_values, "0", "primary",
            "flow_table_time", "ntopng.prefs.flow_table_time")

        h_labels = { i18n("prefs.ip_order"), i18n("prefs.name_order") }

        multipleTableButtonPrefs(subpage_active.entries["flow_table_probe_order"].title,
            subpage_active.entries["flow_table_probe_order"].description, h_labels, h_values, "0", "primary",
            "flow_table_probe_order", "ntopng.prefs.flow_table_probe_order")

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')
        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
    </form>]]
    end

    -- ================================================================================

    function printUpdates()
        print('<form method="post">')
        print('<table class="table">')

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.updates") ..
            '</th></tr></thead>')
        prefsToggleButton(subpage_active, {
            field = "toggle_autoupdates",
            default = "0",
            pref = "is_autoupdates_enabled"
        })

        -- #####################

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')
        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
    </form>]]
    end

    -- ================================================================================

    local function printAuthDuration()
        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.authentication_duration") ..
            '</th></tr></thead>')

        prefsInputFieldPrefs(subpage_active.entries["authentication_duration"].title,
            subpage_active.entries["authentication_duration"].description, "ntopng.prefs.", "auth_session_duration",
            prefs.auth_session_duration, "number", true, nil, nil, {
                min = 60 --[[ 1 minute --]],
                max = 86400 * 7 --[[ 7 days --]],
                tformat = "mhd"
            })

        prefsToggleButton(subpage_active, {
            field = "toggle_auth_session_midnight_expiration",
            default = "0",
            pref = "auth_session_midnight_expiration"
        })
    end

    -- ================================================================================

    local function printLdapAuth()
        if not ntop.isPro() then
            return
        end

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.ldap_authentication") ..
            '</th></tr></thead>')

        local elementToSwitch = { "row_multiple_ldap_account_type", "row_toggle_ldap_anonymous_bind", "server",
            "bind_dn", "bind_pwd", "ldap_server_address", "search_path", "user_group",
            "admin_group", "row_toggle_ldap_referrals", "row_toggle_ldap_debug" }

        prefsToggleButton(subpage_active, {
            field = auth_toggles.ldap,
            pref = "ldap.auth_enabled",
            default = "0",
            to_switch = elementToSwitch,

            -- Similar to "to_switch" but for nested items (e.g. "local hosts cache" only
            -- enabled when both "host cache" and "cache" are enabled).
            -- The following inputs will be shown/hidden when this preference changes.
            nested_to_switch = { -- input: the input ID to toggle (e.g. the "local hosts cache")
                -- parent: the parent of the input which affects the input logic (e.g. "host cache")
                -- parent_enabled_value: the parent input value that should make the child input visible
                -- pref_enabled_value: this preference value that should make the child input visible (e.g. "1" when "cache" is enabled)
                {
                    input = "bind_dn",
                    parent = "input-toggle_ldap_anonymous_bind",
                    parent_enabled_value = "0",
                    pref_enabled_value = "1"
                }, {
                input = "bind_pwd",
                parent = "input-toggle_ldap_anonymous_bind",
                parent_enabled_value = "0",
                pref_enabled_value = "1"
            } }
        })

        local showElements = (ntop.getPref("ntopng.prefs.ldap.auth_enabled") == "1")

        local labels_account = { i18n("prefs.posix"), i18n("prefs.samaccount") }
        local values_account = { "posix", "samaccount" }
        multipleTableButtonPrefs(subpage_active.entries["multiple_ldap_account_type"].title,
            subpage_active.entries["multiple_ldap_account_type"].description, labels_account, values_account, "posix",
            "primary", "multiple_ldap_account_type", "ntopng.prefs.ldap.account_type", nil, nil, nil, nil, showElements)

        prefsInputFieldPrefs(subpage_active.entries["ldap_server_address"].title,
            subpage_active.entries["ldap_server_address"].description, "ntopng.prefs.ldap", "ldap_server_address",
            "ldap://localhost:389", nil, showElements, true, true, {
                attributes = {
                    pattern = "ldap(s)?://[0-9.\\-A-Za-z]+(:[0-9]+)?",
                    spellcheck = "false",
                    required = "required",
                    maxlength = 255
                }
            })

        local elementToSwitchBind = { "bind_dn", "bind_pwd" }
        prefsToggleButton(subpage_active, {
            field = "toggle_ldap_anonymous_bind",
            default = "1",
            pref = "ldap.anonymous_bind",
            to_switch = elementToSwitchBind,
            reverse_switch = true,
            hidden = not showElements
        })

        local showEnabledAnonymousBind = false
        if ntop.getPref("ntopng.prefs.ldap.anonymous_bind") == "0" then
            showEnabledAnonymousBind = true
        end
        local showElementsBind = showElements
        if showElements == true then
            showElementsBind = showEnabledAnonymousBind
        end

        prefsInputFieldPrefs(subpage_active.entries["bind_dn"].title, subpage_active.entries["bind_dn"].description ..
            "\"CN=ntop_users,DC=ntop,DC=org,DC=local\".", "ntopng.prefs.ldap", "bind_dn", "", nil, showElementsBind,
            true, false, {
                attributes = {
                    spellcheck = "false",
                    maxlength = 255
                }
            })
        prefsInputFieldPrefs(subpage_active.entries["bind_pwd"].title, subpage_active.entries["bind_pwd"].description,
            "ntopng.prefs.ldap", "bind_pwd", "", "password", showElementsBind, true, false, {
                attributes = {
                    maxlength = 255
                }
            })
        prefsInputFieldPrefs(subpage_active.entries["search_path"].title,
            subpage_active.entries["search_path"].description, "ntopng.prefs.ldap", "search_path", "", "text",
            showElements, nil, nil, {
                attributes = {
                    spellcheck = "false",
                    maxlength = 255
                }
            })
        prefsInputFieldPrefs(subpage_active.entries["user_group"].title,
            subpage_active.entries["user_group"].description, "ntopng.prefs.ldap", "user_group", "", "text",
            showElements, nil, nil, {
                attributes = {
                    spellcheck = "false",
                    maxlength = 255
                }
            })
        prefsInputFieldPrefs(subpage_active.entries["admin_group"].title,
            subpage_active.entries["admin_group"].description, "ntopng.prefs.ldap", "admin_group", "", "text",
            showElements, nil, nil, {
                attributes = {
                    spellcheck = "false",
                    maxlength = 255
                }
            })

        prefsToggleButton(subpage_active, {
            field = "toggle_ldap_referrals",
            default = "1",
            pref = "ldap.follow_referrals",
            reverse_switch = true,
            hidden = not showElements
        })

        prefsToggleButton(subpage_active, {
            field = "toggle_ldap_debug",
            default = "0",
            pref = "ldap_debug",
            hidden = not showElements
        })

    end

    -- #####################

    local function printRadiusAuth()
        if subpage_active.entries["toggle_radius_auth"].hidden then
            return
        end

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.radius_auth") ..
            '</th></tr></thead>')

        -- RADIUS GUI authentication

        local elementToSwitch = { "row_toggle_radius_accounting", "row_toggle_radius_external_auth_for_local_users",
            "radius_admin_group", "radius_unpriv_capabilties_group", "radius_server_address",
            "radius_acct_server_address", "radius_secret", "row_radius_auth_proto" }

        prefsToggleButton(subpage_active, {
            field = auth_toggles.radius,
            pref = "radius.auth_enabled",
            default = "0",
            to_switch = elementToSwitch
        })

        -- RADIUS traffic accounting
        local showElements = (ntop.getPref("ntopng.prefs.radius.auth_enabled") == "1")
        -- RADIUS server settings (used for both RADIUS auth and accountign)
        prefsInputFieldPrefs(subpage_active.entries["radius_server"].title,
            subpage_active.entries["radius_server"].description, "ntopng.prefs.radius", "radius_server_address",
            "127.0.0.1:1812", nil, showElements, true, false, {
                attributes = {
                    spellcheck = "false",
                    maxlength = 255,
                    required = "required",
                    pattern = "[0-9.\\-A-Za-z]+:[0-9]+"
                }
            })

        -- https://github.com/FreeRADIUS/freeradius-client/blob/7b7473ab78ca5f99e083e5e6c16345b7c2569db1/include/freeradius-client.h#L395
        prefsInputFieldPrefs(subpage_active.entries["radius_secret"].title,
            subpage_active.entries["radius_secret"].description, "ntopng.prefs.radius", "radius_secret", "", "password",
            showElements, true, false, {
                attributes = {
                    spellcheck = "false",
                    maxlength = 48,
                    required = "required"
                }
            })

        local labels_auth_protocols = { i18n("prefs.pap"), i18n("prefs.chap") }
        local values_auth_protocols = { "pap", "chap" }
        multipleTableButtonPrefs(subpage_active.entries["radius_auth_proto"].title,
            subpage_active.entries["radius_auth_proto"].description, labels_auth_protocols, values_auth_protocols,
            "pap", "primary", "radius_auth_proto", "ntopng.prefs.radius.radius_auth_proto", nil, nil, nil, nil,
            showElements)

        local groupsElements = { "radius_admin_group", "radius_unpriv_capabilties_group" }
        local showGroupsElements = (ntop.getPref("ntopng.prefs.radius.external_auth_for_local_users_enabled") ~= "1")
        prefsToggleButton(subpage_active, {
            field = "toggle_radius_external_auth_for_local_users",
            pref = "radius.external_auth_for_local_users_enabled",
            default = "0",
            to_switch = groupsElements,
            reverse_switch = true,
            hidden = not showElements
        })

        prefsInputFieldPrefs(subpage_active.entries["radius_admin_group"].title,
            subpage_active.entries["radius_admin_group"].description, "ntopng.prefs.radius", "radius_admin_group", "",
            nil, showElements and showGroupsElements, true, false, {
                attributes = {
                    spellcheck = "false",
                    maxlength = 255,
                    pattern = "[^\\s]+"
                }
            })

        prefsInputFieldPrefs(subpage_active.entries["radius_unpriv_capabilties_group"].title,
            subpage_active.entries["radius_unpriv_capabilties_group"].description, "ntopng.prefs.radius",
            "radius_unpriv_capabilties_group", "", nil, showElements and showGroupsElements, true, false, {
                attributes = {
                    spellcheck = "false",
                    maxlength = 255,
                    pattern = "[^\\s]+"
                }
            })

        local accountingElements = { "radius_acct_server_address" }

        prefsToggleButton(subpage_active, {
            field = "toggle_radius_accounting",
            pref = "radius.accounting_enabled",
            default = "0",
            to_switch = accountingElements,
            hidden = not showElements
        })
        local showElementsAccounting = (ntop.getPref("ntopng.prefs.radius.accounting_enabled") == "1")

        -- RADIUS server settings (used for both RADIUS auth and accountign)
        prefsInputFieldPrefs(subpage_active.entries["radius_accounting_server"].title,
            subpage_active.entries["radius_accounting_server"].description, "ntopng.prefs.radius",
            "radius_acct_server_address", "127.0.0.1:1813", nil, showElements and showElementsAccounting, true, false, {
                attributes = {
                    spellcheck = "false",
                    maxlength = 255,
                    required = "required",
                    pattern = "[0-9.\\-A-Za-z]+:[0-9]+"
                }
            })
    end

    -- #####################

    local function printHttpAuth()
        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.http_auth") ..
            '</th></tr></thead>')

        local elementToSwitch = { "http_auth_url" }

        prefsToggleButton(subpage_active, {
            field = auth_toggles.http,
            pref = "http_authenticator.auth_enabled",
            default = "0",
            to_switch = elementToSwitch
        })

        local showElements = (ntop.getPref("ntopng.prefs.http_authenticator.auth_enabled") == "1")

        prefsInputFieldPrefs(subpage_active.entries["http_auth_server"].title,
            subpage_active.entries["http_auth_server"].description, "ntopng.prefs.http_authenticator", "http_auth_url",
            "", nil, showElements, true, true --[[ allowUrls ]], {
                attributes = {
                    spellcheck = "false",
                    maxlength = 255,
                    required = "required",
                    pattern = getURLPattern()
                }
            })

        local showElements = (ntop.getPref("ntopng.prefs.http_authenticator.log_positive_event_enabled") == "1")

        prefsInputFieldPrefs(subpage_active.entries["http_auth_server"].title,
            subpage_active.entries["http_auth_server"].description,
            "ntopng.prefs.http_authenticator.log_positive_event_enabled", "http_auth_url", "", nil, showElements, true,
            true --[[ allowUrls ]], {
                attributes = {
                    spellcheck = "false",
                    maxlength = 255,
                    required = "required",
                    pattern = getURLPattern()
                }
            })
    end

    -- #####################

    local function printLocalAuth()
        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.local_auth") ..
            '</th></tr></thead>')

        prefsToggleButton(subpage_active, {
            field = auth_toggles["local"],
            pref = "local.auth_enabled",
            default = "1"
        })
    end

    -- #####################

    function printAuthentication()
        print('<form method="post">')
        print('<table class="table">')

        local entries = subpage_active.entries

        printAuthDuration()

        -- Note: order must correspond to evaluation order in Ntop.cpp
        print('<thead class="table-primary"><tr><th class="info" colspan="2">' .. i18n("prefs.client_x509_auth") ..
            '</th></tr></thead>')
        prefsToggleButton(subpage_active, {
            field = "toggle_client_x509_auth",
            default = "0",
            pref = "is_client_x509_auth_enabled"
        })
        if not entries.toggle_ldap_auth.hidden then
            printLdapAuth()
        end

        if not entries.toggle_radius_auth.hidden then
            printRadiusAuth()
        end

        if not entries.toggle_http_auth.hidden then
            printHttpAuth()
        end
        if not entries.toggle_local_auth.hidden then
            printLocalAuth()
        end

        if not ntop.isnEdge() then
            prefsInformativeField(i18n("notes"), i18n("prefs.auth_methods_order"))
        else
            prefsInformativeField(i18n("notes"), i18n("nedge.authentication_gui_and_captive_portal", {
                product = product,
                url = ntop.getHttpPrefix() .. "/lua/pro/nedge/system_setup_ui/captive_portal.lua"
            }))
        end

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')
        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />]]
        print('</form>')
    end

    -- #####################

    function printOTProtocols()
        print('<form method="post">')
        print('<table class="table">')

        -- ######################

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.ot_protocols") ..
            '</th></tr></thead>')
        -- By default 1 hour of learning
        prefsInputFieldPrefs(subpage_active.entries["iec60870_learning_period"].title,
            subpage_active.entries["iec60870_learning_period"].description, "ntopng.prefs.", "iec60870_learning_period",
            prefs.iec60870_learning_period or 3600, "number", nil, nil, nil, {
                min = 21600,
                tformat = "hd"
            })

        -- By default 6 hours of learning
        prefsInputFieldPrefs(subpage_active.entries["modbus_learning_period"].title,
            subpage_active.entries["modbus_learning_period"].description, "ntopng.prefs.", "modbus_learning_period",
            prefs.modbus_learning_period or 21600, "number", is_behaviour_analysis_enabled, nil, nil, {
                min = 3600,
                tformat = "hd"
            })

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')

        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />]]
        print('</form>')
    end

    -- #####################

    function printNetworkBehaviour()
        local LEARNING_STATUS = { -- Keep it in sync with ntop_typedefs.h ServiceAcceptance
            ALLOWED = "0",
            DENIED = "1",
            UNDECIDED = "2"
        }

        print('<form method="post">')
        print('<table class="table">')

        -- ######################

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.service_map") ..
            '</th></tr></thead>')
        -- Behavior analysis for asn, network and l7proto (iface)

        local is_behaviour_analysis_enabled = ntop.isEnterpriseL()

        prefsInputFieldPrefs(subpage_active.entries["behaviour_analysis_learning_period"].title,
            subpage_active.entries["behaviour_analysis_learning_period"].description, "ntopng.prefs.",
            "behaviour_analysis_learning_period", prefs.behaviour_analysis_learning_period, "number",
            is_behaviour_analysis_enabled, nil, nil, {
                min = 3600,
                tformat = "hd"
            })

        multipleTableButtonPrefs(subpage_active.entries["behaviour_analysis_learning_status_during_learning"].title,
            subpage_active.entries["behaviour_analysis_learning_status_during_learning"].description, { i18n(
                "traffic_behaviour.undecided"), i18n("traffic_behaviour.allowed"), i18n("traffic_behaviour.denied") },
            { LEARNING_STATUS.UNDECIDED, LEARNING_STATUS.ALLOWED, LEARNING_STATUS.DENIED }, LEARNING_STATUS.ALLOWED, -- [default value]
            "primary",                                                                                             -- [selected color]
            "behaviour_analysis_learning_status_during_learning",
            "ntopng.prefs.behaviour_analysis_learning_status_during_learning",                                     -- [redis key]
            false,                                                                                                 -- [disabled]
            {}, nil, nil, is_behaviour_analysis_enabled --[[show]])

        multipleTableButtonPrefs(subpage_active.entries["behaviour_analysis_learning_status_post_learning"].title,
            subpage_active.entries["behaviour_analysis_learning_status_post_learning"].description, { i18n(
                "traffic_behaviour.undecided"), i18n("traffic_behaviour.allowed"), i18n("traffic_behaviour.denied") },
            { LEARNING_STATUS.UNDECIDED, LEARNING_STATUS.ALLOWED, LEARNING_STATUS.DENIED }, LEARNING_STATUS.ALLOWED, -- [default value]
            "primary", "behaviour_analysis_learning_status_post_learning",
            "ntopng.prefs.behaviour_analysis_learning_status_post_learning", false, {}, nil, nil,
            is_behaviour_analysis_enabled --[[show]])

        -- #####################

        local is_device_connection_disconnection_analysis_enabled = ntop.isEnterpriseM()

        if is_device_connection_disconnection_analysis_enabled then
            print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.devices_behaviour") ..
                '</th></tr></thead>')
            -- Behavior analysis for asn, network and l7proto (iface)

            prefsInputFieldPrefs(subpage_active.entries["devices_learning_period"].title,
                subpage_active.entries["devices_learning_period"].description, "ntopng.prefs.",
                "devices_learning_period", prefs.devices_learning_period, "number",
                is_device_connection_disconnection_analysis_enabled, nil, nil, {
                    min = 7200,
                    tformat = "hd"
                })

            multipleTableButtonPrefs(subpage_active.entries["devices_status_during_learning"].title,
                subpage_active.entries["devices_status_during_learning"].description,
                { i18n("traffic_behaviour.allowed"), i18n("traffic_behaviour.denied") },
                { LEARNING_STATUS.ALLOWED, LEARNING_STATUS.DENIED }, LEARNING_STATUS.ALLOWED,    -- [default value]
                "primary",                                                                       -- [selected color]
                "devices_status_during_learning", "ntopng.prefs.devices_status_during_learning", -- [redis key]
                false,                                                                           -- [disabled]
                {}, nil, nil, is_device_connection_disconnection_analysis_enabled --[[show]])

            multipleTableButtonPrefs(subpage_active.entries["devices_status_post_learning"].title,
                subpage_active.entries["devices_status_post_learning"].description,
                { i18n("traffic_behaviour.allowed"), i18n("traffic_behaviour.denied") },
                { LEARNING_STATUS.ALLOWED, LEARNING_STATUS.DENIED }, LEARNING_STATUS.ALLOWED, -- [default value]
                "primary", "devices_status_post_learning", "ntopng.prefs.devices_status_post_learning", false, {}, nil,
                nil, is_device_connection_disconnection_analysis_enabled --[[show]])
        end

        -- #####################

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.host_analysis") ..
            '</th></tr></thead>')

        prefsInputFieldPrefs(subpage_active.entries["host_port_learning_period"].title,
            subpage_active.entries["host_port_learning_period"].description, "ntopng.prefs.",
            "host_port_learning_period", prefs.host_port_learning_period, "number", ntop.isEnterpriseM(), nil, nil, {
                min = 7200,
                tformat = "hd"
            })

        -- #####################

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')

        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />]]
        print('</form>')
    end

    -- ================================================================================

    function printInMemory()
        print('<form id="localRemoteTimeoutForm" method="post">')

        print('<table class="table">')
        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.stats_reset") ..
            '</th></tr></thead>')
        prefsToggleButton(subpage_active, {
            field = "toggle_midnight_stats_reset",
            default = "0",
            pref = "midnight_stats_reset_enabled"
        })

        print(
            '<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.local_hosts_cache_settings") ..
            '</th></tr></thead>')

        prefsToggleButton(subpage_active, {
            field = "toggle_local_host_cache_enabled",
            default = "1",
            pref = "is_local_host_cache_enabled",
            to_switch = { "local_host_cache_duration", "row_toggle_active_local_host_cache_enabled",
                "active_local_host_cache_interval" },

            -- Similar to "to_switch" but for nested items (e.g. "local hosts cache" only
            -- enabled when both "host cache" and "cache" are enabled).
            -- The following inputs will be shown/hidden when this preference changes.
            nested_to_switch = { -- input: the input ID to toggle (e.g. the "local hosts cache")
                -- parent: the parent of the input which affects the input logic (e.g. "host cache")
                -- parent_enabled_value: the parent input value that should make the child input visible
                -- pref_enabled_value: this preference value that should make the child input visible (e.g. "1" when "cache" is enabled)
                {
                    input = "active_local_host_cache_interval",
                    parent = "input-toggle_active_local_host_cache_enabled",
                    parent_enabled_value = "1",
                    pref_enabled_value = "1"
                } }
        })

        local showLocalHostCacheInterval = false
        if ntop.getPref("ntopng.prefs.is_local_host_cache_enabled") == "1" then
            showLocalHostCacheInterval = true
        end

        prefsInputFieldPrefs(subpage_active.entries["local_host_cache_duration"].title,
            subpage_active.entries["local_host_cache_duration"].description, "ntopng.prefs.",
            "local_host_cache_duration", prefs.local_host_cache_duration, "number", showLocalHostCacheInterval, nil,
            nil, {
                min = 60,
                tformat = "mhd"
            })

        prefsToggleButton(subpage_active, {
            field = "toggle_active_local_host_cache_enabled",
            default = "0",
            pref = "is_active_local_host_cache_enabled",
            to_switch = { "active_local_host_cache_interval" }
        })

        local showActiveLocalHostCacheInterval = false
        if ntop.getPref("ntopng.prefs.is_active_local_host_cache_enabled") == "1" then
            showActiveLocalHostCacheInterval = true
        end

        prefsInputFieldPrefs(subpage_active.entries["active_local_host_cache_interval"].title,
            subpage_active.entries["active_local_host_cache_interval"].description, "ntopng.prefs.",
            "active_local_host_cache_interval", prefs.active_local_host_cache_interval or 3600, "number",
            showActiveLocalHostCacheInterval, nil, nil, {
                min = 60,
                tformat = "mhd"
            })


        prefsToggleButton(subpage_active, {
            field = "toggle_assets_collection",
            default = "1",
            pref = "enable_assets_collection"
        })

        prefsInputFieldPrefs(subpage_active.entries["mac_address_cache_duration"].title,
            subpage_active.entries["mac_address_cache_duration"].description, "ntopng.prefs.",
            "mac_address_cache_duration", prefs.mac_address_cache_duration or 300, "number", true, nil, nil, {
                min = 5,
                tformat = "mhd"
        })

        print('</table>')

        print('<table class="table">')
        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.idle_timeout_settings") ..
            '</th></tr></thead>')

        prefsInputFieldPrefs(subpage_active.entries["flow_max_idle"].title,
            subpage_active.entries["flow_max_idle"].description, "ntopng.prefs.", "flow_max_idle", prefs.flow_max_idle,
            "number", nil, nil, nil, {
                min = 1,
                max = 3600,
                tformat = "smh"
            })

        prefsInputFieldPrefs(subpage_active.entries["local_host_max_idle"].title,
            subpage_active.entries["local_host_max_idle"].description, "ntopng.prefs.", "local_host_max_idle",
            prefs.local_host_max_idle, "number", nil, nil, nil, {
                min = 1,
                max = 7 * 86400,
                tformat = "smh",
                attributes = {
                    ["data-localremotetimeout"] = "localremotetimeout"
                }
            })

        prefsInputFieldPrefs(subpage_active.entries["non_local_host_max_idle"].title,
            subpage_active.entries["non_local_host_max_idle"].description, "ntopng.prefs.", "non_local_host_max_idle",
            prefs.non_local_host_max_idle, "number", nil, nil, nil, {
                min = 1,
                max = 7 * 86400,
                tformat = "smh"
            })

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')
        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
  </form>

  <script>
    function localRemoteTimeoutValidator() {
      var form = $("#localRemoteTimeoutForm");
      var local_timeout = resol_selector_get_raw($("input[name='local_host_max_idle']", form));
      var remote_timeout = resol_selector_get_raw($("input[name='non_local_host_max_idle']", form));

      if ((local_timeout != null) && (remote_timeout != null)) {
        if (local_timeout < remote_timeout)
          return false;
      }

      return true;
    }

    var idleFormValidatorOptions = {
      disable: true,
      custom: {
         localremotetimeout: localRemoteTimeoutValidator,
      }, errors: {
         localremotetimeout: "Cannot be less then Remote Host Idle Timeout",
      }
   }

   $("#localRemoteTimeoutForm")
      .validator(idleFormValidatorOptions);

   /* Retrigger the validation every second to clear outdated errors */
   setInterval(function() {
      $("#localRemoteTimeoutForm").data("bs.validator").validate();
    }, 1000);
  </script>
  ]]
    end

    -- ================================================================================

    function printStatsTimeseries()
        print('<form method="post">')
        print('<table class="table">')

        local force_rrd = false -- ntop.isWindows()

        if not force_rrd then
            print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n('prefs.timeseries_database') ..
                '</th></tr></thead>')
        end

        local elementToSwitch = { "ts_post_data_url", "influx_dbname", "influx_retention", "row_toggle_influx_auth",
            "influx_username", "influx_password", "row_ts_high_resolution" }
        local showElementArray = { false, true, false }

        local active_driver = "rrd"
        local influx_active = false

        if not force_rrd then
            -- Similar to "to_switch" but for nested items (e.g. "local hosts cache" only
            -- enabled when both "host cache" and "cache" are enabled).
            -- The following inputs will be shown/hidden when this preference changes.
            local nested_to_switch = { -- input: the input ID to toggle (e.g. the "local hosts cache")
                -- parent: the parent of the input which affects the input logic (e.g. "host cache")
                -- parent_enabled_value: the parent input value that should make the child input visible
                -- pref_enabled_value: this preference value that should make the child input visible (e.g. "1" when "cache" is enabled)
                {
                    input = "influx_username",
                    parent = "input-toggle_influx_auth",
                    parent_enabled_value = "1",
                    pref_enabled_value = "influxdb"
                }, {
                input = "influx_password",
                parent = "input-toggle_influx_auth",
                parent_enabled_value = "1",
                pref_enabled_value = "influxdb"
            } }

            multipleTableButtonPrefs(subpage_active.entries["multiple_timeseries_database"].title,
                subpage_active.entries["multiple_timeseries_database"].description, { "RRD", "InfluxDB 1.x/2.x" },
                { "rrd", "influxdb" }, "rrd", "primary", "timeseries_driver", "ntopng.prefs.timeseries_driver", nil,
                elementToSwitch, showElementArray, nested_to_switch, true --[[show]])

            active_driver = ntop.getPref("ntopng.prefs.timeseries_driver")
            influx_active = (active_driver == "influxdb")
        end

        prefsInputFieldPrefs(subpage_active.entries["influxdb_url"].title,
            subpage_active.entries["influxdb_url"].description, "ntopng.prefs.", "ts_post_data_url",
            "http://localhost:8086", false, influx_active, nil, nil, {
                attributes = {
                    spellcheck = "false"
                },
                pattern = getURLPattern(),
                required = true
            })

        if ntop.isnEdge() and ntop.getPref("ntopng.prefs.influx_dbname") == "ntopng edge" then
            -- Fixes issue #1939 with wrong deployed nedge db name
            ntop.delCache("ntopng.prefs.influx_dbname")
        end
        prefsInputFieldPrefs(subpage_active.entries["influxdb_dbname"].title,
            subpage_active.entries["influxdb_dbname"].description, "ntopng.prefs.", "influx_dbname",
            product:gsub(' ', '_'), nil, influx_active, nil, nil, {
                pattern = "[A-z,0-9,_]+"
            })

        prefsToggleButton(subpage_active, {
            field = "toggle_influx_auth",
            default = "0",
            pref = "influx_auth_enabled",
            to_switch = { "influx_username", "influx_password" },
            hidden = not influx_active
        })

        local auth_enabled = influx_active and (ntop.getPref("ntopng.prefs.influx_auth_enabled") == "1")

        prefsInputFieldPrefs(subpage_active.entries["influxdb_username"].title,
            subpage_active.entries["influxdb_username"].description, "ntopng.prefs.", "influx_username", "", false,
            auth_enabled, nil, nil, {
                attributes = {
                    spellcheck = "false"
                },
                pattern = "[^\\s]+"
            })

        prefsInputFieldPrefs(subpage_active.entries["influxdb_password"].title,
            subpage_active.entries["influxdb_password"].description, "ntopng.prefs.", "influx_password", "", "password",
            auth_enabled, nil, nil, {
                attributes = {
                    spellcheck = "false"
                },
                pattern = "[^\\s]+"
            })

        local resolutions_labels = { "1m", "5m" }
        local resolutions_values = { "60", "300" }

        multipleTableButtonPrefs(subpage_active.entries["timeseries_resolution_resolution"].title,
            subpage_active.entries["timeseries_resolution_resolution"].description .. "<br><b>" .. i18n("notes") ..
            [[</b>:<ul>
      <li>]] .. i18n("prefs.ts_resolution_note2", {
                external_icon = "<i class='fas fa-external-link-alt'></i>",
                url =
                "https://docs.influxdata.com/influxdb/v1.8/query_language/manage-database/#delete-a-database-with-drop-database"
            }) .. [[</li>
      </ul>]], resolutions_labels, resolutions_values, "300", "primary", "ts_high_resolution",
            "ntopng.prefs.ts_resolution", nil, nil, nil, nil, influx_active)

        prefsInputFieldPrefs(subpage_active.entries["influxdb_query_timeout"].title,
            subpage_active.entries["influxdb_query_timeout"].description, "ntopng.prefs.", "influx_query_timeout", "10",
            "number", influx_active, nil, nil, {
                min = 1
            })

        prefsInputFieldPrefs(subpage_active.entries["ts_data_retention"].title,
            subpage_active.entries["ts_data_retention"].description, "ntopng.prefs.",
            "ts_and_stats_data_retention_days", data_retention_utils.getDefaultRetention(), "number", nil, nil, nil, {
                min = 1,
                max = 365 * 10
            })

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n('prefs.interfaces_timeseries') ..
            '</th></tr></thead>')

        -- TODO: make also per-category interface RRDs
        local l7_rrd_labels = { i18n("prefs.none"), i18n("prefs.per_protocol"), i18n("prefs.per_category"),
            i18n("prefs.both") }
        local l7_rrd_values = { "none", "per_protocol", "per_category", "both" }

        local elementToSwitch = {}
        local showElementArray = nil -- { true, false, false }

        prefsToggleButton(subpage_active, {
            field = "toggle_interface_traffic_rrd_creation",
            default = "1",
            pref = "interface_rrd_creation",
            to_switch = { "row_interfaces_ndpi_timeseries_creation" }
        })

        local showElement = ntop.getPref("ntopng.prefs.interface_rrd_creation") == "1"

        retVal = multipleTableButtonPrefs(subpage_active.entries["toggle_ndpi_timeseries_creation"].title,
            subpage_active.entries["toggle_ndpi_timeseries_creation"].description, l7_rrd_labels, l7_rrd_values,
            "per_protocol", "primary", "interfaces_ndpi_timeseries_creation",
            "ntopng.prefs.interface_ndpi_timeseries_creation", nil, elementToSwitch, showElementArray, nil, showElement)

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n('prefs.local_hosts_timeseries') ..
            '</th></tr></thead>')

        local hosts_rrd_labels = { i18n("off"), i18n("light"), i18n("full") }
        local hosts_rrd_values = { "off", "light", "full" }
        local hostElemsToSwitch = { "row_hosts_ndpi_timeseries_creation", "row_toggle_local_hosts_one_way_ts" }
        local hostShowElementArray = { { false, false, true } --[[ ndpi ]], { false, true, true } --[[ one-way traffic ]] }

        multipleTableButtonPrefs(subpage_active.entries["toggle_local_hosts_ts_creation"].title,
            subpage_active.entries["toggle_local_hosts_ts_creation"].description, hosts_rrd_labels, hosts_rrd_values,
            "light", "primary", "hosts_ts_creation", "ntopng.prefs.hosts_ts_creation", nil, hostElemsToSwitch,
            hostShowElementArray, nil, true)

        local hosts_ts_creation = ntop.getPref("ntopng.prefs.hosts_ts_creation")
        local show_host_l7 = (hosts_ts_creation == "full")

        prefsToggleButton(subpage_active, {
            field = "toggle_local_hosts_one_way_ts",
            default = "0",
            pref = "hosts_one_way_traffic_rrd_creation",
            hidden = (hosts_ts_creation == "off")
        })

        retVal = multipleTableButtonPrefs(subpage_active.entries["toggle_ndpi_timeseries_creation"].title,
            subpage_active.entries["toggle_ndpi_timeseries_creation"].description, l7_rrd_labels, l7_rrd_values, "none",
            "primary", "hosts_ndpi_timeseries_creation", "ntopng.prefs.host_ndpi_timeseries_creation", nil,
            elementToSwitch, showElementArray, nil, show_host_l7)

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n('prefs.l2_devices_timeseries') ..
            '</th></tr></thead>')

        prefsToggleButton(subpage_active, {
            field = "toggle_l2_devices_traffic_rrd_creation",
            default = "0",
            pref = "l2_device_rrd_creation",
            to_switch = { "row_l2_devices_ndpi_timeseries_creation" }
        })

        local l7_rrd_labels = { i18n("prefs.none"), i18n("prefs.per_category") }
        local l7_rrd_values = { "none", "per_category" }

        local showElement = ntop.getPref("ntopng.prefs.l2_device_rrd_creation") == "1"

        retVal = multipleTableButtonPrefs(subpage_active.entries["toggle_ndpi_timeseries_creation"].title,
            subpage_active.entries["toggle_ndpi_timeseries_creation"].description, l7_rrd_labels, l7_rrd_values, "none",
            "primary", "l2_devices_ndpi_timeseries_creation", "ntopng.prefs.l2_device_ndpi_timeseries_creation", nil,
            elementToSwitch, showElementArray, nil, showElement)

        if ntop.isPro() then
            print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n('prefs.exporter_timeseries') ..
                '</th></tr></thead>')

            prefsToggleButton(subpage_active, {
                field = "toggle_flow_rrds",
                default = "0",
                pref = "flow_device_port_rrd_creation",
                disabled = not info["version.enterprise_edition"],
                to_switch = { "row_exporters_ts_resolution", "row_exporters_ndpi_ts_creation" }
            })
            showElement = ntop.getPref("ntopng.prefs.flow_device_port_rrd_creation") == "1"
            l7_rrd_labels = { i18n("prefs.none"), i18n("prefs.per_protocol") }
            l7_rrd_values = { "none", "per_protocol" }
            multipleTableButtonPrefs(subpage_active.entries["toggle_exporters_ndpi_ts_creation"].title,
            subpage_active.entries["toggle_exporters_ndpi_ts_creation"].description, l7_rrd_labels, l7_rrd_values, "none",
            "primary", "exporters_ndpi_ts_creation", "ntopng.prefs.exporters_ndpi_ts_creation", nil,
            elementToSwitch, showElementArray, nil, showElement)

            local resolutions_labels = { "1m", "5m" }
            local resolutions_values = { "60", "300" }

            multipleTableButtonPrefs(subpage_active.entries["toggle_flow_rrds_resolution"].title,
                subpage_active.entries["toggle_flow_rrds_resolution"].description, resolutions_labels,
                resolutions_values, "300", "primary", "exporters_ts_resolution", "ntopng.prefs.exporters_ts_resolution",
                nil, nil, nil, nil, areFlowdevTimeseriesEnabled())

            prefsToggleButton(subpage_active, {
                field = "toggle_interface_usage_probes_timeseries",
                default = "1",
                pref = "interface_usage_probes_timeseries",
                disabled = not info["version.enterprise_edition"]
            })
        end

        print(
            '<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n('prefs.system_probes_timeseries') ..
            '</th></tr></thead>')

        prefsToggleButton(subpage_active, {
            field = "toggle_system_probes_timeseries",
            default = "1",
            pref = "system_probes_timeseries"
        })

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n('prefs.other_timeseries') ..
            '</th></tr></thead>')

        if ntop.isPro() then
            prefsToggleButton(subpage_active, {
                field = "toggle_intranet_traffic_rrd_creation",
                default = "0",
                pref = "intranet_traffic_rrd_creation"
            })

            prefsToggleButton(subpage_active, {
                field = "toggle_observation_points_rrd_creation",
                default = "0",
                pref = "observation_points_rrd_creation",
                disabled = not info["version.enterprise_edition"]
            })

            prefsToggleButton(subpage_active, {
                field = "toggle_pools_rrds",
                default = "0",
                pref = "host_pools_rrd_creation"
            })
        end

        prefsToggleButton(subpage_active, {
            field = "toggle_vlan_rrds",
            default = "0",
            pref = "vlan_rrd_creation"
        })

        prefsToggleButton(subpage_active, {
            field = "toggle_asn_rrds",
            default = "0",
            pref = "asn_rrd_creation"
        })

        prefsToggleButton(subpage_active, {
            field = "toggle_country_rrds",
            default = "0",
            pref = "country_rrd_creation"
        })

        if ntop.isPro() then
            prefsToggleButton(subpage_active, {
                field = "toggle_ndpi_flows_rrds",
                default = "0",
                pref = "ndpi_flows_rrd_creation"
            })
        end

        if info["version.enterprise_edition"] then
            prefsInformativeField("SNMP", i18n("prefs.snmp_timeseries_config_link", {
                url = "?tab=snmp&show_advanced_prefs=1"
            }))
        end

        prefsToggleButton(subpage_active, {
            field = "toggle_internals_rrds",
            default = "0",
            pref = "internals_rrd_creation"
        })

        print('</table>')

        print('<table class="table">')
        if show_advanced_prefs and false --[[ hide these settings for now ]] then
            print(
                '<thead class="table-primary"><tr><th colspan=2 class="info">Network Interface Timeseries</th></tr></thead>')
            prefsInputFieldPrefs("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.",
                "ntopng.prefs.", "intf_rrd_raw_days", prefs.intf_rrd_raw_days, "number", nil, nil, nil, {
                    min = 1,
                    max = 365 * 5 --[[ TODO check min/max ]]
                })
            prefsInputFieldPrefs("Days for 1 min resolution stats",
                "Number of days for which stats are kept in 1 min resolution. Default: 30.", "ntopng.prefs.",
                "intf_rrd_1min_days", prefs.intf_rrd_1min_days, "number", nil, nil, nil, {
                    min = 1,
                    max = 365 * 5 --[[ TODO check min/max ]]
                })
            prefsInputFieldPrefs("Days for 1 hour resolution stats",
                "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "ntopng.prefs.",
                "intf_rrd_1h_days", prefs.intf_rrd_1h_days, "number", nil, nil, nil, {
                    min = 1,
                    max = 365 * 5 --[[ TODO check min/max ]]
                })
            prefsInputFieldPrefs("Days for 1 day resolution stats",
                "Number of days for which stats are kept in 1 day resolution. Default: 365.", "ntopng.prefs.",
                "intf_rrd_1d_days", prefs.intf_rrd_1d_days, "number", nil, nil, nil, {
                    min = 1,
                    max = 365 * 5 --[[ TODO check min/max ]]
                })

            print(
                '<thead class="table-primary"><tr><th colspan=2 class="info">Protocol/Networks Timeseries</th></tr></thead>')
            prefsInputFieldPrefs("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.",
                "ntopng.prefs.", "other_rrd_raw_days", prefs.other_rrd_raw_days, "number", nil, nil, nil, {
                    min = 1,
                    max = 365 * 5 --[[ TODO check min/max ]]
                })
            -- prefsInputFieldPrefs("Days for 1 min resolution stats", "Number of days for which stats are kept in 1 min resolution. Default: 30.", "ntopng.prefs.", "other_rrd_1min_days", prefs.other_rrd_1min_days)
            prefsInputFieldPrefs("Days for 1 hour resolution stats",
                "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "ntopng.prefs.",
                "other_rrd_1h_days", prefs.other_rrd_1h_days, "number", nil, nil, nil, {
                    min = 1,
                    max = 365 * 5 --[[ TODO check min/max ]]
                })
            prefsInputFieldPrefs("Days for 1 day resolution stats",
                "Number of days for which stats are kept in 1 day resolution. Default: 365.", "ntopng.prefs.",
                "other_rrd_1d_days", prefs.other_rrd_1d_days, "number", nil, nil, nil, {
                    min = 1,
                    max = 365 * 5 --[[ TODO check min/max ]]
                })
        end
        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')
        print('</table>')

        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
  </form> ]]
    end

    -- ================================================================================

    function printLogging()
        if prefs.has_cmdl_trace_lvl then
            return
        end
        print('<form method="post">')
        print('<table class="table">')
        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.logging") ..
            '</th></tr></thead>')

        loggingSelector(subpage_active.entries["toggle_logging_level"].title,
            subpage_active.entries["toggle_logging_level"].description, "toggle_logging_level",
            "ntopng.prefs.logging_level")

        prefsToggleButton(subpage_active, {
            field = "toggle_log_to_file",
            default = "0",
            pref = "log_to_file"
        })

        prefsToggleButton(subpage_active, {
            field = "toggle_access_log",
            default = "0",
            pref = "enable_access_log"
        })

        prefsToggleButton(subpage_active, {
            field = "toggle_host_pools_log",
            default = "0",
            pref = "enable_host_pools_log"
        })

        if ntop.isEnterprise() or ntop.isnEdgeEnterprise() then
            prefsToggleButton(subpage_active, {
                field = "toggle_asset_inventory_log",
                default = "0",
                pref = "enable_asset_inventory_log"
            })
        end

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')

        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
  </form>
  </table>]]
    end

    function printSnmp()
        if not ntop.isPro() then
            return
        end

        print('<form method="post">')
        print('<table class="table">')
        print('<thead class="table-primary"><tr><th colspan=2 class="info">SNMP</th></tr></thead>')
        local disabled = not info["version.enterprise_edition"]

        prefsToggleButton(subpage_active, {
            field = "toggle_snmp_rrds",
            default = "0",
            pref = "snmp_devices_rrd_creation",
            disabled = disabled
        })

        prefsToggleButton(subpage_active, {
            field = "toggle_snmp_polling",
            default = "0",
            pref = "snmp_polling"
        })

        local t_labels = { "v1", "v2c" }
        local t_values = { "0", "1" }

        multipleTableButtonPrefs(subpage_active.entries["default_snmp_proto_version"].title,
            subpage_active.entries["default_snmp_proto_version"].description, t_labels, t_values, "1", "primary",
            "default_snmp_version", "ntopng.prefs.default_snmp_version", disabled)

        prefsInputFieldPrefs(subpage_active.entries["default_snmp_community"].title,
            subpage_active.entries["default_snmp_community"].description, "ntopng.prefs.", "default_snmp_community",
            "public", false, nil, nil, nil, {
                attributes = {
                    spellcheck = "false",
                    maxlength = 64
                },
                disabled = disabled
            })

        prefsInputFieldPrefs(subpage_active.entries["default_snmp_timeout"].title,
            subpage_active.entries["default_snmp_timeout"].description, "ntopng.prefs.", "snmp_timeout_sec", 3, -- default 3 sec
            "number", nil, nil, nil, {
                min = 1,
                max = 10
            })

        if (ntop.isEnterpriseL()) then
            prefsToggleButton(subpage_active, {
                field = "toggle_snmp_excluded_from_usage",
                default = "0",
                pref = "toggle_snmp_excluded_from_usage"
            })
        end

        if (ntop.isEnterpriseXL()) then
            prefsToggleButton(subpage_active, {
                field = "toggle_snmp_trap",
                default = "0",
                pref = "toggle_snmp_trap"
            })
        end

        prefsToggleButton(subpage_active, {
            field = "toggle_snmp_debug",
            default = "0",
            pref = "snmp_debug"
        })

        if (disabled) then
            prefsInformativeField(i18n("notes"), i18n("enterpriseOnly"))
        end

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')

        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
  </form>
  </table>]]
    end

    function printVulnerabilityScan()
        print('<form method="post">')
        print('<table class="table">')

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' ..
            i18n("hosts_stats.page_scan_hosts.prefs_tab_title") .. '</th></tr></thead>')

        prefsInputFieldPrefs(subpage_active.entries["vs_concurrently_scan_number"].title,
            subpage_active.entries["vs_concurrently_scan_number"].description, "ntopng.prefs.",
            "host_to_scan_max_num_scans", prefs.host_to_scan_max_num_scans or 4, "number", true, false, nil, {
                min = 1,
                max = 16
            })
        local default_vs_slow_scan_value = ternary(prefs.vs_slow_scan == false, "0", "1")
        prefsToggleButton(subpage_active, {
            field = "toggle_slow_mode",
            default = default_vs_slow_scan_value,
            pref = "vs.vs_slow_scan"
        })

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')

        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
    </form>
    </table>]]
    end

    function printDumpSettings()
        print('<form method="post">')
        print('<table class="table">')
        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.flows_dump") ..
            '</th></tr></thead>')

        local elements_to_switch = { "row_toggle_tiny_flows_dump", "max_num_packets_per_tiny_flow",
            "max_num_bytes_per_tiny_flow" }
        if prefs.is_dump_flows_to_es_enabled then
            elements_to_switch[#elements_to_switch + 1] = "dump_frequency"
        end

        prefsToggleButton(subpage_active, {
            field = "toggle_enable_runtime_flows_dump",
            default = "1",
            pref = "enable_runtime_flows_dump",
            to_switch = elements_to_switch,
            -- Similar to "to_switch" but for nested items (e.g. "local hosts cache" only
            -- enabled when both "host cache" and "cache" are enabled).
            -- The following inputs will be shown/hidden when this preference changes.
            nested_to_switch = { -- input: the input ID to toggle (e.g. the "local hosts cache")
                -- parent: the parent of the input which affects the input logic (e.g. "host cache")
                -- parent_enabled_value: the parent input value that should make the child input visible
                -- pref_enabled_value: this preference value that should make the child input visible (e.g. "1" when "cache" is enabled)
                {
                    input = "max_num_packets_per_tiny_flow",
                    parent = "input-toggle_tiny_flows_dump",
                    parent_enabled_value = "1",
                    pref_enabled_value = "1"
                }, {
                input = "max_num_bytes_per_tiny_flow",
                parent = "input-toggle_tiny_flows_dump",
                parent_enabled_value = "1",
                pref_enabled_value = "1"
            } }
        })

        local showAllElements = ntop.getPref("ntopng.prefs.enable_runtime_flows_dump") ~= "0"

        prefsInputFieldPrefs(subpage_active.entries["dump_frequency"].title,
            subpage_active.entries["dump_frequency"].description, "ntopng.prefs.", "dump_frequency",
            prefs.dump_frequency, "number", showAllElements and prefs.is_dump_flows_to_es_enabled, false, nil, {
                min = 1,
                max = 2 ^ 32 - 1,
                tformat = "sm"
            })

        prefsToggleButton(subpage_active, {
            field = "toggle_tiny_flows_dump",
            default = "1",
            pref = "tiny_flows_export_enabled",
            to_switch = { "max_num_packets_per_tiny_flow", "max_num_bytes_per_tiny_flow" },
            reverse_switch = true,
            hidden = not showAllElements
        })

        local showTinyElements = showAllElements and ntop.getPref("ntopng.prefs.tiny_flows_export_enabled") ~= "1"

        prefsInputFieldPrefs(subpage_active.entries["max_num_packets_per_tiny_flow"].title,
            subpage_active.entries["max_num_packets_per_tiny_flow"].description, "ntopng.prefs.",
            "max_num_packets_per_tiny_flow", prefs.max_num_packets_per_tiny_flow, "number", showTinyElements, false,
            nil, {
                min = 1,
                max = 2 ^ 32 - 1
            })

        prefsInputFieldPrefs(subpage_active.entries["max_num_bytes_per_tiny_flow"].title,
            subpage_active.entries["max_num_bytes_per_tiny_flow"].description, "ntopng.prefs.",
            "max_num_bytes_per_tiny_flow", prefs.max_num_bytes_per_tiny_flow, "number", showTinyElements, false, nil, {
                min = 1,
                max = 2 ^ 32 - 1
            })

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')

        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
  </form>
  </table>]]
    end

    function printClickHouseOptions()
        print('<form method="post">')
        print('<table class="table">')
        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.clickhouse") ..
            '</th></tr></thead>')

        local showAggregateFlowsPrefs = ntop.isEnterpriseXL() and ntop.isClickHouseEnabled()

        prefsInputFieldPrefs(subpage_active.entries["flow_data_retention"].title,
            subpage_active.entries["flow_data_retention"].description, "ntopng.prefs.",
            "flows_and_alerts_data_retention_days", data_retention_utils.getDefaultRetention(), "number", nil, nil, nil,
            {
                min = 1,
                max = 365 * 10
            })

        prefsInputFieldPrefs(subpage_active.entries["aggregated_flows_data_retention"].title,
            subpage_active.entries["aggregated_flows_data_retention"].description, "ntopng.prefs.",
            "aggregated_flows_data_retention_days", data_retention_utils.getAggregatedFlowsDataRetention(), "number",
            showAggregateFlowsPrefs, nil, nil, {
                min = 2,
                max = 365 * 10
            })
        prefsInputFieldPrefs(subpage_active.entries["toggle_flow_aggregated_limit"].title,
            subpage_active.entries["toggle_flow_aggregated_limit"].description, "ntopng.prefs.",
            "max_aggregated_flows_upperbound", prefs.max_aggregated_flows_upperbound or 10000, "number",
            showAggregateFlowsPrefs, false, nil, {
                min = 1000,
                max = 10000000
            })

        prefsInputFieldPrefs(subpage_active.entries["toggle_flow_aggregated_traffic_limit"].title,
            subpage_active.entries["toggle_flow_aggregated_traffic_limit"].description, "ntopng.prefs.",
            "max_aggregated_flows_traffic_upperbound", prefs.max_aggregated_flows_traffic_upperbound or 5, "number",
            showAggregateFlowsPrefs, false, nil, {
                min = 0,
                max = 5000
            })

        prefsToggleButton(subpage_active, {
            field = "toggle_flow_aggregated_alerted_flows",
            default = "0",
            pref = "include_alerted_flows_in_aggregated_flows",
            hidden = not showAggregateFlowsPrefs
        })
        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')

        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />]]
        print [[  </form>]]
        print [[  </table>]]
    end

    function printNames()
        print('<form method="post">')
        print('<table class="table">')

        -- ######################

        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.names") ..
            '</th></tr></thead>')

        local ntopng_host_info = ntop.getHostInformation()
        prefsInputFieldPrefs(subpage_active.entries["ntopng_host_address"].title,
            subpage_active.entries["ntopng_host_address"].description, "ntopng.prefs.", "ntopng_host_address",
            ntopng_host_info.ip or "", -- default
            false, true, nil, nil, {
                attributes = {
                    spellcheck = "false"
                },
                required = false
            })

        prefsInputFieldPrefs(subpage_active.entries["ntopng_instance_name"].title,
            subpage_active.entries["ntopng_instance_name"].description, "ntopng.prefs.", "ntopng_instance_name",
            ntopng_host_info.instance_name or "", -- default
            false, true, nil, nil, {
                attributes = {
                    spellcheck = "false"
                },
                required = false,
                disabled = true,
                skip_redis = true
            })
        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')

        print('</table>')
        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />]]
        print('</form>')
    end

    function printMessageBroker()
        local title = i18n("prefs.message_broker")
        local current_brokers_pref = "ntopng.prefs.selected_message_broker"
        local lint_preference = "message_broker"
        local showElement = (ntop.getPref("ntopng.prefs.toggle_message_broker") == "1")
        local brokers_list = {
            names = { i18n('prefs.nats') --[[, i18n('prefs.mqtt')]] },
            ids = { 'nats' --[[, 'mqtt']] }
        }
        local elementsToSwitch = { "row_message_broker", "message_broker_url", "message_broker_username",
            "message_broker_password", "message_broker_topics_list" }
        if (_POST["toggle_message_broker"]) then
            showElement = (_POST["toggle_message_broker"] == "1")
        end

        create_table()

        add_section(title)

        prefsToggleButton(subpage_active, {
            field = "toggle_message_broker",
            default = "0",
            pref = "toggle_message_broker",
            to_switch = elementsToSwitch
        })

        local m_broker_type = ntop.getPref("ntopng.prefs.message_broker")
        local default_broker_id
        if (not isEmptyString(m_broker_type)) then
            default_broker_id = m_broker_type
        else
            default_broker_id = brokers_list.ids[1]
        end

        multipleTableButtonPrefs(subpage_active.entries["message_brokers_list"].title,
            subpage_active.entries["message_brokers_list"].description, brokers_list.names, brokers_list.ids,
            default_broker_id, "primary", lint_preference, "ntopng.prefs.message_broker", { nil }, nil, nil, nil,
            showElement, default_broker_id --[[show]])

        prefsInputFieldPrefs(subpage_active.entries["message_broker_url"].title,
            subpage_active.entries["message_broker_url"].description, "ntopng.prefs.", "message_broker_url",
            prefs.message_broker_url, "text",
            showElement, nil, nil, {
                attributes = {
                    spellcheck = "false"
                },
                pattern = "[^\\s]+",
                required = true
            })

        prefsInputFieldPrefs(subpage_active.entries["message_broker_username"].title,
            subpage_active.entries["message_broker_username"].description, "ntopng.prefs.", "message_broker_username",
            "", "text", showElement, nil, nil, {
                attributes = {
                    spellcheck = "false"
                },
                pattern = "[^\\s]+"
            })

        prefsInputFieldPrefs(subpage_active.entries["message_broker_password"].title,
            subpage_active.entries["message_broker_password"].description, "ntopng.prefs.", "message_broker_password",
            "", "text", showElement, nil, nil, {
                attributes = {
                    spellcheck = "false"
                },
                pattern = "[^\\s]+"
            })

        end_table()
    end

    function printAssetsInventory()
        if not ntop.isPro() then
            return
        end
        local disabled = not info["version.enterprise_edition"]
        local netbox_activation_url = ntop.getPref("ntopng.prefs.netbox_activation_url")
        local netbox_default_site = ntop.getPref("ntopng.prefs.netbox_default_site")

        if isEmptyString(netbox_activation_url) then
            netbox_activation_url = "http://localhost:8000"
        end
        if isEmptyString(netbox_default_site) then
            netbox_default_site = "Default"
        end

        print('<form id="assetsInventory" method="post">')
        print('<table class="table">')
        print('<thead class="table-primary"><tr><th colspan=2 class="info">Assets Inventory</th></tr></thead>')

        -- show or not show table entries for netbox configuration
        local showNetboxConfiguration = false

        if ntop.getPref("ntopng.prefs.toggle_netbox") == "1" then
            showNetboxConfiguration = true
        end
        if (_POST["toggle_netbox"]) then
            showNetboxConfiguration = (_POST["toggle_netbox"] == "1")

            if (showNetboxConfiguration == true) then
                package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
                local netbox_manager = require("netbox_manager")

                traceError(TRACE_NORMAL, TRACE_CONSOLE, "[NetBox] Initializing...\n")
                if (netbox_manager.netbox_initialization() == true) then
                    traceError(TRACE_NORMAL, TRACE_CONSOLE, "[NetBox] Initialization completed")
                else
                    traceError(TRACE_NORMAL, TRACE_CONSOLE, "[NetBox] Initialization failed")
                end
            end
        end

        -- ntop asset inventory
        --[[
            prefsToggleButton(subpage_active, {
                field = "toggle_ntopng_assets_inventory",
                default = "0",
                pref = "toggle_ntopng_assets_inventory",
                to_switch = {}
            })
        ]]

        -- Netbox toggle
        prefsToggleButton(subpage_active, {
            field = "toggle_netbox",
            default = "0",
            pref = "toggle_netbox",
            to_switch = { "netbox_activation_url", "netbox_default_site", "netbox_personal_access_token" }
        })

        -- (label, comment, prekey, key, default_value, _input_type, showEnabled, disableAutocomplete, allowURLs, extra)
        -- Netbox Activation URL
        -- tprint(prefs)
        -- Render the NetBox Activation URL input field
        prefsInputFieldPrefs(subpage_active.entries["netbox_activation_url"].title,
            subpage_active.entries["netbox_activation_url"].description, "ntopng.prefs.", "netbox_activation_url",
            netbox_activation_url, false, showNetboxConfiguration, nil, nil, {
                attributes = {
                    spellcheck = "false"
                },
                required = true,
                disabled = disabled
            })

        -- Render the NetBox Default Site input field
        prefsInputFieldPrefs(subpage_active.entries["netbox_default_site"].title,
            subpage_active.entries["netbox_default_site"].description, "ntopng.prefs.", "netbox_default_site",
            netbox_default_site, false, showNetboxConfiguration, nil, nil, {
                attributes = {
                    spellcheck = "false"
                },
                required = true,
                disabled = disabled
            })

        -- Netbox Personal Access token
        prefsInputFieldPrefs(subpage_active.entries["netbox_personal_access_token"].title,
            subpage_active.entries["netbox_personal_access_token"].description, "ntopng.prefs.",
            "netbox_personal_access_token", ntop.getPref("ntopng.prefs.netbox_personal_access_token") or "", "text",
            showNetboxConfiguration, nil, nil, {
                required = true,
                inputBoxWidth = "24em",
                disabled = disabled
            })

        if (disabled) then
            prefsInformativeField(i18n("notes"), i18n("enterpriseOnly"))
        end

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')

        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
  </form>
  </table>]]
    end

    function printReportsOptions()
        print('<form method="post">')
        print('<table class="table">')
        print('<thead class="table-primary"><tr><th colspan=2 class="info">' .. i18n("prefs.reports") ..
            '</th></tr></thead>')

        prefsToggleButton(subpage_active, {
            field = "toggle_enable_automatic_reports",
            default = "0",
            pref = "automatic_reports_enabled",
            to_switch = {},
            hidden = false
        })

        prefsInputFieldPrefs(subpage_active.entries["reports_data_retention_time"].title,
            subpage_active.entries["reports_data_retention_time"].description, "ntopng.prefs.",
            "reports_data_retention_days", data_retention_utils.getDefaultRetention(), "number", nil, nil, nil, {
                min = 1,
                max = 365 * 10
            })

        print(
            '<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">' ..
            i18n("save") .. '</button></th></tr>')

        print [[<input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />]]
        print [[  </form>]]
        print [[  </table>]]
    end

    print [[
       <table class="table">
         <col width="20%">
         <col width="80%">
         <tr><td style="padding-right: 20px;">]]

    print(template.gen("prefs_search.template", {
        http_prefix = ntop.getHttpPrefix(),
        placeholder = i18n("prefs.search_preferences")
    }))

    print [[
           <div class="list-group">]]
    printMenuSubpages(tab)

    local simple_view_class = (show_advanced_prefs and 'btn-secondary' or 'btn-primary active')
    local expert_view_class = (show_advanced_prefs and 'btn-primary active' or 'btn-secondary')

    print([[
           </div>
           <div class="text-center">

            <div id="prefs_toggle" class="btn-group">
              <form method='post'>
                <input name="csrf" type="hidden" value="]] .. ntop.getRandomCSRFValue() .. [[" />
                <div class="btn-group btn-toggle mt-2">
                  <button class='btn btn-sm ]] .. expert_view_class .. [[' name='show_advanced_prefs' value='true'>]] ..
        i18n("prefs.expert_view") .. [[</button>
                  <button class='btn btn-sm ]] .. simple_view_class .. [[' name='show_advanced_prefs' value='false'>]] ..
        i18n("prefs.simple_view") .. [[</button>
                </div>
              </form>

            </div>

           </div>
]])
    print [[
        </td><td colspan=2>]]

    if (tab == "in_memory") then
        printInMemory()
    end

    if (tab == "clickhouse") then
        printClickHouseOptions()
    end

    if (tab == "dump_settings") then
        printDumpSettings()
    end

    if (tab == "on_disk_ts") then
        printStatsTimeseries()
    end

    if (tab == "alerts") then
        printAlerts()
    end

    if (tab == "active_monitoring") then
        printActiveMonitoring()
    end

    if (tab == "protocols") then
        printProtocolPrefs()
    end

    if (tab == "discovery") then
        printNetworkDiscovery()
    end

    if (tab == "recording") then
        printRecording()
    end

    if (tab == "traffic_behaviour") then
        printNetworkBehaviour()
    end

    if (tab == "ot_protocols") then
        printOTProtocols()
    end

    if (tab == "names") then
        printNames()
    end

    if (tab == "message_broker") then
        printMessageBroker()
    end

    if (tab == "misc") then
        printMisc()
    end

    if (tab == "gui") then
        printGUI()
    end

    if (tab == "updates") then
        printUpdates()
    end

    if (tab == "auth") then
        printAuthentication()
    end
    if (tab == "ifaces") then
        printInterfaces()
    end
    if (tab == "logging") then
        printLogging()
    end
    if (tab == "snmp") then
        printSnmp()
    end

    if (tab == "reports") then
        printReportsOptions()
    end

    if (tab == "vulnerability_scan") then
        printVulnerabilityScan()
    end

    --[[
        if (tab == "assets_inventory") then
            printAssetsInventory()
        end
    ]]

    print [[
        </td></tr>
      </table>
]]

    dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

    print([[<script>
aysHandleForm("form", {
  disable_on_dirty: '.disable-on-dirty',
});

/* Use the validator script to override default chrome bubble, which is displayed out of window */
$("form[id!='search-host-form']").validator({disable:true});
</script>]])
end --[[ isAdministratorOrPrintErr ]]
