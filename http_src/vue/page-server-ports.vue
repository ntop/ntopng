<!--
  (C) 2013-23 - ntop.org
-->

<template>
    <div class="row">
        <div class="col-md-12 col-lg-12">
            <div class="card  card-shadow">
                <div class="card-body">
                    <div class="d-flex mb-3">
                        <div class="d-flex align-items-center ml-2 mb-2">
                            <div class="d-flex no-wrap" style="text-align:left;margin-right:1rem;min-width:25rem;">
                                <label class="my-auto me-1">{{ _i18n('protocol') }}: </label>
                                <SelectSearch v-model:selected_option="selected_criteria" :options="criteria_list"
                                    @select_option="update_criteria">
                                </SelectSearch>
                            </div>
                        </div>

                        <div class="d-flex align-items-center mb-2">
                            <div class="d-flex no-wrap" style="text-align:left;margin-right:1rem;min-width:25rem;">
                                <label class="my-auto me-1">{{ _i18n('application') }}: </label>
                                <SelectSearch v-model:selected_option="selected_application" :options="application_list"
                                    @select_option="update_port_list">
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
                    </div>
                    <div>
                        <TableWithConfig ref="table_server_ports" :csrf="csrf" :table_id="table_id"
                            :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj"
                            @custom_event="on_table_custom_event">
                            <template v-slot:custom_header>

                                <Dropdown v-for="(t, t_index) in filter_table_array"
                                    :f_on_open="get_open_filter_table_dropdown(t, t_index)"
                                    :ref="el => { filter_table_dropdown_array[t_index] = el }" :hidden="t.hidden">
                                    <!-- Dropdown columns -->
                                    <template v-slot:title>
                                        <Spinner :show="t.show_spinner" size="1rem" class="me-1"></Spinner>
                                        <a class="ntopng-truncate" :title="t.title">{{ t.label }}</a>
                                    </template>
                                    <template v-slot:menu>
                                        <a v-for="opt in t.options" style="cursor:pointer; display: block;"
                                            @click="add_table_filter(opt, $event)" class="ntopng-truncate tag-filter"
                                            :title="opt.value">

                                            <template v-if="opt.count == null">{{ opt.label }}</template>
                                            <template v-else>{{ opt.label + " (" + opt.count + ")" }}</template>
                                            </a>
                                    </template>
                                </Dropdown>
                            </template> <!-- Dropdown filters -->
                        </TableWithConfig>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import NtopUtils from "../utilities/ntop-utils.js";
import { default as Spinner } from "./spinner.vue";

import { default as TableWithConfig } from "./table-with-config.vue";
import { default as Dropdown } from "./dropdown.vue";

import { default as SelectSearch } from "./select-search.vue";
const filter_table_array = ref([]);
const filter_table_dropdown_array = ref([])

