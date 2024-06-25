<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>
    {{_i18n("modal_timeseries.title")}}
  </template>
  <template v-slot:body>
    <ul class="nav nav-tabs">
      <li class="nav-item" @click="change_action('add')">
    	<a class="nav-link" :class="{'active': action == 'add'}" href="#">{{_i18n("modal_timeseries.add_timeseries")}}
	</a>
      </li>
      <li class="nav-item" @click="change_action('select')">
    	<a class="nav-link" :class="{'active': action == 'select' }" href="#">{{_i18n("modal_timeseries.manage_timeseries")}}</a>
      </li>
    </ul>
    <!-- action add -->
    <template v-if="action == 'add'">
      <!-- Sources Types -->
      <div class="form-group ms-2 me-2 mt-3 row">
	<div class="form-group row">
	  <label class="col-form-label col-sm-4" >
            <b>{{_i18n("modal_timeseries.source_type")}}</b>
	  </label>
	  <div class="col-sm-8">
	    <SelectSearch v-model:selected_option="selected_source_type"
			  @select_option="change_source_type()"
			  :options="sources_types">
	    </SelectSearch>
	  </div>
	</div>
      </div>
      
      <!-- Sources -->
      <div v-if="!hide_sources" class="form-group ms-2 me-2 mb-2 mt-3 row">
	<div class="form-group row ">
	  <label class="col-form-label col-sm-4" >
            <b>{{_i18n("modal_timeseries.source")}}</b>
	  </label>
	  <div class="col-sm-8">
	    <input class="form-control" v-model="selected_sources_union_label" :title="selected_sources_union_label" style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" type="text" disabled>
	  </div>
	</div>
	<template v-for="(source_def, source_def_index) in selected_source_type.source_def_array">
	  <!-- select -->
	  <div v-if="source_def.ui_type == ui_types.select" class="form-group mt-2 row">
	    <label class="col-form-label col-sm-4" >
              <b>{{source_def.label}}</b>
	    </label>
	    <div class="col-sm-8">
	      <SelectSearch v-model:selected_option="selected_source_array[source_def_index]"
			    @select_option="change_selected_source(source_def, source_def_index, true)"
			    :options="sources_array[source_def_index]">
	      </SelectSearch>
	    </div>
	  </div> <!-- end select -->

	  <!-- input text -->
	  <div v-if="source_def.ui_type == ui_types.input" class="form-group mt-2 row">
	    <label class="col-form-label col-sm-4" >
              <b>{{source_def.label}}</b>
	    </label>
	    <div class="col-sm-8">
	      <input class="form-control" @input="change_selected_source(source_def, source_def_index)" v-model="selected_source_text_array[source_def_index]" :pattern="source_text_validation_array[source_def_index]" required type="text" placeholder="">
	    </div>
	  </div> <!-- input text -->

	  <!-- input confirm text -->
	  <div v-if="source_def.ui_type == ui_types.input_confirm" class="form-group mt-2 row">
	    <label class="col-form-label col-sm-4" >
              <b>{{source_def.label}}</b>
	    </label>
	    <div class="col-sm-7">
	      <input class="form-control" @input="change_selected_source(source_def, source_def_index)" v-model="selected_source_text_array[source_def_index]" :pattern="source_text_validation_array[source_def_index]" required type="text" placeholder="">
	    </div>
	    <div class="col-sm-1">
              <button type="button" class="btn btn-link btn-sm" @click="reload_sources(source_def, source_def_index)" :title="_i18n(source_def.refresh_i18n)" :disabled="!enable_apply_source"><i class="fas fa-refresh"></i></button>
            </div>
	  </div> <!-- input confirm text -->
	</template>
	
	<div v-show="enable_apply_source" class="form-group row mt-2" style="text-align:end;">
	  <div class="col-sm-12">
      	    <button type="button" @click="apply_source_array" :disabled="enable_apply_source == false" class="btn btn-primary">{{_i18n("modal_timeseries.apply_source")}}</button>
	  </div>	  
	</div>	
      </div> <!-- end Sources -->
      
      <!-- Metrics -->
      <div class="form-group ms-2 me-2 mt-3 row">
	<div class="form-group row">
	  <label class="col-form-label col-sm-4" >
            <b>{{_i18n("modal_timeseries.metric")}}</b>
	  </label>
	  <div class="col-sm-8">
            <SelectSearch ref="select_search_metrics"
	  		  @select_option="update_timeseries_to_add()"
	  		  v-model:selected_option="selected_metric"
	  		  :options="metrics">
            </SelectSearch>
	    
	  </div>	  
	</div>
      </div>
      
      <ListTimeseries
	:title="_i18n('modal_timeseries.timeseries_list')"
	v-model:timeseries="timeseries_to_add">
      </ListTimeseries>      
    </template><!-- action == add -->

    <!-- action select-->
    <template v-if="action == 'select'">
      <template v-for="item in timeseries_groups_added">
	<ListTimeseries
	  :id="get_timeseries_group_id(item)"
	  :title="get_timeseries_group_name(item)"
	  v-model:timeseries="item.timeseries"
	  :show_delete_button="timeseries_groups_added.length > 1"
	  @delete_ts="delete_ts">
	</ListTimeseries>      
      </template><!-- v-for timeseries_groups_added -->
    </template><!-- action == select -->
  </template><!-- modal-body -->
  
  <template v-slot:footer>
    <button v-show="action == 'add'" type="button" @click="apply" :disabled="enable_apply_source" class="btn btn-primary">{{_i18n("modal_timeseries.add")}}</button>
    <button v-show="action == 'select'" type="button" @click="apply" class="btn btn-primary">{{_i18n("modal_timeseries.apply")}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, watch } from "vue";
