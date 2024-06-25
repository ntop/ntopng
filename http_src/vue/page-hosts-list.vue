<!-- (C) 2024 - ntop.org     -->
<template>
    <div class="m-2 mb-3">
        <TableWithConfig ref="table_hosts_list" :table_id="table_id" :csrf="csrf" :f_map_columns="map_table_def_columns"
            :get_extra_params_obj="get_extra_params_obj" :f_sort_rows="columns_sorting"
            @custom_event="on_table_custom_event" @rows_loaded="change_filter_labels">
            <template v-slot:custom_header>
                <div class="dropdown me-3 d-inline-block" v-for="item in filter_table_array">
                    <span class="no-wrap d-flex align-items-center my-auto me-2 filters-label"><b>{{ item["basic_label"] }}</b></span>
                    <!-- :key="host_filters_key" -->
                    <SelectSearch v-model:selected_option="item['current_option']" theme="bootstrap-5" 
                        dropdown_size="small" :options="item['options']"
                        @select_option="add_table_filter">
                    </SelectSearch>
                </div>
            </template> <!-- Dropdown filters -->
        </TableWithConfig>
    </div>
</template>
<script setup>
import { ref, onMounted, nextTick } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as osUtils } from "../utilities/map/os-utils.js";
import { default as dataUtils } from "../utilities/data-utils.js";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils.js";

/* ************************************** */

const props = defineProps({
    context: Object,
});

/* ************************************** */

const host_filters_key = ref(0);
const table_id = props.context?.has_vlans ? ref('hosts_list_with_vlans') : ref('hosts_list');
const table_hosts_list = ref(null);
const csrf = props.context.csrf;
const filter_table_array = ref([]);
const filter_table_dropdown_array = ref([]);
const child_safe_icon = "<font color='#5cb85c'><i class='fas fa-lg fa-child' aria-hidden='true' title='" + i18n("host_pools.children_safe") + "'></i></font>"
const system_host_icon = "<i class='fas fa-flag' title='" + i18n("system_host") + "'></i>"
const hidden_from_top_icon = "<i class='fas fa-eye-slash' title='" + i18n("hidden_from_top_talkers") + "'></i>"
const dhcp_host_icon = '<i class="fa-solid fa-bolt" title="DHCP Host"></i>'
const blacklisted_icon = "<i class='fas fa-ban fa-sm' title='" + i18n("hosts_stats.blacklisted") + "'></i>"
const crawler_bot_scanner_host_icon = "<i class='fas fa-spider fa-sm' title='" + i18n("hosts_stats.crawler_bot_scanner") + "'></i>"
const multicast_icon = "<abbr title='" + i18n("multicast") + "'><span class='badge bg-primary'>" + i18n("short_multicast") + "</span></abbr>"
const localhost_icon = "<abbr title='" + i18n("details.label_local_host") + "'><span class='badge bg-success'>" + i18n("details.label_short_local_host") + "</span></abbr>"
const remotehost_icon = "<abbr title='" + i18n("details.label_remote") + "'><span class='badge bg-secondary'>" + i18n("details.label_short_remote") + "</span></abbr>"
const blackhole_icon = "<abbr title='" + i18n("details.label_blackhole") + "'><span class='badge bg-info'>" + i18n("details.label_short_blackhole") + "</span></abbr>"
const blocking_quota_icon = "<i class='fas fa-hourglass' title='" + i18n("hosts_stats.blocking_traffic_policy_popup_msg") + "'></i>"
const thpt_trend_icons = {
    1: "<i class='fas fa-arrow-up'></i>",
    2: "<i class='fas fa-arrow-down'></i>",
    3: "<i class='fas fa-minus'></i>",
}

/* ************************************** */

