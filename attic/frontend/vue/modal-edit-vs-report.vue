<!-- (C) 2023 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>{{ title }}</template>
    <template v-slot:body>
      <!-- Target information, here an IP is put -->
      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("hosts_stats.page_scan_hosts.reports_page.date") }}</b>
        </label>
        <div class="col-sm-10">
          <input v-model="report_date" :disabled="true" class="form-control" type="text" />
        </div>
      </div>

      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("hosts_stats.page_scan_hosts.reports_page.name") }}</b>
        </label>
        <div class="col-sm-10">
          <input v-model="report_name"  class="form-control" type="text" @input="check_title"  required />
        </div>
      </div>
      

      <div class="mt-4">
          <NoteList :note_list="note_list"> </NoteList>
      </div>
    </template>

    <template v-slot:footer>
      
      <div>
        <button type="button" @click="edit_" :disabled="!(is_report_name_correct)" class="btn btn-primary">
          {{ _i18n("apply") }}
        </button>
      </div>
    </template>
  </modal>
</template>

<script setup>
/* Imports */
import { ref } from "vue";
import { default as modal } from "./modal.vue";
import { default as NoteList } from "./note-list.vue";
import regexValidation from "../utilities/regex-validation.js";


/* ****************************************************** */

const _i18n = (t) => i18n(t);
const emit = defineEmits(["add", "edit"]);
const props = defineProps({
  context: Object,
});

/* Consts */
const title = ref(i18n("hosts_stats.page_scan_hosts.reports_page.edit_report"));

const modal_id = ref(null);
const report_date = ref(null);
const report_name = ref(null);
const row_to_edit = ref(null);

const is_report_name_correct = ref(false);

const note_list = [
  _i18n("hosts_stats.page_scan_hosts.reports_page.notes.note_1"),
];
/* ****************************************************** */

/*
 * Reset fields in modal form
 */
const reset_modal_form = function () {
  report_date.value = "";
  report_name.value = "";
  row_to_edit.value = null;
  is_report_name_correct.value = false; 
  
};

/* ****************************************************** */

/*
 * Set row to edit
 */
const set_row_to_edit = (row) => {

  row_to_edit.value = row;
  /* Set host values */
  report_date.value = row.report_date;
  report_name.value = row.name;

};

/* ****************************************************** */

/* This method is called whenever the modal is opened */
const show = (row) => {
  /* First of all reset all the data */
  reset_modal_form();
  set_row_to_edit(row)

  modal_id.value.show();
};

/* ****************************************************** */


/* ****************************************************** */

/* Function called when the edit button is clicked */
const edit_ = () => {
  const tmp_report_date = row_to_edit.value.epoch;
  const tmp_name = report_name.value.replaceAll(" ", "_");

  emit("edit", {
      report_title: tmp_name,
      epoch_end: tmp_report_date
    });
  
    modal_id.value.close();
};

/* ****************************************************** */

/* Function called when the modal is closed */
const close = () => {
  modal_id.value.close();
};

/* ****************************************************** */



/* ****************************************************** */

const check_title = () => {
  // Handle empty input
  if (!report_name.value || report_name.value.trim() === "") {
    is_report_name_correct.value = false;
    return;
  }

  const name = report_name.value.trim();
  
  // Only allow alphanumeric characters, spaces, hyphens, and underscores
  const safeCharacterPattern = /^[a-zA-Z0-9\s\-_]+$/;
  
  const sqlInjectionPatterns = [
    /['"`]/,           // Single quotes, double quotes, backticks
    /[;]/,             // Semicolon
    /--/,              // SQL comments
    /\/\*/,            // Multi-line comment start
    /\*\//,            // Multi-line comment end
    /\b(union|select|insert|update|delete|drop|create|alter|exec|execute)\b/i, // SQL keywords
    /[<>]/,            // HTML/XML tags (XSS prevention)
    /[\\]/,            // Backslashes
    /\x00/,            // Null bytes
  ];
  
  const containsOnlySafeChars = safeCharacterPattern.test(name);
  const containsSqlInjection = sqlInjectionPatterns.some(pattern => pattern.test(name));
  
  // length check
  const isReasonableLength = name.length > 0 && name.length <= 100;
  
  is_report_name_correct.value = containsOnlySafeChars && !containsSqlInjection && isReasonableLength;
};

defineExpose({ show, close });
</script>
