<!--
  (C) 2013-22 - ntop.org
  -->

<template>
<div class="mb-2">
  
  <h2>{{ _i18n("nedge.repeaters_config_title") }}</h2>
  <br />
  
</div>

<div id="aggregated_live_flows">
  <Datatable ref="table_rules"
	     :table_buttons="table_config.table_buttons"
	     :columns_config="table_config.columns_config"
	     :data_url="table_config.data_url"
	     :filter_buttons="table_config.table_filters"
	     :enable_search="table_config.enable_search"
	     :table_config="table_config.table_config">
  </Datatable>
</div>
<ModalAddRepeaterConfig ref="modal_add_repeater_config" @add="add_repeater" @edit="edit_repeater"></ModalAddRepeaterConfig>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import NtopUtils from "../utilities/ntop-utils";
import { default as Datatable } from "./datatable.vue";
import { default as ModalAddRepeaterConfig } from "./modal-nedge-add-repeater-config.vue";
import { ntopng_utility, ntopng_url_manager, ntopng_status_manager } from "../services/context/ntopng_globals_services.js";

const _i18n = (t) => i18n(t);

const timeout_delete = 1 * 500;

const props = defineProps({
    url: String,
    ifid: Number,
    csrf: String,
    columns_config: Array
});

const table_config = ref({});
const table_rules = ref(null);
const modal_add_repeater_config = ref(null);

onBeforeMount(async () => {
    set_datatable_config();
});

function edit_repeater(repeater) {    
    const edit_url = `${http_prefix}/lua/rest/v2/edit/nedge/forwarder.lua`;
    set_rule(repeater, edit_url);
}

function add_repeater(repeater) {
    const add_url = `${http_prefix}/lua/rest/v2/add/nedge/forwarder.lua`;
    set_rule(repeater, add_url);
}


function set_rule(rule, url) {
    let headers = {
        'Content-Type': 'application/json'
    };
    let body = JSON.stringify({ ...rule, csrf: props.csrf});
    
    ntopng_utility.http_request(url, { method: "post", headers, body});
    refresh_table();    
}



const format_interfaces = function(data, rowData) { 
    return data.split(",").join(", ");
}
function set_datatable_config() {
    const datatableButton = [];
    
    let params = { 
	ifid: ntopng_url_manager.get_url_entry("ifid") || props.ifid,	
    };
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    
    datatableButton.push({
	text: '<i class="fas fa-sync"></i>',
	className: 'btn-link',
	action: function (e, dt, node, config) {
	    refresh_table();
            // table_rules.value.reload();
	}
    }, {
	text: '<i class="fas fa-plus"></i>',
	className: 'btn-link',
	action: function () {
	    modal_add_repeater_config.value.show(null);
	}
    });
    
    let defaultDatatableConfig = {
	table_buttons: datatableButton,
	data_url: `${props.url}?${url_params}`,
	enable_search: false,
    };
    
    let columns = [
	 { 
	    columnName: _i18n("nedge.page_repeater_config.type"), targets: 0, name: 'type', data: 'type', className: 'text-nowrap text-left', responsivePriority: 1
	},
     { 
	    columnName: _i18n("nedge.page_repeater_config.ip"), targets: 0, name: 'ip', data: 'ip', className: 'text-nowrap text-left', responsivePriority: 1
	},
     { 
	    columnName: _i18n("nedge.page_repeater_config.port"), targets: 0, name: 'port', data: 'port', className: 'text-nowrap text-left', responsivePriority: 1
	},
    {
	    columnName: _i18n("nedge.page_repeater_config.interfaces"), targets: 0, name: 'interfaces', data: 'details', className: 'text-nowrap text-left', responsivePriority: 1, render: function (data,_,rowData)  {
		    return format_interfaces(data, rowData)}
	},
    ];
    let wrap_columns_config = columns.map((c) => c);
    // let wrap_columns_config = props.columns_config.map((c) => c);
    wrap_columns_config.push({ columnName: _i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, render: function (_, type, rowData) { return add_action_column(rowData) } });
    
    defaultDatatableConfig.columns_config = wrap_columns_config;
    table_config.value = defaultDatatableConfig;
}

const add_action_column = function (rowData) {
    let delete_handler = {
	handlerId: "delete_host",	  
	onClick: () => {
	    delete_rule(rowData);
	},
    };
    
    let edit_handler = {
	handlerId: "edit_rule",
	onClick: () => {
	    modal_add_repeater_config.value.show(rowData);
	},
    }
    
    return DataTableUtils.createActionButtons([
	{ class: `pointer`, handler: edit_handler, handlerId: "edit_rule", icon: 'fa-edit', title: i18n('edit') },
	{ class: `pointer`, handler: delete_handler, handlerId: "delete_rule", icon: 'fa-trash', title: i18n('delete') },
    ]);
};

function delete_rule(repeater) {
    const add_url = `${http_prefix}/lua/rest/v2/delete/nedge/forwarder.lua`;
    let headers = {
        'Content-Type': 'application/json'
    };
    let body = JSON.stringify({ repeater_id: repeater.repeater_id, csrf: props.csrf});
    
    ntopng_utility.http_request(add_url, { method: "post", headers, body});
    refresh_table();    
}

function refresh_table() {
    setTimeout(() => {
	ntopng_url_manager.reload_url();
 	// table_rules.value.reload();
    }, timeout_delete);
}
</script>
