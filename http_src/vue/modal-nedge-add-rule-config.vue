<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>{{title}}</template>
  <template v-slot:body>
    <div class="container-fluid">

      <!-- Source -->
      <div class="row form-group mb-3">
	<div class="col col-md-6">
          <label class="form-label">{{_i18n("nedge.page_rules_config.modal_rule_config.source_type")}}</label>
	    <SelectSearch v-model:selected_option="selected_source_type"
			  @select_option="change_source_type()"
			  :options="type_array">
	    </SelectSearch>
	</div>
	<div class="col col-md-6">
          <label class="form-label">{{_i18n("nedge.page_rules_config.source")}}</label>
	  <div v-if="selected_source_type.value == 'interface'">
	    <SelectSearch v-model:selected_option="selected_source_interface"
			  :options="interface_array">
	    </SelectSearch>
	  </div>
	  <div v-else>	    
            <input type="text" class="form-control" :pattern="source_regex"  v-model="source">
	  </div>
	</div>
      </div>
      
      <!-- Dest -->
      <div class="row form-group mb-3">
	<div class="col col-md-6">
          <label class="form-label">{{_i18n("nedge.page_rules_config.modal_rule_config.dest_type")}}</label>
	    <SelectSearch v-model:selected_option="selected_dest_type"
			  @select_option="change_dest_type()"
			  :options="type_array">
	    </SelectSearch>
	</div>
	<div class="col col-md-6">
          <label class="form-label">{{_i18n("nedge.page_rules_config.dest")}}</label>
	  <div v-if="selected_dest_type.value == 'interface'">
	    <SelectSearch v-model:selected_option="selected_dest_interface"
			  :options="interface_array">
	    </SelectSearch>
	  </div>
	  <div v-else>	    
            <input type="text" class="form-control" :pattern="dest_regex" v-model="dest">
	  </div>
	</div>
      </div>
      
      <!-- Direction -->
      <div class="row form-group mb-3">
	<div class="col col-md-12">
          <label class="form-label">{{_i18n("nedge.page_rules_config.direction")}}</label>
	    <SelectSearch v-model:selected_option="selected_direction"
			  :options="directions">
	    </SelectSearch>
	</div>
      </div>

      <!-- Action -->
      <div class="row form-group mb-3">
	<div class="col col-md-12">
          <label class="form-label">{{_i18n("nedge.page_rules_config.action")}}</label>
	    <SelectSearch v-model:selected_option="selected_action"
			  :options="actions">
	    </SelectSearch>
	</div>
      </div>

    </div>
  </template>
  <template v-slot:footer>
    <button type="button" :disabled="!is_valid_source || !is_valid_dest" @click="apply" class="btn btn-primary">{{button_text}}</button>
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

const modal_id = ref(null);
const emit = defineEmits(['edit', 'add'])

const showed = () => {};

const props = defineProps({
});

const title = ref("");

const type_array = [
    { label: _i18n("nedge.page_rules_config.modal_rule_config.ip"), value: "ip", default: true },
    { label: _i18n("nedge.page_rules_config.modal_rule_config.cidr"), value: "cidr" },
    { label: _i18n("interface"), value: "interface" },
];

let default_direction_value = "source_to_dest";
const directions = [
    { label: _i18n("nedge.page_rules_config.bidirectional"), value: "bidirectional", bidirectional: true, },
    { label: _i18n("nedge.page_rules_config.source_to_dest"), value: "source_to_dest", bidirectional: false, },
];
const selected_direction = ref({});

let default_action_value = "accept";
const actions = [
    { label: _i18n("nedge.page_rules_config.accept"), value: "accept" },
    { label: _i18n("nedge.page_rules_config.deny"), value: "deny" },
];
const selected_action = ref({});

const selected_source_type = ref({});
const source_regex = ref("");
const source = ref("");

const selected_dest_type = ref({});
const dest_regex = ref("");
const dest = ref("");

const interface_list_url = `${http_prefix}/lua/rest/v2/get/nedge/interfaces.lua`;
let interface_list;
const interface_array = ref([]);

const selected_source_interface = ref({});
const selected_dest_interface = ref({});

const button_text = ref("");

const is_valid_source = computed(() => {
    return is_valid(selected_source_type.value, source.value, source_regex.value);
});

