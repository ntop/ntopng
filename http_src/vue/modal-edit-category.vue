<!-- (C) 2026 - ntop.org -->
<template>
  <modal @showed="showed()" ref="modal_id">
    <template v-slot:title>{{ title }}</template>
    <template v-slot:body>
      <template v-if="!is_edit_mode">
        <div class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-4">
            <b>{{ _i18n("category") }}</b>
          </label>
          <div class="col-8">
            <SelectSearch v-model:selected_option="selected_category" :options="category_options" />
          </div>
        </div>
      </template>
      <template v-else>
        <div class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-4">
            <b>{{ _i18n("category") }}</b>
          </label>
          <div class="col-8">
            <input class="form-control" type="text" :value="category_name_display" readonly>
          </div>
        </div>
      </template>

      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-4">
          <b>{{ _i18n("custom_categories.category_name") }}</b>
        </label>
        <div class="col-8">
          <input class="form-control" type="text" v-model="category_alias" spellcheck="false">
        </div>
      </div>

      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-4">
          <b>{{ _i18n("custom_categories.custom_hosts") }}</b>
        </label>
        <div class="col-8">
          <textarea class="form-control" v-model="hosts_list" rows="8" spellcheck="false"></textarea>
        </div>
      </div>
    </template>
    <template v-slot:footer>
      <NoteList :note_list="note_list" />
      <button type="button" @click="save_" class="btn btn-primary">{{ _i18n("save") }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref } from "vue";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as NoteList } from "./note-list.vue";

const _i18n = (t) => i18n(t);

const modal_id = ref(null);
const emit = defineEmits(["save"]);

const is_edit_mode = ref(false);
const title = ref("");
const category_name_display = ref("");
const category_alias = ref("");
const hosts_list = ref("");
const selected_category = ref({});
const category_options = ref([]);
let current_category_id = null;

const note_list = [
  _i18n("custom_categories.each_host_separate_line"),
  _i18n("custom_categories.host_domain_or_cidr"),
];

const showed = () => {};

const reset = () => {
  category_alias.value = "";
  hosts_list.value = "";
  current_category_id = null;
};

const show_add = () => {
  reset();
  is_edit_mode.value = false;
  title.value = i18n("custom_categories.add_to_categories");
  if (category_options.value.length > 0) {
    selected_category.value = category_options.value[0];
  }
  modal_id.value.show();
};

const show_edit = (row) => {
  reset();
  is_edit_mode.value = true;
  title.value = i18n("custom_categories.edit_custom_rules");
  current_category_id = row.column_category_id;
  category_name_display.value = row.column_category_name;
  category_alias.value = row.column_category_name;
  if (row.column_category_hosts) {
    hosts_list.value = row.column_category_hosts.split(",").join("\n");
  }
  modal_id.value.show();
};

const set_category_list = (list) => {
  const formatted = list
    .map((item) => ({
      id: item.column_category_id,
      label: item.column_category_name,
    }))
    .sort((a, b) => {
      if (!a.label) return -1;
      if (!b.label) return 1;
      return a.label.toString().localeCompare(b.label.toString());
    });
  category_options.value = formatted;
  if (formatted.length > 0) {
    selected_category.value = formatted[0];
  }
};

const save_ = () => {
  const cat_id = is_edit_mode.value
    ? current_category_id
    : selected_category.value?.id;

  const unique_hosts = [];
  hosts_list.value.split("\n").forEach((host) => {
    host = host.trim();
    if (host && unique_hosts.indexOf(host) === -1) {
      unique_hosts.push(host);
    }
  });

  emit("save", {
    category: "cat_" + cat_id,
    category_alias: category_alias.value,
    custom_hosts: unique_hosts.join(","),
  });

  modal_id.value.close();
};

defineExpose({ show_add, show_edit, set_category_list });
</script>

<style scoped></style>
