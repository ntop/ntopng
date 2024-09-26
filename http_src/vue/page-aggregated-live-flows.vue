<!--
  (C) 2013-23 - ntop.org
-->

<template>
    <div class="row">
        <div class="col-md-12 col-lg-12">
            <div class="card  card-shadow">
                <div class="card-body">
                    <div class="d-flex align-items-center mb-2">
                        <div class="d-flex no-wrap" style="text-align:left;margin-right:1rem;min-width:25rem;">
                            <label class="my-auto me-1">{{ _i18n('criteria_filter') }}: </label>
                            <SelectSearch v-model:selected_option="selected_criteria" :options="criteria_list"
                                @select_option="update_criteria">
                            </SelectSearch>
                        </div>
                    </div>

                    <div>
                        <TableWithConfig ref="table_aggregated_live_flows" :csrf="csrf" :table_id="table_id"
                            :table_config_id="table_config_id" :f_map_columns="map_table_def_columns"
                            :get_extra_params_obj="get_extra_params_obj" :f_map_config="map_config">
                            <template v-slot:custom_header>
                                <div class="dropdown me-3 d-inline-block" v-for="item in filter_table_array">
                                    <span class="no-wrap d-flex align-items-center filters-label">
                                        <b>{{ item["basic_label"] }}</b>
                                    </span>
                                    <SelectSearch v-model:selected_option="item['current_option']" theme="bootstrap-5"
                                        dropdown_size="small" :disabled="loading" :options="item['options']"
                                        @select_option="add_table_filter">
                                    </SelectSearch>
                                </div>
                                <div class="d-flex justify-content-center align-items-center">
                                    <div class="btn btn-sm btn-primary mt-2 me-3" type="button" @click="reset_filters">
                                        {{ _i18n('reset') }}
                                    </div>
                                    <Spinner :show="loading" size="1rem" class="me-1"></Spinner>
                                </div>
                            </template>
                        </TableWithConfig>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, nextTick } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import NtopUtils from "../utilities/ntop-utils";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as Dropdown } from "./dropdown.vue";
import { default as Spinner } from "./spinner.vue";
import infoUtils from "../utilities/map/info-utils.js";
import { default as SelectSearch } from "./select-search.vue";

const props = defineProps({
    context: Object
});

const csrf = ref(props.context.csrf);
const _i18n = (t) => i18n(t);

const criteria_list_def = [
    { label: _i18n("application_proto"), value: 1, param: "application_protocol", table_id: "aggregated_app_proto", enterprise_m: false, search_enabled: true },
    { label: _i18n("client"), value: 2, param: "client", table_id: "aggregated_client", enterprise_m: false, search_enabled: false },
    { label: _i18n("client_server"), value: 4, param: "client_server", table_id: "aggregated_client_server", enterprise_m: true, search_enabled: false },
    { label: _i18n("client_server_application_proto"), value: 5, param: "app_client_server", table_id: "aggregated_app_client_server", enterprise_m: true, search_enabled: true },
    { label: _i18n("client_server_srv_port"), value: 7, param: "client_server_srv_port", table_id: "aggregated_client_server_srv_port", enterprise_m: false, search_enabled: false },
    { label: _i18n("client_server_srv_port_app_proto"), value: 8, param: "client_server_srv_port_app_proto", table_id: "aggregated_client_server_srv_port_app_proto", enterprise_m: false, search_enabled: false },
    { label: _i18n("info"), value: 6, param: "info", table_id: "aggregated_info", enterprise_m: true, search_enabled: true },
    { label: _i18n("server"), value: 3, param: "server", table_id: "aggregated_server", enterprise_m: false, search_enabled: false },
];

const loading = ref(false)
const table_aggregated_live_flows = ref();
const filter_table_array = ref([]);
const filter_table_dropdown_array = ref([])
const filters = ref([]);