const is_valid_dest = computed(() => {
    return is_valid(selected_dest_type.value, dest.value, dest_regex.value);
});

const show = (row, default_action) => {
    init(row, default_action);
    modal_id.value.show();
};

let is_open_in_add = true;
let rule_id;
function init(row, default_action) {
    is_open_in_add = row == null;
    if (default_action != null) {
	default_action_value = default_action.value;
    }
    // check if we need open in edit
    if (is_open_in_add == false) {
	title.value = _i18n("nedge.page_rules_config.modal_rule_config.title_edit");
	button_text.value = _i18n("edit");
	selected_source_type.value = type_array.find((s) => s.value == row.source.type);
	selected_dest_type.value = type_array.find((s) => s.value == row.destination.type);
	selected_direction.value = directions.find((d) => d.bidirectional == row.bidirectional);
	selected_action.value = actions.find((a) => a.value == row.action);
	rule_id = row.rule_id;
    } else {
	title.value = _i18n("nedge.page_rules_config.modal_rule_config.title_add");
	button_text.value = _i18n("add");
	let default_type = type_array.find((s) => s.default == true);
	selected_source_type.value = default_type;
	selected_dest_type.value = default_type;
	selected_direction.value = directions.find((d) => d.value == default_direction_value);
	selected_action.value = actions.find((a) => a.value != default_action_value);
    }
    change_source_type(row);
    change_dest_type(row);
}

async function change_source_type(row) {
    let value = null;
    if (row != null) {
	value = row.source.value;
    }
    if (selected_source_type.value.value == "interface") {
	await set_interface_array();
	if (value != null) {
	    selected_source_interface.value = interface_array.value.find((i) => i.value == value);
	} else {
	    selected_source_interface.value = interface_array.value[0];
	}
    } else {
	if (row != null) {
	    source.value = row.source.value;
	} else {
	    source.value = "";
	}
	set_regex(source_regex, selected_source_type.value.value);
    }    
}

async function change_dest_type(row) {
    let value = null;
    if (row != null) {
	value = row.destination.value;
    }
    if (selected_dest_type.value.value == "interface") {
	await set_interface_array();
	if (value != null) {
	    selected_dest_interface.value = interface_array.value.find((i) => i.value == value);
	} else {
	    selected_dest_interface.value = interface_array.value[0];
	}
    } else {
	if (row != null) {
	    dest.value = row.destination.value;
	} else {
	    dest.value = "";
	}
	set_regex(dest_regex, selected_dest_type.value.value);
    }
}

function is_valid(selected_type, text, rg_text) {
    if (selected_type.value == "interface") {
	return true;
    }
    let regex = new RegExp(rg_text);
    return regex.test(text);
}

let is_set_interface_array = false;
async function set_interface_array() {
    if (is_set_interface_array == true) { return; }
	if (interface_list == null) {
	    interface_list = ntopng_utility.http_request(interface_list_url);
	}
	let res_interface_list = await interface_list;
	interface_array.value = res_interface_list.filter((i) => i.role == "lan").map((i) => {
	    return {
		label: i.label,
		value: i.ifname,
	    };
	});
    is_set_interface_array = true;
}

function set_regex(rg, type) {
    rg.value = regexValidation.get_data_pattern(type);
}

const apply = () => {
    let src_type = selected_source_type.value.value;    
    let src_value = source.value;
    if (src_type == "interface") {
	src_value = selected_source_interface.value.value;
    }
    let dst_type = selected_dest_type.value.value;    
    let dst_value = dest.value;
    if (dst_type == "interface") {
	dst_value = selected_dest_interface.value.value;
    }
    let policy = selected_action.value.value;
    let bidirectional = selected_direction.value.value == "bidirectional";
    let obj = {
	src_type,
	src_value,
	dst_type,
	dst_value,
	policy,
	bidirectional,
    };
    let event = "add";
    if (is_open_in_add == false) {
	obj.rule_id = rule_id;
	event = "edit";
    }
    
    emit(event, obj);
    close();
};

const close = () => {
    modal_id.value.close();
};


defineExpose({ show, close });

onMounted(() => {
});

</script>

<style scoped>
input:invalid {
  border-color: #ff0000;
}
</style>
