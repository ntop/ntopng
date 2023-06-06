<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>
    <template v-if="edit_all == false">
      {{title}}
    </template>
    <template v-else>
      {{ title_edit_all }}
    </template>
    
  </template>
  <template v-slot:body>
      <template v-if="edit_all == false">

      <div class="form-group mb-3 row">
        <label class="col-form-label col-sm-4">{{ _i18n('edit_check.device_alias') }}</label>
        <div class="col-sm-7">
          <input type="text" name="custom_name" class="form-control" :placeholder="custom_name_placeholder"
            v-model="input_mac_address_name">
        </div>

      </div>
      </template>

      <div class="form-group mb-3 row">
        <label class="col-form-label col-sm-4">{{ _i18n('edit_check.device_status') }}</label>
        <div class="col-sm-7">
          <select name="device_status" class="form-select" v-model="input_device_status">
            <option value="allowed">{{ _i18n('allowed') }}</option>
            <option value="denied">{{ _i18n('denied') }}</option>
          </select>
        </div>
      </div>
      <div class="form-group mb-3 row">
        <label class="col-form-label col-sm-4 pt-2">{{ _i18n('edit_check.trigger_device_disconnected_alert') }}</label>
        <div class="form-switch col-sm-7 pt-2 ps-3">
          <input type="checkbox" class="form-check-input ms-0" v-model="input_trigger_alerts">
        </div>
        <small class="col-form-label">{{ _i18n('edit_check.trigger_device_disconnected_alert_descr') }}</small>
      </div>
    </template>
    <template v-slot:footer>
      <button type="button" @click="edit_" class="btn btn-primary">{{ _i18n('edit') }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const input_mac_address_name = ref("");
const input_device_status = ref("");
const input_trigger_alerts = ref("");

const custom_name_placeholder = ref(i18n('if_stats_config.custom_name'));
const modal_id = ref(null);
const emit = defineEmits(['edit']);

const showed = () => { };

const props = defineProps({
    title: String,
    title_edit_all: String,
});

const edit_all = ref(false);

const show = (row) => {
    if(row != null) {
      input_device_status.value = row.status;
      input_mac_address_name.value = row.mac_address.mac;
      input_trigger_alerts.value = row.trigger_alert || false;
    } else {
      edit_all.value = true;
    }
    
    modal_id.value.show();
};

const edit_ = () => {
    if(edit_all.value == false)
      emit('edit', { mac_alias: input_mac_address_name.value, mac_status: input_device_status.value, trigger_alerts: input_trigger_alerts.value });
    else 
      emit('edit', { mac_status: input_device_status.value, trigger_alerts: input_trigger_alerts.value });

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

<style scoped></style>
