<!-- (C) 2024 - ntop.org     -->
<template>
    <div class="m-2 mb-3">
<!--    <div class="d-flex justify-content-center align-items-center">
            <div class="col-12">
                <PietyChart ref="chart" :id="piety_id" :refresh_rate="refresh_rate">
                </PietyChart>
            </div>
        </div>
-->     <TableWithConfig ref="table_flows_list" :table_id="table_id" :csrf="csrf" :f_map_columns="map_table_def_columns"
            :get_extra_params_obj="get_extra_params_obj" :f_sort_rows="columns_sorting"
            @custom_event="on_table_custom_event" @rows_loaded="change_filter_labels">
            <template v-slot:custom_header>
                <div class="dropdown me-3 d-inline-block" v-for="item in filter_table_array">
                    <span class="no-wrap d-flex align-items-center filters-label"><b>{{ item["basic_label"]
                            }}</b></span>
                    <SelectSearch v-model:selected_option="item['current_option']" theme="bootstrap-5"
                        dropdown_size="small" :disabled="loading" :options="item['options']" @select_option="add_table_filter">
                    </SelectSearch>
                </div>
                <div class="d-flex justify-content-center align-items-center">
                    <div class="btn btn-sm btn-primary me-3" type="button" @click="reset_filters">
                        {{ _i18n('reset') }}
                    </div>
                    <Spinner :show="loading" size="1rem" class="me-1"></Spinner>
                </div>
            </template> <!-- Dropdown filters -->
        </TableWithConfig>
    </div>
</template>
<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as SelectSearch } from "./select-search.vue";
//import { default as PietyChart } from "../components/charts/piety-chart.vue";
import { default as protocolUtils } from "../utilities/map/protocol-utils.js";
import { default as alertSeverities } from "../utilities/map/alert-severities.js";
import { default as dataUtils } from "../utilities/data-utils.js";
import { default as Spinner } from "./spinner.vue";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils.js";

/* ************************************** */

const _i18n = (t) => i18n(t);
const props = defineProps({
    context: Object,
});

/* ************************************** */

const table_id = props.context?.has_exporters ? ref('flows_list_with_exporters') : ref('flows_list');
const table_flows_list = ref(null);
const csrf = props.context.csrf;
//const chart = ref(null);
const filter_table_array = ref([]);
const filters = ref([]);
const refresh_rate = 10000;
const application_thpt_url = `${http_prefix}/lua/rest/v2/get/flow/traffic_stats.lua`
const piety_id = ref("throughput_piety");
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
const loading = ref(false);
const interval_id = ref(null);

/* ************************************** */

const format_host = function (value) {
    let icons = ''
    let port_name = ` : ${value.port}`
    let process = ''
    let container = ''
    const url = `${http_prefix}/lua/host_details.lua?host=${value.ip}&vlan=${value.vlan}`

    if (!dataUtils.isEmptyOrNull(value.system_host)) {
        icons = `${icons} ${system_host_icon}`
    }
    if (!dataUtils.isEmptyOrNull(value.os)) {
        const os_icon = osUtils.getOS(value.os);
        icons = `${icons} ${os_icon.icon}`
    }
    if (!dataUtils.isEmptyOrNull(value.device_type)) {
        icons = `${icons} ${osUtils.getAssetIcon(value.device_type) || ''}`
    }
    if (!dataUtils.isEmptyOrNull(value.hidden_from_top)) {
        icons = `${icons} ${hidden_from_top_icon}`
    }
    if (!dataUtils.isEmptyOrNull(value.child_safe)) {
        icons = `${icons} ${child_safe_icon}`
    }
    if (!dataUtils.isEmptyOrNull(value.dhcp_host)) {
        icons = `${icons} ${dhcp_host_icon}`
    }
    if (!dataUtils.isEmptyOrNull(value.blocking_traffic_policy)) {
        icons = `${icons} ${blocking_quota_icon}`
    }
    if (!dataUtils.isEmptyOrNull(value.country)) {
        icons = `${icons} <a href='${http_prefix}/lua/hosts_stats.lua?country=${value.country}'><img src='${http_prefix}/dist/images/blank.gif' class='flag flag-${value.country.toLowerCase()}'></a>`
    }
    if (!dataUtils.isEmptyOrNull(value.is_blacklisted)) {
        icons = `${icons} ${blacklisted_icon}`
    }
    if (!dataUtils.isEmptyOrNull(value.crawler_bot_scanner_host)) {
        icons = `${icons} ${crawler_bot_scanner_host_icon}`
    }
    if (!dataUtils.isEmptyOrNull(value.is_multicast)) {
        icons = `${icons} ${multicast_icon}`
    }
    if (!dataUtils.isEmptyOrNull(value.localhost)) {
        icons = `${icons} ${localhost_icon}`
    }
    if (!dataUtils.isEmptyOrNull(value.remotehost)) {
        icons = `${icons} ${remotehost_icon}`
    }
    if (!dataUtils.isEmptyOrNull(value.is_blackhole)) {
        icons = `${icons} ${blackhole_icon}`
    }
    if (value.port !== 0) {
        port_name = ` : <a href="#" class="tableFilter" tag-filter="port" tag-value="${value.port}">${value.service_port || value.port}</a>`
    } else {
        port_name = ''
    }
    if (!dataUtils.isEmptyOrNull(value.process.name)) {
        process = ` <a href="${http_prefix}/lua/process_details.lua?host=${value.ip}&vlan=${value.vlan}&pid_name=${value.process.pid_name}&pid=${value.process.pid}"><i class='fas fa-terminal'></i> ${value.process.process_name}</a>`
    }
    if (!dataUtils.isEmptyOrNull(value.container.id)) {
        container = ` <a href="${http_prefix}/lua/flows_stats.lua?container=${value.container.id}"><i class='fas fa-ship'></i> ${value.container.name}</a>`
    }
    if (props.context.is_viewed) {
        return `${value.name} ${icons}${port_name}${process}${container}`
    } else {
        return `<a href=${url}>${value.name}</a> ${icons}${port_name}${process}${container}`
    }
}

