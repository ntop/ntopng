<!-- (C) 2024 - ntop.org     -->
<template>
    <div class="m-2 mb-3">
        <TableWithConfig ref="table_hosts_list" :table_id="table_id" :csrf="csrf" :showLoading="true"
            :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj"
            :f_sort_rows="columns_sorting" :handleLoadedColumns="handleLoadedColumns"
            @custom_event="on_table_custom_event" @rows_loaded="on_rows_loaded">
            <template v-slot:custom_header>
                <div class="dropdown d-inline-flex flex-column me-2" v-for="item in filter_table_array">
                    <span class="no-wrap filters-label"><b>{{ item["basic_label"]
                            }}</b></span>
                    <SelectSearch v-model:selected_option="item['current_option']" theme="bootstrap-5"
                        dropdown_size="small" :disabled="loading || props.locked_filters.includes(item['id'])"
                        :options="item['options']" @select_option="add_table_filter">
                    </SelectSearch>
                </div>
                <div class="d-inline-flex flex-column">
                    <!-- Little trick to have a smooth GUI, empty span so everything is on the same level -->
                    <span class="no-wrap filters-label">&nbsp;</span>
                    <div class="d-flex align-items-center">
                        <div class="btn btn-sm btn-primary" type="button" @click="reset_filters">
                            {{ _i18n('reset') }}
                        </div>
                        <Spinner :show="loading" size="1rem"></Spinner>
                    </div>
                </div>
            </template> <!-- Dropdown filters -->
        </TableWithConfig>
    </div>
</template>
<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as osUtils } from "../utilities/map/os-utils.js";
import { default as dataUtils } from "../utilities/data-utils.js";
import { default as Spinner } from "./spinner.vue";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils.js";

/* ************************************** */

const _i18n = (t) => i18n(t);
const props = defineProps({
    context: Object,
    // Filter ids (e.g. "deviceIP") whose dropdown is shown but disabled, for
    // callers that pin those filters externally (e.g. the sites dashboard
    // embeds this table already scoped to one exporter).
    locked_filters: {
        type: Array,
        default: () => [],
    },
});

// total-loaded(total_rows): fired every time the table (re)loads a page, so
// callers embedding this table (e.g. the sites dashboard's tab pill count)
// can stay in sync with the exact same recordsTotal the table itself shows,
// instead of polling active_list.lua separately.
const emit = defineEmits(["total-loaded"]);

/* ************************************** */

const loading = ref(false);
const table_id = ref('hosts_list')
const table_hosts_list = ref(null);
const csrf = props.context.csrf;
const filter_table_array = ref([]);
const filters = ref([]);
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

/*******************************************************/

/* This function dinamycally modify the columns in order to 
 * change visibility of the columns based on license and available 
 * data (e.g. flow exporters)
 */
const handleLoadedColumns = (columns) => {
    let modified_columns = columns
    if (props.context.has_vlans === false) {
        /* Remove the column QoE in case ntopng is not Enterprise L, not available/computed in that version */
        modified_columns = modified_columns.filter(element => element.id !== "vlan")
    }
    if (props.context.isNedge === false) {
        /* Remove the column QoE in case ntopng is not Enterprise L, not available/computed in that version */
        modified_columns = modified_columns.filter(element => element.id !== "location")
    }
    return modified_columns
}

/* ************************************** */

const map_table_def_columns = (columns) => {
    let map_columns = {
        "ip_address": (value, row) => {
            const host = row.host
            let ip_address = host.ip
            let icons = ''
            const url = `${http_prefix}/lua/host_details.lua?host=${host.ip}&vlan=${host.vlan.id}&mac=${host.mac.address}`

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

            // Strike throough in nEdge
            if (row.isBlocked) {
                ip_address = `<span style="text-decoration: line-through">${ip_address}</span>`;
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
        "location": (value, row) => {
            if (!dataUtils.isEmptyOrNull(value)) {
                if (value == "unknown") {
                    return value.charAt(0).toUpperCase() + value.slice(1)
                } else {
                    return value.toUpperCase()
                }
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
        if (c.id == "actions") {
            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class, row) => {

                    // handle block button
                    if (b.id === "block_host") {
                        if (props.context.isNedge) {
                            current_class[0] = row.isBlocked ? "btn-danger" : "btn-secondary";
                        } else {
                            // ntopng
                            current_class[0] = "invisible";
                        }
                    }

                    return current_class;
                }
            });
        }
    });

    return columns;
};

/* ************************************** */

function set_filters_list(res) {
    if (!res) {
        filter_table_array.value = filters.value.filter((t) => {
            if (t.show_with_key) {
                const key = ntopng_url_manager.get_url_entry(t.show_with_key)
                if (key !== t.show_with_value) {
                    return false
                }
            }
            return true
        })
    } else {
        filters.value = res.map((t) => {
            const key_in_url = ntopng_url_manager.get_url_entry(t.name);
            if (key_in_url === null) {
                ntopng_url_manager.set_key_to_url(t.name, ``);
            }
            return {
                id: t.name,
                label: t.label,
                title: t.tooltip,
                options: t.value,
                show_with_key: t.show_with_key,
                show_with_value: t.show_with_value,
            };
        });
        set_filters_list();
        return;
    }
    set_filter_array_label();
}

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

function add_table_filter(opt) {
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    refresh_table_without_loading();
    load_table_filters_array()
}

/* ************************************** */

async function load_table_filters_array() {
    loading.value = true;

    const extra_params = get_extra_params_obj();
    const url_params = ntopng_url_manager.obj_to_url_params(extra_params);
    const url = `${http_prefix}/lua/rest/v2/get/host/host_filters.lua?${url_params}`;
    const res = await ntopng_utility.http_request(url);

    set_filters_list(res)

    loading.value = false;
}

/* ************************************** */

function reset_filters() {
    filter_table_array.value.forEach((el, index) => {
        // Locked filters (e.g. deviceIP/network, pinned externally by the
        // sites dashboard) stay untouched -- Reset only clears the filters
        // the user can actually edit here.
        if (props.locked_filters.includes(el.id)) return;
        /* Getting the currently selected filter */
        ntopng_url_manager.set_key_to_url(el.id, ``);
    })
    load_table_filters_array();
    refresh_table();
}

/* ************************************** */

function columns_sorting(col, r0, r1) { }

function on_rows_loaded(res) {
    emit("total-loaded", res?.total_rows ?? null);
}

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

async function click_button_drop_host_traffic(event) {

    const host_ip = event.row.host.ip;
    const url = `${http_prefix}/lua/pro/nedge/toggle_block_host.lua?host=${host_ip}`;

    try {
        const res = await ntopng_utility.http_request(url);
        let status = res.status

        if (status == "BLOCKED") {
            event.row.isBlocked = true;
        }
        else if (status == "UNBLOCKED") {
            event.row.isBlocked = false;
        }

    } catch (err) {
        console.error("HTTP request failed:", err);
    }
}


/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_live_flows": click_button_live_flows,
        "click_button_drop_host_traffic": click_button_drop_host_traffic,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

/* ************************************** */

function refresh_table_without_loading() {
    table_hosts_list.value.refresh_table(false);
}

/* ************************************** */

function refresh_table() {
    table_hosts_list.value.refresh_table(true);
}

/* ************************************** */

onBeforeMount(() => {
    load_table_filters_array();
})

/* ************************************** */

onMounted(async () => {
    setInterval(refresh_table, 10000)
    set_filter_array_label()
});

</script>
