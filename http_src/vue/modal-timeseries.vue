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
            <option v-for="item in sources" :value="item">{{item.ifname}}</option>
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
      
      <div>
      	<div class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-4" >
            <b>Timeseries:</b>
          </label>
	</div>
	<div v-for="item in timeseries_to_add" class="form-group ms-4 me-2 mt-1 row">
      	  <div class="custom-control custom-switch">
      	    <input type="checkbox" class="custom-control-input whitespace form-check-input" v-model="item.raw">
	    
      	    <label class="custom-control-label ms-1 form-check-label">{{item.label}}</label>
      	  </div>
      	  <div class="custom-control custom-switch">
      	    <input type="checkbox" class="custom-control-input whitespace form-check-input" v-model="item.avg">
	    
      	    <label class="custom-control-label ms-1 form-check-label">Avg {{item.label}}</label>
      	  </div>
      	  <div class="custom-control custom-switch">
      	    <input type="checkbox" class="custom-control-input whitespace form-check-input" v-model="item.perc_95">
	    
      	    <label class="custom-control-label ms-1 form-check-label">95th Perc {{item.label}}</label>
      	  </div>
	</div>
      </div>

      
    </template><!-- action == add -->

    <template v-if="action == 'select'">
      <template v-for="item in metrics_added">
	Hello World
	<!-- <div v-if="exclude_type == 'ip'" class="ip-fields"> -->
	<!--   <div class="mb-3 row"> -->
        <!--     <label class="col-form-label col-sm-4" > -->
        <!--       <b>{{ _i18n("check_exclusion.ip_address") }}</b> -->
        <!--     </label> -->
        <!--     <div class="col-sm-6"> -->
        <!--       <input :pattern="pattern_ip" placeholder="192.168.1.1" required type="text" name="ip_address" class="form-control" v-model="input_ip" /> -->
        <!--     </div> -->
	<!--   </div> -->
	<!-- </div> -->

	<!-- <div class="form-group ms-2 me-2 mt-3 row"> -->
	<!--   <div class="custom-control custom-switch"> -->
	<!--     <input type="checkbox" class="custom-control-input whitespace form-check-input" v-model="apply_time"> -->
	    
	<!--     <label class="custom-control-label ms-1 form-check-label">{{apply_time_text}}</label> -->
	<!--   </div> -->
	<!-- </div> -->
      </template><!-- v-for metrics_added -->
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

const modal_id = ref(null);
const showed = () => {};

const action = ref("select"); // add/select 

let sources_types = ["interface"];
const selected_source_type = ref(sources_types[0]);

const sources = ref([]);
const selected_source = ref({});

const metrics = ref([]);
const selected_metric = ref({});

const metrics_added = ref([]);

const timeseries_to_add = ref([]);

onMounted(async () => {
});

let is_already_init = false;
const show = () => {
    if (is_already_init == false) {
	init();
	is_already_init= true;
    }
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
    selected_metric.value = res[0];
    console.log(res);
    metrics.value = res;

    update_timeseries_to_add();

    // init metrics added
    let metric_default = metrics.value.find((m) => m.default_visible);
    metrics_added.value.push({
	source_type: selected_source_type.value,
	source: selected_source.value,
	metric: metric_default,
    });
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

const apply = () => {
    console.log(selected_metric.value);
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