import { default as modal } from "./modal.vue";
import { default as ListTimeseries } from "./list-timeseries.vue";
import { default as SelectSearch } from "./select-search.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

import metricsManager from "../utilities/metrics-manager.js";
import timeseriesUtils from "../utilities/timeseries-utils.js";
import regexValidation from "../utilities/regex-validation.js";

const props = defineProps({
    sources_types_enabled: Object,
});

const modal_id = ref(null);
const select_search_metrics = ref(null);

const showed = () => {};

const action = ref("select"); // add/select 

let current_page_source_type = metricsManager.get_current_page_source_type();

const sources_types = metricsManager.sources_types;
const selected_source_type = ref(current_page_source_type);

const ui_types = metricsManager.ui_types;
const sources_array = ref([]); // array of sources, each element is the sources list of source_type.source_def_array[i]
const selected_source_array = ref([]);
const selected_source_text_array = ref([]); // array of source_value binding with input text
// const sub_sources = ref([]);
// const selected_sub_source = ref({});
const selected_sources_union_label = ref("");
const source_text_validation_array = ref ([]);

const is_selected_source_changed = ref(false);
const enable_apply_source = computed(() => {
    if (is_selected_source_changed.value == false) {
	return false;
    }
    for (let i = 0; i < source_text_validation_array.value.length; i += 1) {
	let rg_text = source_text_validation_array.value[i];
	if (rg_text == null) { continue; }
	let regex = new RegExp(rg_text);
	let source_text = selected_source_text_array.value[i];
	if (regex.test(source_text) == false) {
	    return false;
	}	
    }
    return true;
});
const hide_sources = ref(false);

const metrics = ref([]);
const selected_metric = ref({});

const timeseries_groups_added = ref([]);

const timeseries_to_add = ref([]);

const emit = defineEmits(['apply']);

let wait_init = null;
let last_source_value_array = null;

onBeforeMount(() => {
    sources_types.forEach((source_type) => {
	let source_type_enabled = props.sources_types_enabled[source_type.id];
	if (source_type_enabled == null || source_type_enabled == false) {
	    // source_type.disabled = true;
	}
    });    
});

onMounted(async () => {
    wait_init = init();
});

const show = async (timeseries_groups) => {
    timeseries_groups_added.value = timeseries_groups;
    await wait_init;
    action.value = "select";
    modal_id.value.show();
};

function change_action(a) {
    action.value = a;
}

async function change_source_type() {
    is_selected_source_changed.value = false;
    set_regex();
    set_hide_sources();
    await set_sources_array();
    await set_metrics();
}

function set_hide_sources() {
    let source_type = selected_source_type.value;
    hide_sources.value = source_type.source_def_array.map((sd) => sd.ui_type == ui_types.hide).every((hide) => hide == true);
}

async function apply_source_array() {
    is_selected_source_changed.value = false;
    selected_source_text_array.value.forEach((source_value, i) => {
	let source_def = selected_source_type.value.source_def_array[i];
	if (source_def.ui_type == ui_types.input) {
	    let source = selected_source_array.value[i];
            set_source_input(source, source_value)
	}
    });    
    await change_source_array();
    set_selected_sources_union_label();
}

function set_source_input(source, source_value) {
    source.value = source_value;
    source.label = source_value;
}

async function change_source_array() {
    // reload metrics 
    await set_metrics();
}

function change_selected_source(source_def, source_def_index, force_reload_sources) {
    is_selected_source_changed.value = true;
    if (force_reload_sources == true) {
        reload_sources(source_def, source_def_index);
    }
}

// reload all sources for each source_def with refresh_on_sources_change == true
async function reload_sources(source_def, source_def_index) {
    if (source_def.ui_type == ui_types.input_confirm) {
        set_source_input(selected_source_array.value[source_def_index], selected_source_text_array.value[source_def_index]);
    }
    let source_def_array = selected_source_type.value.source_def_array;
    let source_value_array = selected_source_array.value.map((s) => s.value);
    for (let i = source_def_index + 1; i < source_def_array.length; i += 1) {
        const source_def = source_def_array[i];
        if (!source_def.refresh_on_sources_change) { continue; }

        let sources = await metricsManager.get_sources(http_prefix, selected_source_type.value.id, source_def, source_value_array);
        sources_array.value[i] = sources;
        if (sources.length > 0) {
            selected_source_array.value[i] = sources[0];
        } else {
            selected_source_array.value[i] = { label: "", value: "" };
            console.warn(`No sources availables to select for ${selected_source_type.value.id} sorce_def`);
        }
    }
}