const map_table_def_columns = (columns) => {
    let map_columns = {
        "ip_address": (value, row) => {
            const host = row.host
            let ip_address = host.ip
            let icons = ''
            const url = `${http_prefix}/lua/host_details.lua?host=${host.ip}&vlan=${host.vlan.id}`

            if (!dataUtils.isEmptyOrNull(host.system_host)) {
                icons = `${icons} ${system_host_icon}`
            }
            if (!dataUtils.isEmptyOrNull(host.os)) {
                const os_icon = osUtils.getOS(host.os);
                icons = `${icons} ${os_icon.icon}`
            }
            if (!dataUtils.isEmptyOrNull(host.device_type)) {
                icons = `${icons} ${osUtils.getAssetIcon(host.device_type) || ''}`
            }
            if (!dataUtils.isEmptyOrNull(host.hidden_from_top)) {
                icons = `${icons} ${hidden_from_top_icon}`
            }
            if (!dataUtils.isEmptyOrNull(host.child_safe)) {
                icons = `${icons} ${child_safe_icon}`
            }
            if (!dataUtils.isEmptyOrNull(host.dhcp_host)) {
                icons = `${icons} ${dhcp_host_icon}`
            }
            if (!dataUtils.isEmptyOrNull(host.blocking_traffic_policy)) {
                icons = `${icons} ${blocking_quota_icon}`
            }
            if (!dataUtils.isEmptyOrNull(host.country)) {
                icons = `${icons} <a href='${http_prefix}/lua/hosts_stats.lua?country=${host.country}'><img src='${http_prefix}/dist/images/blank.gif' class='flag flag-${host.country.toLowerCase()}'></a>`
            }
            if (!dataUtils.isEmptyOrNull(host.is_blacklisted)) {
                icons = `${icons} ${blacklisted_icon}`
            }
            if (!dataUtils.isEmptyOrNull(host.crawler_bot_scanner_host)) {
                icons = `${icons} ${crawler_bot_scanner_host_icon}`
            }
            if (!dataUtils.isEmptyOrNull(host.is_multicast)) {
                icons = `${icons} ${multicast_icon}`
            }
            if (!dataUtils.isEmptyOrNull(host.localhost)) {
                icons = `${icons} ${localhost_icon}`
            }
            if (!dataUtils.isEmptyOrNull(host.remotehost)) {
                icons = `${icons} ${remotehost_icon}`
            }
            if (!dataUtils.isEmptyOrNull(host.is_blackhole)) {
                icons = `${icons} ${blackhole_icon}`
            }
            return `<a href=${url}>${ip_address}</a> ${icons}`
        },
        "num_flows": (value, row) => {
            if (value > 0) {
                return formatterUtils.getFormatter("full_number")(value)
            }
            return ''
        },
        "alerts": (value, row) => {
            if (value > 0) {
                return formatterUtils.getFormatter("full_number")(value) + " <i class='fas fa-exclamation-triangle' style='color: #B94A48;'></i>"
            }
            return ''
        },
        "vlan": (value, row) => {
            const vlan = row.host.vlan
            if (!dataUtils.isEmptyOrNull(vlan.name)) {
                return vlan.name
            }
            if (!dataUtils.isEmptyOrNull(vlan.id)) {
                return vlan.id
            }
            return ''
        },
        "num_cves": (value, row) => {
            if (value > 0) {
                return formatterUtils.getFormatter("full_number")(value)
            }
            return ''
        },
        "tcp_unresp_as_server": (value, row) => {
            if (value > 0) {
                return formatterUtils.getFormatter("full_number")(value)
            }
            return ''
        },
        "hostname": (hostname, row) => {
            let name = hostname.name
            if (!dataUtils.isEmptyOrNull(hostname.alt_name)) {
                name = hostname.alt_name
                if (hostname.alt_name != hostname.name && !dataUtils.isEmptyOrNull(hostname.name)) {
                    name = `${name} [${hostname.name}]`
                }
            }

            return name
        },
        "first_seen": (value, row) => {
            if (value > 0) {
                return NtopUtils.secondsToTime((Math.round(new Date().getTime() / 1000)) - value)
            }
            return ''
        },
        "score": (value, row) => {
            if (value > 0) {
                return formatterUtils.getFormatter("full_number")(value)
            }
            return ''
        },
        "traffic_breakdown": (value, row) => {
            const sent_pctg = row.bytes.sent * 100 / row.bytes.total
            const rcvd_pctg = row.bytes.rcvd * 100 / row.bytes.total
            return NtopUtils.createBreakdown(sent_pctg, rcvd_pctg, i18n('sent'), i18n('rcvd'))
        },
        "throughput": (value, row) => {
            let return_value = ''
            if (value.type === 'bps' && !dataUtils.isEmptyOrNull(value.bps)) {
                return_value = formatterUtils.getFormatter("bps")(value.bps)
            } else if (value.type === 'pps' && !dataUtils.isEmptyOrNull(value.pps)) {
                return_value = formatterUtils.getFormatter("pps")(value.pps)
            }
            if (!dataUtils.isEmptyOrNull(return_value) && !dataUtils.isEmptyOrNull(value.trend)) {
                return_value = `${return_value} ${thpt_trend_icons[value.trend]}`
            }
            return return_value
        },
        "bytes": (value, row) => {
            if (!dataUtils.isEmptyOrNull(value.total)) {
                return formatterUtils.getFormatter("bytes")(value.total)
            }
            return ''
        },
    };
    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
    });

    return columns;
};

