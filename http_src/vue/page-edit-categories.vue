<!--
  (C) 2026 - ntop.org
-->
<template>
  <div>
    <!-- Applications tab -->
    <div v-if="props.context.page_name === 'protocols'">
      <PageEditApplications :context="props.context" />
    </div>

    <!-- Categories tab -->
    <div v-else>
      <div v-if="!hidden_message" class="alert alert-info mb-3">{{ message }}</div>

      <TableWithConfig
        ref="categories_table"
        table_config_id="edit_categories"
        :get_extra_params_obj="getExtraParams"
        @custom_event="on_table_custom_event"
      >
        <template v-slot:custom_buttons>
          <button class="btn btn-link" type="button" @click="open_add_modal">
            <i class="fas fa-plus"></i>
          </button>
          <button class="btn btn-link" type="button" @click="download_categories"
            :title="_i18n('download_categories')">
            <i class="fas fa-download"></i>
          </button>
        </template>
      </TableWithConfig>
    </div>

    <!-- Modal for add / edit categories -->
    <ModalEditCategory ref="modal_edit_category" @save="on_save" />
  </div>
</template>

<script setup>
import { ref } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as PageEditApplications } from "./page-edit-applications.vue";
import { default as ModalEditCategory } from "./modal-edit-category.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: Object,
});

const categories_table    = ref(null);
const modal_edit_category = ref(null);
const hidden_message      = ref(true);
let message = "";

function getExtraParams() {
  return { ifid: props.context.ifid };
}

function on_table_custom_event(event) {
  if (event.event_id === "click_edit_category") {
    modal_edit_category.value.show_edit(event.row);
  }
}

async function open_add_modal() {
  const rsp = await ntopng_utility.http_request(
    `${http_prefix}/lua/rest/v2/get/category/list.lua?ifid=${props.context.ifid}`
  );
  if (rsp) modal_edit_category.value.set_category_list(rsp);
  modal_edit_category.value.show_add();
}

async function on_save(params) {
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
