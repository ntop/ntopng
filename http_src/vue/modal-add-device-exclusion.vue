<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>{{title}}</template>
  <template v-slot:body>
    <div class="form-group mb-3 row">
      <label class="col-form-label col-sm-4">{{body}}</label>
      <div class="col-sm-7">
        <textarea name="items-list" id="itemslist-textarea" class="w-100 form-control" rows="6" v-model="input_mac_list"></textarea>
          <small>{{list_notes}}</small>
        <div class="invalid-feedback"></div>
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
    {{_i18n('host_details.notes')}}:
    {{footer}}
    <button type="button" @click="add_" class="btn btn-primary">{{_i18n('add')}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const input_mac_list = ref("");
const input_trigger_alerts = ref("");

const modal_id = ref(null);
const emit = defineEmits(['add'])

const showed = () => {};

const props = defineProps({
    body: String,
    title: String,
    footer: String,
    list_notes: String,
});

const show = () => {
    input_mac_list.value = "";
    modal_id.value.show();
};

const add_ = () => {
    emit('add', { mac_list: input_mac_list.value, trigger_alerts: input_trigger_alerts.value });
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
