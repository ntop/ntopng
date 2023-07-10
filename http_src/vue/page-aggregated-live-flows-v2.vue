<!--
  (C) 2013-23 - ntop.org
-->

<template>
    <div class="row">
        <div class="col-md-12 col-lg-12">
            <div class="card  card-shadow">
                <!-- <Loading ref="loading"></Loading> -->
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
                        <Table ref="table_aggregated_live_flows" id="table_aggregated_live_flows"
                               :key="table_config.columns" :columns="table_config.columns"
                               :get_rows="table_config.get_rows"
                               :get_column_id="(col) => table_config.get_column_id(col)"
                               :print_column_name="(col) => table_config.print_column_name(col)"
			       :print_html_row="(col, row) => table_config.print_html_row(col, row)"
			       :f_get_column_classes="get_column_classes"
			       :f_is_column_sortable="is_column_sortable"
			       :enable_search="true"
                   :display_empty_rows="true"
			       :paging="true">
                        </Table>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import NtopUtils from "../utilities/ntop-utils";
import { default as Datatable } from "./datatable.vue";
import { default as Table } from "./table.vue";
import { default as Loading } from "./loading.vue";
import { default as SelectSearch } from "./select-search.vue";

const props = defineProps({
    is_ntop_enterprise_m: Boolean,
    vlans: Array,
    ifid: Number,
    aggregation_criteria: String,
    page: Number,
    sort: String,
    order: String,
    start: Number,
    length: Number,
    host: String,
});

const _i18n = (t) => i18n(t);

const criteria_list_def = [
    { label: _i18n("application_proto"), value: 1, param: "application_protocol", table_id: "aggregated_app_proto", enterprise_m: false },
    { label: _i18n("client"), value: 2, param: "client", table_id: "aggregated_client", enterprise_m: false },
    { label: _i18n("server"), value: 3, param: "server", table_id: "aggregated_server", enterprise_m: false },
    { label: _i18n("client_server"), value: 4, param: "client_server", table_id: "aggregated_client_server", enterprise_m: true },
    { label: _i18n("application_proto_client_server"), value: 5, param: "app_client_server", table_id: "aggregated_app_client_server", enterprise_m: true },
    { label: _i18n("info"), value: 6, param: "info", table_id: "aggregated_info", enterprise_m: true }
];

const loading = ref(null)
const table_aggregated_live_flows = ref(null);

const selected_criteria = ref(criteria_list_def[0]);
const table_config = ref({})
let default_url_params = {};

const criteria_list = function () {
    if (props.is_ntop_enterprise_m) {
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
});

onMounted(async () => {
    load_table();
});

function init_selected_criteria() {
    let aggregation_criteria = ntopng_url_manager.get_url_entry("aggregation_criteria");
    if (aggregation_criteria == null || aggregation_criteria == "") {
        return;
    }
    selected_criteria.value = criteria_list_def.find((c) => c.param == aggregation_criteria);
}

function update_criteria() {
    ntopng_url_manager.set_key_to_url("aggregation_criteria", selected_criteria.value.param);
    load_table();
};

function load_table() {
    table_config.value = {
        columns: get_table_columns_config(),
        get_rows: get_rows,
        get_column_id: get_column_id,
        print_column_name: print_column_name,
        print_html_row: print_html_row,
        paging: true,
    };
}

function get_column_id(col) {
    return col.data;
}

function print_column_name(col) {
    if (col.columnName == null || col.columnName == "") {
        return "";
    }
    return col.columnName;
}

let counter = 0;
function print_html_row(col, row) {
    // console.log(`counter: ${counter}; col: ${col.data}; row:${row[col.data]}`);
    counter += 1;
    let data = row[col.data];
    if (col.render != null) {
        return col.render(data, null, row);
    }
    return data;
}

const get_rows = async (active_page, per_page, columns_wrap, map_search, first_get_rows) => {
    // loading.value.show_loading();

    let params = get_url_params(active_page, per_page, columns_wrap, map_search, first_get_rows);
    set_params_in_url(params);
    const url_params = ntopng_url_manager.obj_to_url_params(params);
    const url = `${http_prefix}/lua/rest/v2/get/flow/aggregated_live_flows.lua?${url_params}`;
    let res = await ntopng_utility.http_request(url, null, null, true);
    // if (res.rsp.length > 0) { res.rsp[0].server_name.alerted = true };

    return { total_rows: res.recordsTotal, rows: res.rsp };

    // loading.value.hide_loading();
};

