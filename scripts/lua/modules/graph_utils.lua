--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" ..
                   package.path

require "lua_utils"
require "db_utils"
require "rrd_paths"

local ts_utils = require("ts_utils")
local format_utils = require "format_utils"

-- ########################################################

local graph_utils = {}

-- ########################################################

-- "#0A84FF", -- Blue (information)

local function hue2rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1 / 6 then return p + (q - p) * 6 * t end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then
        return p + (q - p) * (2 / 3 - t) * 6
    end
    return p
end

-- ########################################################

function generateColorPalette(n, alpha)
    local colors = {}
    local alpha = 0.8
    
    local baseColors = {
        "#00A3FF", -- Electric blue (primary)
        "#FF3B5C", -- Neon red (critical)
        "#FF9E00", -- Vivid orange (warning)
        "#FFD600", -- Bright yellow (alerts)
        "#3DFAFF", -- Cyan (monitoring)
        "#5232FF", -- Deep purple (intelligence)
        "#00E676", -- Neon green (secure)
        "#B94FFF", -- Magenta (anomalies)
        "#0F2B46", -- Dark blue (protected)
        "#56CFE1", -- Light blue (information)
        "#FF5864", -- Coral (threat)
        "#3F51B5", -- Indigo (defense)
        "#01C8AA", -- Teal (normal)
        "#6874E8", -- Periwinkle (analysis)
        "#FFB627"  -- Amber
    }

    -- Function to convert hex to RGBA
    local function hexToRgba(hex, alpha)
        local hex = hex:gsub("#","")
        local r = tonumber("0x"..hex:sub(1,2))
        local g = tonumber("0x"..hex:sub(3,4))
        local b = tonumber("0x"..hex:sub(5,6))
        return string.format("rgba(%d, %d, %d, %.2f)", r, g, b, alpha)
    end
    
    -- Function to convert hex to hex with alpha
    local function hexToHexAlpha(hex, alpha)
        local alphaHex = string.format("%02x", math.floor(alpha * 255 + 0.5))
        return hex .. alphaHex
    end

    -- If requested colors are fewer than our base set, return a subset
    if n <= #baseColors then
        for i = 1, n do
            -- table.insert(colors, hexToRgba(baseColors[i], alpha))
            table.insert(colors, hexToHexAlpha(baseColors[i], alpha))
        end
        return colors
    end

    -- Get base colors
    for i = 1, #baseColors do 
        -- table.insert(colors, hexToRgba(baseColors[i], alpha))
        table.insert(colors, hexToHexAlpha(baseColors[i], alpha))
    end

    local saturation = 75
    local lightness = 55

    for i = #baseColors, n - 1 do
        -- Use golden angle to distribute hues 
        local hue = (i * 137.508) % 360

        -- Convert HSL to RGB
        local h = hue / 360
        local s = saturation / 100
        local l = lightness / 100

        local r, g, b

        if s == 0 then
            r, g, b = l, l, l
        else

            local q = l < 0.5 and l * (1 + s) or l + s - l * s
            local p = 2 * l - q

            r = hue2rgb(p, q, h + 1 / 3)
            g = hue2rgb(p, q, h)
            b = hue2rgb(p, q, h - 1 / 3)
        end

        local r_int = math.floor(r * 255 + 0.5)
        local g_int = math.floor(g * 255 + 0.5)
        local b_int = math.floor(b * 255 + 0.5)

        local rgba = string.format("rgba(%d, %d, %d, %.2f)", 
                                   r_int, g_int, b_int,
                                   alpha)

        local hex = string.format("#%02X%02X%02X", r_int, g_int, b_int)
        hex = hexToHexAlpha(hex, alpha)

        table.insert(colors, hex)
    end

    return colors
end

graph_utils.graph_colors = generateColorPalette(30)

