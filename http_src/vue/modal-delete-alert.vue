<!-- (C) 2022 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>
      {{ _i18n("show_alerts.delete_alert") }}
    </template>
    <template v-slot:body>
      <AlertInfo :no_close_button="true" ref="alert_info"></AlertInfo>
    </template><!-- modal-body -->

    <template v-slot:footer>
      <button type="button" @click="delete_alert" class="btn btn-primary">{{ _i18n("delete") }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";
import { default as AlertInfo } from "./alert-info.vue";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services";

const _i18n = (t) => i18n(t);
const modal_id = ref(null);
const alert_info = ref(null);

const emit = defineEmits(["delete_alert"]);
const alert = ref({});
let status_view = "historical";

const props = defineProps({
  context: Object,
  page: String,
});

onMounted(() => {
});

async function delete_alert() {
  let url = `${http_prefix}/lua/rest/v2/delete/${props.page}/alerts.lua`;
  /* The SNMP page is the only exception where the url totally changes */
  if (props.page == 'snmp_device') {
    url = `${http_prefix}/lua/pro/rest/v2/delete/snmp/device/alerts.lua`
  }
  const params = {
    csrf: props.context.csrf,
    ifid: props.context.ifid,
    status: status_view,
    row_id: alert.value.row_id,
  };
  let headers = {
    'Content-Type': 'application/json'
  };
  await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
  emit("delete_alert");
  close();
}


const show = (_alert, _status_view) => {
  alert.value = _alert;
  status_view = _status_view;
  let message_body = _i18n("show_alerts.confirm_label_alert");
  alert_info.value.show(message_body, "alert-danger");
  modal_id.value.show();
};

const close = () => {
  modal_id.value.close();
};

defineExpose({ show, close });

</script>
