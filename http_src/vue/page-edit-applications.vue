<!--
  (C) 2013-26 - ntop.org
-->

<template>
  <div>
    <div v-if="!hidden" class="alert alert-info mb-3">{{ message }}</div>

    <ModalAddApplication
      ref="modal_add_application"
      :page_csrf="props.context.page_csrf"
      :ifid="props.context.ifid"
      @add="_add"
    />
    <ModalDeleteApplication ref="modal_delete_application" @remove="_remove" />

    <TableWithConfig
      ref="applications_table"
      table_config_id="edit_applications"
      :get_extra_params_obj="getExtraParams"
      :f_map_columns="mapColumns"
      :f_sort_rows="columns_sorting"
      @custom_event="on_table_event"
    >
      <template v-slot:custom_buttons>
        <button v-if="props.context.has_protos_file" class="btn btn-link" type="button"
          @click="open_add_modal()">
          <i class="fas fa-plus"></i>
        </button>
        <button class="btn btn-link" type="button" @click="download"
          :title="_i18n('download_applications')">
          <i class="fas fa-download"></i>
        </button>
      </template>
    </TableWithConfig>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as ModalAddApplication } from "./modal-add-application.vue";
import { default as ModalDeleteApplication } from "./modal-delete-application.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

const _i18n = (t) => i18n(t);

const props = defineProps({ context: Object });

const applications_table     = ref(null);
const modal_add_application  = ref(null);
const modal_delete_application = ref(null);
const hidden  = ref(true);
let message = '';

function getExtraParams() {
  return { ifid: props.context.ifid };
}

// ── sorting ───────────────────────────────────────────────────────────────────
const SORT_FIELDS = {
  application:  { getter: (r) => r.application,  fn: sortingFunctions.sortByName },
  category:     { getter: (r) => r.category,     fn: sortingFunctions.sortByName },
  custom_rules: { getter: (r) => r.custom_rules, fn: sortingFunctions.sortByName },
};

function columns_sorting(col, r0, r1) {
  if (!col) return 0;
  const def = SORT_FIELDS[col.id];
  if (!def) return 0;
  return def.fn(def.getter(r0), def.getter(r1), col.sort);
}

// ── f_map_columns — conditional delete + disabled edit ───────────────────────
async function mapColumns(columns) {
  const actions = columns.find(c => c.id === 'actions');
  if (actions) {
    actions.button_def_array = actions.button_def_array.map(b => {
      if (b.id === 'edit' && !props.context.has_protos_file) {
        return { ...b, class: ['disabled'] };
      }
      if (b.id === 'delete') {
        return {
          ...b,
          f_map_class: (classes, row) => row.is_custom ? classes : [...classes, 'd-none'],
        };
      }
      return b;
    });
  }
  return columns;
}

// ── event handling ────────────────────────────────────────────────────────────
function on_table_event(event) {
  if (event.event_id === 'edit_app')   open_add_modal(event.row);
  if (event.event_id === 'delete_app') modal_delete_application.value.show(event.row);
}

async function open_add_modal(row) {
  const category_list = await ntopng_utility.http_request(
    `${http_prefix}/lua/rest/v2/get/l7/category/consts.lua`
  );
  if (category_list) modal_add_application.value.loadCategoryList(category_list);
  modal_add_application.value.show(row);
}

const _add = async (params) => {
  const is_edit_page = params.is_edit_page;
  params.is_edit_page = null;
  const url = NtopUtils.buildURL(`${http_prefix}/lua/rest/v2/edit/application/application.lua`, {
    csrf: props.context.page_csrf, ifid: props.context.ifid, ...params,
  });
  await ntopng_utility.http_request(url);
  show_message(i18n(is_edit_page ? 'custom_categories.succesfully_edited' : 'custom_categories.succesfully_added'));
  applications_table.value.refresh_table();
};

const _remove = async (params) => {
  const url = NtopUtils.buildURL(`${http_prefix}/lua/rest/v2/delete/application/application.lua`, {
    csrf: props.context.page_csrf, ifid: props.context.ifid, ...params,
  });
  await ntopng_utility.http_request(url);
  show_message(i18n('custom_categories.succesfully_removed'));
  applications_table.value.refresh_table();
};

function show_message(msg) {
  message = msg;
  hidden.value = false;
  setTimeout(() => { hidden.value = true; }, 4000);
}

function download() {
  window.location.href = `${http_prefix}/lua/rest/v2/get/ndpi/export/protocols.lua`;
}
</script>
