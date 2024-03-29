<!-- (C) 2023 ntop -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>
    {{ title }}
  </template>
  <template v-slot:body>
    <div class="form-group ms-2 me-2 mt-3 row">
      <label class="col-form-label col-sm-4" >
        <b>{{ _i18n("order_by") }}</b>
      </label>
      <div class="col-sm-8">
        <select class="form-select" @change="sort_files_by()" v-model="order_by">
          <option value="name">{{_i18n("name")}}</option>
          <option value="date">{{_i18n("date")}}</option>
        </select>
      </div>
    </div>
    <div class="form-group ms-2 me-2 mt-3 row">
      <label class="col-form-label col-sm-4" >
        <b>{{ file_title }}</b>
      </label>
      <div class="col-sm-8">
        <SelectSearch v-model:selected_option="file_selected" :options="files">
        </SelectSearch>        
        </div>
      </div>
  </template><!-- modal-body -->
  
  <template v-slot:footer>
    <button @click="delete_file(true)" type="button" style="text-align: left;margin-left: 0px;" class="btn btn-danger start-0 position-absolute ms-3">{{_i18n("delete_all_entries")}}</button>    
    <button type="button" @click="delete_file" :disabled="disable_select" class="btn btn-danger">{{_i18n("delete")}}</button>
    <button type="button" @click="select_file" :disabled="disable_select" class="btn btn-primary">{{_i18n("open")}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";

const modal_id = ref(null);
const showed = () => {};
const file_selected = ref({});
const file_name = ref("");
const files = ref([]);
const order_by = ref("date"); // name / date

const props = defineProps({
    csrf: String,
    title: String,
    file_title: String,
    list_files: Function,
    open_file: Function,
    delete_file: Function,
});

const emit = defineEmits(['file_deleted']);

let pattern_singleword = NtopUtils.REGEXES.singleword;

const disable_select = computed(() => {
    return file_selected.value == "";
});

const show = () => {
    init();
    modal_id.value.show();
};

function display_name(file) {
    let utc_ms = file.epoch * 1000;
    let date = ntopng_utility.from_utc_to_server_date_format(utc_ms, "DD/MM/YYYY");
    return `${file.name} (${date})`
}

function sort_files_by() {
    files.value = files.value.sort((a, b) => {
	if (order_by.value == "name") {
            /* Name asc */
	    return a.name.localeCompare(b.name);
	} else {
            /* Date desc (last first) */
	    return b.epoch - a.epoch;
        }
    });
    if (files.value.length > 0) {
	file_selected.value = files.value[0];
    }
}

async function init() {
    file_name.value = "";
    files.value = await props.list_files();
    files.value.forEach((f) => f.label = display_name(f));
    sort_files_by();
    if (files.value.length > 0) {
	file_selected.value = files.value[0];
    }
}

const select_file = () => {
    close();
    props.open_file(file_selected.value.name);
}

const delete_file = async (delete_all) => {
    let name = file_selected.value.name;
    if (delete_all == true) { name = "*"; }
    if (props.delete_file(name)) {
        emit('file_deleted', name);
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