function set_regex() {
    let regex_source_array = selected_source_type.value?.source_def_array.map((source_def) => source_def.regex_type);
    if (regex_source_array == null) { regex_source_array = []; }
    source_text_validation_array.value = regex_source_array.map((regex_source) => {
	if (regex_source == null) { return  null; }
	return regexValidation.get_data_pattern(regex_source);
    });
}

function get_selected_sources_union_label() {
    let source_label_array = selected_source_array.value.filter((source) => source.label != null && source.label != "").map((source) => source.label);
    let label = source_label_array.join(" - ");
    return `${label}`;
}

function set_selected_sources_union_label() {
    selected_sources_union_label.value = get_selected_sources_union_label();
}

async function set_sources_array() {
    let source_def_array = selected_source_type.value.source_def_array;
    let sources_array_temp = [];
    let default_source_array = await metricsManager.get_default_source_array(http_prefix, selected_source_type.value);
    let default_source_value_array = default_source_array.map((s) => s.value);
    for (let i = 0; i < source_def_array.length; i += 1) {
	let sources = await metricsManager.get_sources(http_prefix, selected_source_type.value.id, source_def_array[i], default_source_value_array);
	sources_array_temp.push(sources);
    }
    selected_source_array.value = default_source_array;
    sources_array.value = sources_array_temp;
    selected_source_text_array.value = default_source_value_array;
    set_selected_sources_union_label();
}

async function set_metrics() {
    metrics.value = await metricsManager.get_metrics(http_prefix, selected_source_type.value, selected_source_array.value);
    metrics.value.sort(NtopUtils.sortAlphabetically);
    selected_metric.value = metricsManager.get_default_metric(metrics.value);
    update_timeseries_to_add(false);    
}

async function init() {
    await change_source_type();
    // take default visible
    update_timeseries_to_add(false);
    //emit('apply', timeseries_groups_added.value);
}

function update_timeseries_to_add(default_config) {
    timeseries_to_add.value = [];
    let timeseries = selected_metric.value.timeseries;
    for (let ts_id in timeseries) {
    	timeseries_to_add.value.push({
    	    id: ts_id,
    	    label: timeseries[ts_id].label,
    	    raw: true,
	    past: false,
    	    avg: false,
    	    perc_95: false,
    	});
    }
}

function get_timeseries_group_name(ts_group) {
    let source_type_name = ts_group.source_type.label;
    let source_def_index = timeseriesUtils.getMainSourceDefIndex(ts_group);
    let source = ts_group.source_array[source_def_index];
    let source_name = source.label;
    let metric_name = ts_group.metric.label;
    return `${source_type_name} - ${source_name} - ${metric_name}`;
}

function get_timeseries_group_id(ts_group) {
    let source_type, source_array, metric;
    if (ts_group == null) {
	source_type = selected_source_type.value;
	source_array = selected_source_array.value;
	metric = selected_metric.value;
    } else {
	source_type = ts_group.source_type;
	source_array = ts_group.source_array;
	metric = ts_group.metric;
    }
    let id = metricsManager.get_ts_group_id(source_type, source_array, metric);
    return id;
}

const delete_ts = (ts_group_id) => {
    timeseries_groups_added.value = timeseries_groups_added.value.filter((ts_group) => get_timeseries_group_id(ts_group) != ts_group_id);
};

const set_timeseries_groups = (timeseries_groups, emit_apply) => {
    timeseries_groups_added.value = timeseries_groups;
    if (emit_apply) {
	emit('apply', timeseries_groups_added.value);
    }
};

const add_ts_group = (ts_group_to_add, emit_apply) => {
    let ts_group_index = timeseries_groups_added.value.findIndex((ts_group) => ts_group.id == ts_group_to_add.id);
    if (ts_group_index < 0) {
	timeseries_groups_added.value.push(ts_group_to_add);
    } else {
	timeseries_groups_added.value[ts_group_index] = ts_group_to_add;
    }

    if (emit_apply) {
	emit('apply', timeseries_groups_added.value);
    }
};

const apply = () => {
    if (action.value == "add") {
	let ts_group_id = get_timeseries_group_id();
	let ts_group = {
	    id: ts_group_id,
	    source_type: selected_source_type.value,
	    source_array: ntopng_utility.clone(selected_source_array.value),
	    metric: selected_metric.value,
	    timeseries: ntopng_utility.clone(timeseries_to_add.value),
	};
	add_ts_group(ts_group);
    }
    emit('apply', timeseries_groups_added.value);
    close();
};

const close = () => {
    modal_id.value.close();
};
const _i18n = (t) => i18n(t);

defineExpose({ show, close, add_ts_group, set_timeseries_groups });

</script>

<style scoped>
input:invalid {
  border-color: #ff0000;
}

.custom-margin {
margin-left: -0.4rem;
}
.warn {
border-color: #ffd500;
border-style: solid;
}
</style>
