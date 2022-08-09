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
          <b>Select Source Type</b>
	</label>
	<div class="col-sm-8">
          <select class="form-select"  v-model="selected_source_type">
            <option v-for="item in sources_types" :value="item">{{item}}</option>
          </select>
	</div>
      </div>
      <div class="form-group ms-2 me-2 mt-3 row">
	<label class="col-form-label col-sm-4" >
          <b>Select Source</b>
	</label>
	<div class="col-sm-8">
          <select class="form-select"  v-model="selected_source">
            <option v-for="item in sources" :value="item">{{get_name_from_source(item)}}</option>
          </select>
	</div>
      </div>
      <div class="form-group ms-2 me-2 mt-3 row">
	<label class="col-form-label col-sm-4" >
          <b>Select Metric</b>
	</label>
	<div class="col-sm-8">
          <select class="form-select" @click="update_timeseries_to_add()" v-model="selected_metric">
            <option v-for="item in metrics" :value="item">{{item.label}}</option>
          </select>
	</div>
      </div>
      
      <ListTimeseries
	title="Timeseries:"
	:timeseries="timeseries_to_add">
      </ListTimeseries>      
    </template><!-- action == add -->

    <template v-if="action == 'select'">
      <template v-for="item in timeseries_groups_added">
	<ListTimeseries
	  :title="get_timeseries_group_name(item)"
	  :timeseries="item.timeseries">
	</ListTimeseries>      
      </template><!-- v-for timeseries_groups_added -->
    </template><!-- action == select -->
  </template><!-- modal-body -->
  
  <template v-slot:footer>
    <button type="button" @click="apply" class="btn btn-primary">Apply</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";
import { default as ListTimeseries } from "./list-timeseries.vue";

const modal_id = ref(null);
const showed = () => {};

const action = ref("select"); // add/select 

const source_type_enum = {
    interface: "ifid"
}

let sources_types = [source_type_enum.interface];
const selected_source_type = ref(sources_types[0]);

const sources = ref([]);
const selected_source = ref({});

// const timeseries_group_name = computed(() => {
//     let name = get_name_from_source(ts_group.source);
//     return name;
// });

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

async function init() {
    console.log("INIT modal-timeseries");
    let res
    // init sources, todo
    let url_interfaces = `${http_prefix}/lua/rest/v2/get/ntopng/interfaces.lua`;
    res = await ntopng_utility.http_request(url_interfaces);
    console.log(res);
    sources.value = res;
    if (res.length > 0) {
	selected_source.value = res[0];
    }
    
    // init metrics
    let url = `${http_prefix}/lua/pro/rest/v2/get/timeseries/type/consts.lua`;
    res = await ntopng_utility.http_request(url);
    console.log(res);
    metrics.value = res;
    // take default visible
    let metric_default = metrics.value.find((m) => m.default_visible);    
    selected_metric.value = metric_default;
    
    update_timeseries_to_add();
    
    // init metrics added
    let ts_group = {
	id: get_timeseries_group_id(),
	source_type: selected_source_type.value,
	source: selected_source.value,
	metric: metric_default,
	timeseries: timeseries_to_add.value,
    };
    timeseries_groups_added.value.push(ts_group);
    console.log("emit");
    emit('apply', timeseries_groups_added.value);
}

function update_timeseries_to_add() {
    timeseries_to_add.value = [];
    let timeseries = selected_metric.value.timeseries
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
    let source_type_name = "";
    if (ts_group.source_type == source_type_enum.interface)  {
	source_type_name = "Interface";
    }
    let name = get_name_from_source(ts_group.source);
    let metric_name = ts_group.metric.label;
    return `${source_type_name} - ${name} - ${metric_name}`;
}

function get_timeseries_group_id() {
    let source = selected_source.value;
    let source_type = selected_source_type.value;
    let metric = selected_metric.value;
    let source_id = get_id_from_source(source, source_type);
    return `${source_type} - ${source_id} - ${metric.schema}`;
}

function get_name_from_source(source, source_type) {
    if (source_type == null) {
	source_type = selected_source_type.value;
    }
    if (source_type == source_type_enum.interface) {
	return source.ifname;
    }
}

function get_id_from_source(source, source_type) {
    if (source_type == null) {
	source_type = selected_source_type.value;
    }
    if (source_type == source_type_enum.interface) {
	return source.ifid;
    }
}

const apply = () => {
    if (action.value == "add") {
	let ts_group_id = get_timeseries_group_id();
	if (!timeseries_groups_added.value.some((ts_group) => ts_group.id == ts_group_id)) {
	    timeseries_groups_added.value.push({
		id: ts_group_id,
		source_type: selected_source_type.value,
		source: selected_source.value,
		metric: selected_metric.value,
		timeseries: timeseries_to_add.value,
	    });
	}
    }
    emit('apply', timeseries_groups_added.value);
    close();
}

const close = () => {
    modal_id.value.close();
};

defineExpose({ show, close });

const _i18n = (t) => i18n(t);

</script>

<style scoped>
</style>
