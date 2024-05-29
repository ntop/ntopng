<!-- (C) 2022 - ntop.org     -->
<template>
  <modal @showed="showed()" ref="modal_id">
    <template v-slot:title>{{ title }}</template>
    <template v-slot:body>
      <!-- Target information, here an IP is put -->
      <div class="custom-file">
        <label class='form-label' for='import-input'>
          {{ _i18n("browse_snmp_devices", {}) }}
        </label>
        <input required class="custom-file-input form-control" ref="import_input" id="import-input" name="CSV"
          type="file" @change="handleFileUpload" accept=".json,.csv" />

      </div>

    </template>

    <template v-slot:footer>
      <NoteList :note_list="note_list"> </NoteList>
      <div v-if="is_data_not_ok" class="me-auto text-danger d-inline">
        {{ message }}
      </div>
      <Spinner :show="activate_import_spinner" size="1rem" class="me-2"></Spinner>

      <button type="button" :disabled="!is_not_empty_file" @click="_import"
        class="btn btn-primary">{{ _i18n('import') }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onBeforeMount } from "vue";
import { default as modal } from "./modal.vue";
import { default as Spinner } from "./spinner.vue";
import { default as NoteList } from "./note-list.vue";

const modal_id = ref(null);
const emit = defineEmits(['add', 'edit']);
const _i18n = (t) => i18n(t);
const activate_import_spinner = ref(false);
const is_data_not_ok = ref(false);
const is_not_empty_file = ref(false);
let title = _i18n('snmp.import_devices');
let message = "";
const max_size = 131072;
const json_file = ref(null);
const import_input = ref(null);

const note_list = [
  i18n("snmp.snmp_import_devices_json"),
  i18n("snmp.snmp_import_devices_csv"),
  i18n("snmp.snmp_import_devices_csv2"),
  i18n("snmp.snmp_import_devices_issues")
];

const showed = () => { };

const props = defineProps({
  ifid_list: Array,
  snmp_devices_list: Array,
  snmp_metric_list: Array,
  frequency_list: Array,
  init_func: Function,
  page_csrf: String,
});

/**
 * 
 * Reset fields in modal form 
 */
const reset_modal_form = function () {
  json_file.value = null;
  activate_import_spinner.value = false;
  is_data_not_ok.value = false;
  is_not_empty_file.value = false;
  import_input.value.value = null;
}

const show = (row) => {
  reset_modal_form();
  modal_id.value.show();
};

const handleFileUpload = (event) => {
  json_file.value = event.target.files[0];
  const size = json_file.value.size;
  is_not_empty_file.value = json_file.value != null && size < max_size; //128KB
  if (size > max_size) {
    is_data_not_ok.value = true;
    message = _i18n("file_to_large")
  } else {
    is_data_not_ok.value = false;
    message = "";
  }
}

/**
 * Function to add rule to rules list
 */
const _import = (is_edit) => {
  activate_import_spinner.value = true;
  is_data_not_ok.value = false;
  const fileReader = new FileReader();
  fileReader.readAsText(json_file.value, "UTF-8");

  fileReader.onload = () => {
    // Set file content to data property
    const is_json = fileReader.result.contains('\"')

    if (is_json) {
      emit('add', {
        devices: fileReader.result
      });
    } else {
      emit('add', {
        devices_csv: fileReader.result
      })
    }


  };
};

const show_bad_feedback = (bad_message) => {
  message = bad_message;
  is_data_not_ok.value = true;
  activate_import_spinner.value = false;
};

const close = () => {
  activate_import_spinner.value = false;
  is_data_not_ok.value = false;
  modal_id.value.close();
};

defineExpose({ show, close, show_bad_feedback });

</script>

<style scoped></style>