const table_config_id = ref('aggregated_live_flows');
const table_id = computed(() => {
    if (selected_criteria.value?.value == null) { return table_config_id.value; }
    let id = `${table_config_id.value}_${selected_criteria.value.value}`;
    return id;
});
const selected_criteria = ref(criteria_list_def[0]);
let default_url_params = {};

const criteria_list = function () {
    if (props.context.is_ntop_enterprise_m) {
        return ref(criteria_list_def);
    }
    else {
        let critera_list_def_com = [];
        criteria_list_def.forEach((c) => {
            if (!c.enterprise_m)
                critera_list_def_com.push(c);
        });
        return ref(critera_list_def_com);
    }
}();

onBeforeMount(async () => {
    init_selected_criteria();
    load_table_filters_array();
});

function init_selected_criteria() {
    let aggregation_criteria = ntopng_url_manager.get_url_entry("aggregation_criteria");
    if (aggregation_criteria == null || aggregation_criteria == "") {
        return;
    }
    selected_criteria.value = criteria_list_def.find((c) => c.param == aggregation_criteria);
}

async function update_criteria() {
    ntopng_url_manager.set_key_to_url("aggregation_criteria", selected_criteria.value.param);
};

const get_extra_params_obj = () => {
    /*let params = get_url_params(active_page, per_page, columns_wrap, map_search, first_get_rows);
      set_params_in_url(params);*/
    let params = get_url_params();
    return params;
};

/* ************************************** */

function reset_filters() {
    filter_table_array.value.forEach((el, index) => {
        /* Getting the currently selected filter */
        ntopng_url_manager.set_key_to_url(el.id, ``);
    })
    load_table_filters_array();
    table_aggregated_live_flows.value.refresh_table();
}

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

function add_table_filter(opt, opt2) {
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    if (opt2) {
        ntopng_url_manager.set_key_to_url(opt2.key, `${opt2.value}`);
    }
    table_aggregated_live_flows.value.refresh_table();
    load_table_filters_array()
}

/* ************************************** */

async function load_table_filters_array() {
    loading.value = true;
    let extra_params = get_extra_params_obj();
    let url_params = ntopng_url_manager.obj_to_url_params(extra_params);
    const url = `${http_prefix}/lua/rest/v2/get/flow/aggregated_live_flows_filters.lua?${url_params}`;
    const res = await ntopng_utility.http_request(url);
    set_filters_list(res)
    loading.value = false;
}

/* ************************************** */

function get_url_params() {
    let actual_params = {
        ifid: ntopng_url_manager.get_url_entry("ifid") || props.context.ifid,
        vlan_id: ntopng_url_manager.get_url_entry("vlan_id")  /* No filter by default */,
        deviceIP: ntopng_url_manager.get_url_entry("deviceIP"),
        inIfIdx: ntopng_url_manager.get_url_entry("inIfIdx"),
        outIfIdx: ntopng_url_manager.get_url_entry("outIfIdx"),
        aggregation_criteria: ntopng_url_manager.get_url_entry("aggregation_criteria") || selected_criteria.value.param,
        host: ntopng_url_manager.get_url_entry("host") || props.context.host,
    };

    return actual_params;
}


const map_config = (config) => {
    config.enable_search = selected_criteria.value.search_enabled == true;
    return config;
};

