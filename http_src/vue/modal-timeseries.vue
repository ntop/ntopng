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
      
      <!-- Sources -->
      <!-- Interface -->
      <template v-if="selected_source_type.ui_type == ui_types.select">
	<div class="form-group ms-2 me-2 mt-3 row">
	  <label class="col-form-label col-sm-4" >
            <b>{{_i18n("modal_timeseries.source")}}</b>
	  </label>
	  <div class="col-sm-8">
	    <SelectSearch v-model:selected_option="selected_source"
			  @select_option="change_source()"
			  :options="sources">
	    </SelectSearch>
	  </div>
	</div>
      </template>
      
      <!-- Pool -->
      <template v-if="selected_source_type.ui_type == ui_types.select_and_select">
	<div class="form-group ms-2 me-2 mt-3 ms-1 me-1">
	  <div class="form-group row ms-1 mb-2">
	    <label class="col-form-label col-sm-4" >
              <b>{{_i18n("modal_timeseries.source")}}</b>
	    </label>
	    <div class="col-sm-8" >
	      <input class="form-control" v-model="selected_source_text" type="text" disabled>
	    </div>
	  </div>
	</div>
	<div class="form-group ms-2 me-2 mt-3 ms-3 me-1 row">
	  <label class="col-form-label col-sm-4" >
            <b>{{selected_source_type.sub_label}}</b>
	  </label>
	  <div class="col-sm-8">
	    <SelectSearch v-model:selected_option="selected_sub_source"
			  :options="sub_sources">
	    </SelectSearch>
	  </div>
	</div>
	<div class="form-group ms-2 me-2 mt-3 ms-3 me-1 row">
	  <label class="col-form-label col-sm-4" >
            <b>{{selected_source_type.label}}</b>
	  </label>
	  <div class="col-sm-6">
	    <SelectSearch v-model:selected_option="selected_source"
			  :options="sources">
	    </SelectSearch>
	  </div>
	  <div class="col-sm-2" style="text-align:end !important;">
	    <button type="button" :disabled="!is_source_text_valid"  @click="apply_source_text(false)" class="btn btn-primary">{{_i18n("modal_timeseries.apply")}}</button>
	  </div>	  
	</div>
      </template>
      
      <!-- Host, Mac -->
      <template v-if="selected_source_type.ui_type == ui_types.select_and_input">
	<div class="form-group ms-2 me-2 mt-3">
	  <div class="form-group row ms-1 me-1 mb-2">
	    <label class="col-form-label col-sm-4" >
              <b>{{_i18n("modal_timeseries.source")}}</b>
	    </label>
	    <div class="col-sm-8" >
	      <input class="form-control" v-model="selected_source_text" type="text" disabled>
	    </div>
	  </div>
	  <div class="form-group row ms-3 me-1">
	    <label class="col-form-label col-sm-4">
              <b>{{ selected_source_type.sub_label }}</b>
	    </label>
	    <div class="col-sm-8">
	      <SelectSearch v-model:selected_option="selected_sub_source"
			    :options="sub_sources">
	      </SelectSearch>
	    </div>
	  </div>
	  <div class="form-group row ms-3 me-1">
	    <label class="col-form-label col-sm-4">
              <b>{{ selected_source_type.label }}</b>
	    </label>
	    <div class="col-sm-6">
	      <input class="form-control" v-model="source_text"  :pattern="source_text_validation" required type="text" placeholder="">	      
	    </div>
	    <div class="col-sm-2" style="text-align:end !important;">
	      <button type="button" :disabled="!is_source_text_valid"  @click="apply_source_text(true)" class="btn btn-primary">{{_i18n("modal_timeseries.apply")}}</button>
	    </div>
	  </div>
	</div>
      </template>

      <!-- Metrics -->
      <div class="form-group ms-2 me-2 mt-3 row">
	<label class="col-form-label col-sm-4" >
          <b>{{_i18n("modal_timeseries.metric")}}</b>
	</label>
	<div class="col-sm-8">
          <!-- <select class="form-select" @click="update_timeseries_to_add()" v-model="selected_metric"> -->
            <!--   <option v-for="item in metrics" :value="item">{{item.label}}</option> -->
          <!-- </select> -->
          <SelectSearch ref="select_search_metrics"
	  		@select_option="update_timeseries_to_add()"
	  		v-model:selected_option="selected_metric"
	  		:options="metrics">
          </SelectSearch>
	  
	</div>
      </div>
      
      <ListTimeseries
	:id="get_timeseries_group_id()"
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
    <button v-show="action == 'add'" type="button" @click="apply" class="btn btn-primary">{{_i18n("modal_timeseries.add")}}</button>
    <button v-show="action == 'select'" type="button" @click="apply" class="btn btn-primary">{{_i18n("modal_timeseries.apply")}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";
import { default as ListTimeseries } from "./list-timeseries.vue";
import { default as SelectSearch } from "./select-search.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

import metricsManager from "../utilities/metrics-manager.js";
import regexValidation from "../utilities/regex-validation.js";

const modal_id = ref(null);
const select_search_metrics = ref(null);

const showed = () => {};

const action = ref("select"); // add/select 

let current_page_source_type = metricsManager.get_current_page_source_type();

const sources_types = metricsManager.sources_types;
const selected_source_type = ref(current_page_source_type);

const ui_types = metricsManager.ui_types;
const sources = ref([]);
const selected_source = ref({});
const selected_source_text = ref("");
const selected_source_text_warn = () => {
    return get_selected_source_text(source_text.value) != get_selected_source_text();
};
const sub_sources = ref([]);
const selected_sub_source = ref({});
const source_text = ref("");
const regex_source = selected_source_type.value?.regex_type;
const source_text_validation = ref(regexValidation.get_data_pattern(regex_source));
const is_source_text_valid = computed(() => {
    let regex = new RegExp(source_text_validation.value);
    return regex.test(source_text.value);
});

const metrics = ref([]);
const selected_metric = ref({});

const timeseries_groups_added = ref([]);

const timeseries_to_add = ref([]);

const emit = defineEmits(['apply'])

let wait_init = null;

// const props = defineProps({
//     timseries_groups: Array,
// });


onMounted(async () => {
    wait_init = init();
});

// watch(() => props.timeseries_groups, (current_value, old_value) => {
//     if (current_value == null) { return; }
//     timeseries_groups_added.value = current_value;
// });
watch(() => action.value, (current_value, old_value) => {
    if (current_value != "select_search_metrics") { return; }
    //select_search.value.render();
    // take default visible
    // selected_metric.value = metricsManager.get_default_metric(metrics.value);
    // select_search.value.init();
}, { flush: 'post'});

const show = async (timeseries_groups) => {
    console.log(selected_metric.value);
    timeseries_groups_added.value = timeseries_groups;
    await wait_init;
    action.value = "select";
    modal_id.value.show();
};

function change_action(a) {
    action.value = a;
}

async function apply_source_text(set_selected_source) {
    if (set_selected_source == true) {
	selected_source.value = await metricsManager.get_source_from_value(http_prefix, selected_source_type.value, source_text.value, selected_sub_source.value.value);
    } else {
	selected_source.value.sub_value = selected_sub_source.value.value;
    }
    set_selected_source_text();
    await set_metrics();
}

async function change_source_type() {
    let regex_source = selected_source_type.value?.regex_type;
    source_text_validation.value = regexValidation.get_data_pattern(regex_source);

    await set_sources();
    await set_metrics();
}

async function change_source() {
    await set_metrics();
}

function get_selected_source_text(source_label) {
    if (source_label == null) {
	source_label = selected_source.value.label;
    }
    return `${selected_sub_source.value.label} - ${source_label}`;
}

function set_selected_source_text() {
    selected_source_text.value = get_selected_source_text();
}

async function set_sources() {
    if (selected_source_type.value.sub_value != null) {
	sub_sources.value = await metricsManager.get_sub_sources(http_prefix, selected_source_type.value.sub_value);
	selected_sub_source.value = await metricsManager.get_default_sub_source(http_prefix, selected_source_type.value.sub_value);
    }
    if (!selected_source_type.value.disable_url) {
	sources.value = await metricsManager.get_sources(http_prefix, selected_source_type.value);
    }
    let default_source = await metricsManager.get_default_source(http_prefix, selected_source_type.value);
    selected_source.value = default_source;
    // if (selected_source_type.value.ui_type == ui_types.select_and_input) {
	source_text.value = selected_source.value.value;
	set_selected_source_text();
    // }
}

async function set_metrics() {
    metrics.value = await metricsManager.get_metrics(http_prefix, selected_source_type.value, selected_source.value);
    metrics.value.sort(NtopUtils.sortAlphabetically);
    selected_metric.value = metricsManager.get_default_metric(metrics.value);
}

async function init() {
    console.log("INIT MODAL TIMESERIES");
    // set sources
    await set_sources();
    // set metrics
    await set_metrics();
    // take default visible
    update_timeseries_to_add(false);
    console.log("emit");
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
    let source_name = ts_group.source.label;
    let metric_name = ts_group.metric.label;
    return `${source_type_name} - ${source_name} - ${metric_name}`;
}

function get_timeseries_group_id(ts_group) {
    let source_type, source, metric;
    if (ts_group == null) {
	source_type = selected_source_type.value;
	source = selected_source.value;
	metric = selected_metric.value;
    } else {
	source_type = ts_group.source_type;
	source = ts_group.source;
	metric = ts_group.metric;
    }
    let id = metricsManager.get_ts_group_id(source_type, source, metric);
    console.log(`modal-timeseries: id = ${id}`);
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
	    source: selected_source.value,
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

.warn {
border-color: #ffd500;
border-style: solid;
}
</style>