const map_table_def_columns = (columns) => {
    let map_columns = {
        "flow": (value, row) => {
            const client = format_host(row.client)
            const server = format_host(row.server)
            return `${client} <i class="fas fa-exchange-alt fa-lg" aria-hidden="true"></i> ${server}`
        },
        "protocol": (value, row) => {
            value = row.application
            const name = row.verdict ? ` <strike>${value.name}</strike>` : `${value.name}`
            const l7_proto_id = (dataUtils.isEmptyOrNull(value.master_id) || value.master_id === value.app_id) ? value.app_id : `${value.master_id}.${value.app_id}`
            const application = `<a href="#" class="tableFilter" tag-filter="application" tag-value="${l7_proto_id}">${name} ${protocolUtils.formatBreedIcon(value.breed, value.encrypted)}</a> ${protocolUtils.formatConfidence(value.confidence, value.confidence_id)}`
            value = row.l4_proto
            let proto = ""
            if (value && value.name) {
                proto = row.verdict ? ` <strike>${value.name}</strike>` : `${value.name}`
            }
            proto = `<a href="#" class="tableFilter" tag-filter="l4proto" tag-value="${value.id}">${proto}</a>`
            return `${proto}:${application}`
        },
        "proto": (value, row) => {
            if (value) {
                const name = row.verdict ? ` <strike>${value}</strike>` : `${value}`
                return name
            }
            return ""
        },
        "first_seen": (value, row) => {
            if (value > 0) {
                return NtopUtils.secondsToTime((Math.round(new Date().getTime() / 1000)) - value)
            }
            return ''
        },
        "last_seen": (value, row) => {
            if (value > 0) {
                return NtopUtils.secondsToTime((Math.round(new Date().getTime() / 1000)) - value)
            }
            return ''
        },
        "score": (value, row) => {
            if (value > 0) {
                let danger_icon = ''
                if (!dataUtils.isEmptyOrNull(row.predominant_alert)) {
                    danger_icon = ` <i class="${alertSeverities.getSeverityIcon(row.predominant_alert.severity_id)}" title="${row.predominant_alert.name}"></i>`
                }
                return `${formatterUtils.getFormatter("full_number")(value)}${danger_icon}`
            }
            return ''
        },
        "traffic_breakdown": (value, row) => {
            const cli_bytes_pctg = row.bytes.cli_bytes * 100 / row.bytes.total
            const srv_bytes_pctg = (row.bytes.total - row.bytes.cli_bytes) * 100 / row.bytes.total
            return NtopUtils.createBreakdown(cli_bytes_pctg, srv_bytes_pctg, i18n('client'), i18n('server'))
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
        "info": (value, row) => {
            let info = ''
            if (!dataUtils.isEmptyOrNull(value)) {
                info = value
                const periodic_map_url = `${http_prefix}/lua/pro/enterprise/network_maps.lua?map=periodicity_map&page=table`
                if (row.periodic_flow) {
                    const address = row.client.mac ? row.client.mac : row.client.host
                    info = `${value} <a href="${periodic_map_url}&host=${address}&l7proto=${row.application.name}"><span class="badge bg-warning text-dark">${i18n("periodic_flow")}</span></a>`
                }
                if (row.application.http_method) {
                    let span_mode = "warning"
                    let color_class = "badge bg-danger"
                    if (row.application.http_method == "GET") {
                        span_mode = "success"
                    }
                    if (row.application.return_code < 400) {
                        color_class = "badge bg-success"
                    }
                    info = `<span class="badge bg-${span_mode}">${row.application.http_method}</span> <span class="${color_class}">${row.application.rsp_status_code}</span> ${info}`
                }
            }
            return info
        },
        "flow_exporter": (value) => {
            if (!dataUtils.isEmptyOrNull(value)) {
                return `<a href="${http_prefix}/lua/pro/enterprise/flowdevice_details.lua?ip=${value.device.ip}">${value.device.name}</a>`
            }
            return ''
        },
        "in_index": (value, row) => {
            if (!dataUtils.isEmptyOrNull(row.flow_exporter)) {
                let name = row.flow_exporter.in_port.name
                if (name !== row.flow_exporter.in_port.index) {
                    name = `${name} [${row.flow_exporter.in_port.index}]`
                }
                return `<a href="${http_prefix}/lua/pro/enterprise/flowdevice_details.lua?ip=${row.flow_exporter.device.ip}&snmp_port_idx=${row.flow_exporter.in_port.index}">${name}</a>`
            }
            return ''
        },
        "out_index": (value, row) => {
            if (!dataUtils.isEmptyOrNull(row.flow_exporter)) {
                let name = row.flow_exporter.out_port.name
                if (name !== row.flow_exporter.out_port.index) {
                    name = `${name} [${row.flow_exporter.out_port.index}]`
                }
                return `<a href="${http_prefix}/lua/pro/enterprise/flowdevice_details.lua?ip=${row.flow_exporter.device.ip}&snmp_port_idx=${row.flow_exporter.out_port.index}">${name}</a>`
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

function add_filter_from_table_element(e) {
    const value = e.target.getAttribute("tag-value")
    const filter = e.target.getAttribute("tag-filter")
    add_table_filter({
        key: filter,
        value: value
    })
    load_table_filters_array()
}

/* ************************************** */

function add_filters_to_rows() {
    const filters = document.querySelectorAll('.tableFilter');
    filters.forEach(filter => {
        filter.addEventListener('click', add_filter_from_table_element);
    });
}

/* ************************************** */

function change_filter_labels() {
    add_filters_to_rows()
}

/* ************************************** */

function add_table_filter(opt) {
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
//    reset_piety();
    table_flows_list.value.refresh_table();
}

/* ************************************** */

function set_filters_list(res) {
    if(!res) {
        filter_table_array.value = filters.value.filter((t) => {
        if(t.show_with_key) {
            const key = ntopng_url_manager.get_url_entry(t.show_with_key)
            if(key !== t.show_with_value) {
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

async function load_table_filters_array() {
    /* Clear the interval 2 times just in case, being this function async, 
        it could happen some strange behavior */
    clearInterval(interval_id.value);
    loading.value = true;
    let extra_params = get_extra_params_obj();
    let url_params = ntopng_url_manager.obj_to_url_params(extra_params);
    const url = `${http_prefix}/lua/rest/v2/get/flow/flow_filters.lua?${url_params}`;
    const res = await ntopng_utility.http_request(url);
    set_filters_list(res)
    loading.value = false;
    clearInterval(interval_id.value);
    interval_id.value = setInterval(refresh_table, refresh_rate)
}

/*
const reset_piety = async function () {
    await chart.value.reset();
    await chart.value.update(application_thpt_url + "?" + ntopng_url_manager.get_url_params());
}
*/

/* ************************************** */

function reset_filters() {
    filter_table_array.value.forEach((el, index) => {
        /* Getting the currently selected filter */
        ntopng_url_manager.set_key_to_url(el.id, ``);
    })
//    reset_piety();
    load_table_filters_array();
    
    table_flows_list.value.refresh_table();
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
    return `${http_prefix}/lua/flow_details.lua?flow_key=${row.key}&flow_hash_id=${row.hash_id}`
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

/* ************************************** */

function refresh_table() {
//    chart.value.update(application_thpt_url + "?" + ntopng_url_manager.get_url_params());
    table_flows_list.value.refresh_table(true);
}

/* ************************************** */

onBeforeMount(() => {
    load_table_filters_array();
})

/* ************************************** */

onMounted(() => {
    clearInterval(interval_id.value);
    interval_id.value = setInterval(refresh_table, refresh_rate)
//    chart.value.update(application_thpt_url + "?" + ntopng_url_manager.get_url_params());
});

</script>../utilities/formatter-utils.js
