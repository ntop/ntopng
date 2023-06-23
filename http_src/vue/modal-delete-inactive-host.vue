<!-- (C) 2022 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>
      {{ _i18n("delete_inactive_host_title") }}
    </template>
    <template v-slot:body>
    {{ message }}
    </template><!-- modal-body -->

    <template v-slot:footer>
      <button type="button" @click="delete_host" class="btn btn-primary">{{ _i18n("delete") }}</button>
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

const emit = defineEmits(["delete_host"]);
const row_id = ref({});

const props = defineProps({
  context: Object,
});

onMounted(() => {});

async function delete_host() {
  const url = `${http_prefix}/lua/rest/v2/delete/host/inactive_host.lua`;
  const params = {
    csrf: props.context.csrf,
    ifid: props.context.ifid,
    serial_key: row_id.value,
  };

  debugger;
  let headers = {
    'Content-Type': 'application/json'
  };
  await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
  emit("delete_host");
  close();
}


const show = (_row_id, _message) => {
  row_id.value = _row_id;
  message.value = _message;
  modal_id.value.show();
};

const close = () => {
  modal_id.value.close();
};

defineExpose({ show, close });

</script>