/// methods to get columns config
const map_table_def_columns = async (columns) => {
    columns = [];
    columns.push(
        {
            sortable: false, title_i18n: 'flows_page.live_flows', name: 'flows_icon', data_field: 'live_flows', class: ['text-center'], responsivePriority: 1, render_func: (data_field, rowData) => {
                return format_flows_icon(data_field, rowData)
            }
        });

    if (selected_criteria.value.value == 1) {

        // application protocol case
        columns.push(
            {
                title_i18n: "application_proto", sortable: true, name: 'application', data_field: 'application', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {
                    return format_application_proto_guessed(data_field, rowData)
                    //return `${data_field.label_with_icons}`
                }
            },
            /*{
                title_i18n: "application_proto_guessed",sortable: false, name: 'application', data_field: 'is_not_guessed', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {
                    return format_application_proto_guessed(data_field, rowData)
                }
            }*/
        );
    }
    else if (selected_criteria.value.value == 2) {
        // client case
        columns.push(
            {
                title_i18n: "client", sortable: true, name: 'client', data_field: 'client', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {

                    return format_client_name(data_field, rowData)
                }
            });
    }
    else if (selected_criteria.value.value == 3) {
        // server case
        columns.push(
            {
                title_i18n: "last_server", sortable: true, name: 'server', data_field: 'server', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {
                    return format_server_name(data_field, rowData)
                }
            });
    }
    else if (selected_criteria.value.value == 7) {
        columns.push(
            {
                title_i18n: "client", sortable: true, name: 'client', data_field: 'client', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {
                    return format_client_name(data_field, rowData)
                }
            }, {
            title_i18n: "last_server", sortable: true, name: 'server', data_field: 'server', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {
                return format_server_name(data_field, rowData);
            }
        })
    } else if (selected_criteria.value.value == 8) {
        columns.push(

            {
                title_i18n: "client", sortable: true, name: 'client', data_field: 'client', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {
                    return format_client_name(data_field, rowData)
                }
            }, {
            title_i18n: "last_server", sortable: true, name: 'server', data_field: 'server', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {
                return format_server_name(data_field, rowData);
            }
        },
            {
                title_i18n: "application_proto", sortable: true, name: 'application', data_field: 'application', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {
                    return format_application_proto_guessed(data_field, rowData);
                    //return `${data_field.label_with_icons}`
                }
            }
        )
    }
    else if (props.context.is_ntop_enterprise_m) {
        if (selected_criteria.value.value == 4 || selected_criteria.value.value == 7) {
            columns.push(
                {
                    title_i18n: "client", sortable: true, name: 'client', data_field: 'client', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {
                        return format_client_name(data_field, rowData)
                    }
                }, {
                title_i18n: "last_server", sortable: true, name: 'server', data_field: 'server', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {
                    return format_server_name(data_field, rowData);
                }
            })
        } else if (selected_criteria.value.value == 5) {
            columns.push(
                {
                    title_i18n: "client", sortable: true, name: 'client', data_field: 'client', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {
                        return format_client_name(data_field, rowData);
                    }
                },
                {
                    title_i18n: "last_server", sortable: true, name: 'server', data_field: 'server', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {
                        return format_server_name(data_field, rowData);
                    }
                },
                {
                    title_i18n: "application_proto", sortable: true, name: 'application', data_field: 'application', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field, rowData) => {
                        return format_application_proto_guessed(data_field, rowData);
                        //return `${data_field.label_with_icons}`
                    }
                });
        } else if (selected_criteria.value.value == 6) {
            columns.push(
                {
                    title_i18n: "info", sortable: true, name: 'info', data_field: 'info', class: ['text-nowrap'], responsivePriority: 1, render_func: (data_field) => {
                        return `${infoUtils.addFlowInfoIcon(data_field.label)}`
                    }
                });
        }
    }

    if (props.context.vlans.length > 2) {
        columns.push({
            title_i18n: "vlan", sortable: true, name: 'vlan_id', data_field: 'vlan_id', class: ['text-nowrap ', 'text-center'], responsivePriority: 1, render_func: (data_field) => {
                if (data_field.id === 0 || data_field.id == undefined) {
                    const label = i18n('no_vlan')
                    return `<a href="${http_prefix}/lua/flows_stats.lua?vlan=0">${label}</a>`
                }
                else {
                    return `<a href="${http_prefix}/lua/flows_stats.lua?vlan=${data_field.id}">${data_field.label}</a>`
                }
            }
        });
    }
    columns.push({
        title_i18n: "flows", sortable: true, name: 'flows', data_field: 'flows', class: ['text-nowrap ', 'text-center'], responsivePriority: 1
    }, {
        title_i18n: "total_score", sortable: true, name: 'score', data_field: 'tot_score', class: ['text-center'], responsivePriority: 1
    });

    if (selected_criteria.value.value != 2 && selected_criteria.value.value != 4 && selected_criteria.value.value != 7)
        columns.push({ title_i18n: "clients", sortable: true, name: 'num_clients', data_field: 'num_clients', class: ['text-nowrap ', 'text-center'], responsivePriority: 1 });

    if (selected_criteria.value.value != 3 && selected_criteria.value.value != 4 && selected_criteria.value.value != 7)
        columns.push({ title_i18n: "servers", sortable: true, name: 'num_servers', data_field: 'num_servers', class: ['text-nowrap ', 'text-center'], responsivePriority: 1 });

    columns.push({
        title_i18n: "breakdown", sortable: false, name: 'breakdown', data_field: 'breakdown', class: ['text-nowrap', 'text-center'], responsivePriority: 1, render_func: (data_field) => {
            return NtopUtils.createBreakdown(data_field.percentage_bytes_sent, data_field.percentage_bytes_rcvd, i18n('sent'), i18n('rcvd'));
        }
    }, {
        title_i18n: "traffic_sent", sortable: true, name: 'bytes_sent', data_field: 'bytes_sent', class: ['text-nowrap', 'text-end'], responsivePriority: 1, render_func: (data_field) => {
            return NtopUtils.bytesToSize(data_field);
        }
    }, {
        title_i18n: "traffic_rcvd", sortable: true, name: 'bytes_rcvd', data_field: 'bytes_rcvd', class: ['text-nowrap', 'text-end'], responsivePriority: 1, render_func: (data_field) => {
            return NtopUtils.bytesToSize(data_field);
        }
    }, {
        title_i18n: "total_traffic", sortable: true, name: 'tot_traffic', data_field: 'tot_traffic', class: ['text-nowrap', 'text-end'], responsivePriority: 1, render_func: (data_field) => {
            return NtopUtils.bytesToSize(data_field);
        }
    });
    return columns;
}