const props = defineProps({
    is_ntop_enterprise_m: Boolean,
    csrf: String,
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
const context = ref({
    csrf: props.csrf,
    ifid: props.ifid
})
const _i18n = (t) => i18n(t);

/* L4 Protocol List */
const criteria_list_def = [
    { label: _i18n("tcp"), value: 6, param: "tcp", table_id: "tcp_ports_analysis", enterprise_m: false },
    { label: _i18n("udp"), value: 17, param: "udp", table_id: "udp_ports_analysis", enterprise_m: false },
];


/* Consts */
const selected_criteria = ref(criteria_list_def[0]);
const table_id = ref('server_ports');
const selected_port = ref({});
const selected_application = ref({});
const table_server_ports = ref();

let port_list = ref([]);
let application_list = ref([]);

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

onMounted(async () => {
    let port = ntopng_url_manager.get_url_entry('port');
    let l4_proto = ntopng_url_manager.get_url_entry('protocol');
    const l7_proto = ntopng_url_manager.get_url_entry('application');  
    ntopng_url_manager.set_key_to_url('ifid', props.ifid); /* Current interface */


    if (port != null && port.localeCompare("") != 0 &&
        l4_proto != null && l4_proto.localeCompare("") != 0 &&
        l7_proto != null && l7_proto.localeCompare("") != 0) {
        
        port = Number(port);
        l4_proto = Number(l4_proto);
        selected_criteria.value = criteria_list_def.find((proto) => (proto.value == l4_proto));
        

        await update_dropdown_menus(false, l7_proto, port);

    } else {
        selected_criteria.value = criteria_list_def[0];
        await update_dropdown_menus(false);

    }

    load_table_filters_overview();
    table_server_ports.value.refresh_table();


});


const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* Function to update L4 Protocol */
async function update_criteria() {
    await update_dropdown_menus(false);
    table_server_ports.value.refresh_table();

};

/* Function to update Application */
async function update_port_list() {
    await update_dropdown_menus(true)
    table_server_ports.value.refresh_table();
}

/* Function to update port */
function update_port() {
    set_port_in_url();
    table_server_ports.value.refresh_table();
}

function set_port_in_url() {
    ntopng_url_manager.set_key_to_url("port", selected_port.value.id);
}


/* Function to load filters (Just VLANs) */
async function load_table_filters_array(action, filter) {
    let extra_params = get_extra_params_obj();
    let url_params = ntopng_url_manager.obj_to_url_params(extra_params);
    const url = `${http_prefix}/lua/pro/rest/v2/get/host/hosts_details_by_port_filters.lua?action=${action}&${url_params}`;
    let res = await ntopng_utility.http_request(url);
    return res.map((t) => {
        return {
            id: t.action || t.name,
            label: t.label,
            title: t.tooltip,
            data_loaded: action != 'overview',
            options: t.value,
            hidden: (t.value.length == 1)
        };
    });
}

const get_open_filter_table_dropdown = (filter, filter_index) => {
    return (_) => {
        load_table_filters(filter, filter_index);
    };
};

async function load_table_filters(filter, filter_index) {
    filter.show_spinner = true;
    await nextTick();
    if (filter.data_loaded == false) {
        let new_filter_array = await load_table_filters_array(filter.id, filter);
        filter.options = new_filter_array.find((t) => t.id == filter.id).options;
        await nextTick();
        let dropdown = filter_table_dropdown_array.value[filter_index];
        dropdown.load_menu();
    }
    filter.show_spinner = false;
}

async function load_table_filters_overview(action) {
    filter_table_array.value = await load_table_filters_array("overview");
    set_filter_array_label();
}

/* Function to handle actions entries */
function on_table_custom_event(event) {
    let events_managed = {
        "click_button_flows": click_button_flows,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

function click_button_flows(event) {
    live_flows(event.row.ip);
}

const live_flows = function (data) {

    let params = {
        l4proto: selected_criteria.value.value,
        server: data,
        port: selected_port.value.id,
        vlan: ntopng_url_manager.get_url_entry('vlan_id')
    };
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    const url = `${http_prefix}/lua/flows_stats.lua?${url_params}`;
    ntopng_url_manager.go_to_url(`${url}`);
};

function set_filter_array_label() {
    filter_table_array.value.forEach((el, index) => {
        if (el.basic_label == null) {
            el.basic_label = el.label;
        }

        const url_entry = ntopng_url_manager.get_url_entry(el.id)
        if (url_entry != null) {
            el.options.forEach((option) => {
                if (option.value.toString() === url_entry) {
                    el.label = `${el.basic_label}: ${option.label || option.value}`
                }
            })
        }
    })
}

function add_table_filter(opt, event) {
    event.stopPropagation();
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    set_filter_array_label();
    table_server_ports.value.refresh_table();
}

/* Function to update dropdown menus */
async function update_dropdown_menus(is_application_selected, app, port) {
    ntopng_url_manager.set_key_to_url("protocol", selected_criteria.value.value);
    const vlan_id = ntopng_url_manager.get_url_entry("vlan_id") || "";
    const url = `${http_prefix}/lua/pro/rest/v2/get/host/server_ports.lua?protocol=${selected_criteria.value.value}&ifid=${props.ifid}&vlan_id=${vlan_id}`;
    let res = await ntopng_utility.http_request(url, null, null, true);
    let ports = [];
    application_list.value = [];
    port_list.value = [];

    res.rsp.forEach((item) => {
        let name = item.l7_proto_name;
        ports.push({ label: `${item.srv_port}/${name} (${item.n_hosts})`, id: item.srv_port, application: name, application_id: item.proto_id,num_hosts: item.n_hosts, vlan_id:item.vlan_id })
    })

    ports.forEach((port) => {
        let proto_id = port.application_id;
        if (! application_list.value.find(item => item.id == proto_id)) {
            application_list.value.push({ label: port.application, id: port.application_id, value: proto_id });
        }
    })

    application_list.value.sort((a, b) => {
        let x = a.label.toLowerCase();
        let y = b.label.toLowerCase();

        if (x < y) { return -1; }
        if (x > y) { return 1; }
        return 0;
    })

    if (!is_application_selected) {
      // by default select first l7_proto
      selected_application.value =  (app == null) ? 
                                    application_list.value[0] :
                                    application_list.value.find((item) => (item.id == app));
    }
    ntopng_url_manager.set_key_to_url("application", selected_application.value.id);
    ports.forEach((item) => {
        if (item.application == selected_application.value.label)
            port_list.value.push({ label: item.id + " (" + item.num_hosts + ")", id: item.id, value: item.id, vlan_id: item.vlan_id, n_hosts: item.num_hosts });
    })

    port_list.value.sort((a, b) => {
        let x = a.id;
        let y = b.id;

        if (x < y) { return -1; }
        if (x > y) { return 1; }
        return 0;
    })

    if (port != null) {
        selected_port.value = port_list.value.find((item) => (item.id == port));
    } else {
        selected_port.value = port_list.value[0];
    }

    set_port_in_url();
}

function get_count_vlan_hosts(vlan_id) {
    let count_vlan_host = 0;
    port_list.value.forEach((item) => {
        if (item.vlan_id == vlan_id) {
            count_vlan_host = count_vlan_host + item.n_hosts
        }
    })
    return count_vlan_host;
}

/* Function to format data */
const map_table_def_columns = async (columns) => {
    let map_columns = {
        "ip": (ip, row) => {
            if (ip !== undefined) {
                return format_ip(ip, row);
            }
        },
        "name": (name, row) => {
            if (name !== undefined) {
                return format_host_name(name, row);
            }
        },
        "mac": (mac, row) => {
            if (mac !== undefined) {
                return format_mac(mac, row);
            }
        },
        "tot_traffic": (tot_traffic, row) => {
            if (tot_traffic !== undefined) {
                return NtopUtils.bytesToSize(tot_traffic);
            }
        }
    }

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
    });
    // console.log(columns);
    return columns;
};

/* Function to format IP label */
const format_ip = function (data, rowData) {
    if (data != null) {
        if (rowData.vlan_id != 0)
            return `<a href="${http_prefix}/lua/flows_stats.lua?server=${data}&vlan=${rowData.vlan_id}&port=${selected_port.value.id}">${data}@${rowData.vlan_id}</a>`;
        else
            return `<a href="${http_prefix}/lua/flows_stats.lua?server=${data}&port=${selected_port.value.id}">${data}</a>`;
    }
    return data;

}

/* Function to format MAC Address label */
const format_mac = function (data, rowData) {
    if (data != null)
        return `<a href="${http_prefix}/lua/mac_details.lua?host=${data}">${data}</a>`;
    return data;
}

/* Function to format Host Name label */
const format_host_name = function (data, rowData) {
    if (data != null) {
        if (rowData.vlan_id != 0)
            return `<a href="${http_prefix}/lua/host_details.lua?host=${rowData.ip}&vlan=${rowData.vlan_id}">${data}</a>`
        else
            return `<a href="${http_prefix}/lua/host_details.lua?host=${rowData.ip}">${data}</a>`
    }
    return data;
}

</script>