function set_params_in_url(params) {
    ntopng_url_manager.add_obj_to_url(params);
}

function get_url_params(active_page, per_page, columns_wrap, map_search, first_get_rows) {
    let sort_column = columns_wrap.find((c) => c.sort != 0);

    let actual_params = {
        ifid: ntopng_url_manager.get_url_entry("ifid") || props.ifid,
        vlan_id: ntopng_url_manager.get_url_entry("vlan_id") || '-1' /* No filter by default */,
        aggregation_criteria: ntopng_url_manager.get_url_entry("aggregation_criteria") || selected_criteria.value.param,
        page: ntopng_url_manager.get_url_entry("page") || props.page,
        sort: ntopng_url_manager.get_url_entry("sort") || props.sort,
        order: ntopng_url_manager.get_url_entry("order") || props.order,
        host: ntopng_url_manager.get_url_entry("host") || props.host,
        start: (active_page * per_page),
        length: per_page,
	map_search,
    };
    if (first_get_rows == false) {
        if (sort_column != null) {
            actual_params.sort = sort_column.data.data;
            actual_params.order = sort_column.sort == 1 ? "asc" : "desc";
        }
        // actual_params.start = (active_page * per_page);
        // actual_params.length = per_page;
    }

    return actual_params;
}

const is_column_sortable = (col) => {
    return col.data != "breakdown" && col.name != 'flows_icon' ;
};

const get_column_classes = (col) => {
    if (col.className == null || col.className == "") {
	return [];
    }
    return col.className.split(" ");
}