/* FUNCTIONS TO FORMAT */
const format_client_name = function (data, rowData) {
    let alert_label = ''
    if (data.is_alerted) {
        alert_label = `<i class='fas fa-exclamation-triangle' style='color: #B94A48;'></i>`;
    }

    if (!data.in_memory) {
        return `${data.label} ${alert_label} ${data.extra_labels}`;
    } else {
        return `<a href="${http_prefix}/lua/flows_stats.lua?client=${data.ip}&vlan=${data.vlan_id}">${data.label}</a> ${alert_label} ${data.extra_labels} <a href="${http_prefix}/lua/host_details.lua?host=${data.ip}&vlan=${data.vlan_id}" data-bs-toggle='tooltip' title=''><i class='fas fa-laptop'></i></a>`;
    }
}

const format_server_name = function (data, rowData) {
    let alert_label = ''
    if (data.is_alerted) {
        alert_label = `<i class='fas fa-exclamation-triangle' style='color: #B94A48;'></i>`;
    }

    if (!data.in_memory) {
        if ((selected_criteria.value.value == 7 || selected_criteria.value.value == 8) && rowData.srv_port != null) {
            return `${data.label} ${alert_label} ${data.extra_labels}:${rowData.srv_port.label}`;
        } else {
            return `${data.label} ${alert_label} ${data.extra_labels}`;
        }

    } else {
        if ((selected_criteria.value.value == 7 || selected_criteria.value.value == 8) && rowData.srv_port != null) {
            return `<a href="${http_prefix}/lua/flows_stats.lua?server=${data.ip}&vlan=${data.vlan_id}">${data.label}</a> ${alert_label} ${data.extra_labels} <a href="${http_prefix}/lua/host_details.lua?host=${data.ip}&vlan=${data.vlan_id}" data-bs-toggle='tooltip' title=''><i class='fas fa-laptop'></i></a>:<a href="${http_prefix}/lua/flows_stats.lua?port=${rowData.srv_port.id}&vlan=${data.vlan_id}">${rowData.srv_port.label}</a>`;
        } else {
            return `<a href="${http_prefix}/lua/flows_stats.lua?server=${data.ip}&vlan=${data.vlan_id}">${data.label}</a> ${alert_label} ${data.extra_labels} <a href="${http_prefix}/lua/host_details.lua?host=${data.ip}&vlan=${data.vlan_id}" data-bs-toggle='tooltip' title=''><i class='fas fa-laptop'></i></a>`;

        }
    }
}

