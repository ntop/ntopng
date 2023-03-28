<!--
  (C) 2013-22 - ntop.org
  -->

<template>
<div class="mb-2">
  
  <h2>{{ _i18n("nedge.rules_config_title") }}</h2>
  <br />
  <h5 class="d-inline-block">{{_i18n("nedge.page_rules_config.default policy")}}
    <span v-if="default_policy?.value == 'accept'" style="color:green;">
      {{ default_policy?.label }}
    </span>
    <span v-if="default_policy?.value == 'deny'" style="color:red;">
      {{ default_policy?.label }}
    </span>

    <small><a href="javascript:void(0)" style="margin-left: 0.5rem;" @click="show_modal_change_policy"><i class="fas fa-cog"></i></a></small>
  </h5>
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
<ModalAddRuleConfig ref="modal_add_rule_config" @add="add_rule" @edit="edit_rule"></ModalAddRuleConfig>
<ModalChangeDefaultPolicy ref="modal_change_default_policy" @apply="set_default_policy" ></ModalChangeDefaultPolicy>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import NtopUtils from "../utilities/ntop-utils";
import { default as Datatable } from "./datatable.vue";
import { default as ModalAddRuleConfig } from "./modal-nedge-add-rule-config.vue";
import { default as ModalChangeDefaultPolicy } from "./modal-nedge-change-default-policy.vue";
import { ntopng_utility, ntopng_url_manager, ntopng_status_manager } from "../services/context/ntopng_globals_services.js";

const _i18n = (t) => i18n(t);

const timeout_delete = 1 * 500;

const props = defineProps({
    url: String,
    ifid: Number,
    csrf: String,
    columns_config: Array
});

const table_config = ref({})
const table_rules = ref(null);
const modal_add_rule_config = ref(null);
const modal_change_default_policy = ref(null);
const default_policy = ref({});

onBeforeMount(async () => {
    set_datatable_config();
    load_default_policy();
});

function edit_rule(rule) {    
    const edit_url = `${http_prefix}/lua/rest/v2/edit/nedge/policy/rule.lua`;
    set_rule(rule, edit_url);
}

function add_rule(rule) {
    const add_url = `${http_prefix}/lua/rest/v2/add/nedge/policy/rule.lua`;
    set_rule(rule, add_url);
}

async function load_default_policy(policy) {
    if (policy == null) {
	const get_policy_url = `${http_prefix}/lua/rest/v2/get/nedge/policy/default.lua`;
	let policy_res = await ntopng_utility.http_request(get_policy_url);
	policy = policy_res.default_policy;
    }
    if (policy == "accept") {
	default_policy.value = {
	    value: policy,
	    label: _i18n("nedge.page_rules_config.accept"),
	};
    } else {
	default_policy.value = {
	    value: policy,
	    label: _i18n("nedge.page_rules_config.deny"),
	};    
    }
}

async function set_default_policy(policy) {
    const set_policy_url = `${http_prefix}/lua/rest/v2/set/nedge/policy/default.lua`;
    let headers = {
        'Content-Type': 'application/json'
    };
    let body = JSON.stringify({ default_policy: policy, csrf: props.csrf});
    let res = await ntopng_utility.http_request(set_policy_url, { method: "post", headers, body});
    load_default_policy(policy);
    refresh_table();    
}

function set_rule(rule, url) {
    let headers = {
        'Content-Type': 'application/json'
    };
    let body = JSON.stringify({ ...rule, csrf: props.csrf});
    
    ntopng_utility.http_request(url, { method: "post", headers, body});
    refresh_table();    
}

function show_modal_change_policy() {    
    modal_change_default_policy.value.show(default_policy.value);
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
	    modal_add_rule_config.value.show(null, default_policy.value);
	}
    });
    
    let defaultDatatableConfig = {
	table_buttons: datatableButton,
	data_url: `${props.url}?${url_params}`,
	enable_search: false,
    };
    
    let columns = [
	{ 
	    columnName: _i18n("nedge.page_rules_config.rule_id"), targets: 0, name: 'rule_id', data: 'rule_id', className: 'text-nowrap text-center', responsivePriority: 1
	}, { 
	    columnName: _i18n("nedge.page_rules_config.source"), targets: 0, name: 'source', data: 'source.value', className: 'text-nowrap text-center', responsivePriority: 1
	}, { 
	    columnName: _i18n("nedge.page_rules_config.dest"), targets: 0, name: 'dest', data: 'destination.value', className: 'text-nowrap text-center', responsivePriority: 1
	}, { 
	    columnName: _i18n("nedge.page_rules_config.direction"), targets: 0, name: 'bidirectional', data: 'bidirectional', className: 'text-nowrap text-center', responsivePriority: 1, render: function(value, type, rowData) {
		if (value == true) {
		    return _i18n("nedge.page_rules_config.bidirectional");
		} 
		return _i18n("nedge.page_rules_config.source_to_dest");
	    }
	}, { 
	    columnName: _i18n("nedge.page_rules_config.action"), targets: 0, name: 'action', data: 'action', className: 'text-nowrap text-center', responsivePriority: 1, render: function(value, type, rowData) {
		let color = "red";
		let name = _i18n(`nedge.page_rules_config.deny`);
		if (value == "accept") {
		    color = "green";
		    name =  _i18n(`nedge.page_rules_config.accept`);
		}
		return `<span style="color:${color};">${name}</span>`;
	    }
	}
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
	    modal_add_rule_config.value.show(rowData);
	},
    }
    
    return DataTableUtils.createActionButtons([
	{ class: `btn-secondary`, handler: edit_handler, handlerId: "edit_rule", icon: 'fa-edit', title: i18n('edit') },
	{ class: `btn-danger`, handler: delete_handler, handlerId: "delete_rule", icon: 'fa-trash', title: i18n('delete') },
    ]);
};

async function delete_rule(rule) {
    const add_url = `${http_prefix}/lua/rest/v2/delete/nedge/policy/rule.lua`;
    let headers = {
        'Content-Type': 'application/json'
    };
    let body = JSON.stringify({ rule_id: rule.rule_id, csrf: props.csrf});
    
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
