<!--
  (C) 2013-23 - ntop.org
-->

<template>
    <div class="row">
        <div class="col-md-12 col-lg-12">
            <div class="card  card-shadow">
                <!-- <Loading ref="loading"></Loading> -->
                <div class="card-body">
                    <div class="d-flex align-items-center ml-2 mb-2">
                        <div class="d-flex no-wrap" style="text-align:left;margin-right:1rem;min-width:25rem;">
                            <label class="my-auto me-4">{{ _i18n('protocol') }}: </label>
                            <SelectSearch v-model:selected_option="selected_criteria" :options="criteria_list"
                                @select_option="update_criteria">
                            </SelectSearch>
                        </div>
                    </div>

                    <div class="d-flex align-items-center mb-2">
                        <div class="d-flex no-wrap" style="text-align:left;margin-right:1rem;min-width:25rem;">
                            <label class="my-auto me-1">{{ _i18n('db_search.tags.srv_port') }}: </label>
                            <SelectSearch v-model:selected_option="selected_port" :options="port_list"
                                @select_option="update_port">
                            </SelectSearch>
                        </div>
                    </div>

                    <div>
                        <Table ref="table_hosts_ports_analysis" id="table_hosts_ports_analysis"
                                :key="table_config.columns" :columns="table_config.columns"
                                :get_rows="table_config.get_rows"
                                :get_column_id="(col) => table_config.get_column_id(col)"
                                :print_column_name="(col) => table_config.print_column_name(col)"
                                :print_html_row="(col, row) => table_config.print_html_row(col, row)"
                                :f_is_column_sortable="is_column_sortable"
                                :enable_search="true"
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
    { label: _i18n("udp"), value: 17, param: "udp", table_id: "udp_ports_analysis", enterprise_m: false },
    { label: _i18n("tcp"), value: 6, param: "client", table_id: "tcp_ports_analysis", enterprise_m: false },
];

const loading = ref(null)
const table_aggregated_live_flows = ref(null);

const selected_criteria = ref(criteria_list_def[0]);
const table_config = ref({})
const selected_port = ref({});
let port_list = ref([]);
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
    init_selected_criteria();

    load_table();
});

function update_port() {
    ntopng_url_manager.set_key_to_url("protocol", selected_criteria.value.value);

    if( selected_port.value != undefined && 
        selected_port.value != null &&
        selected_port.value.id != undefined && 
        selected_port.value.id != null)
        ntopng_url_manager.set_key_to_url("port", selected_port.value.id);
    load_table();
}

async function init_selected_criteria() {
    let aggregation_criteria = ntopng_url_manager.get_url_entry("aggregation_criteria");
    if (aggregation_criteria == null || aggregation_criteria == "") {
        return;
    }
    selected_criteria.value = criteria_list_def.find((c) => c.param == aggregation_criteria);
    ntopng_url_manager.set_key_to_url("protocol", selected_criteria.value.value);
    const url = `${http_prefix}/lua/pro/rest/v2/get/host/server_ports.lua?protocol=`+selected_criteria.value.value;
    let res = await ntopng_utility.http_request(url, null, null, true);
    let ports = []
    res.rsp.forEach((item) => {
        let name = item.l7_proto_name.split(".")[0];
        ports.push({label: item.srv_port+"/"+name+" ("+item.n_hosts+")", id: item.srv_port})
    })
    port_list.value = ports;
    selected_port.value = port_list.value[0];
    if( selected_port.value != undefined && 
        selected_port.value != null &&
        selected_port.value.id != undefined && 
        selected_port.value.id != null)        
        ntopng_url_manager.set_key_to_url("port", selected_port.value.id);    
    //load_table();

}

