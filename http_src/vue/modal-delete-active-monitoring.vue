<!-- (C) 2022 - ntop.org     -->
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
      <button type="button" @click="delete_measurement" class="btn btn-danger">{{ _i18n("delete") }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as modal } from "./modal.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services";

const _i18n = (t) => i18n(t);
const modal_id = ref(null);
const message = ref('')
const return_message = ref('')
const show_return_msg = ref(false)
const title = ref('')
const err = ref(false);
const row = ref(null);

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
async function formatMessage(_row) {
  title.value = `${i18n("delete")}: ${i18n("active_monitoring_page." + _row.last_measurement.measurement_type)} ${_row.target.name}`
  message.value = i18n('active_monitoring_page.delete');
}

/* ****************************************** */

/* This function runs the delete code, called when apply is clicked */
async function delete_measurement() {
  const url = `${http_prefix}/lua/rest/v2/delete/active_monitoring/measurement.lua`;
  let params = {
    csrf: props.context.csrf,
    ifid: props.context.ifid,
    am_host: row.value.target.host,
    measurement: row.value.last_measurement.measurement_type,
  };

  const res = await ntopng_utility.http_post_request(url, params);
  if (res) {
    close();
  }
}

const show = (_row) => {
  resetModal();
  row.value = _row;
  formatMessage(_row);
  modal_id.value.show();
};

const close = () => {
  setTimeout(() => {
    modal_id.value.close();
    emit("delete");
  }, 500 /* 0.5 seconds */)
};

defineExpose({ show, close });

</script>
