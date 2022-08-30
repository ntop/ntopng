<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>
    Manage Timeseries
  </template>
  <template v-slot:body>
    <ul class="nav nav-tabs">
      <li class="nav-item" @click="action='add'">
    	<a class="nav-link" :class="{'active': action == 'add'}" href="#">Add Timeseries</a>
      </li>
      <li class="nav-item" @click="action='select'">
    	<a class="nav-link" :class="{'active': action == 'select' }" href="#">Manage Timeseries</a>
      </li>
    </ul>
    <template v-if="action == 'add'">
      <div class="form-group ms-2 me-2 mt-3 row">
	<label class="col-form-label col-sm-4" >
          <b>Source Type</b>
	</label>
	<div class="col-sm-8">
          <select class="form-select" v-model="selected_source_type">
            <option v-for="item in sources_types" :value="item">{{item.name}}</option>
          </select>
	</div>
      </div>
      <div class="form-group ms-2 me-2 mt-3 row">
	<label class="col-form-label col-sm-4" >
          <b>Source</b>
	</label>
	<div class="col-sm-8">
          <select class="form-select"  v-model="selected_source">
            <option v-for="item in sources" :value="item">{{item.name}}</option>
          </select>
	</div>
      </div>
      <div class="form-group ms-2 me-2 mt-3 row">
	<label class="col-form-label col-sm-4" >
          <b>Metric</b>
	</label>
	<div class="col-sm-8">
          <select class="form-select" @click="update_timeseries_to_add()" v-model="selected_metric">
            <option v-for="item in metrics" :value="item">{{item.label}}</option>
          </select>
	</div>
      </div>
      
      <ListTimeseries
	:id="get_timeseries_group_id()"
	title="Timeseries:"
	v-model:timeseries="timeseries_to_add">
      </ListTimeseries>      
    </template><!-- action == add -->

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
    <button v-show="action == 'add'" type="button" @click="apply" class="btn btn-primary">Add</button>
    <button v-show="action == 'select'" type="button" @click="apply" class="btn btn-primary">Apply</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";
import { default as ListTimeseries } from "./list-timeseries.vue";

import metricsManager from "../utilities/metrics-manager.js";

const modal_id = ref(null);
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

onMounted(async () => {
    action.value = "select";
    let wait_init = init();
});

const show = async () => {
    await wait_init;
    modal_id.value.show();
};

const select_metric = (metric) => {
    selected_source_type.value = current_page_source_type;
    init(metric);
};

async function init(default_selected_metric) {
    sources.value = await metricsManager.get_sources(http_prefix, current_page_source_type);
    let default_source_value = metricsManager.get_default_source_value(selected_source_type.value);
    selected_source.value = sources.value.find((s) => s.value == default_source_value);
    
    // init metrics
    metrics.value = await metricsManager.get_metrics();
    // take default visible
    if (default_selected_metric == null) {
	selected_metric.value = metricsManager.get_default_metric(metrics.value);
    } else {
 	selected_metric.value = default_selected_metric;
    }
    
    update_timeseries_to_add(false);
    
    // init metrics added
    timeseries_groups_added.value = [];
    let ts_group = {
	id: get_timeseries_group_id(),
	source_type: selected_source_type.value,
	source: selected_source.value,
	metric: selected_metric.value,
	timeseries: ntopng_utility.clone(timeseries_to_add.value),
    };
    timeseries_groups_added.value.push(ts_group);
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
    	    avg: false || default_config,
    	    perc_95: false || default_config,
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
    return `${source_type.value} - ${source.value} - ${metric.schema}`;
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

defineExpose({ show, close, select_metric });

const _i18n = (t) => i18n(t);

</script>

<style scoped>
</style>