async function update_criteria() {

    const url = `${http_prefix}/lua/pro/rest/v2/get/host/server_ports.lua?protocol=`+selected_criteria.value.value;
    let res = await ntopng_utility.http_request(url, null, null, true);
    let ports = []
    res.rsp.forEach((item) => {
        let name = item.l7_proto_name.split(".")[0];
        ports.push({label: item.srv_port+"/"+name+" ("+item.n_hosts+")", id: item.srv_port})
    })
    port_list.value = ports;
    selected_port.value = port_list.value[0];
    ntopng_url_manager.set_key_to_url("protocol", selected_criteria.value.value);
    if( selected_port.value != undefined && 
        selected_port.value != null &&
        selected_port.value.id != undefined && 
        selected_port.value.id != null)        
        ntopng_url_manager.set_key_to_url("port", selected_port.value.id);    
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
    ntopng_url_manager.set_key_to_url("protocol", selected_criteria.value.value);
    let url;
    let res;
    
    if (selected_port.value == null || selected_port.value == undefined || selected_port.value.value == undefined) {
        url = `${http_prefix}/lua/pro/rest/v2/get/host/server_ports.lua?protocol=`+selected_criteria.value.value;
        res = await ntopng_utility.http_request(url, null, null, true);
        let ports = []
        res.rsp.forEach((item) => {
            let name = item.l7_proto_name.split(".")[0];
            ports.push({label: item.srv_port+"/"+name+" ("+item.n_hosts+")", id: item.srv_port})
        })
        port_list.value = ports;
        selected_port.value = port_list.value[0];   
    }
    //selected_port.value = selected_port.value;
     
    if( selected_port.value != undefined && 
        selected_port.value != null &&
        selected_port.value.id != undefined && 
        selected_port.value.id != null) {
            
        ntopng_url_manager.set_key_to_url("port", selected_port.value.id);
        url = `${http_prefix}/lua/pro/rest/v2/get/host/hosts_details_by_port.lua?${url_params}&protocol=`+selected_criteria.value.value+`&port=`+selected_port.value.id;

    } else {
        url = `${http_prefix}/lua/pro/rest/v2/get/host/hosts_details_by_port.lua?${url_params}&protocol=`+selected_criteria.value.value;
    }       
    res = await ntopng_utility.http_request(url, null, null, true);
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

/// methods to get columns config
function get_table_columns_config() {
    let columns = [];

    
    columns.push({
        columnName: i18n("prefs.ip_order"), targets: 0, name: 'ip', data: 'ip', className: 'text-nowrap text-center', responsivePriority: 1, render: (data,_, rowData) => {
            return format_ip(data, rowData);
        }
    }, 
    {
        columnName: i18n("db_explorer.host_name"), targets: 0, name: 'name', data: 'name', className: 'text-nowrap text-center', responsivePriority: 1, render: (data,_, rowData) => {
            return format_host_name(data, rowData);
        }
    },
    {
        columnName: i18n("mac_details.mac"), targets: 0, name: 'mac', data: 'mac', className: 'text-nowrap text-center', responsivePriority: 1, render: (data,_, rowData) => {
            return format_mac(data, rowData);
        }
    },
    {
        columnName: i18n("total_score_host_page"), targets: 0, name: 'score', data: 'score', className: 'text-nowrap text-center', responsivePriority: 1
    },
    {
        columnName: i18n("db_explorer.total_flows"), targets: 0, name: 'flows', data: 'flows', className: 'text-nowrap text-end', responsivePriority: 1
    },
    {
        columnName: i18n("total_traffic"), targets: 0, name: 'tot_traffic', data: 'tot_traffic', className:  'text-nowrap text-end', responsivePriority: 1, render: (data) => {
            return NtopUtils.bytesToSize(data);
        }
    },
    );

    
    return columns;
}

const format_ip = function(data, rowData) {
    if(data != null) {
        if(rowData.vlan_id != 0)
            return `<a href="${http_prefix}/lua/flows_stats.lua?server=${data}&vlan=${rowData.vlan_id}&port=${selected_port.value.id}">${data}@${rowData.vlan_id}</a>`;
        else    
            return `<a href="${http_prefix}/lua/flows_stats.lua?server=${data}&port=${selected_port.value.id}">${data}</a>`;
    } 
    return data;
    
}

const format_mac = function(data, rowData) {
    if (data != null)
        return `<a href="${http_prefix}/lua/mac_details.lua?host=${data}">${data}</a>`;
    return data;
}

const format_host_name = function(data, rowData) {
    if(data != null) {
        if(rowData.vlan_id != 0)
            return `<a href="${http_prefix}/lua/host_details.lua?host=${rowData.ip}&vlan=${rowData.vlan_id}">${data}</a>`
        else    
            return `<a href="${http_prefix}/lua/host_details.lua?host=${rowData.ip}">${data}</a>`
    }
    return data;    
}


</script>
