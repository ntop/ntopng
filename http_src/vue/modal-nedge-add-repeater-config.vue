<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>{{title}}</template>
  <template v-slot:body>

      <!-- Repeater Type -->
		<div class="form-group ms-2 me-2 mt-3 row">
				<label class="col-form-label col-sm-3">
					<b>{{_i18n("nedge.page_repeater_config.modal_repeater_config.repeater_type")}}</b>
				</label>
				<div class="col-7">
				<SelectSearch v-model:selected_option="selected_repeater_type"
					@select_option="change_repeater_type()"
					:options="repeater_type_array">
				</SelectSearch>
				</div>
		</div>
      
      <!-- IP -->
	

		<div v-if="selected_repeater_type.value == 'custom'" >
				<div class="form-group ms-2 me-2 mt-3 row">

					<label class="col-form-label col-sm-3" >
						<b>{{_i18n("nedge.page_repeater_config.ip")}}</b>
					</label>
					<div class="col-7">
	      	<input v-model="ip"  @focusout="check_empty_host" class="form-control col-7" type="text" :placeholder="host_placeholder" required>
					</div>
				</div>
		</div>
            
						
			<!-- Port -->
	

		<div v-if="selected_repeater_type.value == 'custom'" >
			<div class="form-group ms-2 me-2 mt-3 row">

				<label class="col-form-label col-sm-3" >
					<b>{{_i18n("nedge.page_repeater_config.port")}}</b>
				</label>
				<div class="col-7">

	      <input v-model="port"  @focusout="check_empty_port" class="form-control" type="text" :placeholder="port_placeholder" required>
				</div>

    	</div>
		</div>

	<!-- Keep Source Address -->
	

		<div v-if="selected_repeater_type.value == 'custom'" >
      <div class="form-group ms-2 me-2 mt-3 row">

				<label class="col-form-label col-sm-3" >
					<b>{{_i18n("nedge.page_repeater_config.keep_src_address")}}</b>
				</label>

				<label class="switch col-1 mt-3">
					<input type="checkbox" v-model="keep_src_address">
				</label>
			</div>
		</div>

		<div class="form-group ms-2 me-2 mt-3 row">
	
			<label class="col-form-label col-sm-3" >
				<b>{{_i18n("nedge.page_repeater_config.interfaces")}}</b>
	    </label>
			<div class="col-7">

				<SelectSearch ref="interfaces_search"
						v-model:selected_options="selected_interfaces"
						:options="interface_array"
                          :multiple="true"
                          @select_option="update_interfaces_selected"
                          @unselect_option="remove_interfaces_selected"
                          @change_selected_options="all_criteria">
            </SelectSearch>
	

			</div>
		</div>


  </template>
  <template v-slot:footer>
    <button type="button" :disabled="disable_add" @click="apply" class="btn btn-primary">{{button_text}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";
import regexValidation from "../utilities/regex-validation.js";

const _i18n = (t) => i18n(t);
const host_placeholder = i18n('if_stats_config.multicast_ip_placeholder')
const port_placeholder = i18n('if_stats_config.port_placeholder')
const modal_id = ref(null);
const selected_interfaces = ref([]);
const ip = ref(null);
const port = ref(null);
const repeater_type = ref({value: "mdns", label: "MDNS" });
const emit = defineEmits(['edit', 'add'])
const interfaces_search = ref(null);
const keep_src_address = ref(false);

const showed = () => {};

const props = defineProps({});

const disable_add = ref(true);
const invalid_iface_number = ref(true);
const not_valid_ip = ref(true);
const not_valid_port = ref(true);

const check_empty_host = () => {
  let regex = new RegExp(regexValidation.get_data_pattern('ip'));
  not_valid_ip.value = !(regex.test(ip.value) || ip.value === '*');
	disable_add.value = update_disable_add();
}

const check_empty_port = () => {
	not_valid_port.value = (port.value < 1 || port.value > 65535);
	disable_add.value = update_disable_add();
}

const update_disable_add = () => {
	if (repeater_type.value.value == 'custom') {
		return (invalid_iface_number.value || not_valid_ip.value || not_valid_port.value);
	} else {
		return (invalid_iface_number.value);
	}
}

const title = ref("");

const repeater_type_array = [
    { label: _i18n("nedge.page_repeater_config.modal_repeater_config.mdns"), value: "mdns", default: true },
    { label: _i18n("nedge.page_repeater_config.modal_repeater_config.custom"), value: "custom" },
];

const repeater_id = ref(0);

const selected_repeater_type = ref({});


const interface_list_url = `${http_prefix}/lua/rest/v2/get/nedge/interfaces.lua`;
let interface_list;
const interface_array = ref([]);


const button_text = ref("");

const all_criteria = (item) => {
	invalid_iface_number.value = item.length < 2;
	disable_add.value = update_disable_add();
}

const update_interfaces_selected = (items) => {
	selected_interfaces.value = items;
}

const remove_interfaces_selected = (item_to_delete) => {
	selected_interfaces.value = selected_interfaces.value.filter((item) => item.label != item_to_delete.label);
}

const reset_modal = () => {
	selected_repeater_type.value = {};
	ip.value = "";
	port.value = "";
	selected_interfaces.value = [];
	not_valid_port.value = true;
	not_valid_ip.value = true;
	invalid_iface_number.value = true;
}

const show = (row ) => {
	reset_modal();
    init(row);
    modal_id.value.show();
};

const is_open_in_add = ref(true);

function init(row) {
    is_open_in_add.value = row == null;

    // check if we need open in edit
    if (is_open_in_add.value == false) {
			not_valid_port.value = false;
			not_valid_ip.value = false;
			invalid_iface_number.value = false;
			disable_add.value = false;
			title.value = _i18n("nedge.page_rules_config.modal_rule_config.title_edit");
			button_text.value = _i18n("edit");
			repeater_id.value = row.repeater_id;
			selected_repeater_type.value = repeater_type_array.find((s) => (s.label == row.type));
			if (selected_repeater_type.value.value == 'custom') {
				ip.value = row.ip;
				port.value = row.port;
			}
			keep_src_address.value = row.keep_src_address;
			change_repeater_type(row)

    } else {
			title.value = _i18n("nedge.page_rules_config.modal_rule_config.title_add");
			button_text.value = _i18n("add");
			let default_type = repeater_type_array.find((s) => s.default == true);
    }
		
		if (is_open_in_add.value == false) {
			const row_interfaces = row.interfaces.split(",");
			let tmp_selected_interfaces = [];
			row_interfaces.forEach((row_iface) => {
				if (row_iface != '' && row_iface != null) {
					tmp_selected_interfaces.push(interface_array.value.find((iface) => iface.value == row_iface));
				}
			})

			selected_interfaces.value = tmp_selected_interfaces;
		}
}

async function change_repeater_type(type) {
		repeater_type.value = selected_repeater_type.value;
    if (repeater_type.value.value == "custom") {
			await set_interface_array();
		}
}



let is_set_interface_array = false;
async function set_interface_array() {
    if (is_set_interface_array == true) { return; }
	if (interface_list == null) {
	    interface_list = ntopng_utility.http_request(interface_list_url);
	}
	let res_interface_list = await interface_list;
	interface_array.value = res_interface_list.filter(i => i.role == "lan").map((i) => {
			return {
		label: i.label,
		value: i.ifname,
			};
	});
    is_set_interface_array = true;
}


const apply = () => {
    let repeater_t = repeater_type.value.label;
		let keep_src_address_t = keep_src_address.value;
    let obj = {
			repeater_type: repeater_t,
    };
		if (repeater_type.value.value == "custom") {
			let ip_t = ip.value;
			let port_t = port.value;
			obj = {
				repeater_type: repeater_t,
				ip: ip_t,
				port: port_t,
				keep_src_address: keep_src_address_t
    	};
		}
    let event = "add";
    if (is_open_in_add.value == false) {
	obj.repeater_id = repeater_id.value;
	event = "edit";
    }

	let interfaces = [];
	let details = [];
	
	selected_interfaces.value.forEach((i) => {
		interfaces.push(i.value);
		
		if(i.value != i.label && !i.label.includes(i.value)) {
			details.push(i.label+" ("+i.value+")");
		} else {
			details.push(i.label);
		}
	});

	const tmp_interfaces = interfaces.join(",");
	const tmp_details = details.join(",");

	obj.interfaces = tmp_interfaces;
	obj.interface_details = tmp_details;
    emit(event, obj);
    close();
};

const close = () => {
    modal_id.value.close();
};


defineExpose({ show, close });

onMounted(async () => {
	await set_interface_array();

});

</script>

<style scoped>
input:invalid {
  border-color: #ff0000;
}
</style>
