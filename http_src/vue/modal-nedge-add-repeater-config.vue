<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>{{title}}</template>
  <template v-slot:body>
    <div class="container-fluid">

      <!-- Repeater Type -->
      <div class="row form-group mb-3">
	<div class="col col-md-6">
          <label class="form-label">
						<b>{{_i18n("nedge.page_repeater_config.modal_repeater_config.repeater_type")}}</b>
					</label>
	    <SelectSearch v-model:selected_option="selected_repeater_type"
			  @select_option="change_repeater_type()"
			  :options="repeater_type_array">
	    </SelectSearch>
	</div>
      </div>
      
      <!-- IP -->
      <div class="row form-group mb-3">
	
	<div class="col col-md-6">

		<div v-if="selected_repeater_type.value == 'custom'" >
	    <label class="col-form-label col-sm-2" >
        <b>{{_i18n("nedge.page_repeater_config.ip")}}</b>
	    </label>
	      <input v-model="ip"  @input="check_empty_host" class="form-control" type="text" :placeholder="host_placeholder" required>
    </div>
    
	</div>
      </div>
            
						
			<!-- Port -->
      <div class="row form-group mb-3">
	
	<div class="col col-md-6">

		<div v-if="selected_repeater_type.value == 'custom'" >
	    <label class="col-form-label col-sm-2" >
        <b>{{_i18n("nedge.page_repeater_config.port")}}</b>
	    </label>
	      <input v-model="port"  @input="check_empty_port" class="form-control" type="text" :placeholder="port_placeholder" required>
    
    </div>
		</div>
      </div>
<div class="row form-group mb-3">
	
	<div class="col col-md-6">
		<label class="col-form-label col-sm-10" >
        <b>{{_i18n("nedge.page_repeater_config.interfaces")}}</b>
	    </label>
				<SelectSearch
                          :options="interface_array"
                          :multiple="true"
                          @select_option="update_interfaces_selected"
                          @unselect_option="remove_interfaces_selected"
                          @change_selected_options="all_criteria">
            </SelectSearch>
	

	</div>
      </div>


    </div>
  </template>
  <template v-slot:footer>
    <button type="button" :disabled="disable_add && repeater_type == 'custom'" @click="apply" class="btn btn-primary">{{button_text}}</button>
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
const ip = ref(null);
const port = ref(null);
const repeater_type = ref({value: "mdns", label: "MDNS" });
const emit = defineEmits(['edit', 'add'])

const showed = () => {};

const props = defineProps({
});

const check_empty_host = () => {
  let regex = new RegExp(regexValidation.get_data_pattern('ip'));
  disable_add.value = !(regex.test(ip.value) || ip.value === '*');
}



const check_empty_port = () => {
	disable_add.value = (port < 1 || port > 65535);
}



const title = ref("");

const repeater_type_array = [
    { label: _i18n("nedge.page_repeater_config.modal_repeater_config.mdns"), value: "mdns", default: true },
    { label: _i18n("nedge.page_repeater_config.modal_repeater_config.custom"), value: "custom" },
];

const repeater_id = ref(0);
const disable_add = ref(true)

const selected_repeater_type = ref({});


const interface_list_url = `${http_prefix}/lua/rest/v2/get/nedge/interfaces.lua`;
let interface_list;
const interface_array = ref([]);

const selected_dest_interface = ref([]);

const button_text = ref("");

const all_criteria = (item) => {
	selected_dest_interface.value = item;
}

const update_interfaces_selected = (item) => {

}

const remove_interfaces_selected = (item) => {

}

const show = (row ) => {
    init(row);
    modal_id.value.show();
};

const is_open_in_add = ref(true);

function init(row) {
    is_open_in_add.value = row == null;
    

    // check if we need open in edit
    if (is_open_in_add.value == false) {
			title.value = _i18n("nedge.page_rules_config.modal_rule_config.title_edit");
			button_text.value = _i18n("edit");
			repeater_id.value = row.repeater_id;
			repeater_type_array.forEach((s) => {
				if(s.label == row.type)
					selected_repeater_type.value = s;
			})

			if (selected_repeater_type.value.value == 'custom') {
				ip.value = row.ip;
				port.value = row.port;
			}

			change_repeater_type(row)

    } else {
			title.value = _i18n("nedge.page_rules_config.modal_rule_config.title_add");
			button_text.value = _i18n("add");
			let default_type = repeater_type_array.find((s) => s.default == true);
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
	interface_array.value = res_interface_list.filter(i => i.role != "unused").map((i) => {
			return {
		label: i.label,
		value: i.ifname,
			};
	});
    is_set_interface_array = true;
}


const apply = () => {
    let repeater_t = repeater_type.value.label;
		
    let obj = {
			repeater_type: repeater_t,
    };
		if (repeater_type.value.value == "custom") {
			let ip_t = ip.value;
			let port_t = port.value;
			obj = {
				repeater_type: repeater_t,
				ip: ip_t,
				port: port_t
    	};
		}
    let event = "add";
    if (is_open_in_add.value == false) {
	obj.repeater_id = repeater_id.value;
	event = "edit";
    }

		let interfaces = "";
		if(selected_dest_interface.value.length == 0) {
			interfaces = "enp2s0f1,enp2s0f3";
		}
		selected_dest_interface.value.forEach((i) => {
			interfaces +=i.value+",";
		});
		obj.interfaces = interfaces;
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
