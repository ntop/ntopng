<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>{{title}}</template>
  <template v-slot:body>
      <div class="form-group mb-3 row">
        <label class="col-form-label col-sm-4">{{_i18n('edit_check.device_alias')}}</label>
        <div class="col-sm-7">
          <input type="text" name="custom_name" class="form-control" placeholder="{{_i18n('custom_name')}}" v-model="input_mac_address_name">
        </div>
      </div>
      <div class="form-group mb-3 row">
        <label class="col-form-label col-sm-4">{{_i18n('edit_check.device_status')}}</label>
        <div class="col-sm-7">
          <select name="device_status" class="form-select" v-model="input_device_status">
            <option value="allowed">{{_i18n('allowed')}}</option>
            <option value="denied">{{_i18n('denied')}}</option>
          </select>
        </div>
      </div>
      <div class="form-group mb-3 row">
        <label class="col-form-label col-sm-4 pt-2">{{_i18n('edit_check.trigger_device_disconnected_alert')}}</label>
        <div class="form-switch col-sm-7 pt-2 ps-3">
          <input type="checkbox" class="form-check-input ms-0" v-model="input_trigger_alerts">
        </div>
        <small class="col-form-label">{{_i18n('edit_check.trigger_device_disconnected_alert_descr')}}</small>
      </div>
  </template>
  <template v-slot:footer>
    <button type="button" @click="edit_" class="btn btn-primary">{{_i18n('edit')}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const input_mac_address_name = ref("");
const input_device_status = ref("");
const input_trigger_alerts = ref("");

const modal_id = ref(null);
const emit = defineEmits(['edit'])

const showed = () => {};

const props = defineProps({
    title: String,
});

const show = (row) => {
    input_device_status.value = row.status;
    input_mac_address_name.value = row.mac_address_label.label;
    input_trigger_alerts.value = row.trigger_alert || false;
    modal_id.value.show();
};

const edit_ = () => {
    emit('edit', { mac_alias: input_mac_address_name.value, mac_status: input_device_status.value, trigger_alerts: input_trigger_alerts.value });
    close();
};

const close = () => {
    modal_id.value.close();
};


defineExpose({ show, close });

onMounted(() => {
});

const _i18n = (t) => i18n(t);

</script>

<style scoped>
</style>
