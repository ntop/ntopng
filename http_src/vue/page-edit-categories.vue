<!--
  (C) 2026 - ntop.org
-->
<template>
  <div>
    <ModalAddApplication ref="modal_add_application" :page_csrf="props.context.page_csrf" :ifid="props.context.ifid"
      @add="on_add_application" />
    <ModalDeleteApplication ref="modal_delete_application" @remove="on_remove_application" />

    <!-- Applications tab -->
    <div v-if="!apps_hidden" class="alert alert-info mt-2 mb-3">{{ apps_message }}</div>

    <div v-show="activePage === 'protocols'">
      <TableWithConfig ref="applications_table" table_config_id="edit_applications"
        :get_extra_params_obj="getExtraParams" :f_map_columns="mapColumns" :f_sort_rows="columns_sorting"
        @custom_event="on_applications_table_event">

        <!-- Table Selector: Apps or Categories-->
        <template v-slot:custom_header>
          <NavbarTabs :tabs="tabs" :active_tab_id="activePage" @on_click="(tab) => (activePage = tab.id)" />
        </template>

        <!-- Edit or add Application-->
        <template v-slot:custom_buttons>
          <button v-if="props.context.has_protos_file" class="btn btn-link" type="button"
            @click="open_add_application_modal()">
            <i class="fas fa-plus"></i>
          </button>
          <button class="btn btn-link" type="button" @click="download_applications"
            :title="_i18n('download_applications')">
            <i class="fas fa-download"></i>
          </button>
        </template>
      </TableWithConfig>
    </div>

    <!-- Categories tab -->
    <div v-if="!categories_hidden" class="alert alert-info mb-3">{{ categories_message }}</div>

    <div v-show="activePage === 'categories'">
      <TableWithConfig ref="categories_table" table_config_id="edit_categories" :get_extra_params_obj="getExtraParams"
        @custom_event="on_categories_table_event">

        <!-- Table Selector: Apps or Categories-->
        <template v-slot:custom_header>
          <NavbarTabs :tabs="tabs" :active_tab_id="activePage" @on_click="(tab) => (activePage = tab.id)" />
        </template>

        <template v-slot:custom_buttons>
          <button class="btn btn-link" type="button" @click="open_add_category_modal">
            <i class="fas fa-plus"></i>
          </button>
          <button class="btn btn-link" type="button" @click="download_categories" :title="_i18n('download_categories')">
            <i class="fas fa-download"></i>
          </button>
        </template>
      </TableWithConfig>
    </div>

    <!-- Modals -->
    <ModalEditCategory ref="modal_edit_category" @save="on_save_category" />
  </div>
</template>

<script setup>
import { ref } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as ModalAddApplication } from "./modal-add-application.vue";
import { default as ModalEditCategory } from "./modal-edit-category.vue";
import { default as ModalDeleteApplication } from "./modal-delete-application.vue";
import { default as NavbarTabs } from "./components/navbar-tabs.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: Object,
});

const tabs = [
  { id: "protocols", label_i18n: "applications" },
  { id: "categories", label_i18n: "categories" },
];

const activePage = ref(props.context.page_name || "protocols");

// Applications
const applications_table = ref(null);
const modal_add_application = ref(null);
const modal_delete_application = ref(null);
const apps_hidden = ref(true);
let apps_message = "";

// Categories
const categories_table = ref(null);
const modal_edit_category = ref(null);
const categories_hidden = ref(true);
let categories_message = "";

function getExtraParams() {
  return { ifid: props.context.ifid };
}

// Sorting
const SORT_FIELDS = {
  application: { getter: (r) => r.application, fn: sortingFunctions.sortByName },
  category: { getter: (r) => r.category, fn: sortingFunctions.sortByName },
  custom_rules: { getter: (r) => r.custom_rules, fn: sortingFunctions.sortByName },
};

function columns_sorting(col, r0, r1) {
  if (!col) return 0;
  const def = SORT_FIELDS[col.id];
  if (!def) return 0;
  return def.fn(def.getter(r0), def.getter(r1), col.sort);
}

async function mapColumns(columns) {
  const actions = columns.find(c => c.id === "actions");
  if (actions) {
    actions.button_def_array = actions.button_def_array.map(b => {
      // disable edit if not editable
      if (b.id === "edit" && !props.context.has_protos_file) {
        return { ...b, class: ["disabled"] };
      }
      if (b.id === "delete") {
        return {
          ...b,
          f_map_class: (classes, row) => row.is_custom ? classes : [...classes, "d-none"],
        };
      }
      return b;
    });
  }
  return columns;
}

function on_applications_table_event(event) {
  if (event.event_id === "edit_app") open_add_application_modal(event.row);
  if (event.event_id === "delete_app") modal_delete_application.value.show(event.row);
}

async function open_add_application_modal(row) {
  const category_list = await ntopng_utility.http_request(
    `${http_prefix}/lua/rest/v2/get/l7/category/consts.lua`
  );
  if (category_list) modal_add_application.value.loadCategoryList(category_list);
  modal_add_application.value.show(row);
}

const on_add_application = async (params) => {
  const is_edit_page = params.is_edit_page;
  params.is_edit_page = null;

  const url = NtopUtils.buildURL(`${http_prefix}/lua/rest/v2/edit/application/application.lua`, {
    csrf: props.context.page_csrf, ifid: props.context.ifid, ...params,
  });

  await ntopng_utility.http_request(url);
  show_apps_message(_i18n(is_edit_page ? "custom_categories.succesfully_edited" : "custom_categories.succesfully_added"));
  applications_table.value.refresh_table();
};

const on_remove_application = async (params) => {
  const url = NtopUtils.buildURL(`${http_prefix}/lua/rest/v2/delete/application/application.lua`, {
    csrf: props.context.page_csrf, ifid: props.context.ifid, ...params,
  });

  await ntopng_utility.http_request(url);
  show_apps_message(_i18n("custom_categories.succesfully_removed"));
  applications_table.value.refresh_table();
};

function show_apps_message(msg) {
  apps_message = msg;
  apps_hidden.value = false;
  setTimeout(() => { apps_hidden.value = true; }, 4000);
}

function download_applications() {
  window.location.href = `${http_prefix}/lua/rest/v2/get/ndpi/export/protocols.lua`;
}

function on_categories_table_event(event) {
  if (event.event_id === "click_edit_category") {
    modal_edit_category.value.show_edit(event.row);
  }
}

async function open_add_category_modal() {
  const rsp = await ntopng_utility.http_request(
    `${http_prefix}/lua/rest/v2/get/category/list.lua?ifid=${props.context.ifid}`
  );

  if (rsp) modal_edit_category.value.set_category_list(rsp);
  modal_edit_category.value.show_add();
}

async function on_save_category(params) {
  const body = new URLSearchParams({ ...params, csrf: props.context.page_csrf });

  await ntopng_utility.http_request(
    `${http_prefix}/lua/rest/v2/edit/category/category.lua`,
    { method: "POST", body }
  );
  categories_table.value.refresh_table();
}

function download_categories() {
  window.location.href = `${http_prefix}/lua/rest/v2/get/ndpi/export/categories.lua?ifid=${props.context.ifid}`;
}
</script>

<style scoped></style>