const format_flows_icon = function (data, rowData) {
    let url = ``;
    let add_host = false;
    const exporter = ntopng_url_manager.get_url_entry("deviceIP")
    const in_interface = ntopng_url_manager.get_url_entry("inIfIdx")
    const out_interface = ntopng_url_manager.get_url_entry("outIfIdx")
    
    if (props.context.host != null && props.context.host != "")
        add_host = true;
    if (selected_criteria.value.value == 1) {
        url = `${http_prefix}/lua/flows_stats.lua?application=${rowData.application.id}`;
        if (add_host) url = url + `&host=` + props.context.host;
    }
    else if (selected_criteria.value.value == 2)
        url = `${http_prefix}/lua/flows_stats.lua?client=${rowData.client.ip}&vlan=${rowData.client.vlan_id}`;
    else if (selected_criteria.value.value == 3)
        url = `${http_prefix}/lua/flows_stats.lua?server=${rowData.server.ip}&vlan=${rowData.server.vlan_id}`;
    else if (selected_criteria.value.value == 4)
        url = `${http_prefix}/lua/flows_stats.lua?client=${rowData.client.ip}&server=${rowData.server.ip}&vlan=${rowData.vlan_id.id}`;
    else if (selected_criteria.value.value == 5)
        url = `${http_prefix}/lua/flows_stats.lua?application=${rowData.application.id}&client=${rowData.client.ip}&server=${rowData.server.ip}&vlan=${rowData.vlan_id.id}`;
    else if (selected_criteria.value.value == 6) {
        url = `${http_prefix}/lua/flows_stats.lua?flow_info=${NtopUtils.stripTags(rowData.info.id)}`;
        if (add_host) url = url + `&host=` + props.context.host;
    }
    else if (selected_criteria.value.value == 7) {
        url = `${http_prefix}/lua/flows_stats.lua?client=${rowData.client.ip}&server=${rowData.server.ip}&vlan=${rowData.vlan_id.id}&srv_port=${rowData.srv_port.id}`;
    }
    else if (selected_criteria.value.value == 8) {
        url = `${http_prefix}/lua/flows_stats.lua?application=${rowData.application.id}&client=${rowData.client.ip}&server=${rowData.server.ip}&vlan=${rowData.vlan_id.id}&srv_port=${rowData.srv_port.id}`;
    }

    if (!(exporter === "")) {
        url = `${url}&deviceIP=${exporter}`
    }
    if (!(in_interface === "")) {
        url = `${url}&inIfIdx=${in_interface}`
    }
    if (!(out_interface === "")) {
        url = `${url}&outIfIdx=${out_interface}`
    }

    return `<a href=${url} class="btn btn-sm btn-info" ><i class= 'fas fa-stream'></i></a>`
}

const format_application_proto_guessed = function (data, rowData) {
    if (rowData.confidence == 0)
        return `${data.label_with_icons} <span class=\"badge bg-warning\" title=\" ` + rowData.confidence_name + `\">` + rowData.confidence_name + ` </span>`
    else if (rowData.confidence)
        return `${data.label_with_icons} <span class=\"badge bg-success\" title=\"` + rowData.confidence_name + ` \"> ` + rowData.confidence_name + `</span>`


}

</script>
