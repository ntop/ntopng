<!-- (C) 2026 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>
      {{ title }}
    </template>
    <template v-slot:body>
      {{ message }}
      <div v-if="show_return_msg" class="text-left">
      </div>
    </template><!-- modal-body -->
    <template v-slot:footer>
      <button type="button" @click="delete_site" class="btn btn-danger">{{ _i18n("delete") }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted, nextTick } from "vue";
import { default as modal } from "./modal.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { ntopng_utility } from "../services/context/ntopng_globals_services";

const _i18n = (t) => i18n(t);
const modal_id = ref(null);
const message = ref('')
const return_message = ref('')
const show_return_msg = ref(false)
const title = ref('')
const err = ref(false);
const row = ref(null);
const exporter_site_id = ref(null);
const delete_exporter_site_url = `${http_prefix}/lua/pro/rest/v2/delete/exporter_site/exporter_site.lua`;

const emit = defineEmits(["delete"]);

const props = defineProps({
  context: Object,
});

onMounted(() => { });

/* ****************************************** */

/* This function simply reset the modal to factory values */
async function resetModal() {
  row.value = null;
  message.value = '';
  return_message.value = '';
  show_return_msg.value = false;
  err.value = false;
  title.value = '';
}

/* ****************************************** */

/* This function formats the delete message */
async function formatMessage(site) {
  title.value = i18n("exporter_sites_page.delete_exporter_site_title")
  if (site) {
    const site_name = site.exporter_site_name;
    title.value = title.value + ": " + site_name;
  }
  message.value = i18n('exporter_sites_page.delete_exporter_site');
}

/* ****************************************** */

async function delete_site() {
  const formData = {
    exporter_site_id: exporter_site_id.value,
    delete: true
  };
  emit("delete", formData);
}


const showDelete = async (item) => {
  resetModal();
  exporter_site_id.value = item.exporter_site_id;
  formatMessage(item);
  modal_id.value.show();
};

const close = () => {
  setTimeout(() => {
    modal_id.value.close();
  }, 500 /* 0.5 seconds */)
};

defineExpose({ showDelete, close });

</script>
