<!-- (C) 2022 - ntop.org     -->
<template>
  <modal @showed="showed()" ref="modal_id">
    <template v-slot:title>{{title}}</template>
    <template v-slot:body>
      <!-- Target information, here an IP is put -->
    
  
      <div  class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-2" >
          <b>{{_i18n("hosts_stats.page_scan_hosts.host")}}</b>
          </label>
          <div class="col-sm-10" >
            <input v-model="host"  @input="check_empty_host" class="form-control" type="text" :placeholder="host_placeholder" required>
          </div>
      </div>
  
      <div class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-2" >
          <b>{{_i18n("hosts_stats.page_scan_hosts.scan_type")}}</b>
          </label>
        <div class="col-10">
          
          <SelectSearch v-model:selected_option="selected_scan_type"
                :options="scan_type_list">
          </SelectSearch> 
        </div> 
      </div>
      
    </template>
    <template v-slot:footer>
      <NoteList
      :note_list="note_list">
      </NoteList>
      <template v-if="is_edit_page == false">
      <button type="button" @click="add_" class="btn btn-primary"  :disabled="disable_add">{{_i18n('add')}}</button>
      </template>
      <template v-else>
      <button type="button" @click="edit_" class="btn btn-primary"  :disabled="disable_add ">{{_i18n('apply')}}</button>
      </template>
    </template>
  </modal>
  </template>
  
<script setup>
import { ref } from "vue";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as NoteList } from "./note-list.vue";
import regexValidation from "../utilities/regex-validation.js";

const modal_id = ref(null);
const selected_scan_type = ref(null);
const emit = defineEmits(['add','edit']);
let title = i18n('hosts_stats.page_scan_hosts.add_host');
const host_placeholder = i18n('if_stats_config.host_placeholder')
const _i18n = (t) => i18n(t);

const disable_add = ref(true)
const is_edit_page = ref(false)



const note_list = [
  _i18n('if_stats_config.note_1'),
  _i18n('if_stats_config.note_2'),
  _i18n('if_stats_config.note_3'),
  _i18n('if_stats_config.note_4'),
  _i18n('if_stats_config.note_5')
]

const scan_type_list = ref([])

const host = ref(null)

const showed = () => {};

const props = defineProps({
  scan_type_list: Array,
  page_csrf: String,
});

const rest_params = {
  csrf: props.page_csrf
}

function reset_radio_selection(radio_array) {

  radio_array.forEach((item) => item.active = item.default_active == true );
}

/**
 * 
 * Reset fields in modal form 
 */
const reset_modal_form = async function() {
    host.value = "";
    selected_scan_type.value = scan_type_list.value[0];
}

/**
 * 
 * Set row to edit 
 */
const set_row_to_edit = (row) => {

  if(row != null) {
    title = _i18n('hosts_stats.page_scan_hosts.edit_host_title');
    is_edit_page.value = true;

    disable_add.value = false;

      //set host
    host.value = row.host;
    
    scan_type_list.value.forEach((item) => {
    if (item.id == row.scan_type) {
        selected_scan_type.value = item;
    }
    })
      
      
    
  }
}

const show = (row) => {
  reset_modal_form();
  if(row != null)
    set_row_to_edit(row);
  
  modal_id.value.show();
};


const check_empty_host = () => {
  let regex = new RegExp(regexValidation.get_data_pattern('ip'));
  disable_add.value = !(regex.test(host.value));
}




/**
 * Function to add rule to rules list
 */
const add_ = (is_edit) => {
  let tmp_host = host.value;
  const tmp_scan_type = selected_scan_type.value.id;

  
  let emit_name = 'add';

  if(is_edit == true) 
    emit_name = 'edit';

  
    debugger;

  emit(emit_name, { 
      host: tmp_host, 
      scan_type: tmp_scan_type, 
  });
  
  close();
};


const edit_ = () => {
  add_(true);
}

const close = () => {
  modal_id.value.close();
};
  
const metricsLoaded = async (_scan_type_list ) => {
  debugger;
  scan_type_list.value = _scan_type_list;
}
    
defineExpose({ show, close, metricsLoaded });
  
</script>
<style scoped>
</style>
    