/// methods to get columns config
function get_table_columns_config() {
    let columns = [];

    columns.push(
        {
            orderable: false, targets: 0, name: 'flows_icon', data: 'client', className: 'text-center', responsivePriority: 1, render: (data, _, rowData) => {
                return format_flows_icon(data, rowData)
            }
        });

    if (selected_criteria.value.value == 1) {

        // application protocol case
        columns.push(
            {
                columnName: i18n("application_proto"), targets: 0, name: 'application', data: 'application', className: 'text-nowrap', responsivePriority: 1, render: (data) => {
                    return `${data.label_with_icons}`
                }
            }, 
            {
                columnName: i18n("application_proto_guessed"), targets: 0, name: 'application', data: 'is_not_guessed', className: 'text-nowrap', responsivePriority: 1, render: (data, _, rowData) => {
                    return format_application_proto_guessed(data, rowData)
                }
            }
            );
    }
    else if (selected_criteria.value.value == 2) {
        // client case
        columns.push(
            {
                columnName: i18n("client"), targets: 0, name: 'client', data: 'client', className: 'text-nowrap', responsivePriority: 1, render: (data, _, rowData) => {

                    return format_client_name(data, rowData)
                }
            });
    }
    else if (selected_criteria.value.value == 3) {
        // server case
        columns.push(
            {
                columnName: i18n("last_server"), targets: 0, name: 'server', data: 'server', className: 'text-nowrap', responsivePriority: 1, render: (data, _, rowData) => {
                    return format_server_name(data, rowData)
                }
            });
    }
    else if (props.is_ntop_enterprise_m) {
        if (selected_criteria.value.value == 4) {
            columns.push(
                {
                    columnName: i18n("client"), targets: 0, name: 'client', data: 'client', className: 'text-nowrap', responsivePriority: 1, render: (data, _, rowData) => {
                        return format_client_name(data, rowData)
                    }
                }, {
                columnName: i18n("last_server"), targets: 0, name: 'server', data: 'server', className: 'text-nowrap', responsivePriority: 1, render: (data, _, rowData) => {
                    return format_server_name(data, rowData)
                }
            })
        } else if (selected_criteria.value.value == 5) {
            columns.push(
                {
                    columnName: i18n("application_proto"), targets: 0, name: 'application', data: 'application', className: 'text-nowrap', responsivePriority: 1, render: (data) => {
                        return `${data.label_with_icons}`
                    }
                }, {
                columnName: i18n("client"), targets: 0, name: 'client', data: 'client', className: 'text-nowrap', responsivePriority: 1, render: (data, _, rowData) => {
                    return format_client_name(data, rowData)
                }
            }, {
                columnName: i18n("last_server"), targets: 0, name: 'server', data: 'server', className: 'text-nowrap', responsivePriority: 1, render: (data, _, rowData) => {
                    return format_server_name(data, rowData)
                }
            });
        } else if (selected_criteria.value.value == 6) {
            columns.push(
                {
                    columnName: i18n("info"), targets: 0, name: 'info', data: 'info', className: 'text-nowrap', responsivePriority: 1, render: (data) => {

                        return `${data.label}`
                    }
                });
        }
    }

    if (props.vlans.length > 0) {
        columns.push({
            columnName: i18n("vlan"), targets: 0, name: 'vlan_id', data: 'vlan_id', className: 'text-nowrap text-center', responsivePriority: 1, render: (data) => {
                if (data.id === 0 || data.id == undefined) {
                    const label = i18n('no_vlan')
                    return `<a href="${http_prefix}/lua/flows_stats.lua?vlan=0">${label}</a>`
                }
                else{
                    return `<a href="${http_prefix}/lua/flows_stats.lua?vlan=${data.id}">${data.label}</a>`
                }
            }
        });
    }
    columns.push({
        columnName: i18n("flows"), targets: 0, name: 'flows', data: 'flows', className: 'text-nowrap text-center', responsivePriority: 1
    }, {
        columnName: i18n("total_score"), targets: 0, name: 'score', data: 'tot_score', className: 'text-center', responsivePriority: 1
    });

    if (selected_criteria.value.value != 2 && selected_criteria.value.value != 4)
        columns.push({ columnName: i18n("clients"), targets: 0, name: 'num_clients', data: 'num_clients', className: 'text-nowrap text-center', responsivePriority: 1 });

    if (selected_criteria.value.value != 3 && selected_criteria.value.value != 4)
        columns.push({ columnName: i18n("servers"), targets: 0, name: 'num_servers', data: 'num_servers', className: 'text-nowrap text-center', responsivePriority: 1 });

    columns.push({
        columnName: i18n("breakdown"), targets: 0, sorting: false, name: 'breakdown', data: 'breakdown', className: 'text-nowrap text-center', responsivePriority: 1, render: (data) => {
            return NtopUtils.createBreakdown(data.percentage_bytes_sent, data.percentage_bytes_rcvd, i18n('sent'), i18n('rcvd'));
        }
    }, {
        columnName: i18n("traffic_sent"), targets: 0, name: 'bytes_sent', data: 'bytes_sent', className: 'text-nowrap text-end', responsivePriority: 1, render: (data) => {
            return NtopUtils.bytesToSize(data);
        }
    }, {
        columnName: i18n("traffic_rcvd"), targets: 0, name: 'bytes_rcvd', data: 'bytes_rcvd', className: 'text-nowrap text-end', responsivePriority: 1, render: (data) => {
            return NtopUtils.bytesToSize(data);
        }
    }, {
        columnName: i18n("total_traffic"), targets: 0, name: 'tot_traffic', data: 'tot_traffic', className: 'text-nowrap text-end', responsivePriority: 1, render: (data) => {
            return NtopUtils.bytesToSize(data);
        }
    });
    return columns;
}

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
        return `${data.label} ${alert_label} ${data.extra_labels}`;
    } else {
        return `<a href="${http_prefix}/lua/flows_stats.lua?server=${data.ip}&vlan=${data.vlan_id}">${data.label}</a> ${alert_label} ${data.extra_labels} <a href="${http_prefix}/lua/host_details.lua?host=${data.ip}&vlan=${data.vlan_id}" data-bs-toggle='tooltip' title=''><i class='fas fa-laptop'></i></a>`;
    }
}

const format_flows_icon = function (data, rowData) {
    let url = ``;
    let add_host = false;
    if(props.host != null && props.host != "" )
        add_host = true;
    if (selected_criteria.value.value == 1) {
        url = `${http_prefix}/lua/flows_stats.lua?application=${rowData.application.id}`;
        if (add_host) url = url + `&host=`+props.host;
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
        url = `${http_prefix}/lua/flows_stats.lua?flow_info=${rowData.info.id}`;
        if (add_host) url = url + `&host=`+props.host;

    }


    return `<a href=${url} class="btn btn-sm btn-info" ><i class= 'fas fa-stream'></i></a>`
}

const format_application_proto_guessed = function (data, rowData) {
    if(rowData.confidence == 0 )
        return `<span class=\"badge bg-warning\" title=\" `+ rowData.confidence_name + `\">`+ rowData.confidence_name + ` </span>`
    else if (rowData.confidence)
        return `<span class=\"badge bg-success\" title=\"`+ rowData.confidence_name + ` \"> `+ rowData.confidence_name + `</span>`
    
        
}

</script>
