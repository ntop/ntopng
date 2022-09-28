<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>
      {{_i18n("snapshots.manage")}}
      <a target="_newtab" href="#" style="" class="nav-item text-muted"><i class="fas fa-question-circle" style="margin-left:28rem;padding-top:0.8rem;"></i></a>    
  </template>
  <template v-slot:body>
    <ul class="nav nav-tabs">
      <li class="nav-item" @click="action='add'">
	<a class="nav-link" :class="{'active': action == 'add'}" href="#">{{_i18n("snapshots.add")}}</a>
      </li>
      <li class="nav-item" @click="update_action('select')">
	<a :disabled="snapshots.length == 0" class="nav-link" :class="{'active': action == 'select', 'not-allowed': snapshots.length == 0 }" href="#">{{_i18n("snapshots.manage")}}</a>
      </li>      
    </ul>
    <div v-if="action == 'add'" style="min-height:8.5rem">
      <div class="form-group ms-2 me-2 mt-3 row">
	<label class="col-form-label col-sm-4"><b>{{_i18n("snapshots.name")}}:</b></label>
	<div class="col-sm-6">
	  <input :pattern="pattern_singleword" placeholder="" required type="text" class="form-control" v-model="snapshot_name">
	</div>
      </div>
      <!-- <div class="form-group ms-2 me-2 mt-3 row"> -->
      <!-- 	<div class="custom-control custom-switch"> -->
      <!-- 	  <input type="checkbox" class="custom-control-input whitespace form-check-input" v-model="save_time"> -->
	  
      <!-- 	  <label class="custom-control-label ms-1 form-check-label">{{save_time_text}}</label> -->
      <!-- 	</div> -->
      <!-- </div>       -->
    </div> <!-- action add -->
    
    <div v-if="action == 'select'" style="min-height:8.5rem">
      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-4" >
          <b>{{ _i18n("snapshots.order_by") }}</b>
        </label>
        <div class="col-sm-8">
          <select class="form-select" @click="sort_snapshots_by()" v-model="order_by">
            <option value="name">{{_i18n("snapshots.name")}}</option>
            <option value="date">{{_i18n("snapshots.date")}}</option>
          </select>
        </div>
      </div>
      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-4" >
          <b>{{ _i18n("snapshots.select") }}</b>
        </label>
        <div class="col-sm-8">
          <select class="form-select" v-model="snapshot_selected">
            <option v-for="item in snapshots" :value="item">{{ display_name(item) }}</option>
          </select>
        </div>
      </div>
      <div class="form-group ms-2 me-2 mt-3 row">
	<div class="custom-control custom-switch">
	  <input type="checkbox" class="custom-control-input whitespace form-check-input" v-model="apply_time">
	  
	  <label class="custom-control-label ms-1 form-check-label">{{apply_time_text}}</label>
	</div>
      </div>
    </div> <!-- action select -->
  </template><!-- modal-body -->
  
  <template v-slot:footer>
    <button v-if="action == 'add'" type="button" @click="add_snapshot" :disabled="disable_add" class="btn btn-primary">{{_i18n("snapshots.add")}}</button>
    <button v-if="action == 'select'" @click="delete_snapshot(true)" type="button" style="text-align: left;margin-left: 0px;" class="btn btn-danger start-0 position-absolute ms-3">{{_i18n("snapshots.delete_all")}}</button>    
    <button v-if="action == 'select'" type="button" @click="delete_snapshot" :disabled="disable_select" class="btn btn-danger">{{_i18n("snapshots.delete")}}</button>
    <button v-if="action == 'select'" type="button" @click="select_snapshot" :disabled="disable_select" class="btn btn-primary">{{_i18n("snapshots.apply")}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const modal_id = ref(null);
const action = ref("add"); // add / select
const showed = () => {};
const snapshot_selected = ref("");
const apply_time = ref(false);
const apply_time_text = ref("");
const save_time = ref(true);
const save_time_text = ref("");
const snapshot_name = ref("");
const snapshots = ref([]);
const order_by = ref("date"); // name / date

const props = defineProps({
    csrf: String,
    page: String,
});

const emit = defineEmits(['added_snapshot', 'deleted_snapshot', 'deleted_all_snapshots']);

let pattern_singleword = NtopUtils.REGEXES.singleword;

const disable_add = computed(() => {
    let rg = new RegExp(pattern_singleword);
    return !rg.test(snapshot_name.value);
});

const disable_select = computed(() => {
    return snapshot_selected.value == "";
});

const show = () => {
    init();
    modal_id.value.show();
};

const update_action = (a) => {
    if (snapshots.value.length == 0 && a == "select") { return; }
    action.value = a;
}

function get_page() {
    if (props.page != null) {
	return props.page;
    }
    let is_alert_stats_url = window.location.toString().match(/alert_stats.lua/) != null;
    let page = "alerts";
    if (!is_alert_stats_url) {
	page = "flows";
    }
    return page;
}

function display_name(snapshot) {
    let utc_ms = snapshot.utc * 1000;
    let date = ntopng_utility.from_utc_to_server_date_format(utc_ms, "DD/MM/YYYY");
    return `${snapshot.name} (${date})`
}

let last_order_by = null;
function sort_snapshots_by() {
    if (last_order_by == order_by.value) { return; }
    
    snapshots.value.sort((a, b) => {
	if (order_by.value == "name") {
	    return a.name.localeCompare(b.name);
	}
	return a.utc - b.utc;
    });
    if (snapshots.value.length > 0) {
	snapshot_selected.value = snapshots.value[0];
    }
    last_order_by = order_by.value;    
}

let load_snapshots = true;
async function init() {
    action.value = "add";
    snapshot_name.value = "";
    save_time.value = true;
    apply_time.value = false;
    let status = ntopng_status_manager.get_status();
    let save_time_filter_text = _i18n("snapshots.save_time");
    let begin_time = ntopng_utility.from_utc_to_server_date_format(status.epoch_begin * 1000, "DD/MM/YYYY HH:mm");
    let end_time = ntopng_utility.from_utc_to_server_date_format(status.epoch_end * 1000, "DD/MM/YYYY HH:mm");
    save_time_filter_text = save_time_filter_text.replace(/\%begin_time/, begin_time);
    save_time_filter_text = save_time_filter_text.replace(/\%end_time/, end_time);
    save_time_text.value = save_time_filter_text;
    let apply_time_filter_text = _i18n("snapshots.apply_time");
    apply_time_filter_text = apply_time_filter_text.replace(/\%begin_time/, begin_time);
    apply_time_filter_text = apply_time_filter_text.replace(/\%end_time/, end_time);
    apply_time_text.value = apply_time_filter_text;
    if (load_snapshots) {
	load_snapshots = false;
	let page = get_page();
	let url = `${http_prefix}/lua/pro/rest/v2/get/filters/snapshots.lua?page=${page}`;
	let snapshots_obj = await ntopng_utility.http_request(url);
	snapshots.value = ntopng_utility.object_to_array(snapshots_obj);
    }
    sort_snapshots_by();
    if (snapshots.value.length > 0) {
	snapshot_selected.value = snapshots.value[0];
    }
}

const add_snapshot = async () => {
    let filters;
    if (save_time.value) {
	filters = ntopng_url_manager.get_url_params();
    } else {
	let params_obj = ntopng_url_manager.get_url_object();
	delete params_obj.epoch_begin;
	delete params_obj.epoch_end;
	filters = ntopng_url_manager.obj_to_url_params(params_obj);
    }
    let page = get_page();
    let params = {
	snapshot_name: snapshot_name.value,
	filters,
	page
    };
    
    params.csrf = props.csrf;
    let url = `${http_prefix}/lua/pro/rest/v2/add/filters/snapshot.lua`;
    try {
	let headers = {
	    'Content-Type': 'application/json'
	};
	await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
	load_snapshots = true;
    } catch(err) {
	console.error(err);
    }
    close();
    emit('added_snapshots', params);
}

const select_snapshot = () => {
    close();    
    let filters = snapshot_selected.value.filters;
    if (apply_time.value == true) {
    	let status = ntopng_status_manager.get_status();
    	let params_obj = ntopng_url_manager.get_url_object(filters);
    	params_obj.epoch_begin = status.epoch_begin;
    	params_obj.epoch_end = status.epoch_end;
    	filters = ntopng_url_manager.obj_to_url_params(params_obj);
    }
    ntopng_url_manager.replace_url_and_reload(filters);
}

const delete_snapshot = async (delete_all) => {
    let name = snapshot_selected.value.name;
    if (delete_all == true) { name = "*"; }
    let page = get_page();
    let params = {
    	snapshot_name: name,
	page,
    };
    params.csrf = props.csrf;
    let url = `${http_prefix}/lua/pro/rest/v2/delete/filters/snapshot.lua`;
    try {
    	let headers = {
    	    'Content-Type': 'application/json'
    	};
    	await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
    	load_snapshots = true;
    } catch(err) {
    	console.error(err);
    }
    if (delete_all == true) {
	emit('deleted_all_snapshots', params);
    } else {
	emit('deleted_snapshot', params);
    }
    close();
}

const close = () => {
    modal_id.value.close();
};


defineExpose({ show, close });

onMounted(() => {
});

const _i18n = (t) => i18n(t);

</script>

<style scoped>
input:invalid {
  border-color: #ff0000;
}
.not-allowed {
  cursor: not-allowed;
}
</style>
