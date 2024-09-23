<!-- (C) 2022 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>
      {{ _i18n("show_alerts.acknowledge_alert") }}: {{ title_desc }}
    </template>
    <template v-slot:body>
      <div class="form-group row mb-2">
        <div class="col-sm-6">
          <label class="col-form-label"><b>{{ _i18n("show_alerts.add_a_comment") }}</b></label>
        </div>
        <div class="col-sm-6 mt-1">
          <input v-model="comment" class="form-control" type="text" maxlength="255">
        </div>
      </div>
      <AlertInfo :no_close_button="true" ref="alert_info"></AlertInfo>
    </template><!-- modal-body -->

    <template v-slot:footer>
      <button type="button" @click="acknowledge" class="btn btn-primary">{{ _i18n("acknowledge") }}</button>
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
const comment = ref("");
const title_desc = ref("");

const emit = defineEmits(["acknowledge"]);

const props = defineProps({
  context: Object,
  page: String,
});

onMounted(() => {
});

async function acknowledge() {
  let url = `${http_prefix}/lua/rest/v2/acknowledge/${props.page}/alerts.lua`;
  /* The SNMP page is the only exception where the url totally changes */
  if (props.page == 'snmp_device') {
    url = `${http_prefix}/lua/pro/rest/v2/acknowledge/snmp/device/alerts.lua`
  }
  const params = {
    csrf: props.context.csrf,
    ifid: props.context.ifid,
    label: comment.value,
    row_id: alert.value.row_id,
  };
  let headers = {
    'Content-Type': 'application/json'
  };
  await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
  emit("acknowledge");
  close();
}


const alert = ref({});
const show = (_alert) => {
  alert.value = _alert;
  const $type = $(`<span>${_alert.alert_id.label}</span>`);
  title_desc.value = $type.text().trim();
  comment.value = _alert.user_label;

  let message_body = _i18n("show_alerts.confirm_acknowledge_alert");
  alert_info.value.show(message_body, "alert-warning");
  modal_id.value.show();
};

const close = () => {
  modal_id.value.close();
};

defineExpose({ show, close });

</script>