function graph_utils.get_html_color(index)
    return graph_utils.graph_colors[(index % #graph_utils.graph_colors) + 1]
end

-- ########################################################

function graph_utils.breakdownBar(sent, sentLabel, rcvd, rcvdLabel,
                                  thresholdLow, thresholdHigh)
    if ((sent + rcvd) > 0) then
        sent2rcvd = round((sent * 100) / (sent + rcvd), 0)
        -- io.write("****>> "..sent.."/"..rcvd.."/"..sent2rcvd.."\n")
        if ((thresholdLow == nil) or (thresholdLow < 0)) then
            thresholdLow = 0
        end
        if ((thresholdHigh == nil) or (thresholdHigh > 100)) then
            thresholdHigh = 100
        end

        if (sent2rcvd < thresholdLow) then
            sentLabel = '<i class="fas fa-exclamation-triangle fa-lg"></i> ' ..
                            sentLabel
        elseif (sent2rcvd > thresholdHigh) then
            rcvdLabel = '<i class="fas fa-exclamation-triangle fa-lg""></i> ' ..
                            rcvdLabel
        end

        print(format_utils.createBreakdown(sent2rcvd, 100 - sent2rcvd, sentLabel, rcvdLabel))
    else
        print('&nbsp;')
    end
end

-- ########################################################

function graph_utils.percentageBar(total, value, valueLabel)
    -- io.write("****>> "..total.."/"..value.."\n")
    if ((total ~= nil) and (total > 0)) then
        pctg = round((value * 100) / total, 0)
        print(
            '<div class="progress"><div class="progress-bar bg-warning" aria-valuenow="' ..
                pctg .. '" aria-valuemin="0" aria-valuemax="100" style="width: ' ..
                pctg .. '%;">' .. valueLabel)
        print('</div></div>')
    else
        print('&nbsp;')
    end
end

-- ########################################################

function graph_utils.makeProgressBar(percentage)
    -- nan check
    if percentage ~= percentage then return "" end

    local perc_int = round(percentage)
    return
        '<span style="width: 70%; float:left"><div class="progress"><div class="progress-bar bg-warning" aria-valuenow="' ..
            perc_int .. '" aria-valuemin="0" aria-valuemax="100" style="width: ' ..
            perc_int ..
            '%;"></div></div></span><span style="width: 30%; margin-left: 15px;">' ..
            round(percentage, 1) .. ' %</span>'
end

-- ########################################################

-- ! @brief Prints stacked progress bars with a legend
-- ! @total the raw total value (associated to full bar width)
-- ! @param bars a table with elements in the following format:
-- !    - title: the item legend title
-- !    - value: the item raw value
-- !    - class: the bootstrap color class, usually: "default", "info", "danger", "warning", "success"
-- ! @param other_label optional name for the "other" part of the bar. If nil, it will not be shown.
-- ! @param formatter an optional item value formatter
-- ! @param css_class an optional css class to apply to the progress div
-- ! @skip_zero_values don't display values containing only zero
-- ! @return html for the bar
function graph_utils.stackedProgressBars(total, bars, other_label, formatter,
                                         css_class, skip_zero_values)
    local res = {}
    local cumulative = 0
    local cumulative_perc = 0
    local skip_zero_values = skip_zero_values or false
    formatter = formatter or (function(x) return x end)

    -- The bars
    res[#res + 1] =
        [[<div class=']] .. (css_class or "ntop-progress-stacked") ..
            [['><div class="progress">]]

    for _, bar in ipairs(bars) do cumulative = cumulative + bar.value end
    if cumulative > total then total = cumulative end

    for _, bar in ipairs(bars) do
        local percentage = round(bar.value * 100 / total, 2)
        if cumulative_perc + percentage > 100 then
            percentage = 100 - cumulative_perc
        end
        cumulative_perc = cumulative_perc + percentage
        if bar.class == nil then bar.class = "primary" end
        if bar.style == nil then bar.style = "" end
        if bar.link ~= nil then
            res[#res + 1] = [[<a href="]] .. bar.link .. [[" style="width:]] ..
                                percentage .. [[%;]] .. bar.style ..
                                [[" class="progress-bar bg-]] .. (bar.class) ..
                                [[" role="progressbar"></a>]]
        else
            res[#res + 1] = [[
            <div class="progress-bar bg-]] .. (bar.class) ..
                                [[" role="progressbar" style="width:]] ..
                                percentage .. [[%;]] .. bar.style ..
                                [["></div></a>]]
        end
        if bar.link ~= nil then res[#res + 1] = [[</a>]] end
    end

    res[#res + 1] = [[
      </div></div>]]

    -- The legend
    res[#res + 1] = [[<div class="ntop-progress-stacked-legend">]]

    local legend_items = bars

    if other_label ~= nil then
        legend_items = bars

        legend_items[#legend_items + 1] = {
            title = other_label,
            class = "empty",
            style = "",
            value = math.max(total - cumulative, 0)
        }
    end

    num = 0
    for _, bar in ipairs(legend_items) do
        if skip_zero_values and bar.value == 0 then goto continue end

        res[#res + 1] = [[<span>]]
        if (num > 0) then res[#res + 1] = [[<br>]] end
        if bar.link ~= nil then
            res[#res + 1] = [[<a href="]] .. bar.link .. [[">]]
        end
        res[#res + 1] = [[<span class="badge bg-]] .. (bar.class) ..
                            [[" style="]] .. bar.style .. [[">&nbsp;</span>]]
        if bar.link ~= nil then res[#res + 1] = [[</a>]] end
        res[#res + 1] =
            [[<span> ]] .. bar.title .. " (" .. formatter(bar.value) ..
                ")</span></span>"
        num = num + 1

        ::continue::
    end

    res[#res + 1] =
        [[<span style="margin-left: 0"><span></span><span>&nbsp;&nbsp;-&nbsp;&nbsp;]] ..
            i18n("total") .. ": " .. formatter(total) .. "</span></span>"

    return table.concat(res)
end

-- #################################################

-- Returns both date format strings (chart axis + range-picker) from user prefs.
-- Embed in every Vue page context so JS never needs to call date_format.lua.
function graph_utils.get_date_formats()
    local key
    if _SESSION then
        key = ntop.getPref("ntopng.user." .. (_SESSION["user"] or "") .. ".date_format")
    end
    if key == "big_endian" then
        return "YYYY/MM/DD HH:mm:ss", "Y/m/d H:i"
    elseif key == "middle_endian" then
        return "MM/DD/YYYY HH:mm:ss", "m/d/Y H:i"
    else
        return "DD/MM/YYYY HH:mm:ss", "d/m/Y H:i"
    end
end

-- #################################################

function graph_utils.drawNewGraphs(source_value_object)
    -- Import modules
    local json = require("dkjson")
    local recording_utils = require "recording_utils"
    local template_utils = require "template_utils"

    -- Interface stats
    local ifstats = interface.getStats()
    local ifid = (source_value_object.ifid) or (ifstats.id)

    -- Check extraction permissions (handles View interfaces transparently)
    local _, traffic_extraction_permitted = recording_utils.getStats(ifid)

    if source_value_object == nil then source_value_object = {} end

    -- Checking the available timeseries
    local interface_ts_enabled = ntop.getCache(
                                     "ntopng.prefs.interface_ndpi_timeseries_creation") ==
                                     "1"
    local host_ts_creation = ntop.getPref("ntopng.prefs.hosts_ts_creation") ~=
                                 nil
    local host_ts_enabled = ntop.getCache(
                                "ntopng.prefs.host_ndpi_timeseries_creation")
    local l2_ts_enabled = ntop.getPref("ntopng.prefs.l2_device_rrd_creation") ==
                              "1"
    local network_ts_enabled = true -- always enabled
    local asn_ts_enabled = ntop.getPref("ntopng.prefs.asn_rrd_creation") == "1"
    local country_ts_enabled =
        ntop.getPref("ntopng.prefs.country_rrd_creation") == "1"
    local os_ts_enabled = ntop.getPref("ntopng.prefs.os_rrd_creation") == "1"
    local vlan_ts_enabled = ntop.getPref("ntopng.prefs.vlan_rrd_creation") ==
                                "1"
    local host_pools_ts_enabled = ntop.getPref(
                                      "ntopng.prefs.host_pools_rrd_creation") ==
                                      "1"
    local system_probes_ts_enabled = ntop.getPref(
                                         "ntopng.prefs.system_probes_rrd_creation") ==
                                         "1"
    local am_ts_enabled =
        ntop.getPref("ntopng.prefs.system_probes_timeseries") == "1"
    local snmp_ts_enabled = ntop.getPref(
                                "ntopng.prefs.snmp_devices_rrd_creation") == "1"
    local flow_device_ts_enabled = ntop.getPref(
                                       "ntopng.prefs.flow_device_port_rrd_creation") ==
                                       "1"
    local obs_point_ts_enabled = ntop.getPref(
                                     "ntopng.prefs.observation_points_rrd_creation") ==
                                     "1"

    local topk_heuristic = ntop.getPref("ntopng.prefs.topk_heuristic_precision")
    local ts_driver = ntop.getPref("ntopng.prefs.timeseries_driver")

    local profile_ts_enabled = ntop.isPro() and ifstats.profiles
    local pod_ts_enabled = ifstats.has_seen_pods
    local container_ts_enabled = ifstats.has_seen_containers

    -- Checking which top timeseries are available
    local interface_has_top_protocols = (interface_ts_enabled == "both" or
                                            interface_ts_enabled ==
                                            "per_protocol" or
                                            interface_ts_enabled == "full")
    local interface_has_top_categories =
        (interface_ts_enabled == "both" or interface_ts_enabled ==
            "per_category" or interface_ts_enabled == "full")
    local host_has_top_protocols =
        (host_ts_enabled == "both" or host_ts_enabled == "per_protocol")
    local host_has_top_categories = (host_ts_enabled == "both" or
                                        host_ts_enabled == "per_category")

    local sources_types_enabled = {
        interface = true, -- always enabled
        host = host_ts_creation,
        mac = l2_ts_enabled,
        network = network_ts_enabled,
        as = asn_ts_enabled,
        country = country_ts_enabled,
        os = os_ts_enabled,
        vlan = vlan_ts_enabled,
        pool = host_pools_ts_enabled,
        system = system_probes_ts_enabled,
        profile = profile_ts_enabled,
        redis = ts_driver ~= "influxdb",
        influx = ts_driver == "influxdb",
        active_monitoring = am_ts_enabled,
        pod = pod_ts_enabled,
        container = container_ts_enabled,
        snmp_interface = snmp_ts_enabled,
        snmp_device = snmp_ts_enabled,
        flow_device = flow_device_ts_enabled,
        flow_interface = flow_device_ts_enabled,
        sflow_device = flow_device_ts_enabled,
        sflow_interface = flow_device_ts_enabled,
        observation_point = obs_point_ts_enabled,
        blacklist = true,
        nedge = ntop.isnEdge()
    }

    local sources_types_top_enabled = {
        interface = {
            top_protocols = interface_has_top_protocols or true,
            top_categories = interface_has_top_categories or true,
            top_senders = topk_heuristic ~= "disabled" or true,
            top_receivers = topk_heuristic ~= "disabled" or true
        },
        host = {
            top_protocols = host_has_top_protocols,
            top_categories = host_has_top_categories
        },
        snmp = {top_snmp_ifaces = true},
        flowdevice = {top_flowdev_ifaces = true}
    }

    local date_fmt, date_fmt_picker = graph_utils.get_date_formats()
    local context = {
        csrf = ntop.getRandomCSRFValue(),
        enable_snapshots = (source_value_object.enable_snapshots ~= false) and ntop.isEnterpriseM(),
        traffic_extraction_permitted = traffic_extraction_permitted,
        sources_types_enabled = sources_types_enabled,
        source_value_object = source_value_object,
        sources_types_top_enabled = sources_types_top_enabled,
        is_ntop_pro = ntop.isPro(),
        is_history_enabled = hasClickHouseSupport(),
        date_format = date_fmt,
        date_format_range_picker = date_fmt_picker,
    }
    local json_context = json.encode(context)
    template_utils.render("pages/vue_page.template", { vue_page_name = "PageStats", page_context = json_context })
end

-- #################################################

--
-- proto table should contain the following information:
--    string   traffic_quota
--    string   time_quota
--    string   protoName
--
-- ndpi_stats or category_stats can be nil if they are not relevant for the proto
--
-- quotas_to_show can contain:
--    bool  traffic
--    bool  time
--
function graph_utils.printProtocolQuota(proto, ndpi_stats, category_stats,
                                        quotas_to_show, show_td, hide_limit)
    local total_bytes = 0
    local total_duration = 0
    local output = {}

    if ndpi_stats ~= nil then
        -- This is a single protocol
        local proto_stats = ndpi_stats[proto.protoName]
        if proto_stats ~= nil then
            total_bytes = proto_stats["bytes.sent"] + proto_stats["bytes.rcvd"]
            total_duration = proto_stats["duration"]
        end
    else
        -- This is a category
        local cat_stats = category_stats[proto.protoName]
        if cat_stats ~= nil then
            total_bytes = cat_stats["bytes"]
            total_duration = cat_stats["duration"]
        end
    end

    if quotas_to_show.traffic then
        local bytes_exceeded = ((proto.traffic_quota ~= "0") and
                                   (total_bytes >= tonumber(proto.traffic_quota)))
        local lb_bytes = bytesToSize(total_bytes)
        local lb_bytes_quota = ternary(proto.traffic_quota ~= "0", bytesToSize(
                                           tonumber(proto.traffic_quota)),
                                       i18n("unlimited"))
        local traffic_taken = ternary(proto.traffic_quota ~= "0", math.min(
                                          total_bytes,
                                          tonumber(proto.traffic_quota)), 0)
        local traffic_remaining = math.max(
                                      tonumber(proto.traffic_quota) -
                                          traffic_taken, 0)
        local traffic_quota_ratio = 0
        if traffic_taken + traffic_remaining > 0 then
            traffic_quota_ratio = round(traffic_taken * 100 /
                                            (traffic_taken + traffic_remaining),
                                        0) or 0
        end

        if show_td then
            output[#output + 1] = [[<td class='text-end']] ..
                                      ternary(bytes_exceeded,
                                              ' style=\'color:red;\'', '') ..
                                      "><span>" .. lb_bytes ..
                                      ternary(hide_limit, "",
                                              " / " .. lb_bytes_quota) ..
                                      "</span>"
        end

        local progress_bar_with_inside_value =
            [[<div class='progress' style=']] ..
                (quotas_to_show.traffic_style or "text-align: center;") .. [['>
            <div class='progress-bar bg-warning' aria-valuenow=']] ..
                traffic_quota_ratio ..
                '\' aria-valuemin=\'0\' aria-valuemax=\'100\' style=\'width: ' ..
                traffic_quota_ratio .. '%;color:black;\'>' ..
                ternary(traffic_quota_ratio == traffic_quota_ratio --[[nan check]] ,
                        traffic_quota_ratio, 0) .. [[%
            </div>
          </div>]]

        local progress_bar_with_outside_value = [[
          <div class='progress' style=']] ..
                                                    (quotas_to_show.traffic_style or
                                                        "text-align: center;") ..
                                                    [['>
          
            <div class='progress-bar bg-warning' aria-valuenow=']] ..
                                                    traffic_quota_ratio ..
                                                    '\' aria-valuemin=\'0\' aria-valuemax=\'100\' style=\'width: ' ..
                                                    traffic_quota_ratio ..
                                                    '%;\'>' .. [[
            </div>]] ..
                                                    ternary(
                                                        traffic_quota_ratio ==
                                                            traffic_quota_ratio --[[nan check]] ,
                                                        traffic_quota_ratio, 0) ..
                                                    [[%
          </div>]]

        output[#output + 1] = ternary(traffic_quota_ratio < 50,
                                      progress_bar_with_outside_value,
                                      progress_bar_with_inside_value)
        if show_td then output[#output + 1] = ("</td>") end
    end

    if quotas_to_show.time then
        local time_exceeded = ((proto.time_quota ~= "0") and
                                  (total_duration >= tonumber(proto.time_quota)))
        local lb_duration = secondsToTime(total_duration)
        local lb_duration_quota = ternary(proto.time_quota ~= "0",
                                          secondsToTime(
                                              tonumber(proto.time_quota)),
                                          i18n("unlimited"))

        local duration_taken = ternary(proto.time_quota ~= "0", math.min(
                                           total_duration,
                                           tonumber(proto.time_quota)), 0)
        local duration_remaining =
            math.max(proto.time_quota - duration_taken, 0)
        local duration_quota_ratio = 0
        if duration_taken + duration_remaining > 0 then
            duration_quota_ratio = round(
                                       duration_taken * 100 /
                                           (duration_taken + duration_remaining),
                                       0) or 0
        end

        if show_td then
            output[#output + 1] = [[<td class='text-end']] ..
                                      ternary(time_exceeded,
                                              ' style=\'color:red;\'', '') ..
                                      "><span>" .. lb_duration ..
                                      ternary(hide_limit, "",
                                              " / " .. lb_duration_quota) ..
                                      "</span>"
        end

        output[#output + 1] = ([[
          <div class='progress' style=']] .. (quotas_to_show.time_style or "") ..
                                  [['>
            <div class='progress-bar bg-warning align-items-center justify-content-center' aria-valuenow=']] ..
                                  duration_quota_ratio ..
                                  '\' aria-valuemin=\'0\' aria-valuemax=\'100\' style=\'width: ' ..
                                  duration_quota_ratio .. '%;\'>' ..
                                  ternary(
                                      duration_quota_ratio ==
                                          duration_quota_ratio --[[nan check]] ,
                                      duration_quota_ratio, 0) .. [[%
            </div>
          </div>]])
        if show_td then output[#output + 1] = ("</td>") end
    end

    return table.concat(output, '')
end

-- #################################################

function graph_utils.poolDropdown(ifId, pool_id, exclude)
    local host_pools = require "host_pools"
    local host_pools_instance = host_pools:create()
    pool_id = tostring(pool_id)

    local output = {}
    exclude = exclude or {}

    local pools_list = host_pools_instance:get_all_pools()

    for _, pool in pairsByField(pools_list, 'name', asc) do
        pool.pool_id = tostring(pool.pool_id)

        if (not exclude[pool.pool_id]) or (pool.pool_id == pool_id) then
            output[#output + 1] = '<option value="' .. pool.pool_id .. '"'

            if pool.pool_id == pool_id then
                output[#output + 1] = ' selected'
            end

            local limit_reached = false

            if not ntop.isEnterpriseM() then
                local n_members = table.len(pool["members"])

                if n_members >= host_pools.LIMITED_NUMBER_POOL_MEMBERS then
                    limit_reached = true
                end
            end

            if exclude[pool.pool_id] or limit_reached then
                output[#output + 1] = ' disabled'
            end

            output[#output + 1] = '>' .. pool.name ..
                                      ternary(limit_reached, " (" ..
                                                  i18n(
                                                      "host_pools.members_limit_reached") ..
                                                  ")", "") .. '</option>'
        end
    end

    return table.concat(output, '')
end

-- #################################################

function graph_utils.printPoolChangeDropdown(ifId, pool_id, have_nedge)
    local output = {}

    output[#output + 1] = [[<tr>
      <th>]] .. i18n(ternary(have_nedge, "nedge.user", "host_config.host_pool")) ..
                              [[</th>
      <td>
            <select name="pool" class="form-select" style="width:20em; display:inline;">]]

    output[#output + 1] = graph_utils.poolDropdown(ifId, pool_id)

    local edit_pools_link = ternary(have_nedge,
                                    "/lua/pro/nedge/admin/nf_list_users.lua",
                                    "/lua/admin/manage_pools.lua?page=host")

    output[#output + 1] = [[
            </select>
        <a class='ms-1' href="]] .. ntop.getHttpPrefix() .. edit_pools_link ..
                              [["><i class="fas fa-edit" aria-hidden="true" title="]] ..
                              (have_nedge and i18n("edit") or '') ..
                              [["></i></a>
   </tr>]]

    print(table.concat(output, ''))
end

-- #################################################

function graph_utils.printCategoryDropdownButton(by_id, cat_id_or_name,
                                                 base_url, page_params,
                                                 count_callback, skip_unknown)
    local function count_all(cat_id, cat_name)
        local cat_protos = interface.getnDPIProtocols(tonumber(cat_id))
        return table.len(cat_protos)
    end

    cat_id_or_name = cat_id_or_name or ""
    count_callback = count_callback or count_all

    -- 'Category' button
    print(
        '\'<div class="btn-group float-right"><div class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown">' ..
            i18n("category") .. ternary(not isEmptyString(cat_id_or_name),
                                        '<span class="fas fa-filter"></span>',
                                        '') ..
            '<span class="caret"></span></div> <ul class="dropdown-menu scrollable-dropdown" role="menu" style="min-width: 90px;">')

    -- 'Category' dropdown menu
    local entries = {{text = i18n("all"), id = "", cat_id = ""}}
    entries[#entries + 1] = ""
    for cat_name, cat_id in pairsByKeys(interface.getnDPICategories()) do
        local cat_count = count_callback(cat_id, cat_name)

        if (skip_unknown and (cat_id == "0") and (cat_count > 0)) then
            -- Do not count the Unknown protocol in the Unspecified category
            cat_count = cat_count - 1
        end

        local cat_title = getCategoryLabel(cat_name, cat_id)

        if cat_count > 0 then
            entries[#entries + 1] = {
                text = cat_title .. " (" .. cat_count .. ")",
                id = cat_name,
                cat_id = cat_id
            }
        end
    end

    for _, entry in pairs(entries) do
        if entry ~= "" then
            page_params["category"] = ternary(by_id,
                                              ternary(entry.cat_id ~= "",
                                                      "cat_" .. entry.cat_id, ""),
                                              entry.id)

            print('<li><a class="dropdown-item ' ..
                      ternary(
                          cat_id_or_name ==
                              ternary(by_id, entry.cat_id, entry.id), 'active',
                          '') .. '" href="' .. getPageUrl(base_url, page_params) ..
                      '">' .. (entry.icon or "") .. entry.text .. '</a></li>')
        end
    end

    print('</ul></div>\', ')
    page_params["category"] = cat_id_or_name
end

-- #################################################

-- Convert to the format accepted by the vue Chart/Pie component
-- js_formatter: render function (e.g. 'format_bytes')
-- Input format (res):
-- [ { label = 'xxx', count = yyy }, ... ]
-- Output format:
-- { labels = [ 'xxx', ...], series = [ yyy, ... ], colors = [ ... ], ... }
function graph_utils.convert_pie_data(res, new_charts, js_formatter)
    if not new_charts then return res end
 
    local data = {}
 
    for i, v in ipairs(res) do
        local value = 0
        if v.count then
            value = v.count
        elseif v.value then
            value = v.value
        end
 
        data[#data + 1] = {
            label = v.label,
            value = value,
            url   = v.url or nil
        }
    end
 
    return data
end

-- #################################################

-- Convert to the format accepted by the vue Chart/Bar component
-- js_formatter: render function (e.g. 'format_bytes')
-- Input format (res):
-- [ { label = 'xxx', count = yyy }, ... ]
-- Output format:
-- { series = [{ data = [ yyy, ... ] }], xaxis = { categories = [ 'xxx'] } }
function graph_utils.convert_bar_data(res, new_charts, js_formatter)
    if not new_charts then return res end

    local labels = {}
    local series = {}
    local urls = {}

    for _, v in ipairs(res) do
        labels[#labels + 1] = v.label

        local value = 0
        if v.count then
            value = v.count
        elseif v.value then
            value = v.value
        end
        urls[#urls + 1] = v.url or ''
        series[#series + 1] = value
    end

    res = {
        series = {{data = series}},
        xaxis = {categories = labels},
        urls = urls,
        tooltip = {y = {formatter = js_formatter}}
    }
    return res
end

-- #################################################

-- Merge pie data from 2 data sources (compute top of tops)
function graph_utils.merge_pie_data(aggregated_data, data, max_values)
    -- Merge in temporary table
    -- Note: aggregated_data may be nil
    local items = {}
    if aggregated_data then
        for _, l in ipairs(aggregated_data.labels or {}) do
            items[l] = aggregated_data.series[_]
        end
    end
    for _, l in ipairs(data.labels or {}) do
        if items[l] then
            items[l] = items[l] + data.series[_]
        else
            items[l] = data.series[_]
        end
    end

    -- Compute tops
    data.labels = {}
    data.series = {}
    data.colors = {}
    for l, v in pairsByValues(items or {}, rev) do
        data.labels[#data.labels + 1] = l
        data.series[#data.series + 1] = v
        data.colors[#data.colors + 1] = graph_utils.get_html_color(#data.colors)
        if #data.labels >= max_values then goto done end
    end
    ::done::

    return data
end

-- #################################################

return graph_utils
