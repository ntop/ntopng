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
      <div class="form-group ms-2 me-2 mt-3 row">
	<label class="col-form-label col-sm-4" >
          <b>{{_i18n("modal_timeseries.source_type")}}</b>
	</label>
	<div class="col-sm-8">
    <SelectSearch v-model:selected_option="selected_source_type"
		      :options="sources_types">
	  </SelectSearch>
	</div>
      </div>
      <div class="form-group ms-2 me-2 mt-3 row">
	<label class="col-form-label col-sm-4" >
          <b>{{_i18n("modal_timeseries.source")}}</b>
	</label>
	<div class="col-sm-8">
  <select class="form-select"  v-model="selected_source">
            <option v-for="item in sources" :value="item">{{item.name}}</option>
          </select>
	</div>
      </div>
      <div class="form-group ms-2 me-2 mt-3 row">
	<label class="col-form-label col-sm-4" >
          <b>{{_i18n("modal_timeseries.metric")}}</b>
	</label>
	<div class="col-sm-8">
          <!-- <select class="form-select" @click="update_timeseries_to_add()" v-model="selected_metric"> -->
            <!--   <option v-for="item in metrics" :value="item">{{item.label}}</option> -->
          <!-- </select> -->
          <SelectSearch ref="select_search"
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

const modal_id = ref(null);
const select_search = ref(null);

const showed = () => {};

const action = ref("select"); // add/select 

let current_page_source_type = metricsManager.get_current_page_source_type();
let sources_types = metricsManager.sources_types;

const selected_source_type = ref(current_page_source_type);

const sources = ref([]);
const selected_source = ref({});

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
    if (current_value != "add") { return; }
    select_search.value.render();
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

async function init() {
    console.log("INIT MODAL TIMESERIES");
    sources.value = await metricsManager.get_sources(http_prefix, current_page_source_type);
    let default_source_value = metricsManager.get_default_source_value(selected_source_type.value);
    selected_source.value = sources.value.find((s) => s.value == default_source_value);
    
    // init metrics
    metrics.value = await metricsManager.get_metrics(http_prefix);
    // take default visible
    selected_metric.value = metricsManager.get_default_metric(metrics.value);
    metrics.value.sort((a, b) => {
      const nameA = a.label.toUpperCase(); // ignore upper and lowercase
      const nameB = b.label.toUpperCase(); // ignore upper and lowercase
      if (nameA < nameB) { return -1; }
      if (nameA > nameB) { return 1; }
      return 0;
    });
    update_timeseries_to_add(false);
    
    // init metrics added
    // timeseries_groups_added.value = [];
    // let ts_group = {
    // 	id: get_timeseries_group_id(),
    // 	source_type: selected_source_type.value,
    // 	source: selected_source.value,
    // 	metric: selected_metric.value,
    // 	timeseries: ntopng_utility.clone(timeseries_to_add.value),
    // };
    // timeseries_groups_added.value.push(ts_group);
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
    	    avg: false,
    	    perc_95: false,
    	});
    }
}

function get_timeseries_group_name(ts_group) {
    let source_type_name = ts_group.source_type.name;
    let source_name = ts_group.source.name;
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
    return metricsManager.get_ts_group_id(source_type, source, metric);
}

const delete_ts = (ts_group_id) => {
    timeseries_groups_added.value = timeseries_groups_added.value.filter((ts_group) => get_timeseries_group_id(ts_group) != ts_group_id);
};

const apply = () => {
    if (action.value == "add") {
	let ts_group_id = get_timeseries_group_id();
	let ts_group_index = timeseries_groups_added.value.findIndex((ts_group) => ts_group.id == ts_group_id);
	let ts_group = {
	    id: ts_group_id,
	    source_type: selected_source_type.value,
	    source: selected_source.value,
	    metric: selected_metric.value,
	    timeseries: ntopng_utility.clone(timeseries_to_add.value),
	};
	if (ts_group_index < 0) {
	    timeseries_groups_added.value.push(ts_group);
	} else {
	    timeseries_groups_added.value[ts_group_index] = ts_group;
	}
    }
    emit('apply', timeseries_groups_added.value);
    close();
};

const close = () => {
    modal_id.value.close();
};
const _i18n = (t) => i18n(t);

defineExpose({ show, close });

</script>

<style scoped>
</style>