/* ************************************** */

function set_filter_array_label() {
    filter_table_array.value.forEach((el, index) => {
        /* Setting the basic label */
        if (el.basic_label == null) {
            el.basic_label = el.label;
        }

        /* Getting the currently selected filter */
        const url_entry = ntopng_url_manager.get_url_entry(el.id)
        el.options.forEach((option) => {
            if (option.value.toString() === url_entry) {
                el.current_option = option;
            }
        })
    })
}

/* ************************************** */

function change_filter_labels() {
    set_filter_array_label()
}

/* ************************************** */

async function add_table_filter(opt) {
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    set_filter_array_label();
    table_hosts_list.value.refresh_table();
    filter_table_array.value = await load_table_filters_array()
}

/* ************************************** */

const get_open_filter_table_dropdown = (filter, filter_index) => {
    return (_) => {
        load_table_filters(filter, filter_index);
    };
};

/* ************************************** */

async function load_table_filters(filter, filter_index) {
    filter.show_spinner = true;
    await nextTick();
    filter.options = filter_table_array.value.find((t) => t.id == filter.id).options;
    await nextTick();
    let dropdown = filter_table_dropdown_array.value[filter_index];
    dropdown.load_menu();
    filter.show_spinner = false;
}

/* ************************************** */

async function load_table_filters_array() {
    let extra_params = get_extra_params_obj();
    let url_params = ntopng_url_manager.obj_to_url_params(extra_params);
    const url = `${http_prefix}/lua/rest/v2/get/host/host_filters.lua?${url_params}`;
    let res = await ntopng_utility.http_request(url);
    host_filters_key.value = host_filters_key.value + 1
    return res.map((t) => {
        const key_in_url = ntopng_url_manager.get_url_entry(t.name);
        if(dataUtils.isEmptyOrNull(key_in_url)) {
            ntopng_url_manager.set_key_to_url(t.name, ``);
        }
        return {
            id: t.name,
            label: t.label,
            title: t.tooltip,
            options: t.value,
            hidden: (t.value.length == 1)
        };
    });
}

/* ************************************** */

function columns_sorting(col, r0, r1) { }

/* ************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

function create_config_url_link(row) {
    return `${http_prefix}/lua/host_details.lua?host=${row.host.ip}&vlan=${row.host.vlan.id}&page=flows`
}

/* ************************************** */

function click_button_live_flows(event) {
    const row = event.row;
    window.open(create_config_url_link(row));
}

/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_live_flows": click_button_live_flows,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

function refresh_table() {
    table_hosts_list.value.refresh_table(true);
}

/* ************************************** */

onMounted(async () => {
    setInterval(refresh_table, 10000)
    filter_table_array.value = await load_table_filters_array();
    set_filter_array_label()
});

</script>
